import os, sys, winrm
host=sys.argv[1]; script_file=sys.argv[2]
with open(script_file) as f: ps=f.read()
s=winrm.Session('http://%s:5985/wsman'%host,
    auth=(os.environ['WINUSER'],os.environ['WINPASS']),
    transport='ntlm', server_cert_validation='ignore')
r=s.run_ps(ps)
sys.stdout.write(r.std_out.decode('utf-8','replace'))
err=r.std_err.decode('utf-8','replace').strip()
if err: sys.stderr.write("\n--STDERR--\n"+err+"\n")
print("EXIT",r.status_code)
