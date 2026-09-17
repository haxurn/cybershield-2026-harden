# Windows CIS control mapping (30 controls, all 4 hosts)

Applied via WinRM as `conda.local\administrator`. Script column: which file sets it.

## Account & access — 01-base-part1.ps1
| # | Wazuh ID | CIS | Control | Implementation |
|---|----------|-----|---------|----------------|
| 1 | 16502 | 1.1.4 | Min password length 14 | `net accounts /minpwlen:14` + secedit MinimumPasswordLength=14 |
| 2 | 16511 | 2.3.2.1 | Advanced audit overrides legacy | `Lsa\SCENoApplyLegacyAuditPolicy=1` |
| 3 | 16527 | 2.3.7.2 | Don't show last user | `Policies\System\DontDisplayLastUserName=1` |
| 4 | 16528 | 2.3.7.3 | Inactivity limit <=900 | `Policies\System\InactivityTimeoutSecs=900` |
| 5 | 16543 | 2.3.10.3 | No anon SAM/share enum | `Lsa\RestrictAnonymous=1` |
| 6 | 16544 | 2.3.10.4 | Don't store net creds | `Lsa\DisableDomainCreds=1` |
| 7 | 16567 | 2.3.17.1 | Admin Approval Mode (built-in admin) | `Policies\System\FilterAdministratorToken=1` |
| 8 | 16568 | 2.3.17.2 | Elevation prompt on secure desktop | `Policies\System\PromptOnSecureDesktop=1` |
| 9 | 16569 | 2.3.17.3 | Deny standard-user elevation | `Policies\System\ConsentPromptBehaviorUser=0` |

## Auditing (auditpol) — 17.1.1 in 01, rest in 02-base-part2.ps1
| # | Wazuh ID | CIS | Subcategory | Setting |
|---|----------|-----|-------------|---------|
| 17 | 16603 | 17.1.1 | Credential Validation | Success+Failure |
| 18 | 16611 | 17.2.6 | User Account Management | Success+Failure |
| 19 | 16613 | 17.3.2 | Process Creation | Success |
| 20 | 16616 | 17.5.1 | Account Lockout | Failure |
| 21 | 16620 | 17.5.5 | Other Logon/Logoff Events | Success+Failure |
| 22 | 16623 | 17.6.2 | File Share | Success+Failure |
| 23 | 16628 | 17.7.3 | Authorization Policy Change | Success |
| 24 | 16631 | 17.8.1 | Sensitive Privilege Use | Success+Failure |

## SMB / RDP / PowerShell — 02-base-part2.ps1
| # | Wazuh ID | CIS | Control | Implementation |
|---|----------|-----|---------|----------------|
| 25 | 16649 | 18.4.3 | Disable SMBv1 client driver | `Services\mrxsmb10\Start=4` + strip MRxSmb10 from LanmanWorkstation DependOnService |
| 26 | 16650 | 18.4.4 | Disable SMBv1 server | `LanmanServer\Parameters\SMB1=0` |
| 27 | 16692 | 18.9.3.1 | Cmdline in process events | `...\System\Audit\ProcessCreationIncludeCmdLine_Enabled=1` |
| 28 | 16811 | 18.10.57.3.9.4 | RDP NLA required | `Terminal Services\UserAuthentication=1` |
| 29 | 16829 | 18.10.87.1 | PS Script Block Logging | `PowerShell\ScriptBlockLogging\EnableScriptBlockLogging=1` |
| 30 | 16830 | 18.10.87.2 | PS Transcription | `PowerShell\Transcription\EnableTranscripting=1` (+OutputDirectory) |

## Firewall — 03-firewall.ps1 (member) / 03-firewall-DC.ps1 (DC-1)
| # | Wazuh ID | CIS | Control | Implementation |
|---|----------|-----|---------|----------------|
| 10 | 16577 | 9.1.1 | Domain profile enabled | `Set-NetFirewallProfile -Profile Domain -Enabled True` |
| 11 | 16578 | 9.1.2 | Domain inbound block | `-DefaultInboundAction Block` |
| 12 | 16579 | 9.1.3 | Domain outbound allow | `-DefaultOutboundAction Allow` |
| 13 | 16583 | 9.1.7 | Log dropped Domain packets | `-LogBlocked True` (+logfile/size) |
| 14 | 16585 | 9.2.1 | Private profile enabled | Private `-Enabled True` |
| 15 | 16586 | 9.2.2 | Private inbound block | Private `-DefaultInboundAction Block` |
| 16 | 16593 | 9.3.1 | Public profile enabled | Public `-Enabled True` |

SAFETY: before setting default-block, the script auto-allows every listening TCP/UDP port
(<49152) and enables the Remote Desktop + Windows Remote Management rule groups (DC variant
also enables Active Directory Domain Services, DNS Service, Kerberos KDC, File and Printer
Sharing, Core Networking, WMI, and dynamic RPC), so RDP/WinRM/app/AD traffic keeps flowing.

## Bonus
See ../../README.md "BONUS controls" and files under bonus/. reg-batch-a.txt / reg-batch-b.txt
are `path|name|D(word)/S(tring)|value` lines applied by bonus/runreg.py.
