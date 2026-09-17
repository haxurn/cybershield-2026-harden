# CyberShield 2026 - Harden Day

My notes + scripts from harden day. 6 servers to lock down (4 Windows, 2 Ubuntu), scored by
Wazuh SCA. 30 CIS controls per Windows box, 15 per Ubuntu box, plus bonus stuff on top.

Where it stands: everything is applied and I checked every required service is still up.
Core is 30/30 on all four Windows boxes. Ubuntu has one check per box (28593) that can't
pass because the Wazuh rule itself is broken, details under "fixes after the first real
scan". `scripts/wazuh/check-passes.sh` shows the live numbers, SCA rescans every 10 min.

## the boxes

| Host     | IP          | OS           | How I get in | What runs there |
|----------|-------------|--------------|--------------|-----------------|
| DC-1     | 10.10.1.100 | Win 2019     | RDP / WinRM  | DC for conda.local, DNS, AD |
| DB-1     | 10.10.1.111 | Win 2019     | RDP / WinRM  | SQL Server 1433, SMB |
| SERVER-1 | 10.10.1.30  | Win 2019     | RDP / WinRM  | member server |
| SERVER-2 | 10.10.1.13  | Win 2019     | RDP / WinRM  | member server |
| WEB-1    | 10.10.0.181 | Ubuntu 22.04 | SSH          | apache2 |
| WEB-2    | 10.10.0.103 | Ubuntu 22.04 | SSH          | GitLab, vsftpd, apache2, monitoring |
| Wazuh    | 10.10.1.200 | -            | HTTPS, read only | SCA dashboard |

VPN first: `sudo openvpn --config haxurn.ovpn` (comes up as tun0).

Creds are NOT in this repo. They sit in `creds.env` next to this file (gitignored), same as
the .pem and the .ovpn. `source creds.env` before running any script, they read
WINUSER / WINPASS / WPASS from the environment.

All 4 Windows boxes are joined to conda.local, so I use the domain admin everywhere. One
login for all of them, and no local account UAC token filtering to fight with.
Ubuntu is user `ubuntu` with the .pem key, sudo needs no password.

## what I did

### Windows, 30 controls x 4 hosts
All pushed over WinRM (5985) with pywinrm. The ID to registry/command mapping is in
`scripts/windows/CONTROLS.md`.

- Account and access: min password length 14, force advanced audit policy, hide last signed
  in user, 900s inactivity lock, no anonymous SAM/share enum, don't store network creds,
  Admin Approval Mode for the builtin admin, elevation prompt on secure desktop, auto deny
  elevation for standard users.
- Firewall: all 3 profiles on, inbound block, outbound allow, log dropped packets. Before
  flipping to block, the script makes an allow rule for every port that is currently
  listening and turns on the RDP + WinRM rule groups (AD/DNS/Kerberos groups too on the DC).
  That is what keeps me from locking myself out. Checked after: 3389 and 5985 open on all,
  1433 on DB-1, 88/389/636/3268/53 on DC-1, domain auth still fine.
- Auditing with auditpol: Credential Validation, User Account Mgmt, Other Logon/Logoff,
  File Share, Sensitive Privilege Use = success+failure. Process Creation = success.
  Account Lockout = failure. Authorization Policy Change = success. Set exactly like CIS
  wants, more is not better here, the check compares the exact value.
- SMB / RDP / PowerShell: SMBv1 client driver off (mrxsmb10 Start=4), SMBv1 server off,
  cmdline in process creation events, NLA required for RDP, PS script block logging and
  transcription.

### Ubuntu, 15 controls x 2 hosts
Over SSH. Mapping in `scripts/ubuntu/CONTROLS.md`.

- telnet client removed. auditd installed and enabled, `max_log_file=8`,
  `max_log_file_action=keep_logs`, sudoers watch in `/etc/audit/rules.d/50-scope.rules`,
  `audit_backlog_limit=8192` in grub.
- `/etc/crontab` and `sshd_config` to 600. Root login off, MaxAuthTries 4, LoginGraceTime 60,
  all in a drop-in `/etc/ssh/sshd_config.d/00-cis.conf`. Sudo log in `/etc/sudoers.d/cis-sudolog`.
- UFW: allow every listening port, loopback rules (4.1.4), FTP conntrack helper, then default
  deny and enable. Checked SSH, HTTP, HTTPS, FTP from outside, GitLab answers 200/302,
  vsftpd + apache2 + gitlab all active. 3000/8080/9090/9100 on WEB-2 are bound to 127.0.0.1
  so I left them alone.

## fixes after the first real scan

Config looked right on the boxes but SCA still said Failed on a few. Two real mismatches
between what I set and what the Wazuh check actually reads, plus one broken rule:

1. Windows firewall checks (16577, 16578, 16579, 16583, 16585, 16586, 16593) read the Group
   Policy registry, not the live firewall store. `Set-NetFirewallProfile` alone does nothing
   for them. `bonus/fw-gpo-registry.txt` writes
   `HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\{Domain,Private,Public}Profile`
   (EnableFirewall=1, DefaultInboundAction=1, DefaultOutboundAction=0, logging).
   `bonus/fw-localmerge.txt` sets AllowLocalPolicyMerge=1, without it my local RDP/WinRM
   allow rules stop applying once the policy keys exist. Tested across a `gpupdate`, both
   stayed open.
2. Ubuntu 28577 (CIS 4.1.7) wants default deny on incoming AND outgoing AND routed. I had
   outgoing on allow. `03-ufw-deny-outgoing.sh` adds allow-out for the Wazuh agent
   (10.10.1.200 1514/1515), 10.10.0.0/16, DNS, NTP, HTTP/S, DHCP, then
   `ufw default deny outgoing`. Replies to inbound connections still pass (established /
   related), so nothing facing outside broke. Agent still reporting, GitLab 302.

3. 28656 (sudo logfile). My line in `/etc/sudoers.d/cis-sudolog` was fine, quoted or not, the
   check just can't see it. The policy has two rules for it, one for `/etc/sudoers` and one
   for `/etc/sudoers.d`. The sudoers.d one is written `d:/etc/sudoers.d -> \.* -> ...` with no
   `r:` in front of the filename pattern (61 other dir rules in the same policy have it), so
   Wazuh looks for a file literally called `\.*` and never finds one. Fix is
   `05-sudolog-main-sudoers.sh`: same Defaults line goes into `/etc/sudoers` itself, built in
   a temp copy and only installed if `visudo -cf` likes it. Backup at `/etc/sudoers.bak-cis`.

Still failing and I'm leaving it: 28593 (audit_backlog_limit). The value is set in
`/etc/default/grub` and it's in grub.cfg. The rule is
`not f:/etc/default/grub -> !r:audit_backlog_limit=\d+`. Wazuh runs a negated pattern line by
line, so this only passes when EVERY line of the file has `audit_backlog_limit=N` in it.
No real config can do that. I could stuff a comment onto every line to make it go green but
that's dressing the file up for a broken check. One to raise with the organizers.

## bonus

Extra hardening past the 45 core. Bonus is capped at 2.5 points (0.1 each) and I applied way
more than 25 items so a few not matching doesn't matter. Organizers have to approve bonus
credit.

Rule I followed: only things that can't break access or a required service.

Skipped on purpose:
- NTLM/LM auth level, NTLM min session security, SMB signing required, LDAP signing /
  channel binding. Any of these can break domain auth or SMB/LDAP clients.
- Disabling Print Spooler or other services. "Allow Remote Shell Access = Disabled" (kills
  my own WinRM). Turning on Windows Update (upgrades are not allowed). Disabling IPv6.
- Ubuntu: partition/mount controls (needs reinstall), nftables/iptables controls (rules say
  UFW only), removing apache/rsync (required), sshd AllowUsers (breaks GitLab git over SSH),
  sudo password (breaks my passwordless automation and I don't have the password anyway),
  pam faillock / bootloader password (lockout and boot risk), auditd halt when full.

Windows, about 100 items per host:
- `bonus/10-audit-extra.ps1`: 16 more audit subcategories (Kerberos, PNP, Directory Service,
  Group Membership, Detailed File Share, Removable Storage, MPSSVC, IPsec, Security System
  Extension...).
- `bonus/11-lockout.ps1`: lockout threshold 5, duration 15, window 15.
- `bonus/reg-batch-a.txt` (38 entries): MSS settings (source routing, SafeDllSearchMode,
  SEHOP, NetBT, TCP retransmits, screensaver grace), LLMNR/mDNS off, insecure guest logons
  off, font providers off, P2P off, network bridge/ICS restrictions, autorun/autoplay off,
  lock screen camera/slideshow off, advertising ID, location, OneDrive, cloud search off.
- `bonus/reg-batch-b.txt` (42 entries): RDP (single session, no COM/drive/LPT/PnP redirect,
  always prompt for password, secure RPC, TLS security layer, high encryption, idle 15m,
  disconnect 1m), Defender (network protection, PUA, behavior/script scan, removable/email
  scan, SmartScreen), event log sizes, VBS/Credential Guard policy, LSASS RunAsPPL, cached
  logons 4, block MS accounts, no shutdown without logon, legal notice.
- pushed with `bonus/runreg.py <ip> <batch.txt> <chunk>`. It chunks because pywinrm has a
  size limit on the encoded command.

Ubuntu, `bonus/10-bonus.sh` on both:
ftp client removed, apport off, apparmor + chrony installed and enabled,
systemd-journal-remote, login banners (/etc/issue, issue.net, sshd Banner), /dev/shm with
noexec,nodev,nosuid, grub.cfg 600, cron dirs 700, /etc/shells and opasswd perms, password
aging in login.defs (max 365, min 1, warn 7, inactive 30), libpam-pwquality (minlen 14, all
classes, dictcheck, enforcing), auditd space warning actions, CIS audit rules (time-change,
system-locale, identity, session, logins, MAC-policy, user-emulation), sshd MACs /
MaxStartups / ClientAlive / DisableForwarding. Every sshd change runs `sshd -t` first and
rolls back if it fails.

## layout

```
creds.env                     creds, gitignored
scripts/windows/
  run.py                      pywinrm runner: python3 run.py <ip> <script.ps1>
  01-base-part1.ps1           account/access + first auditpol, run 1st
  02-base-part2.ps1           SMB/RDP/PS registry + rest of auditpol, run 2nd
  00-base-full-reference.ps1  both parts in one file, reference only, too big for one WinRM call
  03-firewall.ps1             firewall for member servers, run 3rd
  03-firewall-DC.ps1          firewall for DC-1, adds AD/DNS/Kerberos groups
  verify-quick.ps1            one line per host
  verify-base.ps1             full dump of base values
  verify-firewall.ps1         firewall profile dump
  CONTROLS.md                 control ID -> what I set
  bonus/
    10-audit-extra.ps1, 11-lockout.ps1
    reg-batch-a.txt, reg-batch-b.txt     registry batches
    fw-gpo-registry.txt, fw-localmerge.txt   the firewall SCA fix
    runreg.py                 chunked registry pusher
    verify-bonus.ps1
scripts/ubuntu/
  00-survey.sh                ports, services, sshd, auditd inventory
  01-base.sh                  the 14 non firewall controls, run 1st
  02-ufw.sh                   UFW default deny with listening ports allowed, run 2nd
  03-ufw-deny-outgoing.sh     deny outgoing fix for 28577
  04-sudolog-canonical.sh     unquoted sudo logfile + create the log
  05-sudolog-main-sudoers.sh  the real 28656 fix, logfile line in /etc/sudoers
  bonus/10-bonus.sh
  CONTROLS.md
scripts/wazuh/
  sca-status.sh               pass/fail per host, give it a host to list failed IDs
  check-passes.sh             knows every control ID I set, shows Passed/Failed per host
RUNBOOK.md                    exact commands to redo everything
```

## gotchas

- pywinrm `run_ps` cuts a big script short and you get a parse error with no hint why.
  That's why base is split into part1 + part2. Don't merge them into one call.
- No reboots. SCA reads registry / config / grub.cfg directly so it passes without one.
  `audit_backlog_limit` only goes live in the kernel after a reboot, but grub.cfg already has
  the value and that's what the check looks at.
- Don't touch the Wazuh agent, SCA policy files, agent keys or Wazuh services. Against the rules.
- Firewall scripts are safe to run again, they rebuild the allow rules from whatever is
  listening at that moment.
- Order matters. Windows: part1, part2, firewall. Ubuntu: base, then UFW.

## checking results

No browser needed. `check-passes.sh` pulls SCA through the dashboard's OpenSearch proxy with
the read only user:

```
./check-passes.sh                 summary + core per host
./check-passes.sh DC-1            core + bonus detail for one host
./check-passes.sh --bonus         bonus detail for all
./check-passes.sh --failed DB-1   everything still failed on a host
./check-passes.sh --id 16502      one check across all hosts
```

Wait ~10 min after a change before trusting it.
