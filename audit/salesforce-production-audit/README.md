# LOVING Salesforce Production Audit

Initiated: 2026-05-19

## Structure

```
audit/salesforce-production-audit/
  raw/                    ← Local only (gitignored). Raw SOQL outputs and metadata retrieval.
  retrieved-metadata/     ← Local only (gitignored). sf project retrieve output.
  LOVING_Salesforce_Production_Audit.md         ← Full technical audit report
  LOVING_Salesforce_Remediation_Backlog.md      ← Prioritized P0–P3 remediation items
  LOVING_Salesforce_Executive_Audit_Summary.md  ← Executive summary
```

## Policy

Raw data files are intentionally excluded from version control.
They contain production usernames, org IDs, and record data.
Only synthesized audit documents (Markdown reports) are committed.

See CLAUDE.md for credential and data handling policy.
