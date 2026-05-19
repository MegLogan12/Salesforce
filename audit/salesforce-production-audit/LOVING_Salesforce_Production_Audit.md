# LOVING Salesforce Production Audit

**Audit Date:** 2026-05-19
**Audited By:** Claude Code (read-only inspection)
**Org:** https://loving.my.salesforce.com
**Scope:** Full platform audit — 16 sections
**Salesforce Edition:** Enterprise Edition, API v66.0
**Audit Method:** Non-destructive read-only queries and metadata inspection only. No data was modified.

---

## TL;DR — Executive Summary

- **Three P0 API limits are actively failing today:** Scheduled Flow Run capacity is 100% exhausted (flows are not running), Daily Delivered Platform Events are 100% exhausted (integrations are dropping messages), and Daily Async Apex Executions are at 98.8% — the org is operating in a degraded state right now and has been for some time.
- **The production org and the GitHub repository are out of sync in a dangerous way:** 11 LOVING_-prefixed Apex classes in the repo do not exist in production; their equivalents exist under different names. Deploying from the repo as-is would create a third trigger on the WorkOrder object alongside two that already exist, likely breaking field service dispatch entirely.
- **Org-wide Apex test coverage is 37.6%** against a required minimum of 75% — no metadata deployment of any kind can succeed until this is resolved. 100+ tests are actively failing due to a single root cause (`Work_Order_Type__c` made required without updating test factories).
- **Field Service Lightning readiness is 3/10:** 14 of 19 service territories have zero assigned technicians, all crew-based dispatch is inactive, skills are unconfigured, and 8 past-due service appointments have not been closed or rescheduled.
- **Aqua Operations readiness is 1/10:** The Aqua workflow references custom fields, objects, and record types that do not exist in production. Aqua flows would fail at runtime if triggered.
- **Inventory tracking is non-functional:** 103 community pricebooks exist but likely contain no entries. Zero ProductItems exist. One warehouse location is marked `IsInventoryLocation=false`. There are only 7 Work Order Line Items in the entire org.
- **Security and access hygiene is poor:** 25 active users have never logged in and are consuming scarce full licenses; a deactivated sysadmin (Frank Realmuto) retains 15 permission set assignments including `FieldServiceAdmin` and `DocuSign_Administrator`; a "Tester Profile" with Guest User License is active in production; a user's Salesforce username is a personal Gmail address; and 340 standalone permission sets exist with no governance model.

---

## Section 1 — Org Foundation

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Platform | Salesforce Edition | Enterprise Edition, API v66.0 | Low | Low | None — current edition supports all planned features | Confirm API version is pinned in CI/deployment tooling | P3 | No |
| Platform | Instance URL | https://loving.my.salesforce.com | Low | Low | None | Document in all integration configs | P3 | No |
| Packages | Installed packages (21 total) | Salesforce Maps, DocuSign (dfsle), RingCentral (RC), Clientell AI v0.5, GPS Insight/WEX fleet, Rippling, HERE Traffic, OSRM routing, Salesforce CRM Dashboards (Summer 2011) | High — deprecated package is actively installed | High — deprecated packages receive no security patches | Deprecated package may conflict with modern metadata | Remove "Salesforce.com CRM Dashboards" (Summer 2011 package) immediately; audit all 21 packages for current support status | P1 | Yes — Meg Logan |
| Packages | Clientell AI v0.5 | Pre-release / beta version active in production | High — beta software in production is unsupported | High — no SLA or stability guarantees | Risk of unexpected behavior in production data or UI | Evaluate production readiness; downgrade to stable release or remove until GA | P1 | Yes — Meg Logan |
| Licenses | Salesforce full licenses | 32 of 36 used (88.9%) | High — only 4 licenses remain as buffer | Medium — growth blocked | Hiring any new field staff risks hitting the license ceiling | Reclaim licenses from 25 never-logged-in users immediately | P1 | No |
| Licenses | Permission Sets | 1,428 of 1,500 used (95.2%) | High — at 95.2% capacity | Medium | Adding permissions for new features will be blocked at 1,500 | Audit and consolidate 340 standalone permission sets; delete unused assignments | P1 | No |
| API Limits | ScheduledFlowRunLimit | 250,000 / 250,000 — **100% exhausted** | Critical — scheduled automation is not running | Critical | Scheduled flows are not executing — operational workflows are silently failing | Immediate investigation required: identify highest-frequency scheduled flows and optimize or reschedule off-peak; consider async Apex replacements | **P0** | No |
| API Limits | DailyDeliveredPlatformEvents | 130,000 / 130,000 — **100% exhausted** | Critical — integration messages are being dropped | Critical | RingCentral, GPS Insight, and any platform event-driven integration is losing data | Audit event volume; implement event replay where possible; consider event bus capacity upgrade | **P0** | Yes — Meg Logan |
| API Limits | DailyAsyncApexExecutions | 247,092 / 250,000 — **98.8% exhausted** | Critical — batch and async Apex will fail before end of day | Critical | Any batch job, future method, or queueable submitted late in the day will be dropped | Audit 70 scheduled cron jobs; reschedule or consolidate jobs; implement governor limit monitoring | **P0** | No |
| Architecture | 552 of 643 Accounts belong to "NextDaySod" | 86% of Account data belongs to a separate business entity | High — data co-mingling between legal entities | Medium | LOVING data obscured by NextDaySod volume; reporting inaccurate | Formally define org sharing strategy; evaluate whether NextDaySod requires its own org | P1 | Yes — Meg Logan |

### Narrative

The org is running three simultaneous P0 limit exhaustions today. These are not warnings — they are active failures. Scheduled flows are not running, platform event integrations are dropping messages, and the async Apex budget is nearly gone for the day. These three conditions together mean that a meaningful portion of the org's automation has been silently non-functional, potentially for days or weeks.

The 21-package footprint includes a package from Summer 2011 (Salesforce CRM Dashboards) that predates modern Lightning Experience by five years and has not received updates in over a decade. It should be removed. Clientell AI v0.5 is a beta/pre-release product operating in production without a stability guarantee.

The NextDaySod data situation is architecturally significant: 86% of Account records in what is supposed to be the LOVING org belong to a different business. This creates reporting noise, permission complexity, and data governance risk that compounds every other issue in this audit.

---

## Section 2 — User Access and Security

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Users | Active users who have never logged in | 25 active users, zero logins on record | High — consuming 25 of 36 full licenses unnecessarily | Low | Blocker for new hires; licenses wasted | Deactivate all 25 never-logged-in users after confirming with Meg Logan they are not pending onboardings | P1 | Yes — Meg Logan |
| Users | Inactive former Sysadmin | Frank Realmuto — deactivated user, last login 46 days ago | High — active permission set assignments on deactivated account | High — assignments persist and may be exploited if account is reactivated | Security exposure if account is ever reactivated | Remove all 15 permission set assignments from Frank Realmuto immediately | P1 | No |
| Users | Permission sets on deactivated users | 15 PSA records on 4 deactivated users, including FieldServiceAdmin and DocuSign_Administrator on Frank Realmuto | High — privilege-rich PSAs on inactive accounts | High | Potential reactivation risk | Audit and remove all PSAs from all deactivated users | P1 | No |
| Users | Personal Gmail as Salesforce username | Justin Johnson — personal Gmail address used as SF username | Medium — username exits org control if employment ends | Low | Username cannot be updated without recreating the user record | Document; plan username governance policy for future users | P2 | No |
| Profiles | "Tester Profile" with Guest User License | Active in production | High — test profile should never exist in production | High — Guest User licenses have unique security posture | Exposes test configuration in live org | Deactivate or delete Tester Profile from production immediately | P1 | Yes — Meg Logan |
| Profiles | 57 profiles total | Extremely high profile count for org of this size | Medium — maintenance burden | Medium — each profile is a security vector | Complexity increases risk of misconfigured access | Profile consolidation project; move to permission set-first model | P2 | No |
| Permission Sets | 340 standalone permission sets | No documented governance or ownership model | High — ungoverned access grants | High — sprawl makes auditing impossible | Users may have access beyond their role requirements | Implement permission set group model; document business owner for each PSA | P1 | No |
| Permission Sets | 209 assignments vs 340 sets | 131 permission sets have zero assignments | Low — waste | Low | No direct impact | Delete unassigned permission sets or document their purpose | P3 | No |
| Role Hierarchy | Person-named roles | Role names reference specific employees, not job functions | Medium — role hierarchy breaks when named employee leaves | Medium — sharing rules tied to person-named roles break silently | Org-wide sharing breaks when employees are reassigned | Rename all roles to job functions (e.g., "Field Manager — Charlotte" not "Jamie Hinson") | P1 | No |
| Sysadmins | 2 active, 1 inactive | 2 active System Administrators; Frank Realmuto (former sysadmin) deactivated 46 days ago | Medium — sysadmin count appropriate but inactive record is risk | Medium | None while deactivated | Complete the deactivation by removing all PSAs; confirm 2 active sysadmins is sufficient | P1 | No |

### Narrative

The access and security picture has four structural problems. First, 25 full Salesforce licenses are allocated to users who have never logged in — in an org with only 4 licenses remaining, this is an immediate operational blocker. Second, deactivated users retain permission set assignments, which is a security gap that violates the principle of least privilege and would cause a significant problem if any account were reactivated. Third, the role hierarchy is named after individual employees rather than job functions, which means it silently breaks every time a person changes roles or leaves. Fourth, 340 standalone permission sets with no governance model makes access auditing practically impossible.

The "Tester Profile" with a Guest User License in production is particularly concerning — this type of profile configuration is typically used during development and should not survive to a production org.

---

## Section 3 — Object Model

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Object Count | 145 custom objects | ~90 LOVING-native, 21 FSL, 17 DocuSign, 6 Maps, 3 RingCentral | Medium — high complexity for org at this stage | High — metadata retrieval and deployment times increase with object count | Cognitive overhead for all developers and admins | Document all custom objects with business owner and data volume | P2 | No |
| WorkOrder | Field count | 263 total fields, 196 custom | High — field sprawl indicates unplanned schema growth | High — SOQL queries approach field limits; page layouts degrade | Field maintenance is unmanageable; new devs cannot orient | Immediate field audit: identify unused fields, candidates for deprecation | P1 | No |
| Account | Field count | 234 total fields, 144 custom | High — same field sprawl problem | High | Same as above | Same field audit approach | P1 | No |
| Architecture | DUAL Work Order model | Standard `WorkOrder` (FSL-integrated, 21 records) AND custom `Work_Order__c` (7 record types, 88 validation rules, 0 records) | Critical — two parallel data models for the same business entity | Critical — automation, triggers, and integrations split across both objects | Impossible to get a single operational view of work orders | Decision required: choose one canonical work order object; migrate and deprecate the other | **P0** | Yes — Meg Logan |
| Schema Drift | Missing fields (Account) | `Lot_Number__c`, `Street_Address__c`, `Lot_Status__c` do not exist on Account in production | High — flows and Apex referencing these fields fail at runtime | High | Core business logic broken | Reconcile repo schema definitions against production; deploy missing fields or update code to remove references | P1 | No |
| Schema Drift | Missing fields (WorkOrder) | `FM__c`, `Lot_Address__c`, `Community__c`, `Health_Check_Status__c`, `Finish_Job_Required__c` do not exist on WorkOrder in production | High — same runtime failure risk | High | Field Service operations broken | Same reconciliation needed | P1 | No |
| Schema Drift | Missing record types | No "Community" or "Lot" record type on Account | High — Aqua and LOVING flows reference these record types | High | Aqua operations cannot function | Deploy missing record types; update all flows referencing them | P1 | No |
| Duplicate Objects | Two "Homeowner" Account record types | `Home_Owner` and `Homeowner` — different developer names, apparent duplicate | Medium — data split across two RTs without clear distinction | Medium | Inconsistent homeowner records | Audit data distribution; merge into single canonical record type | P2 | No |
| Schema Stubs | `QI_Inspection__c` | 0 records, no business fields deployed | Low — no active impact | Low | Quality inspection workflow has no data model | Either build out the schema or remove the stub to reduce clutter | P2 | No |
| Schema Stubs | `Finish_Job__c` | 0 records, no business fields deployed | Low | Low | Same as above | Same recommendation | P2 | No |
| Duplicate Rules | No custom duplicate/matching rules | No rules on any operational object | Medium — duplicate data accumulates silently | Low | Data quality degrades over time | Implement duplicate rules on Account, Contact, and WorkOrder at minimum | P2 | No |

### Narrative

The dual work order model is the most consequential architectural finding in this audit. The org has simultaneously built and partly populated the standard Salesforce `WorkOrder` object (which is FSL-native and has 21 live records) while also maintaining a large custom `Work_Order__c` object with 7 record types, 88 validation rules, and deep automation — but zero confirmed records. This creates an impossible operational question: which object is authoritative? Automation, triggers, and reporting are split between them. Until this is resolved with a clear architectural decision, every feature built on either object is building on an unstable foundation.

The field counts on WorkOrder (196 custom) and Account (144 custom) are hallmarks of unplanned schema growth — likely the result of multiple developers adding fields ad hoc over time without a field governance process. These objects are approaching practical limits for page layout usability and SOQL query complexity.

---

## Section 4 — Record Types, Picklists, and Statuses

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| WorkOrder RTs | 19 record types, 7 inactive | Active: 12. Inactive: Aqua New Install, Land Development, Outdoor Living, Plant & Sod Install, Residential, Site Visit, Temporary Irrigation, Upgrade My Backyard | Medium — inactive RTs clutter UI and confuse users | Medium — inactive RTs still referenced in validation rules and flows | Technicians see record type options that don't apply | Formally deprecate or delete inactive record types; update all rule/flow references first | P2 | No |
| WorkOrder RTs | "Upgrade My Backyard" inactive | One of the core business lines is an inactive record type on WorkOrder | High — if this is an active product line, its WO RT is off | High | Work orders for UMB may be misclassified | Confirm with Meg Logan whether UMB is active; reactivate RT or document the status change | P1 | Yes — Meg Logan |
| Account RTs | Duplicate Homeowner types | `Home_Owner` (API name) and `Homeowner` — two separate active record types | Medium — homeowner data fragmented | Medium | CRM reports on homeowners are inaccurate | Audit which RT has more records; merge data and delete the duplicate | P2 | No |
| Opportunity Stages | "Propsal Presented" typo | Active picklist value has a typo in production | Medium — visible to all sales users and external reports | Low | Unprofessional appearance in reports and exports | Rename picklist value; update any dependent automation referencing the value by name | P2 | No |
| Opportunity Stages | 83% in "Community Activated" | 266 Opportunities, 221 stuck in a single stage | High — pipeline is not progressing | Medium | Revenue forecasting impossible | Investigate why opportunities do not advance; determine if stage definitions match actual business process | P1 | No |
| Case Status | 100% in "New" | 2,065 Cases, all in "New" status | High — case management is non-functional | Low — data load is fine | Customer issues are not being tracked or resolved | Investigate whether Cases are being worked outside Salesforce; if so, build the workflow to close the loop | P1 | No |
| Work Order Statuses | 8 past-due "Scheduled" appointments | Service appointments dated May 10–14, 2026 with no completion or update | High — operational gaps in field scheduling | Low | Technicians have unresolved scheduled work | Reschedule or close each of the 8 appointments; establish a daily dispatch review process | P1 | No |
| Validation Rules | 88 total, 85 active | 8 on WorkOrder, 10 on Voucher__c, 8 on Schedule_Issue__c | Medium — high VR count on single objects increases runtime complexity | Medium — VR interactions are hard to debug | Unexpected save failures for field users | Audit VRs for overlapping logic; document each rule's business owner | P2 | No |

### Narrative

Two findings here have direct revenue impact. First, 83% of Opportunities are stuck in the "Community Activated" stage — this is either a pipeline management failure (deals are progressing but the stage is not being updated) or a process design failure (the stage model does not match the actual sales motion). Either way, leadership cannot make accurate revenue forecasts from this data. Second, all 2,065 Cases are in "New" status, which indicates the Case object is being used as a ticket inbox but not as an operational workflow tool.

The "Upgrade My Backyard" record type being inactive on WorkOrder is worth urgent clarification — if UMB is a live product line, this is causing misclassification of work orders in production today.

---

## Section 5 — Page Layouts and Lightning Experience

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Page Layouts | Audit coverage | Not deeply audited in this pass | Medium — layout issues affect user adoption and data entry | Low | Unknown — may have significant usability problems | Conduct a dedicated page layout audit pass; interview field users and dispatchers about friction points | P2 | No |
| Lightning Experience | Activation status | Not confirmed in this audit | Medium — Classic vs LEX differences affect mobile usability | Medium | Field technicians on mobile need LEX-optimized layouts | Confirm LEX activation status; audit all profiles for "Lightning Experience User" permission | P2 | No |
| WorkOrder Layout | Field density | 196 custom fields exist on WorkOrder | High — unusable layouts for technicians | Medium | Technicians see irrelevant fields | After field audit (Section 3), rebuild WorkOrder layouts with only operationally relevant fields | P1 | No |
| Mobile | FSL Mobile app | Not audited in this pass | High — FSL mobile is the primary technician interface | Medium | If FSL mobile layouts are misconfigured, technicians cannot complete work | Conduct FSL mobile layout audit as part of FSL remediation sprint | P1 | No |

**Note:** Page layouts and Lightning Experience configuration were not deeply audited in this pass. A dedicated follow-up audit of page layouts, compact layouts, Lightning record pages, and FSL mobile configurations is recommended as a separate workstream. Findings from the field audit (Section 3) — particularly the 196-field WorkOrder — strongly suggest layout usability problems exist.

---

## Section 6 — Automation

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Flows | Active flows | 59 active flows | Medium — high flow count increases governor limit consumption | High — unmanaged flow proliferation leads to P0 limits | Contributing to ScheduledFlowRunLimit exhaustion | Audit all 59 active flows; identify which are scheduled; consolidate or deactivate lowest-priority flows immediately | **P0** | No |
| Flows | Non-active flows | 111 non-active: 72 Obsolete, 7 InvalidDraft, 32 Draft | Medium — obsolete flows clutter the org | High — 7 InvalidDraft flows BLOCK future deployments | Any deployment attempt will fail until InvalidDraft flows are resolved | Resolve all 7 InvalidDraft flows immediately (fix or delete) | **P0** | No |
| Flows | Scheduled flow exhaustion | ScheduledFlowRunLimit at 100% | Critical — no scheduled flows are running | Critical | Silent automation failures across the org | See Section 1 P0 items | **P0** | No |
| Legacy Automation | Workflow Rules | 0 active | Low — positive finding | Low | None | No action needed; clean stack | — | No |
| Legacy Automation | Process Builder | 0 active | Low — positive finding | Low | None | No action needed; clean stack | — | No |
| Apex Triggers | Duplicate WorkOrder triggers | `WorkOrderTrigger` + `WorkOrderFieldManagerMobileSync` both active on WorkOrder | High — non-deterministic execution order | High — either trigger can overwrite the other's changes | FSL dispatch and field sync behavior is unpredictable | Merge trigger logic into a single handler; delete the redundant trigger | P1 | No |
| Apex Triggers | Duplicate Opportunity triggers | `ODLHomeownerPropertyIdentityOpportunity` + `ODLOpportunityTrigger` both active | Medium | High — same non-deterministic risk | Sales automation behavior unpredictable | Same merge recommendation | P1 | No |
| Cron Jobs | 70 active scheduled cron jobs | Extremely high scheduled job count | High — primary driver of async Apex limit exhaustion | High | Batch processes failing late in the day | Audit all 70 jobs; consolidate or reschedule to off-peak; eliminate redundant jobs | P1 | No |
| Flows | Aqua flows reference non-existent fields | Aqua_Community__c, Zone__c, Aqua_Customer__c, FM__c do not exist on their objects | Critical — flows will throw runtime errors when triggered | Critical | Aqua operations completely non-functional | Do not activate Aqua flows until missing fields are deployed; see Section 10 | P1 | No |

### Narrative

The automation stack has one genuinely positive finding: zero Workflow Rules and zero Process Builder flows. The org has fully migrated to Flow, which is the correct modern architecture. However, the execution of that migration has created three serious problems.

First, 59 active flows plus 70 scheduled cron jobs are collectively exhausting the daily scheduled flow and async Apex limits before the business day ends. Second, 7 InvalidDraft flows will silently block every future deployment attempt until they are resolved. Third, duplicate triggers on two of the most critical objects (WorkOrder and Opportunity) mean that automation behavior on those objects is non-deterministic — the order in which two triggers execute is not guaranteed in Salesforce, so the outcome of saving a WorkOrder or Opportunity record cannot be predicted with certainty.

---

## Section 7 — Apex and Deployment Health

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Test Coverage | Org-wide Apex coverage | **37.6%** — minimum required: **75%** | Critical — no deployment of any metadata is currently possible | Critical — deploys fail at the org validation step | The org cannot receive any bug fixes, features, or configuration changes via deployment | Fix root-cause test failures immediately (see below) | **P0** | No |
| Test Failures | Root cause | `Work_Order_Type__c` made required but test factories not updated — affects 100+ tests | Critical | Critical | All deployments blocked | Update all test factory methods to populate `Work_Order_Type__c`; re-run full test suite | **P0** | No |
| Test Failures | LovingSchedulingActionServiceTest | 42 individual test failures in this class | High | High | Scheduling service untested | Fix test factory, verify scheduling logic still correct | P0 | No |
| Test Failures | MeasuringCupControllerTest | Failing — same root cause | High | High | Controller untested in production | Same fix | P0 | No |
| Test Failures | LovingFieldManagerMobileSyncServiceTest | Failing — same root cause | High | High | Mobile sync untested | Same fix | P0 | No |
| Zero Coverage | 79 classes/triggers at 0% coverage | Includes LovingSchedulingOverlayService (~86K lines) and AquaConsoleController (~94K lines) | High — two of the largest classes in the org have zero test coverage | High | These classes can contain silent bugs with no test safety net | Write unit tests for all 0%-coverage classes; prioritize by business criticality | P1 | No |
| Repo vs Org | 11 LOVING_-prefixed classes in repo do not exist in production | Repo has LOVING_WorkOrderTriggerHandler, LOVING_SchedulingService, etc.; production has WorkOrderTrigger, etc. | Critical — deploying from repo will create duplicate/conflicting triggers | Critical — a third WorkOrder trigger would be created | Field service could break on deploy | Do NOT deploy from repo until naming alignment is resolved; document canonical names | **P0** | Yes — Meg Logan |
| Triggers | 312 unmanaged Apex classes | High class count for org at this stage | Medium — maintenance burden | Medium | Large surface area for bugs | Enforce class naming standards; group by domain | P2 | No |
| Triggers | 24 unmanaged Apex triggers | Multiple triggers per object (see Section 6) | High | High | Non-deterministic behavior on WorkOrder, Opportunity | Merge to one-trigger-per-object pattern | P1 | No |
| Deployment | 7 InvalidDraft flows | Block all deployments | Critical | Critical | No changes can be deployed | Resolve all 7 before next deployment attempt | **P0** | No |

### Narrative

The org is in a deployment deadlock. Test coverage is 37.6% against a required 75%, which means no metadata can be deployed to production. The root cause is a single data model change (`Work_Order_Type__c` made required) that was not propagated to test factory methods — a common mistake that cascades across every test class that uses those factories. This is fixable in a focused sprint, but until it is fixed, no developer can ship anything.

Compounding this, the repo and production org have diverged significantly. The 11 LOVING_-prefixed classes in the repo represent a planned naming convention that was apparently not applied when the code was originally deployed. Deploying from the repo without reconciling this divergence would create a third trigger on the WorkOrder object — on top of two already there — with potentially catastrophic consequences for field service operations.

LovingSchedulingOverlayService and AquaConsoleController are the two largest classes in the org at approximately 86,000 and 94,000 lines respectively. Both have zero test coverage. These are extremely high-risk assets.

---

## Section 8 — Field Service / FSL Readiness

**FSL Readiness Score: 3/10**

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Territories | 14 of 19 territories have zero service resource members | Only Charlotte North (17 members) and Asheville (4 members) are operational | Critical — auto-scheduling cannot assign work in 14 territories | High | Work orders in unmanned territories cannot be auto-dispatched | Assign service resources to all territories; confirm territory-to-technician mapping with Meg Logan | P1 | Yes — Meg Logan |
| Resources | 4 active technicians unassigned to any territory | Jamie Hinson, Victor Zambrano, Jersain Laris, Scott Spaulding | High — these technicians cannot receive scheduled work | Medium | 4 technicians are invisible to the scheduling engine | Assign each to their correct territory immediately | P1 | No |
| Crews | All crew (C-type) service resources inactive | Crew-based dispatch non-functional across the entire org | High — LOVING's model likely requires crew dispatch | High | No multi-person jobs can be auto-dispatched | Activate crew resources; assign crew members; confirm crew model with operations | P1 | Yes — Meg Logan |
| Skills | ServiceSkill inaccessible | Skills feature unconfigured while "Match Skills" work rule is active | High — scheduling optimization is running against empty skill data | High — "Match Skills" rule will produce incorrect results or errors | Auto-scheduling is not optimizing for technician skills | Either configure skills completely or disable "Match Skills" work rule until skills are populated | P1 | No |
| Work Types | MinimumCrewSize/RecommendedCrewSize null | All 69 work types have null crew size fields | Medium — crew enforcement disabled | Medium | Scheduling engine cannot enforce crew requirements | Populate crew size fields for all work types; align with operations on correct crew sizes | P1 | No |
| Service Appointments | 3 SAs with null WorkType | Auto-scheduling will fail for these appointments | Medium | Medium | 3 jobs cannot be auto-scheduled | Assign work types to all service appointments | P1 | No |
| Operating Hours | Single record for all 19 territories | Territory-specific hours not configured | Medium — scheduling ignores territory time zones and local hours | Medium | Technicians may be scheduled outside their actual working hours | Create territory-specific operating hours records | P2 | No |
| Territories | Geography | 19 service territories in clean NC/SC geographic hierarchy | Low — this is a strength | Low | Well-designed foundation | No action needed; good work | — | No |
| Work Types | 69 work types with realistic durations | Well-populated work type catalog | Low — this is a strength | Low | Good scheduling foundation | No action needed | — | No |
| Scheduling Policies | 4 OOB policies, 14 OOB work rules | Using out-of-box configuration | Medium — OOB may not match LOVING's business rules | Medium | Scheduling optimizations may not reflect actual field priorities | Customize scheduling policies and work rules to match LOVING operations model | P2 | No |
| Past-Due Appointments | 8 past-due "Scheduled" SAs | Service appointments May 10–14, 2026 unresolved | High — these represent work that was never completed or rescheduled | Low | Customer commitments missed | Review each of the 8 SAs; complete, cancel, or reschedule; investigate why they were missed | P1 | No |
| Unassigned SAs | 10 service appointments with no AssignedResource | Cannot be dispatched | High | Low | 10 jobs in limbo | Assign or close each unassigned SA | P1 | No |
| Inactive Owner | WO 00000011 stuck since 2026-04-27 | Owned by inactive user; status "Scheduled" for 22+ days | High — live work order with no active owner | Low | This job may be completely untracked by operations | Reassign to active user; investigate current job status with field team | P1 | No |
| WOs Missing Data | 20 of 21 WOs missing Community__c | Community field is null on nearly all work orders | High — can't report or route by community | High — field doesn't exist on WO object in production | See Section 3 — field must be deployed before it can be populated | Deploy `Community__c` to WorkOrder; then populate from existing data | P1 | No |

### Narrative

FSL scores 3/10. The score reflects genuine architectural investment — a clean 19-territory geographic hierarchy, 69 well-configured work types, and an appropriate set of scheduling policies and work rules — but that investment is not operational. Fourteen of nineteen territories are empty. The scheduling engine has no technicians to assign in the majority of the service area. Crew dispatch, which is likely the primary operating model for a landscaping/field service business, is entirely inactive. Skills are unconfigured while a "Match Skills" work rule is running — meaning the optimization engine is actively making worse decisions than if the rule were simply disabled.

Eight past-due service appointments from May 10–14 have not been closed, rescheduled, or acted on in 5–9 days. This is an active operational gap, not a configuration issue.

The fundamental problem is that FSL was configured but not commissioned. The infrastructure is present; the operational data (territory assignments, crew activation, skill definitions) was never loaded.

---

## Section 9 — Work Order and Production Operations

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Work Orders | Total standard WOs | 21 Work Orders on the FSL `WorkOrder` object | Low — early stage | Low | Very early in operational deployment | Normal for early-stage deployment; focus on quality of these 21 over volume | P3 | No |
| Work Orders | Pipeline breakdown | New(9), Scheduled(5), Pending Takeoff(2), Ready to Schedule(2), FM/QI Review(1), Site Readiness(1), Site Visit Scheduled(1), In Progress(0) | Medium — 0 In Progress is concerning | Low | No work is currently confirmed as in-progress | Investigate whether "In Progress" status is being used correctly by field teams | P2 | No |
| Work Orders | Inactive owner (WO 00000011) | Stuck "Scheduled" since 2026-04-27, owned by inactive user Mahak Soni | High — active WO with no active owner for 22 days | Low | Job may be completely untracked | Reassign immediately; contact field team to confirm job status | P1 | No |
| Work Orders | 4 WOs owned by inactive user Mahak Soni | 4 live work orders with inactive owner | High | Low | These jobs have no active accountable owner | Bulk reassign all 4 WOs to an active user | P1 | No |
| Work Orders | Missing Community__c | 20 of 21 open WOs have null Community__c | High — cannot route or report by community | High — field may not exist on object (see Section 3) | Routing and community-level operations impossible | Deploy field; populate from associated account data | P1 | No |
| Work Orders | Missing Field_Manager__c | 13 of 21 open WOs have null Field_Manager__c | High — field manager accountability unclear | High — field may not exist in production | Cannot assign FM responsibility for most jobs | Deploy field; establish data entry requirement in process | P1 | No |
| Work Orders | UAT test data in production | Lots numbered UAT-xxx visible in live production data | High — test data pollutes production reporting | Low | Reports include fake records | Identify and delete all UAT test records; implement a data cleansing process | P1 | No |
| Work Orders | Dual WO model (see Section 3) | Standard WorkOrder AND custom Work_Order__c | Critical — architectural ambiguity | Critical | Operations team may be using the wrong object | See Section 3 P0 recommendation | **P0** | Yes — Meg Logan |
| Work Orders | Work_Order__c | 7 record types, 88 validation rules, 0 confirmed records | High — large investment in an apparently unused object | High | May be intended as the canonical WO but has zero records | Determine intended use; migrate or deprecate | **P0** | Yes — Meg Logan |
| Work Order Line Items | Only 7 total in org | No meaningful inventory or materials tracking in use | High — job costing impossible | Low | Cannot track materials per job | Build out WOLI workflow; see Section 11 | P1 | No |
| Process | No O → Q → WO handoff workflow | No evidence of Opportunity → Quote → Work Order workflow | High — revenue recognition and job tracking disconnected | Medium | Sales and operations are not connected in Salesforce | Define and build the handoff workflow; this is a core missing process | P1 | Yes — Meg Logan |

### Narrative

Production operations in Salesforce are in a very early state. With 21 Work Orders in the system, the org is being used for scheduling and dispatch of a small initial workload. The critical operational issue is that the work objects are misconfigured in ways that prevent even this small workload from being tracked properly — missing owner assignments, missing community and field manager fields, and the unresolved dual work order model.

The complete absence of an Opportunity-to-Work Order handoff workflow means the sales pipeline and the operations pipeline are disconnected. When a deal closes in Salesforce, there is no automated path to creating a work order, assigning it, and scheduling it. This is likely being done manually today, which introduces data entry errors and gaps.

---

## Section 10 — Aqua Operations

**Aqua Readiness Score: 1/10**

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Data | Aqua Work Orders | 2 Aqua WOs exist (Aqua Check + Aqua Pickup, both Scheduled) | High — very limited data | Low | Near-zero Aqua operational data | These appear to be test or setup records | P3 | No |
| Data | AccountId null on both Aqua WOs | Neither Aqua WO is linked to any community or lot | High — orphaned WOs with no account relationship | Low | Cannot associate Aqua work with any customer or property | Link to correct Account records immediately | P1 | No |
| Schema | Aqua_Community__c does not exist in production | Custom field expected by Aqua flows not deployed | Critical — flows will throw runtime errors | Critical | Aqua flows cannot execute | Deploy all missing Aqua fields before activating any Aqua flows | P1 | No |
| Schema | Zone__c does not exist on expected object | Same — missing field | Critical | Critical | Same | Same | P1 | No |
| Schema | Aqua_Customer__c does not exist on expected object | Same | Critical | Critical | Same | Same | P1 | No |
| Schema | FM__c does not exist on WorkOrder in production | Field expected by multiple flows missing | Critical | Critical | Field service assignments for Aqua broken | Deploy FM__c to WorkOrder | P1 | No |
| Schema | No Community record type on Account | Aqua's community model requires an Account RT that does not exist | Critical — the entire Aqua data model is missing | Critical | All Aqua community tracking non-functional | Design and deploy Community record type on Account; build out full Account schema for Aqua | P1 | Yes — Meg Logan |
| Products | No Aqua products in catalog | Zero Aqua-related products in product/pricebook structure | High — Aqua services cannot be quoted or invoiced | Low | No Aqua revenue tracking possible in Salesforce | Add Aqua products and pricebook entries | P2 | No |
| Automation | Aqua flows reference non-existent fields and objects | Would fail at runtime if any Aqua record is created | Critical | Critical | Aqua cannot operate in Salesforce today | Freeze Aqua flows; complete schema deployment first; then re-test all flows end-to-end | P1 | No |
| Architecture | No Lot record type on Account | Aqua's lot-level model also missing | Critical | Critical | Cannot track work at the lot level | Same as Community record type recommendation | P1 | Yes — Meg Logan |

### Narrative

Aqua scores 1/10. The Aqua workflow was designed for a data model that does not exist in production. The Community and Lot record types on Account, and multiple custom fields required by Aqua flows, were never deployed. If any user attempted to trigger an Aqua flow today, it would fail at runtime. The 2 Aqua Work Orders in the system are orphaned — they have no AccountId and are therefore not linked to any business entity.

The path forward requires a complete Aqua schema deployment sprint before any Aqua flows are activated or any operational data entry begins. This includes deploying Community and Lot record types on Account, deploying all missing custom fields, creating Aqua products in the catalog, and end-to-end testing every Aqua flow in a sandbox before production activation.

This feature is not ready for use.

---

## Section 11 — Inventory, Products, Pricing

**Inventory Readiness Score: 1/10**

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Products | 77 active products | All landscaping/hardscape — trees, shrubs, sod, pavers, irrigation, hardscape | Low — good product catalog foundation | Low | Products are available for use | Review product list for completeness; add Aqua products | P2 | No |
| Products | 0 product descriptions | No description on any of the 77 products | Low — usability issue | Low | Sales team cannot self-serve product info; customer-facing documents look incomplete | Add product descriptions to all 77 products | P3 | No |
| Pricebooks | 104 pricebooks (103 active) | 10+ with apparent duplicate community names | High — pricing governance is unclear | Medium — wrong price applied to wrong community | Incorrect pricing possible on any quote or work order | Audit all 104 pricebooks; resolve duplicates; document which is canonical | P1 | No |
| Pricebooks | 103 community pricebooks likely have zero entries | Only 79 PricebookEntries sampled: 77 in "Upgrade My Backyard Price Book", 2 in Standard | Critical — customers cannot be quoted if pricebook is empty | Medium | Quoting non-functional for most communities | Audit PricebookEntry counts for all 103 community books; populate missing entries | P1 | No |
| Inventory | Zero ProductItems | No inventory quantities tracked in Salesforce | High — no inventory management despite FSL inventory infrastructure | Low | Cannot track stock levels or materials consumption per job | Implement ProductItem tracking; integrate with warehouse | P1 | No |
| Inventory | Warehouse location has IsInventoryLocation=false | "Upgrade My Backyard Countdown Warehouse" not flagged as inventory location | High — prevents FSL inventory tracking | High — ProductItems cannot be created at a non-inventory location | Inventory features completely blocked by this configuration | Set IsInventoryLocation=true on warehouse record | P1 | No |
| Work Order Line Items | 7 total in org | Near-zero materials tracking | High — job costing and materials management impossible | Low | No visibility into what materials are used per job | Build WOLI workflow; require materials entry on work orders | P1 | No |
| Products | No Aqua products | Zero Aqua services in the product catalog | High — Aqua revenue cannot be tracked in Salesforce | Low | Aqua quoting and invoicing non-functional | Add Aqua product lines to catalog and community pricebooks | P2 | No |

### Narrative

Inventory scores 1/10. The product catalog is a solid foundation — 77 relevant products across the right categories — but everything above the product layer is broken. There are 103 community pricebooks that almost certainly contain no pricing entries. The single warehouse location is incorrectly configured to not be an inventory location, which means the FSL inventory tracking feature physically cannot function. There are zero ProductItems in the org and only 7 Work Order Line Items across all operations.

The practical consequence is that LOVING cannot currently track what materials are used on any job, cannot manage stock levels, cannot generate accurate job cost reports, and cannot produce customer-facing invoices from Salesforce that reflect actual materials consumed.

The fix for the warehouse is a single field change (IsInventoryLocation=true). The pricebook entry audit and population is a larger data project but is a prerequisite for any quoting or invoicing workflow.

---

## Section 12 — Sales, Builders, UMB, Customer Pipeline

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Opportunities | 266 total | 83% stuck in "Community Activated" stage | High — pipeline is essentially frozen | Low | Revenue forecasting impossible; sales process not tracked | Investigate "Community Activated" stage definition; determine if deals should advance or if stage is being misused as a holding status | P1 | No |
| Opportunities | Stage typo "Propsal Presented" | Active picklist value with typo | Medium — visible in all reports and exports | Low | Unprofessional; affects data parsing if any system reads stage names | Rename the picklist value | P2 | No |
| Pipeline | No O → Q → WO handoff | No automated path from closed Opportunity to Work Order | High — sales and operations completely disconnected | Medium | Every job conversion is manual and error-prone | Define handoff process; build automation | P1 | Yes — Meg Logan |
| Cases | 2,065 Cases all in "New" | Case management non-functional | High — customer issues are not being resolved in Salesforce | Low — data load fine | No customer service visibility; all escalations invisible | Determine if cases are being worked outside SF; if yes, build the workflow to capture resolution | P1 | No |
| Contacts | 1,169 Contacts | Reasonable data volume | Low | Low | No issue | Ensure contact deduplication rules are in place | P3 | No |
| Account | NextDaySod dominance | 552 of 643 Accounts (86%) are NextDaySod | High — LOVING data is 14% of Account data | Low | Any Account-level report is dominated by NextDaySod data | Implement Account record types and report filters to separate entities | P1 | No |
| UMB | "Upgrade My Backyard" WO RT inactive | See Section 4 | High — if UMB is active, its WO record type is off | Medium | UMB work orders may be misclassified | Confirm UMB status with Meg Logan; reactivate RT if UMB is active | P1 | Yes — Meg Logan |
| Builders | Builder model | Not clearly represented in schema | High — if builder relationships are core to LOVING's model, they're not configured | Medium | Builder pipeline invisible | Define builder Account record type and relationship model; consult with Meg Logan | P1 | Yes — Meg Logan |

### Narrative

The sales and CRM layer is largely unused as an operational tool. Two thousand cases are stuck in "New." Two hundred and twenty-one opportunities are stuck in a single stage. There is no automated handoff from a closed deal to an operational work order. The dominant data in the Account object belongs to a different business.

These are not technical failures — they are process failures. The technology is capable of supporting a full sales and customer service workflow, but the process definitions, stage progression rules, and automation to support them have not been built out. This is a business requirements and configuration effort, not a debugging effort.

---

## Section 13 — Data Quality

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Test Data | UAT test data in production | Lots numbered UAT-xxx visible in live production data | High — reports include fake records; metrics are inaccurate | Low | Operational reporting is polluted | Identify all UAT records by naming pattern; delete after confirming with Meg Logan | P1 | Yes — Meg Logan |
| Duplicate Data | No duplicate/matching rules | No rules on Account, Contact, or any operational object | Medium — duplicates accumulate over time | Low | Sales team may create duplicate accounts or contacts | Implement standard Salesforce duplicate and matching rules on Account and Contact | P2 | No |
| Orphaned Records | 2 Aqua WOs with null AccountId | Work orders linked to no account | High — cannot associate with customer | Low | Aqua operational records are untracked | Link to correct Account or delete if test records | P1 | No |
| Orphaned Records | 4 WOs owned by inactive user Mahak Soni | Active work records with no active owner | High | Low | Jobs have no responsible owner | Reassign to active users | P1 | No |
| Missing Data | 20 of 21 WOs missing Community__c | Core routing field absent | High | High — field may not exist in production | Routing and community reporting impossible | Deploy field; populate retroactively | P1 | No |
| Missing Data | 13 of 21 WOs missing Field_Manager__c | FM accountability field absent | High | High — field may not exist | FM accountability unmeasurable | Deploy field; populate retroactively | P1 | No |
| Missing Data | 3 SAs with null WorkType | Auto-scheduling blocked for these records | Medium | Medium | 3 jobs cannot be auto-dispatched | Assign work types | P1 | No |
| Schema Drift | Missing fields on Account and WorkOrder | Multiple expected fields do not exist (see Section 3) | High | High | Multiple business processes broken | Full schema reconciliation sprint | P1 | No |
| NextDaySod | 552 of 643 Accounts are NextDaySod | Data co-mingling between legal entities | High | Low | LOVING reports are inaccurate by default | Separate reporting by entity; evaluate data isolation strategy | P1 | No |
| Product Data | 0 product descriptions | No descriptions on 77 products | Low | Low | Minor usability issue | Add descriptions | P3 | No |

### Narrative

Data quality issues in this org fall into three categories. First, structural quality issues: fields that don't exist in production are referenced by automation, creating silent failures. Second, population quality issues: fields exist but have not been filled in (Community, Field Manager, Work Type). Third, contamination issues: test data (UAT lots), wrong-entity data (NextDaySod accounts), and orphaned records (unowned work orders, null AccountId on Aqua WOs) pollute every operational report.

The structural issues must be fixed first (deploy missing fields), followed by population (populate the fields on existing records), followed by contamination cleanup (remove UAT data, filter NextDaySod from LOVING reports).

---

## Section 14 — Reports and Dashboards

**Reporting Readiness Score: 2/10**

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Reports | Total reports | 300 (query limit hit — more may exist) | Medium — large report count with unclear ownership | Low | Hard to find relevant reports | Audit report folder structure; delete or archive unused reports | P2 | No |
| Reports | Never-run reports | 154 of 300 (51%) have never been run | Medium — majority of reports have no usage | Low | Unused reports clutter the environment | Delete or archive all never-run reports after 30-day grace period | P3 | No |
| Dashboards | Org-specific dashboards | Only 2: "LOVING Operations Dashboard" and "ODL Operating Layer" | High — leadership has almost no operational visibility | Low | Executive and operational decision-making is uninformed | Build minimum viable dashboard set (see below) | P1 | No |
| Dashboards | Aqua operations | Zero dedicated Aqua reports or dashboards | High — if Aqua is operational, it's invisible | Low | No Aqua performance data | Build after Aqua schema is deployed (see Section 10) | P2 | No |
| Dashboards | Inventory and materials | No inventory reports or dashboards | High — no stock visibility | Low | Cannot manage inventory from Salesforce | Build after inventory is functional (see Section 11) | P2 | No |
| Dashboards | Field tech performance | No technician performance dashboards | High — cannot measure tech efficiency or job completion | Low | Field operations management flying blind | Build dispatcher and manager dashboards showing tech workload and completion rates | P1 | No |
| Dashboards | Scheduling visibility | No scheduling dashboards | High — dispatch team has no Salesforce visibility into schedule | Low | Dispatch relies on off-system tools | Build FSL scheduling dashboard showing territory coverage and appointment pipeline | P1 | No |
| Dashboards | Financial / GP / margin | No GP or margin reports | High — no unit economics visible in Salesforce | Low | Cannot measure profitability by job or community | Build job-level margin reports when WOLI and pricebook data is complete | P2 | No |
| Dashboards | Case resolution | No case performance reports | High — customer service is invisible | Low | No SLA or resolution rate data | Build case resolution dashboard when case management workflow is live | P2 | No |
| Reports | Folder structure | Unclear — possible orphaned reports in personal folders | Medium — personal folder reports lost when users deactivate | Low | Operational reports may be invisible to management | Migrate all shared operational reports to public or org-owned folders | P2 | No |

### Narrative

Reporting scores 2/10. The org has 300 reports, half of which have never been run, and only 2 operational dashboards. There are no dashboards for the business areas that matter most to daily operations: field tech performance, scheduling and dispatch, Aqua operations, inventory, financial margin, and customer service.

The LOVING Operations Dashboard and ODL Operating Layer are presumably functional, but they are carrying the entire reporting burden for what should be a multi-department visibility system. This is not a technology problem — Salesforce's reporting engine is fully capable of supporting everything listed above. It is a requirement definition and build effort.

The priority sequence for dashboard development should follow the remediation plan: fix data first (Sections 3, 9, 10, 11), then build the dashboards that report on that data.

---

## Section 15 — Integrations and External Connections

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Connected Apps | 25 connected apps, zero with session timeout | No session expiration on any connected app including LOVING Operations iOS | High — stolen OAuth tokens remain valid indefinitely | High — security vulnerability | Any compromised mobile session never expires | Configure session timeout on all connected apps; start with LOVING Operations iOS | P1 | No |
| Payment | PayPal live + sandbox both active | Live and sandbox remote sites simultaneously active | High — misconfigured payment requests could hit wrong environment | High — payment processing errors possible | Potential for test transactions hitting live PayPal | Deactivate sandbox remote site in production; keep live only | P1 | No |
| Payment | Stripe live + test both active | Same issue | High | High | Same | Same | P1 | No |
| Payment | Adyen live + test both active | Same issue | High | High | Same | Same | P1 | No |
| Integrations | Google Ads Named Credential null endpoint | Broken integration — endpoint not configured | High — Google Ads data not flowing to Salesforce | Medium | Marketing data invisible in Salesforce | Configure correct endpoint or remove the named credential | P2 | No |
| Remote Sites | 75 total remote site settings (~20 active) | Large number of remote sites, many inactive | Low — inactive sites have no runtime impact | Low | No direct operational impact | Audit and delete inactive remote site settings | P3 | No |
| Named Credentials | 3: Rippling (configured), WEX GPS API (configured), Google Ads (broken) | Rippling and WEX operational; Google Ads broken | Medium | Medium | HR/payroll and fleet integrations functional; marketing integration broken | Fix Google Ads NC (see above) | P2 | No |
| Auth Providers | Zero configured | No OAuth flows via Salesforce Auth Provider framework | Low — most integrations use Named Credentials | Low | No direct impact unless OAuth flow is needed | Document expected auth model; configure if any integration requires Auth Provider | P3 | No |
| API Users | No dedicated API-only users identified | Unclear which user context integrations run under | High — if integrations run as named humans, license and audit trail problems | Medium | Integration failures affect named users' log view | Identify all integration users; create dedicated API user accounts where needed | P1 | No |
| Platform Events | DailyDeliveredPlatformEvents at 100% | See Section 1 — event integrations dropping messages | Critical | Critical | RingCentral, GPS Insight data loss possible | See P0 remediation | **P0** | Yes — Meg Logan |
| RingCentral | Phone integration | Active package; assumed operational | Low | Low | Phone data in Salesforce | Confirm CTI functionality is working given platform event exhaustion | P1 | No |
| Rippling | HR/payroll integration | Named credential configured | Low | Low | HR data flowing | Confirm sync is current; test with Rippling admin | P2 | No |
| GPS Insight/WEX | Fleet integration | Named credential configured | Medium — platform event exhaustion may drop fleet events | High — fleet data loss during event limit exhaustion | Vehicle tracking data may be incomplete | See P0 platform event remediation | P1 | No |

### Narrative

The most critical integration finding is the simultaneous activation of live and test/sandbox remote sites for three payment processors (PayPal, Stripe, Adyen). In a production org, having a sandbox payment endpoint active means that a misconfigured callout could send a real customer payment to a test environment — or that test transactions from development could accidentally hit the live payment processor. These sandbox remote sites should be deactivated in production immediately.

The complete absence of session timeouts on 25 connected apps means that any OAuth token issued to any connected application — including the LOVING Operations iOS app used by field technicians — never expires. A stolen phone retains a valid Salesforce session indefinitely.

---

## Section 16 — Compliance, Risk, and Change Control

### Findings

| Area | Item | Current State | Business Risk | Technical Risk | LOVING Operating Impact | Recommendation | Priority | Approval Needed |
|------|------|---------------|---------------|----------------|------------------------|----------------|----------|-----------------|
| Change Control | No deployment governance documented | No documented approval process for production changes | High — uncontrolled changes can break production | Medium | Changes can be made without review or testing | Establish a change control policy; require sandbox testing and approval for all production changes | P1 | Yes — Meg Logan |
| Sandbox | Sandbox usage | Not confirmed in this audit | High — without a sandbox, all changes are made in production | High | No safe testing environment | Confirm sandbox availability and usage; establish sandbox-first development policy | P1 | No |
| Credentials | Auth tokens in session only | Session tokens stored in ~/.sf/ on container only | Low — correctly handled | Low | Tokens lost on session end — no long-term credential exposure | Current practice is correct; document it | — | No |
| Credentials | No credential files committed to repo | .gitignore covers .sf/, .sfdx/, *.auth.json | Low — correctly configured | Low | No credential exposure in git | Verify .gitignore is comprehensive; audit git history for historical credential exposure | P2 | No |
| Security | Connected app session timeouts | Zero configured (see Section 15) | High | High | Mobile sessions never expire | Configure timeout on all connected apps | P1 | No |
| Security | Deactivated users with PSAs | See Section 2 | High | High | Reactivation risk | Remove all PSAs from deactivated users | P1 | No |
| Security | Guest User License in production | "Tester Profile" active | High | High | Exposes test surface in production | Deactivate immediately | P1 | Yes — Meg Logan |
| Data | UAT test data in production | Test records in live data | High — compliance risk if test data contains PII | Low | Pollutes operational reports | Identify and delete after Meg Logan review | P1 | Yes — Meg Logan |
| Data | NextDaySod data co-mingled | 86% of Account data belongs to separate entity | High — data governance and potential legal separation concern | Low | LOVING data accuracy impacted | Define data isolation policy with legal/ownership guidance | P1 | Yes — Meg Logan |
| Audit | API version governance | API v66.0 active | Low | Low — current version | No issue | Pin API version in deployment tooling | P3 | No |
| Risk | Deployment deadlock | Test coverage at 37.6%; cannot deploy | Critical — bug fixes and features cannot be shipped | Critical | Org is frozen; no changes can reach production | See Section 7 — fix test coverage root cause first | **P0** | No |
| Risk | Dual Work Order model | Two canonical objects for work orders | Critical — architectural debt | Critical | All automation, reporting, and training affected | See Section 3 P0 recommendation | **P0** | Yes — Meg Logan |
| Risk | Clientell AI beta in production | Unsupported pre-release software | High | High | Unpredictable behavior possible | Evaluate for production readiness; consider removal | P1 | Yes — Meg Logan |
| Risk | Summer 2011 deprecated package | Decade-old package with no security updates | High | High — known vulnerabilities may be unpatched | Unknown hidden dependencies | Remove after dependency audit | P1 | Yes — Meg Logan |

### Narrative

The org's risk profile is high across multiple dimensions simultaneously. The deployment deadlock (37.6% test coverage) is the most immediately paralyzing: not a single metadata change can be deployed to fix any of the other problems until coverage is restored above 75%. This makes the test factory fix the single highest-priority technical action in the org.

The data governance situation — UAT test records in production, NextDaySod data co-mingled with LOVING data, and a dual work order model — creates compliance exposure if any of the Account or Work Order data is subject to data residency, segregation, or audit requirements.

The change control gap is a process risk: without a documented approval and testing process, well-intentioned changes can break production. Given that the org is already in a fragile state (P0 API limits, deployment deadlock), uncontrolled changes could escalate existing problems.

---

## Readiness Scorecard

### FSL Readiness Score: 3 / 10

**What earns the 3:** The geographic territory hierarchy is well-designed (19 territories, clean NC/SC coverage). Work types are populated with realistic durations (69 work types). OOB scheduling policies and work rules are configured. The foundational FSL infrastructure was built thoughtfully.

**What limits the score:** The infrastructure was never commissioned. 14 of 19 territories have zero service resource members. All crew resources are inactive. Skills are unconfigured while "Match Skills" is active. 8 past-due service appointments are unresolved. 10 service appointments have no assigned resource. `Community__c` and `Field_Manager__c` are missing from WorkOrder. The org scores 3 rather than 1 because the architecture is sound — it just hasn't been turned on.

---

### Aqua Readiness Score: 1 / 10

**What earns the 1:** The intent to build an Aqua workflow is evidenced by the existence of 2 Aqua-type work orders and Aqua-specific flow logic.

**What limits the score:** The Aqua data model — Community and Lot record types on Account, and all Aqua-specific custom fields — does not exist in production. The two Aqua Work Orders have null AccountId. Aqua flows reference fields that do not exist and would fail at runtime. There are no Aqua products in the catalog. Aqua is not a feature that is partially deployed — it is a feature that is designed but not deployed. Nothing in the Aqua workflow is operational.

---

### Inventory Readiness Score: 1 / 10

**What earns the 1:** 77 active products exist across the correct categories.

**What limits the score:** The single warehouse location has `IsInventoryLocation=false`, making FSL inventory tracking physically impossible. Zero ProductItems exist. Only 7 Work Order Line Items exist across the entire org. 103 community pricebooks almost certainly have no entries. Product descriptions are absent. Materials and inventory management are completely non-functional.

---

### Reporting Readiness Score: 2 / 10

**What earns the 2:** 300 reports exist, indicating historical reporting activity. Two org-specific dashboards are present. The reporting infrastructure (objects, fields, report types) is in place.

**What limits the score:** 51% of reports have never been run. Only 2 operational dashboards exist for the entire organization. There are no dashboards covering field tech performance, scheduling, Aqua, inventory, financial margin, case resolution, or community-level operations. The NextDaySod data contamination means that most Account-based reports require entity filters that have not been applied. Reporting cannot be considered functional until the underlying data quality issues are resolved and a minimum viable dashboard set is built.

---

### Security and Permissions Score: 4 / 10

**What earns the 4:** Two active sysadmins is an appropriate count. Auth tokens are correctly handled (session-only, not committed to git). No credential files are in the repo. The org uses Named Credentials for external integrations (correct pattern).

**What limits the score:** 25 never-logged-in users consuming full licenses. Fifteen permission set assignments on a deactivated sysadmin. A "Tester Profile" with Guest User License active in production. A personal Gmail as a Salesforce username. 340 ungoverned standalone permission sets. Person-named role hierarchy. Zero session timeouts on 25 connected apps. Payment sandbox remote sites active alongside live sites in production. No API-only users identified.

---

### Deployment Readiness Score: 2 / 10

**What earns the 2:** The org uses a modern automation stack (Flow only, no Workflow Rules or Process Builder). Git-based version control is in place. The CLI toolchain is configured and pinned.

**What limits the score:** Org-wide Apex test coverage is 37.6% (required minimum 75%) — no deployment can succeed. 100+ tests are actively failing. 7 InvalidDraft flows will block deployment validation. The repo and production org are dangerously out of sync (11 LOVING_-prefixed classes in repo do not exist in production). Deploying from the repo would create a third WorkOrder trigger. There is no documented sandbox-first change control process. Until coverage is fixed and the repo/org divergence is reconciled, the org is in a deployment deadlock.

---

## Recommended 30-Day Remediation Plan

**Goal:** Stop active failures, unblock deployment, and stabilize the foundation.

### Week 1 — Stop the Bleeding (P0s)

1. **Fix Apex test factory for `Work_Order_Type__c`** — update all test factory methods to populate the required field; re-run full test suite; restore coverage to >75%. This is the single most blocking issue in the org.
2. **Resolve 7 InvalidDraft flows** — fix or delete each to clear the deployment block.
3. **Investigate and address ScheduledFlowRunLimit exhaustion** — identify top 10 scheduled flows by execution volume; disable or reschedule lowest-priority flows; monitor limit recovery.
4. **Investigate and address DailyDeliveredPlatformEvents exhaustion** — identify event sources; implement backpressure; escalate to Salesforce support if needed.
5. **Audit 70 cron jobs** — identify redundant or low-priority jobs; disable or reschedule to off-peak.

### Week 2 — Security and Access

6. **Remove all 15 permission set assignments from Frank Realmuto** and all other deactivated users.
7. **Deactivate or delete the "Tester Profile" with Guest User License.**
8. **Deactivate all 25 never-logged-in users** (after Meg Logan confirms they are not pending onboardings).
9. **Deactivate payment processor sandbox remote sites** (PayPal, Stripe, Adyen) in production.
10. **Configure session timeouts on all 25 connected apps.**

### Week 3 — Schema Reconciliation

11. **Reconcile repo vs production Apex naming** — document canonical class/trigger names; align repo to production names without creating duplicates.
12. **Deploy missing fields** to Account (`Lot_Number__c`, `Street_Address__c`, `Lot_Status__c`) and WorkOrder (`FM__c`, `Lot_Address__c`, `Community__c`, `Health_Check_Status__c`, `Finish_Job_Required__c`).
13. **Deploy Community and Lot record types on Account.**
14. **Merge duplicate WorkOrder triggers** into a single handler pattern.
15. **Fix Google Ads Named Credential** broken endpoint.

### Week 4 — FSL Commission

16. **Assign service resources to all 19 territories.**
17. **Activate crew service resources** and assign crew members.
18. **Assign the 4 unassigned technicians** (Jamie Hinson, Victor Zambrano, Jersain Laris, Scott Spaulding) to their correct territories.
19. **Disable or configure the "Match Skills" work rule** (disable until skills are configured).
20. **Resolve 8 past-due service appointments** and 10 unassigned service appointments.
21. **Reassign 4 Work Orders owned by inactive user Mahak Soni** and investigate WO 00000011.

---

## Recommended 60-Day Stabilization Plan

**Goal:** Achieve a stable, tested, operational baseline across FSL, sales, and core operations.

### Data Model and Automation

22. **Make the dual Work Order model decision** — choose standard `WorkOrder` or custom `Work_Order__c`; begin migration; deprecate the other.
23. **Conduct field audit on WorkOrder and Account** — identify unused custom fields; document business owner for each; deprecate candidates.
24. **Resolve all 7 InvalidDraft flows** and audit 32 Draft flows for disposition.
25. **Implement permission set groups** — consolidate 340 standalone PSAs into governed groups.
26. **Rename person-named roles to job functions.**

### FSL Build-Out

27. **Configure ServiceSkill** — define skills taxonomy; assign skills to technicians.
28. **Populate MinimumCrewSize and RecommendedCrewSize** on all 69 work types.
29. **Create territory-specific operating hours** for all 19 territories.
30. **Customize scheduling policies and work rules** to match LOVING's actual field operations model.

### Inventory and Pricing

31. **Set IsInventoryLocation=true on the warehouse record.**
32. **Audit all 104 pricebooks** — identify and merge duplicates; document which is canonical per community.
33. **Populate PricebookEntries** for all community pricebooks.
34. **Begin Work Order Line Item workflow** — require materials entry on all work orders.

### Sales Process

35. **Define Opportunity stage model** — clarify what "Community Activated" means; build stage advancement rules.
36. **Fix "Propsal Presented" picklist typo.**
37. **Define and build Opportunity → Work Order handoff automation.**
38. **Begin Case management workflow** — define statuses, assignment rules, and resolution process.

---

## Recommended 90-Day Operating System Buildout Plan

**Goal:** Build the full LOVING operating system in Salesforce — Aqua, Inventory, Reporting, and Sales fully operational.

### Aqua Operations (requires 30-day schema work to be complete first)

39. **Deploy all missing Aqua fields** and validate against flow definitions.
40. **End-to-end test all Aqua flows** in sandbox.
41. **Create Aqua products and pricebook entries.**
42. **Link existing Aqua Work Orders to correct Account records.**
43. **Activate Aqua operations** in production after sandbox sign-off.

### Inventory Operations

44. **Build full ProductItem and inventory tracking workflow.**
45. **Integrate warehouse inventory with Salesforce FSL inventory.**
46. **Build job-level materials consumption reports.**

### Reporting and Dashboards — Minimum Viable Set

47. **Field Tech Performance Dashboard** — technician workload, completion rate, SLA adherence by territory.
48. **Dispatch and Scheduling Dashboard** — open appointments, territory coverage, past-due SAs.
49. **Community Operations Dashboard** — work order pipeline by community, FM accountability.
50. **Aqua Operations Dashboard** — Aqua work order pipeline, zone coverage.
51. **Financial and Margin Dashboard** — job-level GP, materials cost, pricebook variance.
52. **Case Resolution Dashboard** — case volume, status distribution, resolution rate, SLA.
53. **Inventory Dashboard** — stock levels, consumption by job, reorder alerts.

### Change Control and Governance

54. **Document and enforce sandbox-first development policy.**
55. **Implement Apex class naming standards** (LOVING_ prefix or domain-based grouping).
56. **Remove deprecated Summer 2011 package** (after dependency audit).
57. **Evaluate and stabilize Clientell AI v0.5** — upgrade to GA or remove.
58. **Implement API governor limit monitoring** — AlertMe or similar for ScheduledFlowRunLimit and DailyAsyncApexExecutions.
59. **Build minimum viable test coverage** — target 80%; prioritize LovingSchedulingOverlayService and AquaConsoleController.

---

## Items Requiring Meg Logan Approval

The following items were identified during this audit as requiring explicit written approval from Meg Logan before any action is taken:

| # | Item | Why Approval Required |
|---|------|-----------------------|
| 1 | Deactivate all 25 never-logged-in users | User management decision; some may be pending onboardings |
| 2 | Remove "Salesforce.com CRM Dashboards" Summer 2011 package | Package removal is irreversible; unknown dependencies |
| 3 | Evaluate/remove Clientell AI v0.5 from production | Business decision on a vendor relationship |
| 4 | Purchase/upgrade DailyDeliveredPlatformEvents capacity | Cost decision |
| 5 | Dual Work Order model decision (WorkOrder vs Work_Order__c) | Foundational architectural decision affecting all operations |
| 6 | NextDaySod data isolation strategy | Legal entity and data governance decision |
| 7 | "Tester Profile" Guest User License deactivation | Confirm no active use case before deactivating |
| 8 | Reconcile repo vs production Apex naming before any deployment | Deploying from repo without this risks breaking FSL |
| 9 | Service territory-to-resource assignments | Operations staffing decision |
| 10 | Activate crew service resources | Operations staffing and dispatch model decision |
| 11 | Confirm whether "Upgrade My Backyard" record type should be active | Business line status decision |
| 12 | Confirm UMB and Builder account/opportunity model design | Business requirements decision |
| 13 | Define Opportunity → Work Order handoff process | Business process design decision |
| 14 | Delete UAT test data from production | Confirm records are truly test data before deletion |
| 15 | NextDaySod / LOVING data separation strategy | May require legal guidance; two-org evaluation |

---

## Stop Conditions and Items Refused During Audit

The following operations were identified as out-of-scope or refused under the terms of the LOVING-SF Claude Code operational policy:

| Item | Reason Refused |
|------|----------------|
| `sf project deploy start` — any production deployment | Explicitly prohibited without written approval from Meg Logan per CLAUDE.md |
| Any command that modifies, deletes, renames, or overwrites production metadata | Prohibited per CLAUDE.md |
| Any command that modifies production data records | Prohibited per CLAUDE.md |
| Deactivating users, modifying permissions, or changing access controls via CLI | Would modify production configuration; requires Meg Logan approval |
| Deleting test data (UAT records) | Data modification; requires Meg Logan approval |
| Changing IsInventoryLocation on the warehouse record via CLI | Data modification; requires Meg Logan approval |
| Removing duplicate pricebooks or merging record types | Irreversible data operations; require Meg Logan approval |
| Configuring session timeouts on connected apps via CLI | Production configuration change; requires approval and testing |

**All audit findings were produced by read-only inspection only.** No data was created, modified, or deleted. No metadata was deployed. All commands run during this audit were of the form `sf org display`, `sf project retrieve`, `sf apex run` (read-only queries), and equivalent non-destructive operations.

---

*End of LOVING Salesforce Production Audit — 2026-05-19*

*This document reflects the state of the org as observed on the audit date. Findings should be reviewed with Meg Logan before any remediation work begins. Priority P0 items represent active production failures and should be triaged immediately.*
