#!/usr/bin/env python3
"""
parse_job_description.py
Pulls structured fields out of LOVING's free-text Cloudscape job descriptions.

Each description crams several things into one box: service type, estimated time,
square footage, material, reference numbers, due dates, and notes. This splits
them apart, scores confidence, and flags anything ambiguous for human review
instead of guessing. Nothing is dropped: the original text is always kept.

Pure standard library. Extend the lookup tables as you see more real data.
"""
import re
from dataclasses import dataclass, asdict, field

# ---- canonical service types (first match wins; order matters) ----
SERVICE_PATTERNS = [
    (r"\blawn\s*mainten", "Lawn Maintenance"),
    (r"\bplant\s*&?\s*sod\s*install|\bsod\s*install|\bplant\s*install", "Plant & Sod Install"),
    (r"\bresod|\bre[\s-]*sod|\breplace\s*sod", "Resod"),
    (r"\bre[\s-]*work\s*swale|\brework\s*swale", "Swale Re-work"),
    (r"\birrigation\s*repair|\birrigation", "Irrigation Repair"),
    (r"\breplace.*tree|\bdead\s*tree|\btree", "Tree Replacement"),
    (r"\btime\s*to\s*roll|\broll\s*yard", "Roll Yard"),
    (r"\baerat", "Aeration"),
    (r"\bwarranty", "Warranty"),
]

MATERIALS = ["bermuda", "fescue", "zoysia", "centipede", "st augustine", "sod", "pine straw", "mulch"]

# patterns
RE_HOURS_EXPLICIT = re.compile(r"[\(<]\s*(\d*\.?\d+)\s*(?:hrs?|hr|hours?)\s*[\)>]", re.I)
RE_HOURS_LOOSE    = re.compile(r"\b(\d*\.?\d+)\s*(?:hrs?|hours?)\b", re.I)
RE_BARE_PAREN     = re.compile(r"\((\d*\.?\d+)\)")               # (0.53) (.75) (6.75)
RE_SQFT           = re.compile(r"(\d[\d,]*)\s*(?:sq\s*ft|sf)\b", re.I)
RE_SQFT_PAREN     = re.compile(r"\((\d[\d,]*)\s*sf\)", re.I)
RE_REF            = re.compile(r"\b([A-Z]{2,4}\d{5,})\b")        # NDS0021645
RE_DUE            = re.compile(r"\bby\s+(\d{1,2}/\d{1,2}(?:/\d{2,4})?)\b", re.I)
RE_STOP           = re.compile(r"\b(\d+(?:st|nd|rd|th)\s+stop)\b", re.I)

FLAG_KEYWORDS = {
    "sub job": "SUB_JOB", "qi list": "QI_LIST", "sent email": "SENT_EMAIL",
    "warranty": "WARRANTY", "model": "MODEL", "see note": "SEE_NOTE",
    "1st stop": "FIRST_STOP", "temp irrigation": "TEMP_IRRIGATION",
}


@dataclass
class Parsed:
    original: str
    service_type: str = ""
    est_hours: float = None
    hours_confidence: str = ""        # high | medium | low
    sq_ft: int = None
    material: str = ""
    ref_no: str = ""
    due_date: str = ""
    stop_sequence: str = ""
    flags: list = field(default_factory=list)
    needs_review: bool = False
    review_reason: str = ""


def _f(x):
    try:
        return float(x)
    except Exception:
        return None


def parse(desc: str) -> Parsed:
    p = Parsed(original=desc or "")
    if not desc:
        p.needs_review = True; p.review_reason = "empty description"; return p
    text = desc.strip()
    low = text.lower()

    # service type
    for pat, name in SERVICE_PATTERNS:
        if re.search(pat, low):
            p.service_type = name; break
    if not p.service_type:
        p.service_type = "Unclassified"; p.needs_review = True; p.review_reason = "service type not recognized"

    # square footage (explicit beats parenthetical)
    m = RE_SQFT.search(text) or RE_SQFT_PAREN.search(text)
    if m:
        p.sq_ft = int(m.group(1).replace(",", ""))

    # hours: explicit (HRS) is high confidence; loose is high; bare parens depend on context
    m = RE_HOURS_EXPLICIT.search(text) or RE_HOURS_LOOSE.search(text)
    if m:
        p.est_hours = _f(m.group(1)); p.hours_confidence = "high"
    else:
        bares = RE_BARE_PAREN.findall(text)
        # a bare (x) right after a material is usually pallets/qty, NOT hours -> do not treat as hours
        after_material = re.search(r"(?:%s)\s*\(\d*\.?\d+\)" % "|".join(MATERIALS), low)
        if bares and not after_material:
            # bare number with no material context. If it reads like maintenance time, accept as hours (medium)
            val = _f(bares[0])
            if val is not None and val <= 12:               # sane hours range
                p.est_hours = val
                p.hours_confidence = "medium"
                if "mainten" not in low:
                    p.needs_review = True; p.review_reason = "bare number assumed hours, verify"
        elif after_material:
            p.flags.append("QTY_AFTER_MATERIAL_UNVERIFIED")
            p.needs_review = True; p.review_reason = "number after material may be pallets/qty, not hours"

    # material
    for mat in MATERIALS:
        if mat in low:
            p.material = mat.title(); break

    # reference number
    m = RE_REF.search(text)
    if m:
        p.ref_no = m.group(1)

    # due date
    m = RE_DUE.search(text)
    if m:
        p.due_date = m.group(1)

    # stop sequence
    m = RE_STOP.search(text)
    if m:
        p.stop_sequence = m.group(1)

    # flags
    for kw, flag in FLAG_KEYWORDS.items():
        if kw in low:
            p.flags.append(flag)

    return p


if __name__ == "__main__":
    # real strings pulled from the Cloudscape screenshots
    samples = [
        "Lawn Maintenance (0.53)",
        "Lawn Maintenance (1.6) see note*",
        "SUB JOB Lawn Maintenance (.75)",
        "6000 SQ FT - Plant & Sod Install - Bermuda (6.75) NDS0021645 1st stop",
        "Re work swale from previous repair (2 HRS)(250 SF) sod del to Sullivan",
        "Resod area near swale/spot in front yard (1 HRS)(20 SF)",
        "Install Lennar Temp Irrigation 6000 SQ FT - Plant & Sod Install - Bermuda",
        "Time to roll yard <.5 hr>",
        "Replace front dead yard tree (.5 HRS)",
        "Replace sod on curb strip & dead tree (1 HR)(150 SF) sod from install",
        "QI List - Irrigation repair - Repair damaged sprinkler head at right front corner (By 6/8)",
        "(SENT EMAIL)Irrigation repair",
    ]
    cols = ["service_type", "est_hours", "hours_confidence", "sq_ft", "material", "ref_no", "due_date", "stop_sequence", "needs_review"]
    print(f"{'description'[:52]:52} | " + " | ".join(c[:10] for c in cols))
    print("-" * 150)
    for s in samples:
        r = parse(s)
        d = asdict(r)
        print(f"{s[:52]:52} | " + " | ".join(str(d[c] if d[c] not in (None, '') else '.')[:10] for c in cols))
        if r.flags:
            print(f"{'':52} | flags: {', '.join(r.flags)}  reason: {r.review_reason}")
