$e='SilentlyContinue'
function G($p,$n){ (Get-ItemProperty -Path $p -Name $n -EA $e).$n }
"NoDriveTypeAutoRun=" + (G 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun')
"RunAsPPL=" + (G 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL')
"RDP-MinEnc=" + (G 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' 'MinEncryptionLevel')
"LLMNR=" + (G 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast')
"NoConnectedUser=" + (G 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'NoConnectedUser')
"lockout=" + ((net accounts | Select-String 'lockout threshold') -replace '\D','')
"Kerb-audit:"; auditpol /get /subcategory:"Kerberos Authentication Service" | Select-String 'Kerberos'
