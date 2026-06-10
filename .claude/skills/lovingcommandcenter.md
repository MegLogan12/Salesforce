# Loving Command Center

Generate a comprehensive Excel workbook that documents every part of the LOVING business process and the Salesforce system — covering all 19+ process areas, every automation, every object/field, every gap, and every recommendation.

## What this skill does

Runs a Python script that produces `/tmp/loving_command_center.xlsx` with multiple worksheets:

1. **GAP ANALYSIS** — Every process area vs. Salesforce: what the docs say, what Salesforce has, the gap, recommendation, and priority
2. **TRIGGERS** — All 22+ active Apex triggers: object, name, status, repo coverage
3. **FLOWS** — All active/inactive flows: API name, label, type, trigger, status
4. **OBJECTS** — Key custom objects: name, label, purpose
5. **PROCESS MAP** — Every named business process from the 19 docs: area, steps summary, owner role, Salesforce coverage status

## Instructions

Run the Python script below. It will create the Excel file, then send it to the user.

```bash
python3 /home/user/Salesforce/.claude/skills/lovingcommandcenter.py
```

Then send the file:
```
/tmp/loving_command_center.xlsx
```

## Notes
- Re-run any time the process docs or org changes
- The script is self-contained — all data is embedded; no org connection needed
- To update data: edit the `ROWS` lists in the Python script
