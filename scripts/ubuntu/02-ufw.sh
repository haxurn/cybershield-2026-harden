set +e
# FTP conntrack helper so passive FTP survives default-deny
if grep -q '^IPT_MODULES=' /etc/default/ufw; then
  grep -q 'nf_conntrack_ftp' /etc/default/ufw || sed -i 's/^IPT_MODULES="/IPT_MODULES="nf_conntrack_ftp nf_nat_ftp /' /etc/default/ufw
fi
# allow every listening TCP service port
for p in $(ss -tlnH | awk '{print $4}' | sed 's/.*://' | sort -un); do ufw allow ${p}/tcp >/dev/null 2>&1; done
# allow listening UDP (keep DNS etc), skip dhcp client 68
for p in $(ss -ulnH | awk '{print $4}' | sed 's/.*://' | sort -un); do [ "$p" = "68" ] && continue; ufw allow ${p}/udp >/dev/null 2>&1; done
# passive FTP range if vsftpd configures one
PMIN=$(grep -oP '^pasv_min_port=\K[0-9]+' /etc/vsftpd.conf 2>/dev/null)
PMAX=$(grep -oP '^pasv_max_port=\K[0-9]+' /etc/vsftpd.conf 2>/dev/null)
[ -n "$PMIN" ] && [ -n "$PMAX" ] && ufw allow ${PMIN}:${PMAX}/tcp >/dev/null 2>&1 && echo "allowed pasv $PMIN:$PMAX"
# loopback (CIS 4.1.4)
ufw allow in on lo >/dev/null 2>&1
ufw allow out on lo >/dev/null 2>&1
ufw deny in from 127.0.0.0/8 >/dev/null 2>&1
ufw deny in from ::1 >/dev/null 2>&1
# defaults (CIS 4.1.7)
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1
ufw status verbose
echo UFW_DONE

# NOTE: Wazuh SCA check 28577 (CIS 4.1.7) requires default deny on incoming AND
# outgoing AND routed. Run 03-ufw-deny-outgoing.sh AFTER this to flip outgoing to
# deny while allowing the Wazuh agent path (10.10.1.200:1514), internal /16, DNS,
# NTP, HTTP/S, DHCP outbound so nothing breaks.
