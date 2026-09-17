#!/usr/bin/env bash
# Read-only SCA pull from Wazuh dashboard OpenSearch proxy (team_readonly).
# Prints latest pass/fail per host and, with an arg, the failed check IDs for that host.
P="${WPASS:?source creds.env first}"; H=10.10.1.200
Q='{"size":8000,"_source":["timestamp","agent.name","data.sca.check.id","data.sca.check.result","data.sca.check.title"],"query":{"bool":{"must":[{"exists":{"field":"data.sca.check.id"}}]}},"sort":[{"timestamp":{"order":"asc"}}]}'
curl -sk -u "team_readonly:$P" -H "osd-xsrf: true" -H "content-type: application/json" -X POST \
  "https://$H/api/console/proxy?path=wazuh-alerts-%2A%2F_search&method=POST" -d "$Q" > /tmp/sca.json
python3 - "$1" <<'PY'
import json,sys
from collections import defaultdict
d=json.load(open('/tmp/sca.json')); only=sys.argv[1] if len(sys.argv)>1 else None
st={};ti={};ts={}
for x in d['hits']['hits']:
    s=x['_source'];c=s.get('data',{}).get('sca',{}).get('check',{})
    a=s.get('agent',{}).get('name');cid=c.get('id');r=c.get('result')
    if not cid:continue
    st[(a,cid)]=r;ti[cid]=c.get('title','')
    if a:ts[a]=max(ts.get(a,''),s.get('timestamp',''))
cnt=defaultdict(lambda:[0,0])
for (a,cid),r in st.items():
    cnt[a][0 if r=='passed' else 1]+=1
for a in sorted(cnt):
    print(f"{a}: passed={cnt[a][0]} failed={cnt[a][1]}  (scan {ts.get(a,'?')})")
if only:
    print(f"\nFAILED on {only}:")
    for (a,cid),r in sorted(st.items()):
        if a==only and r=='failed': print(f"  {cid}  {ti.get(cid,'')[:70]}")
PY
