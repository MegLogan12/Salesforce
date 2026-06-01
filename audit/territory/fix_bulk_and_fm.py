#!/usr/bin/env python3
"""Fix community bulk updates and FM assignments."""
import json, subprocess, csv, sys, os, re
import openpyxl

ORG = "dispatch"
OUTDIR = os.path.dirname(__file__)

FM_MAP = {
    "Justin":  {"name": "Justin Smithwick",  "user_id": "005Vu00000J7hQHIAZ",  "resource_id": "0HnVu0000007mSvKAI"},
    "Trenton": {"name": "Trenton Kinard",    "user_id": "005Vu00000HRvzhIAD",  "resource_id": "0HnVu0000006ZhRKAU"},
    "Jamie":   {"name": "Jamie Hinson",      "user_id": "005Vu00000JHMZ3IAP",  "resource_id": "0HnVu00000081gUKAQ"},
    "Nick":    {"name": "Nick Melendez",     "user_id": "005Vu00000HRhdOIAT",  "resource_id": "0HnVu0000006dZlKAI"},
    "Scott":   {"name": "Scott Spaulding",   "user_id": "005Vu00000JHMXRIA5",  "resource_id": "0HnVu00000081gTKAQ"},
}
ZONE_IDS = {
    1: "0HhVu0000001LSDKA2",
    2: "0HhVu0000001LTpKAM",
    3: "0HhVu0000001LYfKAM",
    4: "0HhVu0000001LVRKA2",
    5: "0HhVu0000001LX3KAM",
}
EXTENSION_CITIES = {
    1: {"asheville", "hendersonville", "weaverville", "denver"},
    2: {"winston salem", "winston-salem", "kernersville", "kennersville", "king", "stokesdale", "archdale", "mocksville"},
    3: {"camden", "cayce", "gaston"},
    4: {"fountain inn", "travelers rest", "woodruff", "spartanburg", "boiling springs", "clinton"},
    5: set(),
}
EXTENSION_NAMES = {1: "Asheville Extension", 2: "Triad Extension", 3: "Columbia Extension", 4: "Greenville Extension", 5: None}

def run(cmd, silent=False):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if not silent and r.returncode != 0:
        print(f"STDERR: {r.stderr[:300]}", file=sys.stderr)
    return r.stdout, r.stderr, r.returncode

def sf_query(soql):
    out, err, rc = run(["sf","data","query","--target-org",ORG,"--query",soql,"--json"], silent=True)
    try:
        return json.loads(out).get("result",{}).get("records",[])
    except:
        return []

def sf_create(sobject, vals_str):
    out, err, rc = run(["sf","data","create","record","--target-org",ORG,
                        "--sobject",sobject,"--values",vals_str,"--json"], silent=True)
    try:
        return json.loads(out).get("result",{}).get("id")
    except:
        return None

def normalize(n):
    n = str(n).lower().strip()
    n = re.sub(r'\s+', ' ', n)
    n = n.replace(' th', ' townhomes').replace(' ths', ' townhomes')
    n = re.sub(r"(\d+)s\b", r"\1", n)
    n = n.replace("'", "").replace("-", " ").replace("/", " ")
    return re.sub(r'\s+', ' ', n).strip()

# ============================================================
# Build community update list from spreadsheet + org data
# ============================================================
print("Building update list...")

# Get territories for lookup
territories = sf_query("SELECT Id, Name, ParentTerritoryId FROM ServiceTerritory")
terr_by_name_parent = {(t["Name"], t.get("ParentTerritoryId","")): t["Id"] for t in territories}

wb = openpyxl.load_workbook('/root/.claude/uploads/a160e003-5255-4957-a10a-33cca7cba422/4f53a66d-Zone_Rule_Breakdown.xlsx')
ws = wb['By Zone']

def get_territory_name(zone_num, city):
    city_norm = city.lower().strip() if city else ""
    if city_norm in EXTENSION_CITIES.get(zone_num, set()):
        return EXTENSION_NAMES.get(zone_num, city)
    elif city_norm == "charlotte":
        return {2:"Charlotte", 3:"Charlotte SW", 4:"Charlotte W", 5:"Charlotte Central"}.get(zone_num, "Charlotte")
    return city

spreadsheet = []
for row in ws.iter_rows(min_row=2, max_row=ws.max_row, values_only=True):
    if not any(v is not None for v in row):
        continue
    zone_num, zone_name, community, city, zip_code, basis, fm, notes = (row+(None,)*8)[:8]
    if not zone_name or not community:
        continue
    zn = int(str(zone_num).replace("Zone ","").strip())
    city_str = str(city).strip() if city else ""
    terr_name = get_territory_name(zn, city_str)
    spreadsheet.append({
        "zone_num": zn,
        "community_name": str(community).strip(),
        "city": city_str,
        "zip": str(zip_code).strip() if zip_code else "",
        "territory_name": terr_name,
        "fm": str(fm).strip() if fm else "",
    })

# Get org communities
org_comms = sf_query("SELECT Id, Name, Community_Zip__c FROM Community__c ORDER BY Name")

def best_match(name, org_comms, zip_code=None):
    norm = normalize(name)
    best = (0, None, None)
    for c in org_comms:
        cn = normalize(c["Name"])
        if norm == cn:
            return 100, c["Id"], c["Name"]
        score = 0
        if norm in cn or cn in norm:
            score = 85
        else:
            tw = set(norm.split())
            ow = set(cn.split())
            if tw and ow:
                overlap = len(tw & ow) / max(len(tw), len(ow))
                score = int(overlap * 75)
        if zip_code and c.get("Community_Zip__c") == zip_code:
            score = min(100, score + 10)
        if score > best[0]:
            best = (score, c["Id"], c["Name"])
    return best if best[0] >= 45 else (0, None, None)

# Match and build updates
updates = {}  # org_id -> update dict
for entry in spreadsheet:
    score, org_id, org_name = best_match(entry["community_name"], org_comms, entry["zip"])
    if not org_id:
        # Try two-word prefix search
        words = entry["community_name"].split()
        if len(words) >= 2:
            prefix = words[0] + " " + words[1]
            candidates = [c for c in org_comms if prefix.lower() in c["Name"].lower()]
            if len(candidates) == 1:
                org_id = candidates[0]["Id"]
                org_name = candidates[0]["Name"]
                score = 55
    
    if not org_id:
        print(f"  UNMATCHED: '{entry['community_name']}' (Zone{entry['zone_num']}, {entry['city']})")
        continue
    
    zone_num = entry["zone_num"]
    zone_id = ZONE_IDS[zone_num]
    fm_data = FM_MAP.get(entry["fm"])
    
    # Don't overwrite if already processed at higher priority (higher zone)
    if org_id in updates:
        continue
    
    updates[org_id] = {
        "Id": org_id,
        "Zone__c": str(zone_num),
        "ServiceTerritory__c": zone_id,
        "Service_Territory_Name__c": entry["territory_name"],
        "FM_Assignment__c": fm_data["user_id"] if fm_data else "",
        "Assigned_FM__c": fm_data["user_id"] if fm_data else "",
    }

print(f"  Will update: {len(updates)} communities")

# Write CSV with proper encoding
csvpath = os.path.join(OUTDIR, "_community_updates_v2.csv")
fieldnames = ["Id","Zone__c","ServiceTerritory__c","Service_Territory_Name__c","FM_Assignment__c","Assigned_FM__c"]

# Write with CRLF
with open(csvpath, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for row in updates.values():
        writer.writerow({k: row.get(k,"") for k in fieldnames})

# Verify line endings
with open(csvpath, "rb") as f:
    first_line = f.readline()
    print(f"  CSV line ending: {'CRLF' if b'\\r\\n' in first_line else 'LF'}")
    print(f"  First line: {first_line[:60]}")

# Try upsert with explicit line-ending flag if available
print("\n--- Trying sf data upsert bulk ---")
out, err, rc = run(["sf","data","upsert","bulk","--target-org",ORG,
                    "--sobject","Community__c","--file",csvpath,
                    "--external-id","Id","--wait","120","--json"])
print(f"  RC: {rc}")
try:
    d = json.loads(out)
    results = d.get("result",{})
    print(f"  Result: {json.dumps(results, indent=2)[:500]}")
except:
    print(f"  Output: {out[:500]}")
    print(f"  Stderr: {err[:300]}")

