set +e
# canonical unquoted form + ensure log file exists
printf 'Defaults logfile=/var/log/sudo.log\n' > /etc/sudoers.d/cis-sudolog
chmod 440 /etc/sudoers.d/cis-sudolog
visudo -cf /etc/sudoers.d/cis-sudolog && echo "sudoers valid" || { echo "INVALID - reverting"; printf 'Defaults logfile="/var/log/sudo.log"\n' > /etc/sudoers.d/cis-sudolog; chmod 440 /etc/sudoers.d/cis-sudolog; }
touch /var/log/sudo.log; chown root:root /var/log/sudo.log; chmod 600 /var/log/sudo.log
sudo -n true 2>/dev/null   # generate a sudo log entry
echo "content:"; cat /etc/sudoers.d/cis-sudolog
echo "logfile:"; ls -l /var/log/sudo.log
echo SUDOLOG_FIX_DONE
