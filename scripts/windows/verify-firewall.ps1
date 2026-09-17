Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction,LogBlocked | Format-Table -Auto | Out-String
