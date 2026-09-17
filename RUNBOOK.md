# Runbook - redo / verify everything

Run from the repo root. VPN (tun0) has to be up.

## before anything
```bash
pip install pywinrm
chmod 600 cybershield-2026-harden-final-3-40.pem
source creds.env        # WINUSER / WINPASS / WPASS, scripts die without it
WIN="10.10.1.100 10.10.1.111 10.10.1.30 10.10.1.13"
MEMBERS="10.10.1.111 10.10.1.30 10.10.1.13"
UBU="10.10.0.181 10.10.0.103"
KEY=$PWD/cybershield-2026-harden-final-3-40.pem
```
(zsh: use `for H in ${=WIN}` or the loops won't split the list)

## Windows core, order matters
```bash
cd scripts/windows
for H in $WIN; do
  python3 run.py $H 01-base-part1.ps1     # account/access + auditpol part 1
  python3 run.py $H 02-base-part2.ps1     # SMB/RDP/PS + auditpol part 2
done
# DC gets its own firewall script, members get the plain one
python3 run.py 10.10.1.100 03-firewall-DC.ps1
for H in $MEMBERS; do python3 run.py $H 03-firewall.ps1; done
```

Then the firewall SCA fix (checks read the GPO registry keys). Localmerge FIRST, so the
RDP/WinRM allow rules keep applying once the policy keys land:
```bash
cd bonus
for H in $WIN; do
  python3 runreg.py $H fw-localmerge.txt 10
  python3 runreg.py $H fw-gpo-registry.txt 10
done
cd ..
```

Am I still in?
```bash
for H in $WIN; do for p in 3389 5985; do
  timeout 4 bash -c "</dev/tcp/$H/$p" 2>/dev/null && echo "$H:$p OPEN" || echo "$H:$p closed"
done; done
```

Verify:
```bash
for H in $WIN; do python3 run.py $H verify-quick.ps1; done
python3 run.py 10.10.1.13 verify-base.ps1        # full dump, one host
python3 run.py 10.10.1.13 verify-firewall.ps1
```

## Windows bonus
```bash
cd bonus
for H in $WIN; do
  python3 ../run.py $H 10-audit-extra.ps1
  python3 ../run.py $H 11-lockout.ps1
  python3 runreg.py $H reg-batch-a.txt 10
  python3 runreg.py $H reg-batch-b.txt 10
  python3 ../run.py $H verify-bonus.ps1
done
cd ../../..
```
Each runreg run should end with `APPLIED n/n entries`. If a chunk fails, lower the chunk size.

## Ubuntu, base then UFW then the fixes
```bash
cd scripts/ubuntu
for H in $UBU; do
  for S in 01-base.sh 02-ufw.sh 03-ufw-deny-outgoing.sh 04-sudolog-canonical.sh 05-sudolog-main-sudoers.sh; do
    ssh -i "$KEY" -o StrictHostKeyChecking=no ubuntu@$H 'sudo bash -s' < $S
  done
done
```
After 02 and again after 03, open a NEW ssh session to each box before closing the old one.
If UFW ate SSH you want to find out while you still have a shell. Same after 05, run
`sudo -n true` in a fresh session to be sure sudoers is still good.

Bonus + survey:
```bash
for H in $UBU; do ssh -i "$KEY" ubuntu@$H 'sudo bash -s' < bonus/10-bonus.sh; done
ssh -i "$KEY" ubuntu@10.10.0.103 'sudo bash -s' < 00-survey.sh
cd ../..
```

Services I check on WEB-2 after any firewall change: gitlab answers 200/302, vsftpd and
apache2 active, Wazuh agent still reporting.

## did I get the points
```bash
scripts/wazuh/check-passes.sh              # summary, core per host
scripts/wazuh/check-passes.sh --failed DC-1
scripts/wazuh/check-passes.sh --id 16577
```
Or in the browser: `https://10.10.1.200` (self signed, click through), user `team_readonly`,
Configuration Assessment -> pick server -> search the check ID. Scans run about every
10 min, so wait, refresh, and look for Failed -> Passed.

## don't
- touch the Wazuh agent, its config, SCA files, keys or services
- change IPs, hostnames or domain membership
- disable a required service just to pass a check
- reboot unless there is no other way
