#!/usr/bin/env python3
"""Static analysis over retrieved LOVING-layer source. Produces audit/data/findings_*.json."""
import json, os, re, glob

BASE = os.path.dirname(__file__)
RET = os.path.join(BASE, "retrieved")
DATA = os.path.join(BASE, "data")

ID_RE   = re.compile(r"['\"]([0-9a-zA-Z]{15}|[0-9a-zA-Z]{18})['\"]")
EMAIL_RE= re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}")
URL_RE  = re.compile(r"https?://[^'\"\s<>]+")
# Salesforce key prefixes -> likely object (subset, for ID classification)
PREFIX = {"00D":"Org","005":"User","00e":"Profile","00G":"Group/Queue","0PS":"PermSet",
 "012":"RecordType","00X":"EmailTemplate","01p":"ApexClass","701":"Campaign",
 "00Q":"Lead","001":"Account","003":"Contact","006":"Opportunity","500":"Case",
 "0WO":"WorkOrder","08p":"ServiceAppt","0Hn":"ServiceResource"}

def looks_like_id(tok):
    if len(tok) not in (15,18): return False
    if not re.fullmatch(r"[0-9a-zA-Z]+", tok): return False
    # must contain at least 1 digit and start with plausible prefix digit pattern
    return bool(re.match(r"[0-9]", tok)) and any(c.isdigit() for c in tok[:3])

# ---------- Apex ----------
def analyze_apex():
    classes = sorted(glob.glob(os.path.join(RET,"classes","*.cls")))
    triggers= sorted(glob.glob(os.path.join(RET,"triggers","*.trigger")))
    out=[]
    for path in classes+triggers:
        name=os.path.basename(path).split(".")[0]
        src=open(path,encoding="utf-8",errors="ignore").read()
        is_test = "@istest" in src.lower() or "testmethod" in src.lower()
        ids=[m.group(1) for m in ID_RE.finditer(src) if looks_like_id(m.group(1))]
        emails=[e for e in EMAIL_RE.findall(src) if not e.endswith(".com'") and "@salesforce" not in e]
        emails=[e for e in set(EMAIL_RE.findall(src))]
        urls=[u for u in set(URL_RE.findall(src))]
        seealldata = "seealldata=true" in src.replace(" ","").lower()
        asserts = len(re.findall(r"\b(System\.assert|Assert\.)", src))
        has_try = "try" in src and "catch" in src
        dml = bool(re.search(r"\b(insert|update|delete|upsert|undelete|Database\.)\b", src))
        sobjects = sorted(set(re.findall(r"\b([A-Z][A-Za-z0-9]+__c)\b", src)))
        out.append({"name":name,"kind":"trigger" if path.endswith(".trigger") else "class",
            "isTest":is_test,"lines":src.count("\n")+1,
            "hardcodedIds":sorted(set(ids)),
            "hardcodedEmails":sorted(e for e in set(emails)),
            "hardcodedUrls":sorted(urls),
            "seeAllData":seealldata,"assertCount":asserts,
            "hasTryCatch":has_try,"hasDml":dml,
            "customObjectsReferenced":sobjects[:40]})
    json.dump(out,open(os.path.join(DATA,"findings_apex.json"),"w"),indent=1)
    nid=sum(1 for c in out if c["hardcodedIds"])
    nsad=sum(1 for c in out if c["seeAllData"])
    print(f"  apex analyzed: {len(out)} files; {nid} with hardcoded IDs; {nsad} SeeAllData=true")

# ---------- Flows ----------
def analyze_flows():
    flows=sorted(glob.glob(os.path.join(RET,"flows","*.flow-meta.xml")))
    # status map from collected data
    flowdefs={f["DeveloperName"]:f for f in json.load(open(os.path.join(DATA,"flowdefinitions.json")))}
    out=[]
    for path in flows:
        name=os.path.basename(path).replace(".flow-meta.xml","")
        src=open(path,encoding="utf-8",errors="ignore").read()
        status = re.search(r"<status>(\w+)</status>", src)
        status = status.group(1) if status else "Unknown"
        ptype = re.search(r"<processType>(\w+)</processType>", src)
        ptype = ptype.group(1) if ptype else "?"
        trig = re.search(r"<triggerType>(\w+)</triggerType>", src)
        trig = trig.group(1) if trig else ""
        obj = re.search(r"<object>([A-Za-z0-9_]+)</object>", src)
        obj = obj.group(1) if obj else ""
        ids=sorted({m.group(1) for m in ID_RE.finditer(src) if looks_like_id(m.group(1))})
        emails=sorted(set(EMAIL_RE.findall(src)))
        urls=sorted(set(URL_RE.findall(src)))
        has_fault = "<faultConnector>" in src
        dml = any(t in src for t in ["<recordCreates>","<recordUpdates>","<recordDeletes>","<recordLookups>"])
        creates=src.count("<recordCreates>")
        updates=src.count("<recordUpdates>")
        deletes=src.count("<recordDeletes>")
        apexcalls=sorted(set(re.findall(r"<apexClass>([A-Za-z0-9_]+)</apexClass>", src)))
        subflows=sorted(set(re.findall(r"<flowName>([A-Za-z0-9_]+)</flowName>", src)))
        active_ver = bool(flowdefs.get(name,{}).get("ActiveVersionId"))
        out.append({"name":name,"status":status,"activeVersion":active_ver,
            "processType":ptype,"triggerType":trig,"object":obj,
            "creates":creates,"updates":updates,"deletes":deletes,
            "hasFaultPath":has_fault,"doesDml":dml,
            "apexCalled":apexcalls,"subflows":subflows,
            "hardcodedIds":ids,"hardcodedEmails":emails,"hardcodedUrls":urls})
    json.dump(out,open(os.path.join(DATA,"findings_flows.json"),"w"),indent=1)
    nofault=[f["name"] for f in out if f["doesDml"] and not f["hasFaultPath"]]
    hid=[f["name"] for f in out if f["hardcodedIds"]]
    print(f"  flows analyzed: {len(out)}; {len(nofault)} do DML without fault path; {len(hid)} with hardcoded IDs")

# ---------- LWC placeholder/toast detection ----------
def analyze_lwc():
    base=os.path.join(BASE,"..","force-app","main","default","lwc")
    out=[]
    for jsf in glob.glob(os.path.join(base,"*","*.js")):
        comp=os.path.basename(os.path.dirname(jsf))
        src=open(jsf,encoding="utf-8",errors="ignore").read()
        toast_only=len(re.findall(r"ShowToastEvent", src))
        navs=len(re.findall(r"NavigationMixin", src))
        # handlers that only fire a toast / Promise.resolve (placeholder)
        placeholders=re.findall(r"handle\w+\([^)]*\)\s*\{\s*[^}]*?_toast\([^}]*?\}\s*", src)
        out.append({"component":comp,"toastRefs":toast_only,
            "placeholderHandlers":len(placeholders)})
    json.dump(out,open(os.path.join(DATA,"findings_lwc.json"),"w"),indent=1)
    print(f"  lwc analyzed: {len(out)} components")

if __name__=="__main__":
    print("[analysis]")
    analyze_apex(); analyze_flows(); analyze_lwc()
    print("done")
