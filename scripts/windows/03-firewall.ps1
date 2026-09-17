$ErrorActionPreference='Continue'
$ports = Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -lt 49152 } | Select-Object -Expand LocalPort -Unique
foreach($p in $ports){
  if(-not (Get-NetFirewallRule -DisplayName "HardenAllow-TCP-$p" -ErrorAction SilentlyContinue)){
    New-NetFirewallRule -DisplayName "HardenAllow-TCP-$p" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $p -Profile Any | Out-Null
  }
}
$uports = Get-NetUDPEndpoint | Where-Object { $_.LocalPort -lt 49152 } | Select-Object -Expand LocalPort -Unique
foreach($p in $uports){
  if(-not (Get-NetFirewallRule -DisplayName "HardenAllow-UDP-$p" -ErrorAction SilentlyContinue)){
    New-NetFirewallRule -DisplayName "HardenAllow-UDP-$p" -Direction Inbound -Action Allow -Protocol UDP -LocalPort $p -Profile Any | Out-Null
  }
}
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$env:systemroot\System32\LogFiles\Firewall" -Force | Out-Null
Set-NetFirewallProfile -Profile Domain  -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -LogBlocked True -LogFileName "%systemroot%\System32\LogFiles\Firewall\domainfw.log" -LogMaxSizeKilobytes 16384
Set-NetFirewallProfile -Profile Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -LogBlocked True
Set-NetFirewallProfile -Profile Public  -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -LogBlocked True
Write-Output "FW_DONE"
