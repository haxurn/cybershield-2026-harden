# 28656: wazuh rule for /etc/sudoers.d has a broken filename pattern (no r: prefix) so it
# never sees cis-sudolog. the /etc/sudoers rule works, so put the same line there too.
set -u
L='Defaults	logfile=/var/log/sudo.log'
if grep -qE '^\s*Defaults\s+logfile=' /etc/sudoers; then echo "already in /etc/sudoers"; else
  cp -p /etc/sudoers /etc/sudoers.bak-cis
  t=$(mktemp)
  # right after the last Defaults line so it sits with the others
  n=$(grep -nE '^\s*Defaults' /etc/sudoers | tail -1 | cut -d: -f1)
  if [ -n "$n" ]; then sed "${n}a $L" /etc/sudoers > $t; else { cat /etc/sudoers; echo "$L"; } > $t; fi
  if visudo -cf $t >/dev/null; then install -m 440 -o root -g root $t /etc/sudoers; echo "added"
  else echo "INVALID, /etc/sudoers not touched"; rm -f $t; exit 1; fi
  rm -f $t
fi
visudo -c || { echo "full check failed, restoring"; cp -p /etc/sudoers.bak-cis /etc/sudoers; exit 1; }
touch /var/log/sudo.log; chown root:root /var/log/sudo.log; chmod 600 /var/log/sudo.log
grep -nE '^\s*Defaults' /etc/sudoers
echo SUDOLOG_MAIN_DONE
