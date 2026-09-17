echo "== HOST =="; hostname
echo "== LISTEN TCP =="; sudo ss -tlnp | awk 'NR>1{print $4}' | sed 's/.*://' | sort -un | tr '\n' ' '; echo
echo "== LISTEN UDP =="; sudo ss -ulnp | awk 'NR>1{print $4}' | sed 's/.*://' | sort -un | tr '\n' ' '; echo
echo "== UFW =="; sudo ufw status verbose 2>&1 | head -20
echo "== telnet pkg =="; dpkg -l telnet 2>/dev/null | grep '^ii' || echo none
echo "== auditd =="; dpkg -l auditd 2>/dev/null | grep '^ii' | awk '{print $2,$3}'; systemctl is-enabled auditd 2>/dev/null; systemctl is-active auditd 2>/dev/null
echo "== ssh include =="; grep -nE '^Include|^\s*Include' /etc/ssh/sshd_config; echo "-- dropins --"; ls -l /etc/ssh/sshd_config.d/ 2>/dev/null; echo "-- effective --"; sudo sshd -T 2>/dev/null | grep -iE '^permitrootlogin|^maxauthtries|^logingracetime'
echo "== perms =="; ls -l /etc/crontab /etc/ssh/sshd_config
echo "== services =="; systemctl list-units --type=service --state=running 2>/dev/null | grep -iE 'gitlab|nginx|apache|vsftpd|ftp|mysql|postgres|docker' | awk '{print $1}' | tr '\n' ' '; echo
echo "== grub audit =="; grep -o 'audit_backlog_limit=[0-9]*' /etc/default/grub || echo "no backlog in grub"
