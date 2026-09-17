$e='SilentlyContinue'
$m=(net accounts | Select-String 'Minimum password length') -replace '\D',''
$sbl=(Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name EnableScriptBlockLogging -EA $e).EnableScriptBlockLogging
$nla=(Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name UserAuthentication -EA $e).UserAuthentication
$fw=(Get-NetFirewallProfile | ForEach-Object {"$($_.Name):$($_.Enabled)/$($_.DefaultInboundAction)/$($_.LogBlocked)"}) -join ' '
Write-Output ("$env:COMPUTERNAME minpw=$m sbl=$sbl nla=$nla FW[$fw]")



