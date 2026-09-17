import os, sys, winrm, math
host=sys.argv[1]; datafile=sys.argv[2]; chunk=int(sys.argv[3]) if len(sys.argv)>3 else 12
lines=[l.strip() for l in open(datafile) if l.strip() and '|' in l]
s=winrm.Session('http://%s:5985/wsman'%host, auth=(os.environ['WINUSER'],os.environ['WINPASS']), transport='ntlm', server_cert_validation='ignore')
ok=0
for i in range(0,len(lines),chunk):
    part=lines[i:i+chunk]
    arr="\n".join("'%s',"%x for x in part).rstrip(',')
    ps="""$R=@(
%s
)
foreach($e in $R){ $p,$n,$t,$v=$e -split '\\|',4; if($t -eq 'D'){$pt='DWord';$val=[int]$v}else{$pt='String';$val=$v}; if(-not(Test-Path $p)){New-Item -Path $p -Force|Out-Null}; New-ItemProperty -Path $p -Name $n -Value $val -PropertyType $pt -Force|Out-Null }
Write-Output "CHUNKOK $($R.Count)"
"""%arr
    r=s.run_ps(ps)
    out=r.std_out.decode('utf-8','replace')
    if 'CHUNKOK' in out: ok+=len(part)
    else: print("  chunk %d FAILED rc=%s"%(i//chunk,r.status_code)); print("   ",out[:200])
print("APPLIED %d/%d entries on %s"%(ok,len(lines),host))
