#!/usr/bin/env bash
# check-passes.sh - verify which controls set by our scripts are PASSED in Wazuh SCA.
# Read-only: pulls SCA results through the Wazuh dashboard OpenSearch proxy (team_readonly).
#
# Usage:
#   ./check-passes.sh                 # summary + core status for every host
#   ./check-passes.sh DC-1            # detail (core + bonus) for one host
#   ./check-passes.sh --bonus         # include bonus detail for all hosts
#   ./check-passes.sh --failed DB-1   # list every still-FAILED check id+title for a host
#   ./check-passes.sh --id 16502      # show one check id across all hosts
#
# Env overrides: WAZUH=10.10.1.200  WUSER=team_readonly  WPASS=...
set -euo pipefail
WAZUH="${WAZUH:-10.10.1.200}"; WUSER="${WUSER:-team_readonly}"; WPASS="${WPASS:?source creds.env first}"
JQTMP="$(mktemp /tmp/sca.XXXXXX.json)"; trap 'rm -f "$JQTMP"' EXIT

echo "[*] pulling SCA from https://$WAZUH ..." >&2
Q='{"size":10000,"_source":["timestamp","agent.name","data.sca.check.id","data.sca.check.result","data.sca.check.title"],"query":{"bool":{"must":[{"exists":{"field":"data.sca.check.id"}}]}},"sort":[{"timestamp":{"order":"asc"}}]}'
if ! curl -sk --connect-timeout 15 -u "$WUSER:$WPASS" -H "osd-xsrf: true" -H "content-type: application/json" \
     -X POST "https://$WAZUH/api/console/proxy?path=wazuh-alerts-%2A%2F_search&method=POST" -d "$Q" > "$JQTMP"; then
  echo "[!] could not reach Wazuh proxy" >&2; exit 1
fi
grep -q '"hits"' "$JQTMP" || { echo "[!] unexpected response:"; head -c 300 "$JQTMP"; exit 1; }

# ---- control-id sets set by our scripts ----
WIN_CORE="16502 16511 16527 16528 16543 16544 16567 16568 16569 16577 16578 16579 16583 16585 16586 16593 16603 16611 16613 16616 16620 16623 16628 16631 16649 16650 16692 16811 16829 16830"
UBU_CORE="28570 28576 28577 28590 28591 28593 28594 28595 28597 28626 28634 28638 28649 28652 28656"
WIN_BONUS="16503 16504 16505 16506 16529 16530 16564 16604 16605 16606 16608 16609 16612 16614 16615 16617 16622 16624 16625 16629 16630 16632 16635 16637 16638 16639 16640 16647 16651 16652 16655 16656 16658 16659 16661 16662 16663 16664 16665 16667 16668 16669 16672 16673 16674 16675 16678 16679 16680 16706 16723 16732 16745 16750 16751 16752 16756 16758 16762 16782 16800 16802 16803 16804 16805 16806 16807 16808 16809 16810 16812 16813 16814 16815 16816 16817 16818 16819 16822 16846 16772 16774 16776 16778 16789 16790 16791 16793 16794 16795 16796 16797 16798 16695 16696 16697 16698 16699"
UBU_BONUS="28523 28528 28531 28533 28534 28538 28539 28546 28598 28599 28600 28601 28602 28603 28604 28605 28614 28627 28628 28629 28630 28631 28645 28648 28650 28653 28661 28665 28666 28668 28712 28717 28730 28731 28749 28750 28751"

export WIN_CORE UBU_CORE WIN_BONUS UBU_BONUS
MODE="summary"; ARG="${1:-}"; ARG2="${2:-}"
case "$ARG" in
  --bonus) MODE="bonus" ;;
  --failed) MODE="failed" ;;
  --id) MODE="id" ;;
  "") MODE="summary" ;;
  *) MODE="host"; ARG2="$ARG" ;;
esac
export MODE ARG2

python3 - "$JQTMP" <<'PY'
import json,os,sys
d=json.load(open(sys.argv[1]))
st={}; ti={}; ts={}
for x in d['hits']['hits']:
    s=x['_source']; c=s.get('data',{}).get('sca',{}).get('check',{})
    a=s.get('agent',{}).get('name'); cid=str(c.get('id')) if c.get('id') is not None else None; r=c.get('result')
    if not cid: continue
    st[(a,cid)]=r; ti[cid]=c.get('title','')
    if a: ts[a]=max(ts.get(a,''), s.get('timestamp',''))

WIN=['DC-1','DB-1','SERVER-1','SERVER-2']; UBU=['WEB-1','WEB-2']
win_core=os.environ['WIN_CORE'].split(); ubu_core=os.environ['UBU_CORE'].split()
win_bonus=os.environ['WIN_BONUS'].split(); ubu_bonus=os.environ['UBU_BONUS'].split()
mode=os.environ['MODE']; arg=os.environ.get('ARG2','')
G='\033[92m'; R='\033[91m'; Y='\033[93m'; D='\033[90m'; N='\033[0m'
def mark(r): return f"{G}PASS{N}" if r=='passed' else (f"{R}FAIL{N}" if r=='failed' else f"{Y} -- {N}")
def counts(host,ids):
    p=sum(1 for i in ids if st.get((host,i))=='passed')
    f=sum(1 for i in ids if st.get((host,i))=='failed')
    n=len(ids)-p-f
    return p,f,n

def core_ids(h): return win_core if h in WIN else ubu_core
def bonus_ids(h): return win_bonus if h in WIN else ubu_bonus

def summary_line(h):
    cp,cf,cn=counts(h,core_ids(h)); bp,bf,bn=counts(h,bonus_ids(h))
    print(f"  {h:10} scan={ts.get(h,'?')[:19]}  core {G}{cp}{N}/{len(core_ids(h))} pass ({cf} fail,{cn} n/a)  bonus {G}{bp}{N}/{len(bonus_ids(h))} pass")

def detail(h):
    print(f"\n=== {h}  (last scan {ts.get(h,'?')[:19]}) ===")
    print("  -- CORE --")
    for i in core_ids(h):
        print(f"   {mark(st.get((h,i)))}  {i}  {ti.get(i,'(not scanned yet)')[:66]}")
    cp,cf,cn=counts(h,core_ids(h)); print(f"   core: {cp}/{len(core_ids(h))} passed")
    if mode in ('bonus','host'):
        print("  -- BONUS --")
        for i in bonus_ids(h):
            print(f"   {mark(st.get((h,i)))}  {i}  {ti.get(i,'(not scanned yet)')[:66]}")
        bp,bf,bn=counts(h,bonus_ids(h)); print(f"   bonus: {bp}/{len(bonus_ids(h))} passed")

hosts=[a for a in WIN+UBU if any(k[0]==a for k in st)]
if mode=='id':
    cid=arg
    print(f"\ncheck {cid}: {ti.get(cid,'(unknown/not scanned)')}")
    for h in WIN+UBU: print(f"   {mark(st.get((h,cid)))}  {h}")
elif mode=='failed':
    h=arg
    print(f"\nStill FAILED on {h}:")
    fails=sorted([cid for (a,cid),r in st.items() if a==h and r=='failed'], key=int)
    for cid in fails: print(f"   {cid}  {ti.get(cid,'')[:70]}")
    print(f"   ({len(fails)} failed)")
elif mode=='host':
    detail(arg)
elif mode=='bonus':
    print("Per-host summary:"); [summary_line(h) for h in hosts]
    for h in hosts: detail(h)
else:  # summary
    print("Per-host summary (controls set by our scripts):")
    for h in hosts: summary_line(h)
    tc=sum(counts(h,core_ids(h))[0] for h in hosts); tct=sum(len(core_ids(h)) for h in hosts)
    tb=sum(counts(h,bonus_ids(h))[0] for h in hosts)
    print(f"\n  TOTAL core passed: {tc}/{tct} instances   bonus passed: {tb} instances")
    print("  (detail: ./check-passes.sh <HOST> | --bonus | --failed <HOST> | --id <NNN>)")
PY
