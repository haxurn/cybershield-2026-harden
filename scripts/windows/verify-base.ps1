$ErrorActionPreference='SilentlyContinue'
function G($p,$n){ (Get-ItemProperty -Path $p -Name $n -ErrorAction SilentlyContinue).$n }
"minpwlen=" + ((net accounts | Select-String 'Minimum password length') -replace '\D','')
"SCENoApply=" + (G 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'SCENoApplyLegacyAuditPolicy')
"DontDisplayLast=" + (G 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'DontDisplayLastUserName')
"Inactivity=" + (G 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'InactivityTimeoutSecs')
"RestrictAnon=" + (G 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymous')
"DisableDomainCreds=" + (G 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'DisableDomainCreds')
"FilterAdminToken=" + (G 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'FilterAdministratorToken')
"PromptSecureDesktop=" + (G 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'PromptOnSecureDesktop')
"ConsentUser=" + (G 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorUser')
"mrxsmb10Start=" + (G 'HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10' 'Start')
"SMB1srv=" + (G 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' 'SMB1')
"CmdLine=" + (G 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' 'ProcessCreationIncludeCmdLine_Enabled')
"NLA=" + (G 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' 'UserAuthentication')
"SBL=" + (G 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' 'EnableScriptBlockLogging')
"Transcript=" + (G 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' 'EnableTranscripting')
"--- auditpol ---"
auditpol /get /category:* | Select-String 'Credential Validation|User Account Management|Process Creation|Account Lockout|Other Logon/Logoff|File Share|Authorization Policy Change|Sensitive Privilege Use'
