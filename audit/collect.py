#!/usr/bin/env python3
"""LOVING production org audit collector.
READ-ONLY. Pulls structured metadata via Tooling/REST/Metadata API using the `sf` CLI.
Each dataset is cached to audit/data/<name>.json so the run is resumable (checkpoint).
"""
import json, os, subprocess, sys, time

ORG = "dispatch"
DATA = os.path.join(os.path.dirname(__file__), "data")
os.makedirs(DATA, exist_ok=True)

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout, r.stderr, r.returncode

def tooling(query):
    out, err, rc = run(["sf","data","query","--use-tooling-api","--target-org",ORG,
                         "--query",query,"--json"])
    try:
        d = json.loads(out)
        return d.get("result",{}).get("records",[])
    except Exception:
        sys.stderr.write(f"TOOLING FAIL: {query[:80]}\n{err[:300]}\n")
        return None

def soql(query):
    out, err, rc = run(["sf","data","query","--target-org",ORG,"--query",query,"--json"])
    try:
        d = json.loads(out)
        return d.get("result",{}).get("records",[])
    except Exception:
        sys.stderr.write(f"SOQL FAIL: {query[:80]}\n{err[:300]}\n")
        return None

def save(name, data):
    if data is None:
        print(f"  SKIP {name} (query failed)"); return
    p = os.path.join(DATA, name+".json")
    with open(p,"w") as f: json.dump(data, f, indent=1, default=str)
    n = len(data) if isinstance(data,list) else 1
    print(f"  saved {name} ({n} rows)")

def have(name):
    return os.path.exists(os.path.join(DATA, name+".json"))

def load(name):
    p = os.path.join(DATA, name+".json")
    if not os.path.exists(p): return None
    with open(p) as f: return json.load(f)

# Standard objects in active LOVING use — get their custom fields too.
STD_FOCUS = {
 "Account","Contact","Lead","Opportunity","Quote","Order","Product2","Pricebook2",
 "Case","WorkOrder","WorkOrderLineItem","ServiceAppointment","ServiceResource",
 "ServiceTerritory","AssignedResource","WorkType","Asset","Task","Event","User",
}

def collect(name, fn, force=False):
    if have(name) and not force:
        print(f"  cached {name}"); return
    save(name, fn())

# ---------- Phase: object & field inventory ----------
def phase_objects():
    print("[objects/fields]")
    # All entity definitions (objects). EntityDefinition disallows ORDER BY + some fields.
    collect("entitydefinitions", lambda: tooling(
        "SELECT QualifiedApiName, Label, PluralLabel, KeyPrefix, IsCustomSetting, "
        "IsCustomizable, NamespacePrefix FROM EntityDefinition LIMIT 2000"))
    # Authoritative custom-object list (no namespace) from Tooling CustomObject.
    collect("customobjects", lambda: tooling(
        "SELECT DeveloperName, NamespacePrefix FROM CustomObject WHERE NamespacePrefix=null"))
    # Field definitions must be filtered per-entity; collect for LOVING-layer objects.
    def fields_per_object():
        cobs = load("customobjects") or []
        targets = sorted({c["DeveloperName"]+"__c" for c in cobs} | STD_FOCUS)
        allf = []
        for i,api in enumerate(targets):
            recs = tooling(
                "SELECT QualifiedApiName, Label, DataType, IsCalculated, IsNillable, "
                "NamespacePrefix FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName='%s'" % api)
            if recs:
                for r in recs:
                    r["Object"] = api
                allf.extend(recs)
            if i % 25 == 0:
                print(f"    fields {i}/{len(targets)} ({api}) total={len(allf)}")
        return allf
    collect("fielddefinitions_custom", fields_per_object)

# ---------- Phase: apex ----------
def phase_apex():
    print("[apex]")
    collect("apexclasses", lambda: tooling(
        "SELECT Name, NamespacePrefix, ApiVersion, Status, LengthWithoutComments, "
        "IsValid, CreatedDate, LastModifiedDate FROM ApexClass ORDER BY Name"))
    collect("apextriggers", lambda: tooling(
        "SELECT Name, NamespacePrefix, TableEnumOrId, Status, ApiVersion, "
        "UsageBeforeInsert, UsageAfterInsert, UsageBeforeUpdate, UsageAfterUpdate, "
        "UsageBeforeDelete, UsageAfterDelete, UsageAfterUndelete, IsValid, "
        "LengthWithoutComments, LastModifiedDate FROM ApexTrigger ORDER BY Name"))
    collect("apexcoverage", lambda: tooling(
        "SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered "
        "FROM ApexCodeCoverageAggregate ORDER BY ApexClassOrTrigger.Name"))

# ---------- Phase: automation ----------
def phase_automation():
    print("[automation]")
    collect("flowdefinitions", lambda: tooling(
        "SELECT DeveloperName, NamespacePrefix, ActiveVersionId, "
        "LatestVersionId FROM FlowDefinition ORDER BY DeveloperName"))
    collect("flows", lambda: tooling(
        "SELECT MasterLabel, DefinitionId, ProcessType, Status, VersionNumber, "
        "ApiVersion, LastModifiedDate FROM Flow ORDER BY MasterLabel, VersionNumber"))
    collect("validationrules", lambda: tooling(
        "SELECT ValidationName, EntityDefinitionId, Active, ErrorMessage, "
        "ErrorDisplayField, Description, NamespacePrefix "
        "FROM ValidationRule ORDER BY EntityDefinitionId, ValidationName"))
    collect("workflowrules", lambda: tooling(
        "SELECT Name, TableEnumOrId FROM WorkflowRule ORDER BY Name"))

# ---------- Phase: ui ----------
def phase_ui():
    print("[ui]")
    collect("customapps", lambda: tooling(
        "SELECT DeveloperName, NamespacePrefix, Label, NavType, UiType "
        "FROM CustomApplication ORDER BY DeveloperName"))
    collect("customtabs", lambda: tooling(
        "SELECT DeveloperName, NamespacePrefix FROM CustomTab ORDER BY DeveloperName"))
    collect("flexipages", lambda: tooling(
        "SELECT DeveloperName, NamespacePrefix, Type, MasterLabel "
        "FROM FlexiPage ORDER BY DeveloperName"))
    collect("weblinks", lambda: tooling(
        "SELECT Name, PageOrSobjectType, LinkType, DisplayType, NamespacePrefix "
        "FROM WebLink ORDER BY PageOrSobjectType, Name"))
    collect("quickactions", lambda: tooling(
        "SELECT DeveloperName, SobjectType, Type, TargetSobjectType, Label, NamespacePrefix "
        "FROM QuickActionDefinition ORDER BY SobjectType, DeveloperName"))

# ---------- Phase: security ----------
def phase_security():
    print("[security]")
    collect("permissionsets", lambda: tooling(
        "SELECT Name, Label, NamespacePrefix, IsCustom, IsOwnedByProfile, "
        "PermissionsModifyAllData, PermissionsViewAllData, PermissionsAuthorApex "
        "FROM PermissionSet ORDER BY Name"))
    collect("profiles", lambda: soql("SELECT Name, UserType FROM Profile ORDER BY Name"))
    collect("permsetgroups", lambda: tooling(
        "SELECT DeveloperName, MasterLabel, Status FROM PermissionSetGroup ORDER BY DeveloperName"))
    collect("userroles", lambda: soql("SELECT Name, DeveloperName, ParentRoleId FROM UserRole ORDER BY Name"))
    collect("groups", lambda: soql("SELECT Name, DeveloperName, Type FROM Group WHERE Type IN ('Regular','Queue') ORDER BY Type, Name"))
    collect("queues_sobjects", lambda: soql("SELECT Queue.Name, SobjectType FROM QueueSobject ORDER BY Queue.Name"))

# ---------- Phase: analytics & comms ----------
def phase_analytics():
    print("[analytics/comms]")
    collect("reports", lambda: soql("SELECT Name, DeveloperName, Format, FolderName, LastRunDate FROM Report ORDER BY FolderName, Name"))
    collect("dashboards", lambda: soql("SELECT Title, DeveloperName, FolderName, Type FROM Dashboard ORDER BY FolderName, Title"))
    collect("emailtemplates", lambda: soql("SELECT Name, DeveloperName, TemplateType, FolderName, IsActive FROM EmailTemplate ORDER BY Name"))
    collect("customlabels", lambda: tooling("SELECT Name, MasterLabel, Category, Value, NamespacePrefix FROM ExternalString ORDER BY Name"))

# ---------- Phase: async / integration ----------
def phase_async():
    print("[async/integration]")
    collect("crontriggers", lambda: soql(
        "SELECT CronJobDetail.Name, CronJobDetail.JobType, State, NextFireTime, "
        "PreviousFireTime, StartTime, CronExpression FROM CronTrigger ORDER BY NextFireTime"))
    collect("asyncjobs_recent", lambda: soql(
        "SELECT JobType, ApexClass.Name, Status, MethodName, JobItemsProcessed, "
        "TotalJobItems, NumberOfErrors, CreatedDate FROM AsyncApexJob "
        "ORDER BY CreatedDate DESC LIMIT 200"))

# ---------- Phase: record counts for key objects ----------
def phase_recordcounts():
    print("[record counts]")
    # Loaded separately after object list is known
    pass

PHASES = {
 "objects": phase_objects, "apex": phase_apex, "automation": phase_automation,
 "ui": phase_ui, "security": phase_security, "analytics": phase_analytics,
 "async": phase_async,
}

if __name__ == "__main__":
    sel = sys.argv[1:] or list(PHASES)
    for p in sel:
        if p in PHASES:
            PHASES[p]()
        else:
            print(f"unknown phase {p}")
    print("done")
