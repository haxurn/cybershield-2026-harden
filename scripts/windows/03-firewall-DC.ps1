$ErrorActionPreference='Continue'
$ports = Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -lt 49152 } | Select-Object -Expand LocalPort -Unique
foreach($p in $ports){ if(-not (Get-NetFirewallRule -DisplayName "HardenAllow-TCP-$p" -ErrorAction SilentlyContinue)){ New-NetFirewallRule -DisplayName "HardenAllow-TCP-$p" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $p -Profile Any | Out-Null } }
$uports = Get-NetUDPEndpoint | Where-Object { $_.LocalPort -lt 49152 } | Select-Object -Expand LocalPort -Unique
foreach($p in $uports){ if(-not (Get-NetFirewallRule -DisplayName "HardenAllow-UDP-$p" -ErrorAction SilentlyContinue)){ New-NetFirewallRule -DisplayName "HardenAllow-UDP-$p" -Direction Inbound -Action Allow -Protocol UDP -LocalPort $p -Profile Any | Out-Null } }
foreach($g in @("Remote Desktop","Windows Remote Management","Active Directory Domain Services","DNS Service","Kerberos Key Distribution Center","File and Printer Sharing","Core Networking","Windows Management Instrumentation (WMI)")){ Enable-NetFirewallRule -DisplayGroup $g -ErrorAction SilentlyContinue }
# allow dynamic RPC inbound for lsass/dns/svchost so AD replication+RPC keeps working under default-block
New-NetFirewallRule -DisplayName "HardenAllow-RPC-Dynamic-TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort RPC -Profile Any -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path "$env:systemroot\System32\LogFiles\Firewall" -Force | Out-Null
Set-NetFirewallProfile -Profile Domain  -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -LogBlocked True -LogFileName "%systemroot%\System32\LogFiles\Firewall\domainfw.log" -LogMaxSizeKilobytes 16384
Set-NetFirewallProfile -Profile Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -LogBlocked True
Set-NetFirewallProfile -Profile Public  -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -LogBlocked True
Write-Output "FW_DONE"
