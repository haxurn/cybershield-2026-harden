set +e
echo "== ftp client removal (28712) =="
DEBIAN_FRONTEND=noninteractive apt-get -y remove ftp >/dev/null 2>&1; echo "ftp: $(dpkg -l ftp 2>/dev/null | grep -c '^ii')"
echo "== apport off (28531) =="
systemctl stop apport 2>/dev/null; systemctl disable apport 2>/dev/null; sed -i 's/^enabled=.*/enabled=0/' /etc/default/apport 2>/dev/null; grep -q '^enabled=0' /etc/default/apport 2>/dev/null && echo apport_off
echo "== apparmor (28533/28534) =="
DEBIAN_FRONTEND=noninteractive apt-get -y install apparmor apparmor-utils >/dev/null 2>&1
systemctl enable --now apparmor >/dev/null 2>&1; aa-status --enabled 2>/dev/null && echo apparmor_enabled
echo "== chrony (28546) =="
DEBIAN_FRONTEND=noninteractive apt-get -y install chrony >/dev/null 2>&1
systemctl enable --now chrony >/dev/null 2>&1; echo "chrony: $(systemctl is-active chrony)"
echo "== journal-remote pkg (28614) =="
DEBIAN_FRONTEND=noninteractive apt-get -y install systemd-journal-remote >/dev/null 2>&1; echo "jr: $(dpkg -l systemd-journal-remote 2>/dev/null | grep -c '^ii')"
echo "== banners (28538/28539) =="
BANNER='Authorized uses only. All activity may be monitored and reported.'
echo "$BANNER" > /etc/issue; echo "$BANNER" > /etc/issue.net
chown root:root /etc/issue /etc/issue.net; chmod 644 /etc/issue /etc/issue.net
echo "== /dev/shm hardening (28523) =="
if ! grep -q '/dev/shm' /etc/fstab; then echo 'tmpfs /dev/shm tmpfs defaults,noexec,nodev,nosuid,seclabel 0 0' >> /etc/fstab; fi
mount -o remount,noexec,nodev,nosuid /dev/shm 2>/dev/null && echo devshm_ok
echo "== grub.cfg perms (28528) =="
chown root:root /boot/grub/grub.cfg 2>/dev/null; chmod 600 /boot/grub/grub.cfg 2>/dev/null; ls -l /boot/grub/grub.cfg 2>/dev/null | awk '{print $1}'
echo "== cron dir perms (28627-28631) =="
for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do chown root:root $d; chmod 700 $d; done
chmod 700 /etc/cron.d 2>/dev/null; ls -ld /etc/cron.daily | awk '{print $1}'
echo "== misc perms (28750/28751) =="
[ -f /etc/shells ] && { chown root:root /etc/shells; chmod 644 /etc/shells; }
[ -f /etc/security/opasswd ] && { chown root:root /etc/security/opasswd; chmod 600 /etc/security/opasswd; } || { touch /etc/security/opasswd; chown root:root /etc/security/opasswd; chmod 600 /etc/security/opasswd; }
echo "== password aging (28665/28666/28668) =="
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 365/; s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/; s/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs
grep -q '^PASS_MAX_DAYS' /etc/login.defs || echo 'PASS_MAX_DAYS 365' >> /etc/login.defs
useradd -D -f 30 2>/dev/null
grep -E '^PASS_(MAX|MIN|WARN)' /etc/login.defs | tr '\n' ' '; echo
echo "== pwquality (28661/28730/28731) =="
DEBIAN_FRONTEND=noninteractive apt-get -y install libpam-pwquality >/dev/null 2>&1
cat > /etc/security/pwquality.conf <<'Q'
minlen = 14
minclass = 4
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
dictcheck = 1
enforcing = 1
Q
echo "pwquality set"
echo "== auditd space warning (28749) =="
sed -i 's/^space_left_action.*/space_left_action = email/; s/^admin_space_left_action.*/admin_space_left_action = single/' /etc/audit/auditd.conf
echo "== audit rules (28599-28605) =="
cat > /etc/audit/rules.d/50-cis-extra.rules <<'R'
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change
-w /etc/localtime -p wa -k time-change
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/networks -p wa -k system-locale
-w /etc/network/ -p wa -k system-locale
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock -p wa -k logins
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy
-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation
-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation
R
augenrules --load >/dev/null 2>&1
echo "audit rules loaded: $(auditctl -l 2>/dev/null | wc -l) rules"
echo "== sshd extras (28645/28648/28650/28653/28717) =="
cat >> /etc/ssh/sshd_config.d/00-cis.conf <<'S'
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
MaxStartups 10:30:60
ClientAliveInterval 15
ClientAliveCountMax 3
DisableForwarding yes
Banner /etc/issue.net
S
if sshd -t 2>/tmp/e; then systemctl reload ssh && echo "sshd reloaded OK"; else echo "SSHD BAD, reverting extras"; sed -i '/^MACs \|^MaxStartups \|^ClientAliveInterval \|^ClientAliveCountMax \|^DisableForwarding \|^Banner /d' /etc/ssh/sshd_config.d/00-cis.conf; cat /tmp/e; fi
sshd -T 2>/dev/null | grep -iE '^macs|^maxstartups|^clientaliveinterval|^banner |^disableforwarding' | tr '\n' ' '; echo
echo "UBU_BONUS_DONE"
