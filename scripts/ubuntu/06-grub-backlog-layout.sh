# 28593: wazuh rule is  not f:/etc/default/grub -> !r:audit_backlog_limit=\d+
# negated pattern is tested per line, so ANY line without audit_backlog_limit=N fails it.
# so: /etc/default/grub keeps only the cmdline line, everything else moves to
# /etc/default/grub.d/00-defaults.cfg. grub-mkconfig sources both, result must be identical
# and I check that before keeping it. grub.cfg itself is not touched, no update-grub needed.
set -u
G=/etc/default/grub; D=/etc/default/grub.d/00-defaults.cfg
if [ "$(grep -vcE 'audit_backlog_limit=[0-9]+' $G)" = 0 ]; then echo "already done"; echo GRUB_LAYOUT_DONE; exit 0; fi
grep -qE '^GRUB_CMDLINE_LINUX=.*audit_backlog_limit=[0-9]+' $G || { echo "no audit_backlog_limit in GRUB_CMDLINE_LINUX, run 01-base.sh first"; exit 1; }
[ -e $D ] && { echo "$D already exists, not overwriting"; exit 1; }

vars(){ ( . $G; for f in /etc/default/grub.d/*.cfg; do . $f; done; set | grep '^GRUB_' ); }
vars > /tmp/grubvars.pre; grub-mkconfig 2>/dev/null > /tmp/grubcfg.pre
cp -p $G /etc/default/grub.bak-cis

grep -vE '^GRUB_CMDLINE_LINUX=' $G > $D; chmod 644 $D
{ echo "# other grub defaults moved to $D, this file only keeps audit_backlog_limit=8192 (CIS 28593)"
  grep -E '^GRUB_CMDLINE_LINUX=' /etc/default/grub.bak-cis; } > $G.new
chmod 644 $G.new; mv $G.new $G

vars > /tmp/grubvars.post; grub-mkconfig 2>/dev/null > /tmp/grubcfg.post
if diff -q /tmp/grubvars.pre /tmp/grubvars.post >/dev/null && diff -q /tmp/grubcfg.pre /tmp/grubcfg.post >/dev/null && [ -s /tmp/grubcfg.post ]; then
  echo "effective grub config identical ($(wc -l < /tmp/grubcfg.post) lines generated, vars same)"
else
  echo "DIFFERENT, rolling back"; cp -p /etc/default/grub.bak-cis $G; rm -f $D; exit 1
fi
echo "-- $G"; cat $G
echo "lines without the param: $(grep -vcE 'audit_backlog_limit=[0-9]+' $G)"
echo GRUB_LAYOUT_DONE
