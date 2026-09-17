net accounts /lockoutthreshold:5 /lockoutduration:15 /lockoutwindow:15 | Out-Null
$o=net accounts | Out-String
Write-Output "BONUS_LOCKOUT_DONE"
