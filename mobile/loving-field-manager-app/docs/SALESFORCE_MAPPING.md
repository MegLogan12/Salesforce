# Salesforce Mapping Summary

## Architecture recommendation

The React and iOS app should remain a thin Field Manager workspace. Salesforce remains the system of record.

| Business Need | Recommended Object / Cloud | Why | Risk | Approval Needed |
|---|---|---|---|---|
| Field Manager job queue | `Work_Order__c`, `Aqua_Check_Ticket__c`, `QI_Inspection__c` | FM needs one queue across closeout, Aqua, and QI. | Bad priority logic can hide urgent work. | No, if read-only DTO only. |
| Work execution | `Work_Order__c` or standard `WorkOrder`, confirmed by org architecture | Primary execution record. | Conflicts exist between custom and standard WorkOrder usage. | Yes, if source of truth changes. |
| Scheduling | FSL ServiceAppointment plus scheduling records | Route, crew, territory, mobile. | FSL not fully ready if territories and licenses are missing. | Yes, if moving scheduling backbone. |
| Photo proof | `Photo__c` plus ContentDocumentLink | Required category proof. | Raw file count is not enough. | Yes, if required categories change. |
| QI | `QI_Inspection__c` | Scoring and closeout gate. | Threshold confusion blocks operations. | Yes, if threshold changes. |
| Finished Job | Child Work Order | Tracks return visit and FM scorecard. | Could distort billing if not no-charge. | No, if following approved FJ rule. |
| Invoice path | `Invoice__c` | Financial source of truth. | Parent billing is a major control failure. | Yes, if billing logic changes. |
| Aqua repair | Aqua ticket plus FSL ServiceAppointment | Same-day dispatch path. | No fake dispatch. Must create real ticket. | No, if using approved Aqua ticket model. |

## Permission intent

| Role | Can Do | Cannot Do |
|---|---|---|
| FM | Review, return, QI, FJ, Aqua repair dispatch, closeout approval. | Edit BMG pricing, bill Parent Account, bypass gates. |
| Foreman | Submit field complete, photos, actuals. | Close Work Order, create Finished Job. |
| Scheduler | Change schedule, release schedule, assign crew. | Approve closeout or QI. |
| CSM | PO and takeoff review. | Schedule field work or approve QI. |
| COO | Visibility and override. | Should not be required for normal field execution. |

## Production build caution

Do not wire this directly to production until the DTO endpoint is tested in sandbox and all closeout gates are validated server-side.
