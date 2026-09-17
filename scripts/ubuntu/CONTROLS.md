# Ubuntu CIS control mapping (15 controls, WEB-1 + WEB-2)

Applied via SSH (user ubuntu, sudo). Script column: which file sets it.

## 01-base.sh
| # | Wazuh ID | CIS | Control | Implementation |
|---|----------|-----|---------|----------------|
| 1  | 28570 | 2.2.4 | Remove telnet client | `apt-get remove -y telnet` |
| 4  | 28590 | 6.3.1.1 | Install auditd | `apt-get install -y auditd audispd-plugins` |
| 5  | 28591 | 6.3.1.2 | Enable+start auditd | `systemctl enable --now auditd` |
| 6  | 28593 | 6.3.1.4 | Audit backlog limit | grub `audit_backlog_limit=8192` + update-grub |
| 7  | 28594 | 6.3.2.1 | Audit log size | auditd.conf `max_log_file = 8` |
| 8  | 28595 | 6.3.2.2 | No auto-delete audit logs | auditd.conf `max_log_file_action = keep_logs` |
| 9  | 28597 | 6.3.3.1 | Audit sudoers changes | rules.d/50-scope.rules watch /etc/sudoers[.d] + augenrules |
| 10 | 28626 | 2.4.1.2 | /etc/crontab perms | `chown root:root; chmod 600` |
| 11 | 28634 | 5.1.1 | sshd_config perms | `chown root:root; chmod 600` |
| 12 | 28638 | 5.1.20 | Disable SSH root login | dropin `PermitRootLogin no` |
| 13 | 28649 | 5.1.16 | SSH MaxAuthTries | dropin `MaxAuthTries 4` |
| 14 | 28652 | 5.1.13 | SSH LoginGraceTime | dropin `LoginGraceTime 60` |
| 15 | 28656 | 5.2.3 | Dedicated sudo log | /etc/sudoers.d/cis-sudolog `Defaults logfile=/var/log/sudo.log` |

SSH directives go in `/etc/ssh/sshd_config.d/00-cis.conf` (read first via the Include at the
top of sshd_config, so it wins in `sshd -T`). Validated with `sshd -t` before `systemctl reload ssh`.

## 02-ufw.sh
| # | Wazuh ID | CIS | Control | Implementation |
|---|----------|-----|---------|----------------|
| 2 | 28576 | 4.1.4 | UFW loopback | allow in/out on lo; deny in from 127.0.0.0/8; deny in from ::1 |
| 3 | 28577 | 4.1.7 | UFW default deny (in+out+routed) | 02-ufw.sh allows listening ports; 03-ufw-deny-outgoing.sh adds safe allow-out (Wazuh 1514, /16, DNS/NTP/HTTP/S) then `ufw default deny outgoing`. SCA needs deny on incoming AND outgoing AND routed. |

SAFETY: allows every listening TCP/UDP port (SSH/HTTP/HTTPS/FTP/GitLab/etc.) + vsftpd passive
range if configured + nf_conntrack_ftp helper, BEFORE default-deny, so no service is cut off.

## Bonus
See ../../README.md "BONUS controls" and bonus/10-bonus.sh (safe extras: apparmor, chrony,
audit rules, banners, /dev/shm, cron perms, password aging, pwquality, sshd MACs/timeouts).
