#!/usr/bin/env python3
"""
CORRECTED territory rebuild per user's column mapping:
  Name           = Column A  ("Zone 1".."Zone 5")
  Parent Territory = Column B (Zone Name, e.g. "North Zone + Asheville Extension")
  Service Territory = Column D (City)  -- leaf, with address (City+Zip from spreadsheet)
  Communities assigned to the Zone (Column A) territory.
  Charlotte (multi-zone) -> "Charlotte <zip>" under the zip's zone.
"""
import subprocess, json, csv, os, re
from collections import defaultdict
import openpyxl

ORG="dispatch"; OP="0OHVu000002ks2fOAA"
OUT="/home/user/Salesforce/audit/territory"

ZONE_IDS = {1:"0HhVu0000001LSDKA2",2:"0HhVu0000001LTpKAM",3:"0HhVu0000001LYfKAM",4:"0HhVu0000001LVRKA2",5:"0HhVu0000001LX3KAM"}
# Column B Zone Names (Zone 3 shortened to fit 40-char ServiceTerritory name limit)
ZONE_PARENT_NAME = {
 1:"North Zone + Asheville Extension",
 2:"Northeast Zone + Triad Extension",
 3:"South/SE Zone + Columbia Extension",   # orig "South / Southeast Zone + Columbia Extension" = 43 chars
 4:"West Zone + Greenville Extension",
 5:"Central Flex Zone",
}
FM_MAP = {"Justin":"005Vu00000J7hQHIAZ","Trenton":"005Vu00000HRvzhIAD","Jamie":"005Vu00000JHMZ3IAP","Nick":"005Vu00000HRhdOIAT","Scott":"005Vu00000JHMXRIA5"}

def run(c): r=subprocess.run(c,capture_output=True,text=True); return r.stdout,r.stderr,r.returncode
def q(s):
    out,err,rc=run(["sf","data","query","--target-org",ORG,"--query",s,"--json"])
    try: return json.loads(out).get("result",{}).get("records",[])
    except: return []
def create(sobj,vals):
    out,err,rc=run(["sf","data","create","record","--target-org",ORG,"--sobject",sobj,"--values",vals,"--json"])
    try: return json.loads(out).get("result",{}).get("id"), json.loads(out).get("message")
    except: return None, out[:150]
def update(sobj,rid,vals):
    out,err,rc=run(["sf","data","update","record","--target-org",ORG,"--sobject",sobj,"--record-id",rid,"--values",vals,"--json"])
    try: return json.loads(out).get("result") is not None, json.loads(out).get("message")
    except: return False, out[:150]
def delete(sobj,rid):
    out,err,rc=run(["sf","data","delete","record","--target-org",ORG,"--sobject",sobj,"--record-id",rid,"--json"])
    return rc==0
def state_for_zip(z):
    z=str(z).strip()
    return "SC" if z[:2]=="29" else "NC"

# ---- Read spreadsheet ----
wb=openpyxl.load_workbook('/root/.claude/uploads/a160e003-5255-4957-a10a-33cca7cba422/4f53a66d-Zone_Rule_Breakdown.xlsx')
ws=wb['By Zone']
rows=[]
for r in ws.iter_rows(min_row=2,values_only=True):
    if not any(v is not None for v in r): continue
    zone,zname,comm,city,zp,basis,fm,notes=(r+(None,)*8)[:8]
    if not zone or not comm: continue
    rows.append({"zn":int(str(zone).replace("Zone ","").strip()),"comm":str(comm).strip(),
                 "city":str(city).strip() if city else "","zip":str(zp).strip() if zp else "","fm":str(fm).strip() if fm else ""})

# ---- Build service-territory (Column D) definitions ----
# For each zone: dict territory_name -> (city, zip, state)
zone_terr = defaultdict(dict)  # zn -> {tname:(city,zip,state)}
# also map (zn, comm) -> service-territory display name (Column D city, or Charlotte <zip>)
for row in rows:
    zn=row["zn"]; city=row["city"]; zp=row["zip"]
    if not city: continue
    if city.lower()=="charlotte":
        tname=f"Charlotte {zp}" if zp else "Charlotte"
    else:
        tname=city
    if tname not in zone_terr[zn]:
        zone_terr[zn][tname]=(city, zp, state_for_zip(zp) if zp else "NC")

print("=== Planned service territories (Column D) per zone ===")
for zn in sorted(zone_terr):
    print(f"  Zone {zn}: {sorted(zone_terr[zn].keys())}")

# ============================================================
# STEP 1: Create the 5 Column-B parent territories
# ============================================================
print("\n=== STEP 1: Create Column-B parent territories ===")
existing=q("SELECT Id,Name,ParentTerritoryId FROM ServiceTerritory")
by_name={t["Name"]:t["Id"] for t in existing}
parent_ids={}
for zn,pname in ZONE_PARENT_NAME.items():
    if pname in by_name:
        parent_ids[zn]=by_name[pname]; print(f"  exists: {pname} -> {parent_ids[zn]}")
        continue
    tid,msg=create("ServiceTerritory",f"Name='{pname}' IsActive=true OperatingHoursId={OP}")
    parent_ids[zn]=tid; print(f"  created: {pname} -> {tid} {msg or ''}")

# ============================================================
# STEP 2: Re-parent Zone 1..5 under their Column-B parent
# ============================================================
print("\n=== STEP 2: Re-parent Zone 1..5 ===")
for zn,zid in ZONE_IDS.items():
    ok,msg=update("ServiceTerritory",zid,f"ParentTerritoryId={parent_ids[zn]}")
    print(f"  Zone {zn} parent -> {ZONE_PARENT_NAME[zn]}: {'OK' if ok else msg}")

# ============================================================
# STEP 3: Delete existing city children under Zone 1..5
# ============================================================
print("\n=== STEP 3: Delete old city sub-territories ===")
existing=q("SELECT Id,Name,ParentTerritoryId FROM ServiceTerritory")
zone_id_set=set(ZONE_IDS.values())
old_children=[t for t in existing if t.get("ParentTerritoryId") in zone_id_set]
print(f"  Found {len(old_children)} city children to delete")
for t in old_children:
    ok=delete("ServiceTerritory",t["Id"])
    print(f"    delete {t['Name']}: {'OK' if ok else 'FAIL'}")

# ============================================================
# STEP 4: Create correct Column-D city service territories with address
# ============================================================
print("\n=== STEP 4: Create city service territories (with address) ===")
city_terr_ids={}  # (zn,tname)->id
for zn in sorted(zone_terr):
    for tname,(city,zp,st) in sorted(zone_terr[zn].items()):
        safe=tname.replace("'","\\'")
        vals=f"Name='{safe}' IsActive=true OperatingHoursId={OP} ParentTerritoryId={ZONE_IDS[zn]} City='{city}' State='{st}' Country='US'"
        if zp: vals+=f" PostalCode='{zp}'"
        tid,msg=create("ServiceTerritory",vals)
        city_terr_ids[(zn,tname)]=tid
        print(f"  Zone {zn} / {tname} ({city},{st} {zp}) -> {tid or msg}")

# ============================================================
# STEP 5: Update communities -> assigned to Zone X (Column A), city name in text field
# ============================================================
print("\n=== STEP 5: Assign communities to Zone (Column A) ===")
org_comms=q("SELECT Id,Name,Community_Zip__c FROM Community__c")
def norm(n):
    n=str(n).lower().strip(); n=re.sub(r'\s+',' ',n)
    n=n.replace("'","").replace("-"," ").replace("/"," "); n=re.sub(r"(\d+)s\b",r"\1",n)
    return re.sub(r'\s+',' ',n).strip()
def match(name,zp=None):
    nt=norm(name); best=(0,None,None)
    for c in org_comms:
        cn=norm(c["Name"])
        if nt==cn: return c["Id"],c["Name"]
        sc=0
        if nt in cn or cn in nt: sc=85
        else:
            tw=set(nt.split()); ow=set(cn.split())
            if tw and ow: sc=int(len(tw&ow)/max(len(tw),len(ow))*75)
        if zp and c.get("Community_Zip__c")==zp: sc=min(100,sc+10)
        if sc>best[0]: best=(sc,c["Id"],c["Name"])
    if best[0]>=45: return best[1],best[2]
    # two-word prefix fallback
    w=name.split()
    if len(w)>=2:
        pref=(w[0]+" "+w[1]).lower()
        cand=[c for c in org_comms if pref in c["Name"].lower()]
        if len(cand)==1: return cand[0]["Id"],cand[0]["Name"]
    return None,None

updates={}
for row in rows:
    zn=row["zn"]; city=row["city"]; zp=row["zip"]
    oid,oname=match(row["comm"],zp)
    if not oid: continue
    if oid in updates: continue  # first (lowest zone) wins; fine
    fm=FM_MAP.get(row["fm"])
    updates[oid]={"Id":oid,"Zone__c":str(zn),"ServiceTerritory__c":ZONE_IDS[zn],
                  "Service_Territory_Name__c":city,"FM_Assignment__c":fm or "","Assigned_FM__c":fm or ""}

csvp=os.path.join(OUT,"_rebuild_comm.csv")
fn=["Id","Zone__c","ServiceTerritory__c","Service_Territory_Name__c","FM_Assignment__c","Assigned_FM__c"]
with open(csvp,"w",newline="\n") as f:
    w=csv.DictWriter(f,fieldnames=fn,lineterminator="\n"); w.writeheader()
    for r in updates.values(): w.writerow({k:r.get(k,"") for k in fn})
out,err,rc=run(["sf","data","upsert","bulk","--target-org",ORG,"--sobject","Community__c",
                "--file",csvp,"--external-id","Id","--wait","120","--line-ending","LF","--json"])
try:
    ji=json.loads(out)["result"]["jobInfo"]
    print(f"  Communities: {ji['numberRecordsProcessed']} processed, {ji['numberRecordsFailed']} failed")
except: print("  ",out[:300])

print("\n=== DONE rebuild ===")
