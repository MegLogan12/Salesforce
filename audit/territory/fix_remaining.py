#!/usr/bin/env python3
"""Fix remaining issues from phase 2."""
import json, subprocess, csv, sys, os, re
import openpyxl

ORG = "dispatch"
OUTDIR = os.path.dirname(__file__)
OP_HOURS = "0OHVu000002ks2fOAA"

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
        sys.stderr.write(f"WARN: {r.stderr[:300]}\n")
    return r.stdout, r.stderr, r.returncode

def sf_query(soql):
    out, err, rc = run(["sf", "data", "query", "--target-org", ORG, "--query", soql, "--json"], silent=True)
    try:
        return json.loads(out).get("result", {}).get("records", [])
    except:
        return []

def sf_create(sobject, values_str):
    out, err, rc = run(["sf", "data", "create", "record", "--target-org", ORG,
                        "--sobject", sobject, "--values", values_str, "--json"], silent=True)
    try:
        d = json.loads(out)
        return d.get("result", {}).get("id")
    except:
        return None

def normalize(n):
    n = str(n).lower().strip()
    n = re.sub(r'\s+', ' ', n)
    n = n.replace(' th', ' townhomes').replace(' ths', ' townhomes')
    n = re.sub(r"(\d+)s\b", r"\1", n)
    n = n.replace("'", "").replace("-", " ").replace("/", " ")
    n = re.sub(r'\s+', ' ', n).strip()
    return n

def write_csv_crlf(path, rows, fieldnames):
    """Write CSV with CRLF line endings for Salesforce bulk API."""
    with open(path, "w", newline="") as f:  # newline="" lets csv write \r\n
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

def bulk_upsert(sobject, rows, fieldnames, ext_id="Id"):
    if not rows:
        print(f"  {sobject}: nothing to upsert")
        return True
    csvpath = os.path.join(OUTDIR, f"_upsert_{sobject}.csv")
    write_csv_crlf(csvpath, [{k: row.get(k,"") for k in fieldnames} for row in rows], fieldnames)
    out, err, rc = run(["sf", "data", "upsert", "bulk", "--target-org", ORG,
                        "--sobject", sobject, "--file", csvpath,
                        "--external-id", ext_id, "--wait", "120", "--json"])
    try:
        d = json.loads(out)
        results = d.get("result", {})
        processed = results.get("numberRecordsProcessed", 0)
        failed = results.get("numberRecordsFailed", 0)
        print(f"  {sobject}: {processed} processed, {failed} failed")
        if failed > 0:
            print(f"    ERRORS: {out[:400]}")
        return failed == 0
    except:
        print(f"  {sobject} upsert output: {out[:400]}")
        return rc == 0

# ============================================================
# 1. Create missing Charlotte territories for zones 3, 4, 5
# ============================================================
print("=== 1. Create missing Charlotte city territories ===")
existing_territories = sf_query("SELECT Id, Name, ParentTerritoryId FROM ServiceTerritory ORDER BY Name")
existing_by_name_parent = {(t["Name"], t.get("ParentTerritoryId","")): t["Id"] for t in existing_territories}

# Zone 2 Charlotte already exists: 0HhVu0000001LjxKAE
# Need Zone3 "Charlotte SW", Zone4 "Charlotte W", Zone5 "Charlotte Central"
charlotte_terr = {
    2: "0HhVu0000001LjxKAE",  # Already created
    3: None,
    4: None,
    5: None,
}
new_charlotte_names = {3: "Charlotte SW", 4: "Charlotte W", 5: "Charlotte Central"}
for zn, tname in new_charlotte_names.items():
    parent_id = ZONE_IDS[zn]
    key = (tname, parent_id)
    if key in existing_by_name_parent:
        charlotte_terr[zn] = existing_by_name_parent[key]
        print(f"  Zone{zn} '{tname}' already exists: {charlotte_terr[zn]}")
        continue
    tid = sf_create("ServiceTerritory", 
                    f"Name='{tname}' IsActive=true OperatingHoursId={OP_HOURS} ParentTerritoryId={parent_id}")
    if tid:
        charlotte_terr[zn] = tid
        print(f"  Zone{zn} '{tname}' created: {tid}")
    else:
        # Check if name already exists
        existing = next((t for t in existing_territories if t["Name"]==tname), None)
        if existing:
            charlotte_terr[zn] = existing["Id"]
            print(f"  Zone{zn} '{tname}' found existing: {existing['Id']}")
        else:
            print(f"  Zone{zn} '{tname}' FAILED")

print(f"  Charlotte territories: {charlotte_terr}")

# ============================================================
# 2. Re-read spreadsheet and build city territory lookup
# ============================================================
print("\n=== 2. Build complete territory lookup ===")
wb = openpyxl.load_workbook('/root/.claude/uploads/a160e003-5255-4957-a10a-33cca7cba422/4f53a66d-Zone_Rule_Breakdown.xlsx')
ws = wb['By Zone']

# Refresh territory list
existing_territories = sf_query("SELECT Id, Name, ParentTerritoryId FROM ServiceTerritory ORDER BY Name")
terr_by_name_parent = {}
for t in existing_territories:
    key = (t["Name"], t.get("ParentTerritoryId",""))
    terr_by_name_parent[key] = t["Id"]

def get_city_territory_id(zone_num, city, zip_code=None):
    """Get city-level territory ID for a community."""
    parent_id = ZONE_IDS[zone_num]
    city_norm = city.lower().strip() if city else ""
    
    if city_norm in EXTENSION_CITIES.get(zone_num, set()):
        terr_name = EXTENSION_NAMES.get(zone_num, city)
    elif city_norm in {"charlotte", "char", "clt"}:
        # Use zone-specific Charlotte name
        if zone_num == 2: terr_name = "Charlotte"
        elif zone_num == 3: terr_name = "Charlotte SW"
        elif zone_num == 4: terr_name = "Charlotte W"
        elif zone_num == 5: terr_name = "Charlotte Central"
        else: terr_name = city
    else:
        terr_name = city
    
    return terr_by_name_parent.get((terr_name, parent_id)), terr_name

# Build spreadsheet data
spreadsheet_data = []
for row in ws.iter_rows(min_row=2, max_row=ws.max_row, values_only=True):
    if not any(v is not None for v in row):
        continue
    zone_num, zone_name, community, city, zip_code, basis, fm, notes = (row + (None,)*8)[:8]
    if not zone_name or not community:
        continue
    zn = int(str(zone_num).replace("Zone ","").strip())
    city_str = str(city).strip() if city else ""
    zip_str = str(zip_code).strip() if zip_code else ""
    
    city_terr_id, terr_name = get_city_territory_id(zn, city_str, zip_str)
    
    spreadsheet_data.append({
        "zone_num": zn,
        "community_name": str(community).strip(),
        "city": city_str,
        "zip": zip_str,
        "territory_name": terr_name,
        "city_territory_id": city_terr_id,
        "fm": str(fm).strip() if fm else "",
    })

print(f"  Spreadsheet entries: {len(spreadsheet_data)}")

# ============================================================
# 3. Match ALL communities (better fuzzy matching)
# ============================================================
print("\n=== 3. Match communities ===")
org_communities = sf_query("SELECT Id, Name, Community_City__c, Community_Zip__c, ServiceTerritory__c FROM Community__c ORDER BY Name")
org_by_id = {c["Id"]: c for c in org_communities}

def best_match(community_name, org_communities, zone_num=None, city=None, zip_code=None):
    """Find best match - try multiple strategies."""
    norm_target = normalize(community_name)
    
    candidates = []
    for org_comm in org_communities:
        norm_org = normalize(org_comm["Name"])
        score = 0
        
        # Exact normalized match
        if norm_target == norm_org:
            score = 100
        # One contains other
        elif norm_target in norm_org or norm_org in norm_target:
            score = 85
        else:
            # Word overlap
            target_words = set(norm_target.split())
            org_words = set(norm_org.split())
            if len(target_words) > 0:
                overlap = len(target_words & org_words) / max(len(target_words), len(org_words))
                score = int(overlap * 75)
        
        # Boost if zip matches
        if zip_code and org_comm.get("Community_Zip__c") == zip_code:
            score = min(100, score + 10)
        
        if score >= 45:
            candidates.append((score, org_comm["Id"], org_comm["Name"]))
    
    candidates.sort(reverse=True)
    if candidates:
        return candidates[0][1], candidates[0][0], candidates[0][2]
    return None, 0, None

matched = {}  # community_name -> {org_id, ...}
unmatched = []

for entry in spreadsheet_data:
    org_id, score, org_name = best_match(
        entry["community_name"], org_communities, 
        entry["zone_num"], entry["city"], entry["zip"]
    )
    if org_id:
        # Handle duplicates (same community in spreadsheet under 2 zones, e.g. zip-boundary communities)
        existing = matched.get(entry["community_name"])
        if not existing or score > existing["score"]:
            matched[entry["community_name"]] = {
                "org_id": org_id,
                "org_name": org_name,
                "score": score,
                "entry": entry,
            }
    else:
        unmatched.append(entry)

print(f"  Matched: {len(matched)}, Unmatched: {len(unmatched)}")
if unmatched:
    print("  Still unmatched:")
    for u in unmatched:
        print(f"    Zone{u['zone_num']}: '{u['community_name']}' ({u['city']})")

# Also try direct name search in org for unmatched
still_unmatched = []
for entry in unmatched:
    # Try searching by partial name
    short_name = entry["community_name"].split()[0] + " " + (entry["community_name"].split()[1] if len(entry["community_name"].split())>1 else "")
    candidates = [c for c in org_communities if short_name.lower() in c["Name"].lower()]
    if len(candidates) == 1:
        org_id = candidates[0]["Id"]
        matched[entry["community_name"]] = {
            "org_id": org_id,
            "org_name": candidates[0]["Name"],
            "score": 60,
            "entry": entry,
        }
        print(f"  Recovered: '{entry['community_name']}' -> '{candidates[0]['Name']}'")
    else:
        still_unmatched.append(entry)

print(f"\n  Final matched: {len(matched)}, Still unmatched: {len(still_unmatched)}")

# ============================================================
# 4. Bulk update Community__c records
# ============================================================
print("\n=== 4. Update Community__c records ===")

update_rows = []
# Build set of already-matched org IDs to avoid duplicates
assigned_org_ids = set()

for comm_name, match_data in matched.items():
    entry = match_data["entry"]
    org_id = match_data["org_id"]
    
    if org_id in assigned_org_ids:
        print(f"  SKIP duplicate: {comm_name} -> {org_id}")
        continue
    assigned_org_ids.add(org_id)
    
    zone_num = entry["zone_num"]
    zone_id = ZONE_IDS[zone_num]
    fm_data = FM_MAP.get(entry["fm"])
    
    row = {
        "Id": org_id,
        "Zone__c": str(zone_num),
        "ServiceTerritory__c": zone_id,
        "Service_Territory_Name__c": entry["territory_name"],
        "FM_Assignment__c": fm_data["user_id"] if fm_data else "",
        "Assigned_FM__c": fm_data["user_id"] if fm_data else "",
    }
    update_rows.append(row)

print(f"  Updating {len(update_rows)} communities...")
fieldnames = ["Id", "Zone__c", "ServiceTerritory__c", "Service_Territory_Name__c", "FM_Assignment__c", "Assigned_FM__c"]
bulk_upsert("Community__c", update_rows, fieldnames, ext_id="Id")

# ============================================================
# 5. Clear ServiceTerritory on unmapped communities pointing to old territories
# ============================================================
print("\n=== 5. Clear old territory refs on unmapped communities ===")
OLD_IDS_SET = {
    "0HhVu0000000ittKAA", "0HhVu00000016JcKAI", "0HhVu0000000isHKAQ",
    "0HhVu00000016JaKAI", "0HhVu00000016JZKAY", "0HhVu0000000ivVKAQ",
    "0HhVu00000016JfKAI", "0HhVu00000016JdKAI", "0HhVu0000000ix7KAA",
    "0HhVu00000016JbKAI", "0HhVu00000016JYKAY", "0HhVu0000001AoXKAU",
    "0HhVu00000016JiKAI", "0HhVu00000016JgKAI", "0HhVu00000016JhKAI",
    "0HhVu00000016JXKAY", "0HhVu00000016JeKAI",
}
# Charlotte-North still exists - it's in OLD_IDS_SET
still_old = sf_query(
    "SELECT Id, Name, ServiceTerritory__c FROM Community__c WHERE ServiceTerritory__c != null"
)
old_ref_rows = [{"Id": c["Id"], "ServiceTerritory__c": ""} for c in still_old 
                if c.get("ServiceTerritory__c") in OLD_IDS_SET and c["Id"] not in assigned_org_ids]
print(f"  Communities still referencing old territories: {len(old_ref_rows)}")
if old_ref_rows:
    bulk_upsert("Community__c", old_ref_rows, ["Id", "ServiceTerritory__c"], ext_id="Id")

# ============================================================
# 6. Fix Charlotte-North: remove its children first, then delete
# ============================================================
print("\n=== 6. Remove Charlotte-North children ===")
charlotte_north_id = "0HhVu0000000isHKAQ"
children = sf_query(f"SELECT Id, Name FROM ServiceTerritory WHERE ParentTerritoryId='{charlotte_north_id}'")
print(f"  Children of Charlotte-North: {[c['Name'] for c in children]}")
# The "Charlotte" territory (Zone 2) was incorrectly created as child of Charlotte-North
# Need to re-parent it to Zone 2
for child in children:
    if child["Name"] in ["Charlotte", "Charlotte SW", "Charlotte W", "Charlotte Central"]:
        # Update its parent to the correct zone
        # Find the right zone for this Charlotte territory
        # The one named "Charlotte" should be Zone 2
        zone_parent = ZONE_IDS[2]
        # Can't update via sf data update record easily - delete and recreate?
        # Actually let's just update the ParentTerritoryId
        out, err, rc = run(["sf", "data", "update", "record", "--target-org", ORG,
                            "--sobject", "ServiceTerritory",
                            "--record-id", child["Id"],
                            "--values", f"ParentTerritoryId={zone_parent}",
                            "--json"], silent=True)
        try:
            d = json.loads(out)
            print(f"  Re-parented '{child['Name']}': {d.get('result','?')}")
        except:
            print(f"  Re-parent '{child['Name']}' output: {out[:200]}")
    else:
        print(f"  Unknown child: {child['Name']} {child['Id']} - leaving")

# Now delete Charlotte-North
children2 = sf_query(f"SELECT Id FROM ServiceTerritory WHERE ParentTerritoryId='{charlotte_north_id}'")
if not children2:
    out, err, rc = run(["sf", "data", "delete", "record", "--target-org", ORG,
                        "--sobject", "ServiceTerritory", "--record-id", charlotte_north_id, "--json"], silent=True)
    try:
        d = json.loads(out)
        print(f"  Deleted Charlotte-North: {d.get('result','?')}")
    except:
        print(f"  Delete Charlotte-North output: {out[:200]}")
else:
    print(f"  Charlotte-North still has {len(children2)} children, skipping delete")

# ============================================================
# 7. Assign FMs to zone territories
# ============================================================
print("\n=== 7. Assign FMs to zone territories ===")
existing_members = sf_query("SELECT Id, ServiceTerritoryId, ServiceResourceId FROM ServiceTerritoryMember")

zone_fm_assignments = [
    (1, "Justin"), (2, "Trenton"), (3, "Jamie"), (4, "Nick"), (5, "Scott"),
]

for zone_num, fm_key in zone_fm_assignments:
    zone_id = ZONE_IDS[zone_num]
    fm_data = FM_MAP[fm_key]
    resource_id = fm_data["resource_id"]
    
    existing = next((m for m in existing_members 
                     if m["ServiceTerritoryId"] == zone_id 
                     and m["ServiceResourceId"] == resource_id), None)
    if existing:
        print(f"  Zone{zone_num} {fm_data['name']}: already assigned")
        continue
    
    vals = f"ServiceTerritoryId={zone_id} ServiceResourceId={resource_id} TerritoryType=P"
    mid = sf_create("ServiceTerritoryMember", vals)
    if mid:
        print(f"  Zone{zone_num}: Assigned {fm_data['name']}: {mid}")
    else:
        # Try without quotes
        out, err, rc = run(["sf", "data", "create", "record", "--target-org", ORG,
                            "--sobject", "ServiceTerritoryMember",
                            "--values", f"ServiceTerritoryId={zone_id} ServiceResourceId={resource_id} TerritoryType=P",
                            "--json"], silent=False)
        print(f"  Zone{zone_num} {fm_data['name']} assignment output: {out[:300]}")

# ============================================================
# 8. Final state summary
# ============================================================
print("\n=== Final State ===")
final_territories = sf_query("SELECT Id, Name, ParentTerritoryId FROM ServiceTerritory ORDER BY Name")
terr_by_id = {t["Id"]: t["Name"] for t in final_territories}

print(f"Service Territories ({len(final_territories)}):")
parents = [t for t in final_territories if not t.get("ParentTerritoryId")]
children_map = {}
for t in final_territories:
    if t.get("ParentTerritoryId"):
        pid = t["ParentTerritoryId"]
        children_map.setdefault(pid, []).append(t["Name"])

for p in sorted(parents, key=lambda x: x["Name"]):
    kids = children_map.get(p["Id"], [])
    print(f"  [{p['Name']}]  ({len(kids)} children)")
    for k in sorted(kids):
        print(f"    - {k}")

final_members = sf_query(
    "SELECT ServiceTerritory.Name, ServiceResource.Name, TerritoryType "
    "FROM ServiceTerritoryMember ORDER BY ServiceTerritory.Name"
)
print(f"\nTerritory Members ({len(final_members)}):")
for m in final_members:
    print(f"  {m['ServiceTerritory']['Name']} | {m['ServiceResource']['Name']} | {m['TerritoryType']}")

# Community spot check
comm_check = sf_query(
    "SELECT Name, Zone__c, ServiceTerritory__c, Service_Territory_Name__c, FM_Assignment__r.Name "
    "FROM Community__c WHERE Zone__c != null ORDER BY Zone__c, Name LIMIT 30"
)
print(f"\nCommunity spot check (first 30 zone-assigned):")
for c in comm_check:
    fm = (c.get("FM_Assignment__r") or {}).get("Name","")
    print(f"  Zone{c['Zone__c']} | {c['Name']} | ST: {c.get('ServiceTerritory__c','')} | Terr: {c.get('Service_Territory_Name__c','')} | FM: {fm}")

