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
Write-Output "H1_DONE"
