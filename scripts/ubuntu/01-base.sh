set +e
echo "== 1 remove telnet client =="
DEBIAN_FRONTEND=noninteractive apt-get -y remove telnet >/dev/null 2>&1; dpkg -l telnet 2>/dev/null | grep -q '^ii' && echo "telnet STILL PRESENT" || echo "telnet removed"
echo "== 4/5 auditd install+enable =="
if ! dpkg -l auditd 2>/dev/null | grep -q '^ii'; then DEBIAN_FRONTEND=noninteractive apt-get -y install auditd audispd-plugins >/dev/null 2>&1; fi
systemctl enable --now auditd >/dev/null 2>&1
echo "auditd: $(systemctl is-enabled auditd) $(systemctl is-active auditd)"
echo "== 7/8 auditd.conf log size + keep =="
sed -i 's/^\s*max_log_file\s*=.*/max_log_file = 8/' /etc/audit/auditd.conf
grep -q '^max_log_file =' /etc/audit/auditd.conf || echo 'max_log_file = 8' >> /etc/audit/auditd.conf
sed -i 's/^\s*max_log_file_action\s*=.*/max_log_file_action = keep_logs/' /etc/audit/auditd.conf
grep -q '^max_log_file_action = keep_logs' /etc/audit/auditd.conf || echo 'max_log_file_action = keep_logs' >> /etc/audit/auditd.conf
grep -E '^max_log_file' /etc/audit/auditd.conf
echo "== 9 audit sudoers changes =="
cat > /etc/audit/rules.d/50-scope.rules <<'R'
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope
R
augenrules --load >/dev/null 2>&1
auditctl -l 2>/dev/null | grep -i sudoers || echo "sudoers watch NOT active"
echo "== 6 grub audit_backlog_limit =="
if ! grep -q 'audit_backlog_limit=' /etc/default/grub; then
  sed -i 's/^\(GRUB_CMDLINE_LINUX="[^"]*\)"/\1 audit_backlog_limit=8192"/' /etc/default/grub
fi
grep '^GRUB_CMDLINE_LINUX=' /etc/default/grub
update-grub >/dev/null 2>&1 && echo "grub updated" || echo "grub update FAILED"
grep -o 'audit_backlog_limit=[0-9]*' /boot/grub/grub.cfg | head -1
echo "== 10 crontab perms =="
chown root:root /etc/crontab; chmod 600 /etc/crontab; ls -l /etc/crontab
echo "== 11 sshd_config perms =="
chown root:root /etc/ssh/sshd_config; chmod 600 /etc/ssh/sshd_config; ls -l /etc/ssh/sshd_config
echo "== 12/13/14 sshd hardening via dropin =="
cat > /etc/ssh/sshd_config.d/00-cis.conf <<'S'
PermitRootLogin no
MaxAuthTries 4
LoginGraceTime 60
S
chmod 600 /etc/ssh/sshd_config.d/00-cis.conf
if sshd -t 2>/tmp/ssherr; then systemctl reload ssh && echo "sshd reloaded OK"; else echo "SSHD CONFIG BAD:"; cat /tmp/ssherr; fi
sshd -T 2>/dev/null | grep -iE '^permitrootlogin|^maxauthtries|^logingracetime'
echo "== 15 sudo dedicated logfile =="
echo 'Defaults logfile="/var/log/sudo.log"' > /etc/sudoers.d/cis-sudolog
chmod 440 /etc/sudoers.d/cis-sudolog
visudo -cf /etc/sudoers.d/cis-sudolog && echo "sudoers OK" || rm -f /etc/sudoers.d/cis-sudolog
echo "BASE_UBU_DONE"
