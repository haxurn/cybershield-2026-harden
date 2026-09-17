$ErrorActionPreference = 'Continue'
function RegSet($path,$name,$val,$type='DWord'){
  if(-not (Test-Path $path)){ New-Item -Path $path -Force | Out-Null }
  New-ItemProperty -Path $path -Name $name -Value $val -PropertyType $type -Force | Out-Null
}
# --- Account & access ---
# 1 (16502) Min password length 14
net accounts /minpwlen:14 | Out-Null
secedit /export /cfg C:\Windows\Temp\sec.inf | Out-Null
(Get-Content C:\Windows\Temp\sec.inf) -replace 'MinimumPasswordLength = .*','MinimumPasswordLength = 14' | Set-Content C:\Windows\Temp\sec2.inf
secedit /configure /db C:\Windows\Temp\sec.sdb /cfg C:\Windows\Temp\sec2.inf /areas SECURITYPOLICY | Out-Null
# 2 (16511) SCENoApplyLegacyAuditPolicy
RegSet 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'SCENoApplyLegacyAuditPolicy' 1
# 3 (16527) DontDisplayLastUserName
RegSet 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'DontDisplayLastUserName' 1
# 4 (16528) InactivityTimeoutSecs 900
RegSet 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'InactivityTimeoutSecs' 900
# 5 (16543) RestrictAnonymous (no anon enum SAM+shares)
RegSet 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymous' 1
# 6 (16544) DisableDomainCreds (do not store creds)
RegSet 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'DisableDomainCreds' 1
# 7 (16567) FilterAdministratorToken (Admin Approval Mode built-in admin)
RegSet 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'FilterAdministratorToken' 1
# 8 (16568) PromptOnSecureDesktop
RegSet 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'PromptOnSecureDesktop' 1
# 9 (16569) ConsentPromptBehaviorUser=0 (deny standard user elevation)
RegSet 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorUser' 0
# --- Auditing (auditpol) ---
auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable | Out-Null       # 17
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable | Out-Null      # 18
auditpol /set /subcategory:"Process Creation" /success:enable /failure:disable | Out-Null            # 19
auditpol /set /subcategory:"Account Lockout" /success:disable /failure:enable | Out-Null             # 20
auditpol /set /subcategory:"Other Logon/Logoff Events" /success:enable /failure:enable | Out-Null    # 21
auditpol /set /subcategory:"File Share" /success:enable /failure:enable | Out-Null                   # 22
auditpol /set /subcategory:"Authorization Policy Change" /success:enable /failure:disable | Out-Null # 23
auditpol /set /subcategory:"Sensitive Privilege Use" /success:enable /failure:enable | Out-Null      # 24
# --- SMB / RDP / PowerShell ---
# 25 (16649) Disable SMBv1 client driver
RegSet 'HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10' 'Start' 4
$dep=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation' -Name DependOnService -ErrorAction SilentlyContinue).DependOnService
if($dep){ $new=$dep | Where-Object {$_ -ne 'MRxSmb10'}; Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation' -Name DependOnService -Value $new }
# 26 (16650) Disable SMBv1 server
RegSet 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' 'SMB1' 0
# 27 (16692) Include cmdline in process creation
RegSet 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' 'ProcessCreationIncludeCmdLine_Enabled' 1
# 28 (16811) Require NLA for RDP
RegSet 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' 'UserAuthentication' 1
# 29 (16829) PS Script Block Logging
RegSet 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' 'EnableScriptBlockLogging' 1
# 30 (16830) PS Transcription
RegSet 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' 'EnableTranscripting' 1
RegSet 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' 'OutputDirectory' 'C:\PSTranscripts' 'String'
Write-Output "BASE_DONE $env:COMPUTERNAME"
