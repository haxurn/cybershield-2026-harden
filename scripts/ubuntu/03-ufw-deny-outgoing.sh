set +e
# CRITICAL: allow Wazuh agent + internal + essential outbound BEFORE denying outgoing
ufw allow out to 10.10.0.0/16 >/dev/null 2>&1          # internal incl Wazuh manager 10.10.1.200:1514/1515
ufw allow out to any port 53 >/dev/null 2>&1           # DNS
ufw allow out 53/udp >/dev/null 2>&1
ufw allow out 123/udp >/dev/null 2>&1                  # NTP
ufw allow out 80/tcp >/dev/null 2>&1                   # HTTP (apt, webhooks)
ufw allow out 443/tcp >/dev/null 2>&1                  # HTTPS
ufw allow out 853/tcp >/dev/null 2>&1                  # DoT
ufw allow out 67/udp >/dev/null 2>&1                   # DHCP
ufw allow out 68/udp >/dev/null 2>&1
ufw default deny outgoing >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1
ufw reload >/dev/null 2>&1
echo "--- ufw defaults ---"; ufw status verbose | grep -i default
echo "--- agent -> manager 1514 reachable? ---"; timeout 5 bash -c '</dev/tcp/10.10.1.200/1514' 2>/dev/null && echo "1514 OK" || echo "1514 FAIL"
echo "--- external DNS/HTTP test ---"; getent hosts archive.ubuntu.com >/dev/null 2>&1 && echo "dns OK" || echo "dns check inconclusive"
echo "--- wazuh agent status ---"; systemctl is-active wazuh-agent 2>/dev/null || /var/ossec/bin/wazuh-control status 2>/dev/null | grep -i agentd | head -1
echo DENYOUT_DONE
