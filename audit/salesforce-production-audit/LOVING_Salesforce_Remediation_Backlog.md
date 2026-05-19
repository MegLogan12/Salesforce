# LOVING Salesforce Remediation Backlog
**Generated:** 2026-05-19
**Source:** Production Org Audit — Read-Only Inspection

---

## How to Use This Backlog

Priority labels follow a four-tier system:

- **P0** — Production-breaking or deployment-blocking. Work stops or data is at risk today. These items must be resolved before any deployment is attempted and before P1 work begins.
- **P1** — High operational risk. Core LOVING workflows (scheduling, dispatch, closeout) are non-functional or degraded. These should be resolved within 30–60 days.
- **P2** — Important. These items will cause problems at scale, create security exposure, or make the platform unreliable as the business grows. Address within 60–90 days.
- **P3** — Cleanup and optimization. Technical debt, unused assets, and cosmetic issues that do not block operations but increase maintenance burden over time.

**Approval:** Any item marked "Meg Logan Approval Required" must receive explicit written authorization before action is taken. No destructive or production-modifying action may be taken without it, regardless of priority level.

**Effort estimates** use T-shirt sizing: XS (<2 hrs), S (half-day), M (1–2 days), L (3–5 days), XL (1–2 weeks), XXL (2+ weeks).

---

## P0 — Production-Breaking / Deployment-Blocking

| ID | Item | Root Cause | Impact if Unresolved | Owner | Approval Needed | Est. Effort |
|----|------|-----------|----------------------|-------|----------------|-------------|
| P0-01 | ScheduledFlowRunLimit at 100% (250,000/250,000) | 70 active cron jobs + scheduled flows consuming entire daily allocation | All scheduled flows are silently not running today. Any flow-driven automation (assignment, notifications, escalations) is frozen. | Admin | Meg Logan Approval Required | L |
| P0-02 | DailyDeliveredPlatformEvents at 100% (130,000/130,000) | Event volume exceeds org limit | All platform event integrations are dropping events. Any system relying on event-driven messaging is silently failing. | Admin | No | M |
| P0-03 | DailyAsyncApexExecutions at 98.8% (247,092/250,000) | 70 active cron jobs + runaway async Apex jobs | Async Apex is functionally exhausted. Batch jobs, future methods, and queueable chains are failing or queued indefinitely. | Admin | Meg Logan Approval Required | M |
| P0-04 | Org-wide Apex test coverage at 37.6% (need 75%) | 79 Apex classes/triggers at 0% coverage; test factory not updated for required fields | Any full metadata deployment will fail with a test coverage error. Deployment is blocked until coverage reaches 75%+. | Dev | No | XXL |
| P0-05 | 100+ failing Apex tests | Work_Order_Type__c required field not reflected in test factory; validation rule interference from Work_Order__c custom object | All test suites are failing. Cannot validate deployments. Test results are unreliable for any class touching Work Orders. | Dev | No | L |
| P0-06 | REPO vs ORG MISMATCH — LOVING_-prefixed classes in repo do not exist in org | Development work done in repo was never deployed; org has diverged | Deploying the current repo would add a third trigger to WorkOrder alongside WorkOrderTrigger + WorkOrderFieldManagerMobileSync — risk of duplicate task creation, double escalations, and corrupted Work Order records. | Dev | Meg Logan Approval Required | L |
| P0-07 | 7 InvalidDraft flows in org | Flows saved in draft state with validation errors | Any deployment that includes these flows will fail. They block the deploy pipeline and cannot be deployed or referenced by other automation. | Admin | No | M |
| P0-08 | 2,065 Cases stuck in "New" status | Case management workflow non-functional — no routing, assignment, or automation moving cases forward | Customer support is non-functional. 2,065 Cases have never progressed. No case is being worked. | Admin | Meg Logan Approval Required | XL |

---

## P1 — High Operational Risk

| ID | Item | Root Cause | Impact if Unresolved | Owner | Approval Needed | Est. Effort |
|----|------|-----------|----------------------|-------|----------------|-------------|
| P1-01 | FSL: 14 of 19 service territories have zero resource members | Resources not assigned to territories after FSL setup | Scheduling is impossible for 14 of 19 markets. Field Service Lightning cannot dispatch to any unassigned territory. | Admin | No | M |
| P1-02 | FSL: All crew (C-type) service resources inactive | Crew resources were deactivated or never fully activated | Crew dispatch is non-functional. Any work type requiring a crew cannot be scheduled or dispatched. | Admin | Meg Logan Approval Required | S |
| P1-03 | FSL: 4 active technicians not assigned to any territory | Technician setup incomplete | 4 active technicians cannot receive scheduled work. They exist in the system but are unreachable by the scheduler. | Admin | No | XS |
| P1-04 | FSL: 8 past-due service appointments (May 10–14, 2026) not completed or updated | No process to close or reschedule missed appointments | Overdue appointments pollute the dispatch board and inflate unresolved work counts. Customers may not have been contacted. | Ops | Meg Logan Approval Required | S |
| P1-05 | FSL: 10 unassigned service appointments | Scheduling backlog not being processed | 10 service appointments have no assigned technician. Work is not being dispatched. | Ops | No | S |
| P1-06 | Dual Work Order model: standard WorkOrder (FSL) vs custom Work_Order__c both active | No clear decision made on which object is authoritative for LOVING operations | Two parallel work order systems with overlapping purpose. Automation, reporting, and integrations are split across both objects. Data integrity is degraded and the business cannot report reliably on work order status. | Meg Logan | Meg Logan Approval Required | XXL |
| P1-07 | QI_Inspection__c is a schema stub — 0 records, no business fields | Object was created but never built out | Quality inspection / closeout workflow is broken. No QI records can be created, populated, or reported on. | Dev | No | XL |
| P1-08 | Finish_Job__c is a schema stub — 0 records, no business fields | Object was created but never built out | Finish job closeout workflow is broken. No Finish Job records can be created, populated, or reported on. | Dev | No | XL |
| P1-09 | 20 of 21 Work Orders missing Community__c | Field not being populated by creation flow or UI | Community__c is a foundational scheduling and reporting field. 95% of Work Orders cannot be correctly routed, filtered, or reported against community. | Admin/Dev | No | M |
| P1-10 | 4 Work Orders owned by inactive user Mahak Soni | User deactivated without ownership reassignment | 4 Work Orders have no active owner. They cannot be actioned, escalated, or dispatched through normal ownership-based flows. | Admin | Meg Logan Approval Required | XS |
| P1-11 | WO 00000011 stuck in "Scheduled" since 2026-04-27, owned by inactive user | No process to detect or escalate stalled Work Orders owned by inactive users | A Work Order has been stuck for 22+ days with no active owner and no progress. Customer impact unknown. | Ops | Meg Logan Approval Required | XS |
| P1-12 | Frank Realmuto (deactivated former sysadmin) has 15 active permission set assignments including FieldServiceAdmin and DocuSign_Administrator; last login 46 days ago | Permission sets not revoked on deactivation | A deactivated user retains elevated administrative access. If the account is re-enabled or compromised, it has full field service admin and DocuSign rights. This is a live security exposure. | Admin | Meg Logan Approval Required | XS |
| P1-13 | Aqua WOs (2 exist) have null AccountId — not linked to any community or lot | Aqua Work Order creation flow missing required relationship | Aqua Work Orders are orphaned. They cannot be associated with a customer, community, or lot. | Dev | No | S |
| P1-14 | Aqua custom fields (Aqua_Community__c, Zone__c, FM__c) do not exist in production | Fields referenced in Aqua flows were never deployed to production | All Aqua flows will fail at runtime with a field-not-found error. Aqua operations cannot run. | Dev | No | M |
| P1-15 | 103 community pricebooks active, likely all with zero entries | Pricebooks created but products never added | Pricing is non-functional. Sales reps cannot generate accurate quotes. Order management has no price basis. | Admin | No | XL |
| P1-16 | 83% of Opportunities stuck in "Community Activated" stage | No stage progression automation or sales process defined beyond activation | Sales pipeline is stalled. Opportunities are not advancing to close. Revenue forecasting is unreliable. | Ops/Admin | Meg Logan Approval Required | L |
| P1-17 | Duplicate triggers on WorkOrder (WorkOrderTrigger + WorkOrderFieldManagerMobileSync) | Two triggers deployed independently with no coordination | Non-deterministic execution order. One trigger can overwrite the other's changes. Risk of duplicate task creation, double escalations, and corrupted field values on every Work Order save. | Dev | No | M |
| P1-18 | Duplicate triggers on Opportunity (ODLHomeownerPropertyIdentityOpportunity + ODLOpportunityTrigger) | Two triggers deployed independently with no coordination | Non-deterministic execution order on every Opportunity save. Risk of data corruption, double-processing, and silent failures on Opportunity automation. | Dev | No | M |

---

## P2 — Important / Needed Before Scale

| ID | Item | Root Cause | Impact if Unresolved | Owner | Approval Needed | Est. Effort |
|----|------|-----------|----------------------|-------|----------------|-------------|
| P2-01 | 25 active users never logged in; 32/36 full licenses used (88.9%) | Licenses assigned without onboarding completion | Only 4 licenses remain. Adding a new employee requires first deactivating or reclaiming an unused license. License ceiling will be hit imminently. | Admin | Meg Logan Approval Required | S |
| P2-02 | 340 standalone permission sets for an org of this size | Permission sets created ad hoc without a permission set group strategy | Permission model is unauditable and unmaintainable. Access control cannot be reviewed, documented, or certified. Over-permissioning is near-certain. | Admin | Meg Logan Approval Required | XL |
| P2-03 | 15 permission set assignments to deactivated users not cleaned up | No deprovisioning process on user deactivation | Deactivated users retain access grants. Any re-activation restores full permissions immediately without review. | Admin | No | XS |
| P2-04 | Justin Johnson using personal Gmail address as Salesforce username | Username set to personal email at user creation | Personal email as Salesforce username creates account recovery risk, identity ambiguity, and cannot be audited against corporate identity systems. | Admin | Meg Logan Approval Required | XS |
| P2-05 | "Tester Profile" with Guest User License active in production | Test profile not removed after development/UAT | A guest-licensed test profile is active in a production org. Guest users can access unauthenticated Salesforce APIs depending on profile configuration. | Admin | Meg Logan Approval Required | XS |
| P2-06 | Person-named role hierarchy (roles named after individual employees) | Role hierarchy built around individuals rather than functions | Every time an employee is hired, promoted, or leaves, the role hierarchy must be manually restructured. This is not scalable and creates reporting gaps during transitions. | Admin | Meg Logan Approval Required | M |
| P2-07 | WorkOrder object has 196 custom fields | Custom fields added without governance or rationalization | 196 fields on one object is an extreme maintenance burden. Layouts are unmanageable, APIs are slow, and most fields are likely unpopulated. Field bloat degrades performance and developer productivity. | Dev | No | XL |
| P2-08 | Account object has 144 custom fields | Same root cause as WorkOrder field bloat | 144 custom fields on Account is excessive. Many are likely unused, unmapped, or duplicates of standard fields. | Dev | No | L |
| P2-09 | No Community or Lot record types on Account | Account model does not reflect LOVING data architecture | Account is being used for Homeowners but the design intent requires Community and Lot as account-level concepts. The object model does not match the business model. | Dev | Meg Logan Approval Required | L |
| P2-10 | No duplicate or matching rules on Lot, Community, WorkOrder, or Account | Never configured | Duplicate records can be created freely on all critical operational objects. Data quality degradation is guaranteed at scale. | Admin | No | M |
| P2-11 | UAT test data (UAT-xxx lot numbers) in production database | Test data not purged after UAT | Test records are mixed into production data. Reports, dashboards, and counts are inflated by test records. | Admin | Meg Logan Approval Required | S |
| P2-12 | Two "Homeowner" Account record types (Home_Owner + Homeowner) | Duplicate record type created without decommissioning the original | Two record types for the same concept causes inconsistent layouts, automation gaps, and split reporting. | Admin | Meg Logan Approval Required | S |
| P2-13 | 552 of 643 Accounts (86%) belong to NextDaySod — separate business entity sharing org | Org was not cleanly separated when LOVING was established | A separate business entity's records are commingled with LOVING's operational data. Reporting, access control, and data governance are all compromised. This is also a potential data privacy concern. | Meg Logan | Meg Logan Approval Required | XXL |
| P2-14 | 7 inactive WorkOrder record types still present (Aqua New Install, Land Development, etc.) | Record types not deactivated after business line changes | Inactive record types appear in picklists, clutter metadata, and can be selected by users who don't know they're deprecated. | Admin | No | XS |
| P2-15 | Zero product descriptions on 77 products | Products created without completing required fields | Product catalog is not usable for customer-facing documents. Quotes, contracts, and proposals will have blank product descriptions. | Admin | No | M |
| P2-16 | Google Ads Named Credential endpoint is null | Named credential created but never configured | Google Ads integration is broken. Any flow or Apex code referencing this credential will throw a null endpoint error at runtime. | Admin/Dev | No | XS |
| P2-17 | PayPal, Stripe, and Adyen live AND test/sandbox remote sites active simultaneously | Remote site settings not separated by environment | Production org has open connections to both live and sandbox payment endpoints. A misconfigured callout could hit a test endpoint and silently fail, or expose live payment credentials to test systems. | Admin | No | XS |
| P2-18 | 25 connected apps with no session timeout configured | Connected apps created without security policy | All 25 connected app sessions are indefinite. Compromised OAuth tokens never expire. | Admin | No | M |
| P2-19 | Stage name typo: "Propsal Presented" | Manual data entry error on stage configuration | Typo appears in all Opportunity reports, dashboards, and customer-facing pipeline views. Cannot be easily corrected without updating all records in that stage. | Admin | No | S |
| P2-20 | FSL: MinimumCrewSize and RecommendedCrewSize null on all 69 work types | Work types created without completing FSL scheduling configuration | FSL scheduling engine cannot optimize crew assignments. Work will be dispatched without crew size constraints, leading to over- or under-staffing. | Admin | No | M |
| P2-21 | FSL: Single "Operations Hours" record for all 19 territories | All territories share one operating hours record | All territories have identical operating hours. Any territory with non-standard hours (different market, different timezone) cannot be correctly scheduled. | Admin | No | M |
| P2-22 | 79 Apex classes/triggers at 0% test coverage | Classes deployed without tests | 79 classes are entirely untested. Any change to these classes is unvalidated. They contribute directly to the 37.6% org-wide coverage failure. | Dev | No | XXL |
| P2-23 | Salesforce.com CRM Dashboards package from 2011 still installed | Legacy managed package never removed | A 15-year-old package is installed in production. It may have security vulnerabilities, no longer be supported, and is consuming metadata namespace and org limits. | Admin | No | S |
| P2-24 | Clientell AI at v0.5 (pre-release/beta) in production | Beta package installed without reviewing release policy | A pre-release AI package is running in production. Beta packages are unsupported by Salesforce and may have data access, security, or stability issues. | Admin | Meg Logan Approval Required | S |

---

## P3 — Cleanup and Optimization

| ID | Item | Root Cause | Impact if Unresolved | Owner | Approval Needed | Est. Effort |
|----|------|-----------|----------------------|-------|----------------|-------------|
| P3-01 | 72 obsolete flow versions cluttering org | Old flow versions not deleted after activation | Org metadata is cluttered. Flow list is difficult to navigate. Obsolete versions contribute to metadata deployment size and increase risk of accidentally activating an old version. | Admin | No | S |
| P3-02 | 7 InvalidDraft flows (secondary — required before deployment) | Already noted in P0-07 — listed here as cleanup context | These are P0-blocking but also represent persistent technical debt if not fully resolved and documented. | Admin | No | M |
| P3-03 | 154 of 300 reports never run (51% unused) | Reports created speculatively or for one-time use, never maintained | Half the report library is dead weight. Developers and admins waste time navigating an oversized report list. | Admin | No | M |
| P3-04 | Only 2 org dashboards total | Dashboards never built out | No operational visibility into the business through dashboards. Leadership, ops, and field teams are flying blind. | Admin | No | XL |
| P3-05 | No Aqua, inventory, scheduling, GP/margin, or QI compliance dashboards | Specialized dashboards never created | Critical business domains have zero dashboard coverage. None of these areas can be monitored at a glance. | Admin/Dev | No | XL |
| P3-06 | Inventory location "Upgrade My Backyard Countdown Warehouse" has IsInventoryLocation=false | Configuration error on location record | The warehouse location cannot track inventory because it is not marked as an inventory location. All inventory assigned to it is invisible to the FSL inventory engine. | Admin | No | XS |
| P3-07 | 1 warehouse location, zero ProductItems — inventory tracking not deployed | Inventory module set up structurally but never populated | Inventory tracking exists as a schema only. No stock levels, no reorder points, no inventory reporting. | Admin/Dev | No | XL |
| P3-08 | 3 service appointments with null WorkType | Created without required FSL field | 3 service appointments have no work type, meaning the FSL scheduler has no duration or skill requirement data to work with. | Admin | No | XS |
| P3-09 | LovingSchedulingOverlayService (~86K lines) at 0% coverage | Large class deployed without test coverage | An 86,000-line class has zero test coverage. Any bug in this class is undetectable until it fails in production. | Dev | No | XXL |
| P3-10 | AquaConsoleController (~94K lines) at 0% coverage | Large class deployed without test coverage | A 94,000-line class has zero test coverage. This is the largest untested code asset in the org. | Dev | No | XXL |
| P3-11 | 70 active cron jobs contributing to limit exhaustion | Cron jobs added without auditing existing scheduled jobs | 70 scheduled jobs consume the daily async and scheduled flow limits. Many are likely redundant or stale. Auditing and pruning these jobs would meaningfully reduce P0-01 and P0-03 limit pressure. | Admin | Meg Logan Approval Required | M |

---

## Future — Revisit After Platform Stabilizes

These items are real but should not be prioritized until P0 and P1 items are resolved and the platform is stable enough to support structural change.

- Redesign the Account object model to introduce Community and Lot as first-class record types
- Evaluate consolidating the dual Work Order model (WorkOrder + Work_Order__c) into a single authoritative object
- Build a permission set group strategy to replace 340 standalone permission sets
- Design and implement a proper role hierarchy based on job functions rather than individual names
- Build a product catalog governance process (descriptions, pricing tiers, pricebook management)
- Migrate NextDaySod data out of the LOVING org into a separate org or archive
- Evaluate Clientell AI for production readiness when a stable release is available
- Implement a formal deprovisioning checklist for user offboarding (permission cleanup, ownership reassignment, credential revocation)
- Evaluate whether QI_Inspection__c and Finish_Job__c should be built out or replaced with a different object model
- Assess LovingSchedulingOverlayService and AquaConsoleController for active use before investing in test coverage — if these classes are not in use, deletion may be preferable

---

## Dependency Map

The following sequencing must be respected. Working P1 items before their P0 dependencies are resolved will produce incomplete or failed results.

**Before any deployment can proceed:**
- P0-04 (test coverage to 75%) must be resolved
- P0-05 (failing tests) must be resolved
- P0-06 (repo/org mismatch) must be assessed and a deployment strategy approved by Meg Logan
- P0-07 (InvalidDraft flows) must be resolved

**Before P0-04 and P0-05 can be resolved:**
- The test factory must be updated for Work_Order_Type__c (required field)
- Validation rule interference from Work_Order__c must be addressed
- The 79 zero-coverage classes must be assigned to developers with a coverage sprint

**Before FSL scheduling can function (P1-01 through P1-05):**
- P0-01 (ScheduledFlowRunLimit) must be brought below 100% or FSL scheduled flows will not run even after territory/resource fixes
- P0-03 (DailyAsyncApexExecutions) must be reduced or FSL async operations will queue indefinitely

**Before Aqua operations can function (P1-13, P1-14):**
- Aqua custom fields must be deployed to production (P1-14) before Aqua flows are activated
- Aqua Work Order AccountId relationship must be fixed (P1-13) before Aqua work orders are usable

**Before pricebook and quoting work is meaningful (P1-15):**
- P1-06 (dual Work Order model decision) must be made — pricing strategy depends on knowing which object drives revenue

**Before security remediation is complete (P1-12, P2-02, P2-03):**
- P1-12 (Frank Realmuto permission revocation) is independent and should be done immediately
- P2-03 (deactivated user permission cleanup) should follow immediately
- P2-02 (340 permission sets) is a longer-term rationalization project that requires P2-03 to be clean first

**Before limit exhaustion (P0-01, P0-02, P0-03) can be sustainably resolved:**
- P3-11 (70 cron jobs) must be audited and pruned — this is the primary driver of limit consumption
