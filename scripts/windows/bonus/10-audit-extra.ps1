$a='auditpol'
& $a /set /subcategory:"Kerberos Authentication Service" /success:enable /failure:enable | Out-Null
& $a /set /subcategory:"Kerberos Service Ticket Operations" /success:enable /failure:enable | Out-Null
& $a /set /subcategory:"Application Group Management" /success:enable /failure:enable | Out-Null
& $a /set /subcategory:"Distribution Group Management" /success:enable /failure:disable | Out-Null
& $a /set /subcategory:"Other Account Management Events" /success:enable /failure:disable | Out-Null
& $a /set /subcategory:"Plug and Play Events" /success:enable /failure:disable | Out-Null
& $a /set /subcategory:"Directory Service Access" /success:disable /failure:enable | Out-Null
& $a /set /subcategory:"Directory Service Changes" /success:enable /failure:disable | Out-Null
& $a /set /subcategory:"Security Group Management" /success:enable /failure:disable | Out-Null
& $a /set /subcategory:"Detailed File Share" /success:disable /failure:enable | Out-Null
& $a /set /subcategory:"Other Object Access Events" /success:enable /failure:enable | Out-Null
& $a /set /subcategory:"Removable Storage" /success:enable /failure:enable | Out-Null
& $a /set /subcategory:"MPSSVC Rule-Level Policy Change" /success:enable /failure:enable | Out-Null
& $a /set /subcategory:"Other Policy Change Events" /success:disable /failure:enable | Out-Null
& $a /set /subcategory:"IPsec Driver" /success:enable /failure:enable | Out-Null
& $a /set /subcategory:"Security System Extension" /success:enable /failure:disable | Out-Null
Write-Output "BONUS_AUDIT_DONE"
