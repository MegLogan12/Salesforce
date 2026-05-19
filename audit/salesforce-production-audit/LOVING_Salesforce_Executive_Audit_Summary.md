# LOVING Salesforce Platform — Executive Audit Summary
**Audit Date:** 2026-05-19
**Platform:** https://loving.my.salesforce.com
**Auditor:** Claude Code (read-only inspection, no changes made to the org)

---

## TL;DR

- **The platform cannot be deployed to today.** Org-wide Apex test coverage is 37.6% against a 75% requirement. 100+ tests are failing. 7 flows are in an invalid state. Any deployment attempt will fail.
- **Three daily governor limits are at or near 100%.** Scheduled flows are not running. Platform events are dropping. Async Apex is exhausted. Automation that appears configured is silently not executing.
- **Field Service Lightning is not operational.** 14 of 19 service territories have no assigned resources. All crew-type resources are inactive. 10 service appointments are unassigned and 8 are overdue.
- **2,065 Cases have never moved out of "New" status.** Case management automation is non-functional. No case has been worked through the system.
- **A deactivated former sysadmin (Frank Realmuto) has 15 active permission set assignments** including FieldServiceAdmin and DocuSign_Administrator, with a login recorded 46 days ago. This is an active security exposure.
- **Two parallel work order systems are running simultaneously** — the standard Salesforce WorkOrder object (FSL) and a custom Work_Order__c object — with no clear decision on which is authoritative. All reporting, automation, and integrations are split across both.
- **The org's code repository does not match production.** Deploying the current repo without a reconciliation plan would add a third trigger to the WorkOrder object alongside two existing triggers, creating a high-probability risk of duplicate task creation and data corruption.
- **86% of Accounts (552 of 643) belong to NextDaySod**, a separate business entity sharing this org. LOVING and NextDaySod data are fully commingled.
- **Core operational modules are stubs.** QI_Inspection__c, Finish_Job__c, and inventory tracking exist as empty schema with no records and no business logic. The workflows that depend on them are broken.
- **The platform is in early-stage condition** — correctly licensed, structurally set up, and actively developed, but not yet operational for its intended purpose. Significant stabilization work is required before this platform can support LOVING's daily operations reliably.

---

## Overall Platform Readiness Assessment

**Overall Score: 2.2 / 10**

The LOVING Salesforce org has the right foundation — FSL is licensed and configured at the surface level, the object model reflects the business's complexity, and substantial development effort has clearly been invested. However, the platform is not operational today in any of its core modules. Field service scheduling cannot dispatch. Case management is not working. Automation is running into governor limit walls and silently failing. Apex test coverage disqualifies any deployment. The code repository is out of sync with production in a way that, if deployed naively, would cause data integrity problems. Two critical operational objects (QI_Inspection__c and Finish_Job__c) exist in name only. The security posture has live exposure from a deactivated user with active admin permissions. And 86% of the Account records belong to a different company. This is an early-stage platform that has been built with real intent and real complexity, but that complexity has outpaced the testing, configuration completion, governance, and operational readiness work needed to make it run. None of this is irreversible, but none of it can be ignored.

---

## What Is Working

- Salesforce Field Service is licensed and the core FSL object model (service territories, service resources, work orders, service appointments) is in place
- The WorkOrder object has a rich custom field set reflecting real LOVING operational requirements
- 5 of 19 service territories have resource members configured
- The Apex trigger architecture exists and has been partially consolidated (single trigger per object pattern attempted)
- An org-wide authentication and session management structure is in place
- The pricebook infrastructure exists (103 community pricebooks created)
- A role hierarchy exists, even if it needs to be restructured
- Connected apps and remote site settings exist, indicating integration work has been attempted
- The project has been version-controlled and a development workflow using SFDX/SF CLI has been established

---

## What Is Broken

- **Scheduled flow automation** — ScheduledFlowRunLimit is at 100%. Flows are not running.
- **Platform event integrations** — DailyDeliveredPlatformEvents is at 100%. Events are dropping.
- **Async Apex jobs** — DailyAsyncApexExecutions at 98.8%. Batch jobs and future methods are backed up or failing.
- **Case management** — 2,065 Cases are permanently stuck in "New." No assignment, routing, or escalation automation is functioning.
- **FSL dispatching** — 14 of 19 territories have no resource members. Work cannot be assigned in those markets.
- **Crew dispatch** — All C-type crew resources are inactive. Crew-based work cannot be dispatched at all.
- **Aqua operations** — Aqua custom fields do not exist in production. Aqua flows will throw runtime errors.
- **QI closeout** — QI_Inspection__c has 0 records and no business fields. Closeout cannot be completed.
- **Finish Job closeout** — Finish_Job__c has 0 records and no business fields. Finish job workflow is broken.
- **Inventory tracking** — The single warehouse location has IsInventoryLocation=false. No ProductItems exist. Inventory is not tracked.
- **Pricing** — 103 community pricebooks have no entries. Quotes cannot be priced.
- **Google Ads integration** — Named Credential endpoint is null. Any callout to Google Ads will fail.
- **Opportunity progression** — 83% of Opportunities are stuck in "Community Activated." The sales pipeline has no forward motion.
- **Deployment pipeline** — Any deployment will currently fail on test coverage (37.6% vs. 75% required) and on 100+ failing tests.

---

## What Is Risky

- **Frank Realmuto (deactivated)** has 15 active permission set assignments including FieldServiceAdmin and DocuSign_Administrator. Last login was 46 days ago despite deactivation. This is an active security exposure.
- **Duplicate triggers on WorkOrder and Opportunity** execute in non-deterministic order on every record save. Either trigger can overwrite the other's field changes. Double-processing of tasks, escalations, and field updates is occurring today.
- **The repo/org mismatch** means that a naive deployment of the current codebase would add a third WorkOrder trigger, creating a high-probability data corruption scenario.
- **PayPal, Stripe, and Adyen** each have both live and sandbox remote sites active in production. A misconfigured callout could silently route to the wrong endpoint.
- **25 connected apps** have no session timeout. Compromised tokens never expire.
- **Tester Profile with Guest User License** is active in production. Guest users can access Salesforce APIs without authentication depending on profile configuration.
- **15 permission set assignments to deactivated users** remain active. Reactivation of any deactivated user immediately restores full permissions without review.
- **NextDaySod data commingled** with LOVING data creates reporting, access control, and data privacy risk.
- **Clientell AI at v0.5** (pre-release beta) is installed in production. Beta packages are unsupported by Salesforce and may have undisclosed data access.
- **Only 4 Salesforce licenses remain.** License ceiling will be hit with the next new hire.

---

## What Is Missing

- A functioning case management process — routing, assignment, escalation, SLA
- Territory resource assignments for 14 of 19 markets
- Crew resource activation for crew-based dispatch
- Business fields on QI_Inspection__c — the closeout object is an empty shell
- Business fields on Finish_Job__c — the finish job object is an empty shell
- ProductItems and inventory stock levels — no inventory has been loaded
- Pricebook entries across 103 community pricebooks
- Aqua custom fields in production (Aqua_Community__c, Zone__c, FM__c)
- A decision on which Work Order model is authoritative (WorkOrder vs Work_Order__c)
- Apex test coverage for 79 classes (currently at 0%) and a plan to reach 75% org-wide
- Duplicate rules and matching rules on Account, WorkOrder, Lot, and Community
- A deprovisioning process for departed employees (permission revocation, ownership reassignment)
- A license management process to prevent exhaustion
- Operational dashboards — only 2 exist today, none covering FSL, Aqua, inventory, QI, or GP/margin
- A function-based role hierarchy (current hierarchy is named after individuals)
- A permission governance model (340 standalone permission sets with no rationalization)

---

## What Is Overbuilt

- **WorkOrder: 196 custom fields** — this is an extreme number of fields on a single object. Most are likely unpopulated. The maintenance burden is high and layouts are unmanageable.
- **Account: 144 custom fields** — similarly excessive. Likely contains redundant, deprecated, and speculative fields.
- **340 standalone permission sets** — for an org of this size, this is unauditable and unmaintainable. A permission set group strategy with 10–20 groups would cover the same access needs with far less complexity.
- **LovingSchedulingOverlayService (~86K lines) at 0% coverage** — the size of this class suggests it may contain large blocks of dead, unreachable, or speculative code.
- **AquaConsoleController (~94K lines) at 0% coverage** — at 94,000 lines with no tests, this is the largest untested code asset in the org. It cannot be safely changed, debugged, or maintained.
- **70 active cron jobs** — this is the primary driver of governor limit exhaustion. The number of scheduled jobs has not been managed and is directly causing P0 failures.
- **103 community pricebooks with zero entries** — the structure exists but has no content and cannot be used.

---

## What Is Underbuilt

- **QI_Inspection__c** — object exists, 0 records, no business fields. A stub.
- **Finish_Job__c** — object exists, 0 records, no business fields. A stub.
- **Inventory module** — warehouse location exists but is mis-configured (IsInventoryLocation=false). Zero ProductItems. Tracking has never been deployed.
- **FSL configuration** — territories created but 14 of 19 have no members. Crew resources exist but are all inactive. Work types created but crew size fields are all null. A single Operations Hours record covers all 19 territories.
- **Reporting infrastructure** — 300 reports exist but 154 have never been run. Only 2 dashboards exist across the entire org.
- **Aqua platform** — Aqua Work Orders exist (2) but are orphaned (null AccountId). The custom fields they depend on do not exist in production. The Aqua module is non-functional.
- **Product catalog** — 77 products with zero descriptions. Pricebooks with zero entries.

---

## What Does Not Match LOVING Operations

- **The Account object has no Community or Lot record types** — the LOVING business model is built around communities and lots, but these concepts do not exist as Account record types. The object model contradicts the business structure.
- **86% of Accounts belong to NextDaySod** — the org's primary account population is a different company. LOVING's own customer data is a small minority of the Account records.
- **Person-named role hierarchy** — roles named after individuals (not job functions) do not survive normal employee turnover. Every departure and hire requires hierarchy restructuring.
- **7 inactive WorkOrder record types still present** (Aqua New Install, Land Development, etc.) — these appear in picklists and suggest business lines that either no longer exist or were never fully built out.
- **Two Homeowner Account record types** (Home_Owner + Homeowner) — duplicate record types for the same concept indicate the data model was built incrementally without reconciliation.
- **Stage name typo "Propsal Presented"** — this appears in all pipeline reports and customer-facing views.
- **UAT test data with UAT-xxx lot numbers** is in the production database — test records are commingled with operational data.
- **Justin Johnson's Salesforce username is a personal Gmail address** — this does not match corporate identity standards and cannot be governed through an enterprise identity provider.
- **FSL MinimumCrewSize and RecommendedCrewSize are null on all 69 work types** — the FSL scheduler has no crew sizing guidance for any work type in the system.

---

## Deployment Blockers

The following items will cause any production deployment to fail and must be resolved before any deployment is attempted:

1. **Org-wide Apex test coverage is 37.6%** — Salesforce requires 75% minimum. Deployment will hard-fail.
2. **100+ failing Apex tests** — all test suites touching Work Orders are failing due to the Work_Order_Type__c required field not being reflected in test factories and validation rule interference from Work_Order__c. Deployment will hard-fail.
3. **7 InvalidDraft flows** — any deployment that includes these flows will fail. They must be fixed or excluded from the deploy scope.
4. **Repo/org mismatch (LOVING_-prefixed classes)** — deploying the current repo without a reconciliation plan will add a third trigger to WorkOrder alongside two existing triggers. This must be assessed and a deployment strategy approved before any deploy runs.

---

## Data Quality Blockers

The following data issues make reports, dashboards, and operational decisions unreliable:

1. **2,065 Cases stuck in "New"** — case data cannot be reported against any meaningful status distribution.
2. **20 of 21 Work Orders missing Community__c** — Work Order reports filtered or grouped by community are wrong for 95% of records.
3. **552 of 643 Accounts (86%) belong to NextDaySod** — all Account-level aggregate reporting is dominated by a different company's data.
4. **UAT test records in production** — lot counts, account counts, and Work Order counts are inflated by test data.
5. **2 Aqua Work Orders with null AccountId** — these records are orphaned and cannot be associated with any community, lot, or customer.
6. **4 Work Orders owned by inactive user Mahak Soni** — these records have no active owner and will not appear correctly in any ownership-based report.
7. **103 pricebooks with zero entries** — any revenue, quoting, or order management report that references pricebook data is returning no results or wrong results.
8. **83% of Opportunities in "Community Activated"** — pipeline stage reporting reflects stalled data, not actual sales motion.
9. **154 of 300 reports never run** — half the report library has never been validated against real data.

---

## Readiness Scores

| Area | Score | One-line Summary |
|------|-------|-----------------|
| FSL Readiness | 3/10 | Object model in place; 14 of 19 territories unstaffed, all crews inactive, limit exhaustion blocking scheduled automation |
| Aqua Readiness | 1/10 | Custom fields missing from production; Work Orders orphaned; Aqua module will fail at runtime |
| Inventory Readiness | 1/10 | Warehouse location mis-configured; zero ProductItems; inventory tracking has never been deployed |
| Reporting Readiness | 2/10 | 300 reports exist, 154 never run, only 2 dashboards, no coverage of FSL / Aqua / inventory / QI / margin |
| Security / Permissions | 4/10 | Active permission exposure from deactivated former sysadmin; 340 unrationalised permission sets; guest profile in production; no session timeouts |
| Deployment Readiness | 2/10 | Blocked by 37.6% test coverage, 100+ failing tests, 7 invalid flows, and repo/org mismatch |

---

## Security and Permissions Findings

**Immediate exposure — Frank Realmuto:** A former sysadmin whose account has been deactivated retains 15 active permission set assignments including FieldServiceAdmin and DocuSign_Administrator. A login was recorded 46 days ago. This is not a theoretical risk — it is a live access control failure. Permission sets must be revoked immediately under Meg Logan's direction.

**Deactivated user cleanup:** 15 total permission set assignments to deactivated users remain active across the org. Any user whose account is accidentally or intentionally re-enabled would immediately recover all permissions without review.

**Permission set sprawl:** 340 standalone permission sets is not a security policy — it is the absence of one. At this scale, it is not possible to audit who has access to what or to certify that access follows the principle of least privilege. A permission set group rationalization project is required before the platform scales further.

**Test profile in production:** The "Tester Profile" with a Guest User License is active in a production environment. Guest user profiles can expose unauthenticated API access depending on configuration. This should be deactivated and audited.

**Connected app sessions:** 25 connected apps have no session timeout configured. If any OAuth token is compromised, it remains valid indefinitely.

**Payment gateway configuration:** PayPal, Stripe, and Adyen each have both live production and sandbox remote sites active simultaneously in the production org. This creates the risk of misconfigured callouts routing to test endpoints or exposing live credentials to test systems.

**Username governance:** One active user (Justin Johnson) has a personal Gmail address as their Salesforce username. This cannot be governed through corporate identity systems and creates account recovery risk.

---

## Recommended 30-Day Remediation Plan

Focus: Unblock deployment. Stop the bleeding on governor limits. Fix immediate security exposure. Establish data integrity baseline.

**Week 1 — Security and access (no deployment required):**
- Revoke all 15 permission set assignments from Frank Realmuto immediately (Meg Logan approval required)
- Clean up remaining 15 deactivated user permission set assignments
- Deactivate "Tester Profile" with Guest User License
- Audit and correct PayPal/Stripe/Adyen remote site settings to remove sandbox endpoints from production

**Week 1 — Governor limit emergency response:**
- Audit all 70 active cron jobs; deactivate redundant or stale scheduled jobs (Meg Logan approval required for any deactivation)
- Identify and pause any runaway async Apex jobs consuming DailyAsyncApexExecutions
- Identify and remove or pause the highest-volume platform event producers

**Week 2 — Deployment blocker: test coverage and failing tests:**
- Update test factory to reflect Work_Order_Type__c as a required field
- Resolve validation rule interference from Work_Order__c in test context
- Assign all 79 zero-coverage classes to developers; begin coverage sprint
- Fix 7 InvalidDraft flows

**Week 3 — Repo/org reconciliation:**
- Conduct a full diff between the repo and production org
- Produce a reconciliation plan for LOVING_-prefixed classes and the third trigger risk
- Submit reconciliation plan to Meg Logan for approval before any deployment proceeds

**Week 4 — Data baseline:**
- Remove UAT test records from production (Meg Logan approval required)
- Reassign 4 Work Orders owned by inactive user Mahak Soni
- Fix WO 00000011 (stuck "Scheduled," inactive owner)
- Correct IsInventoryLocation=false on the warehouse location record

---

## Recommended 60-Day Stabilization Plan

Focus: Make FSL operational. Fix case management. Establish a single authoritative Work Order model.

- Staff the 14 unassigned service territories with resource members
- Activate C-type crew resources under a reviewed crew dispatch policy (Meg Logan approval required)
- Assign 4 active technicians to their correct territories
- Resolve 8 past-due service appointments — complete, cancel, or reschedule (Meg Logan approval required)
- Deploy Aqua custom fields (Aqua_Community__c, Zone__c, FM__c) to production after test coverage is resolved
- Fix Aqua Work Order AccountId relationships
- Build out Case assignment and routing rules to begin clearing the 2,065 stuck Cases (Meg Logan approval for any automation that modifies existing Case records)
- Make the dual Work Order model decision — designate WorkOrder or Work_Order__c as authoritative; plan migration of the other (Meg Logan approval required)
- Configure FSL work type crew size fields (MinimumCrewSize, RecommendedCrewSize) for all 69 work types
- Create territory-specific Operations Hours records to replace the single shared record
- Add at least one product description and pricebook entry per community as a proof-of-concept for the pricing model

---

## Recommended 90-Day Operating-System Buildout Plan

Focus: Build the modules that are currently stubs. Establish governance. Make the platform LOVING's real operating system.

- Build out QI_Inspection__c with the business fields required for closeout workflow
- Build out Finish_Job__c with the business fields required for finish job workflow
- Load ProductItems into the warehouse location and establish an inventory baseline
- Build operational dashboards covering: FSL dispatch status, Work Order completion, Case management, Aqua operations, QI closeout compliance, and pipeline/revenue
- Rationalize 340 permission sets into a permission set group model
- Restructure role hierarchy from person-named to function-based roles
- Implement duplicate and matching rules on Account, WorkOrder, Lot, and Community
- Begin decommissioning inactive WorkOrder record types (7 inactive types)
- Evaluate and resolve the NextDaySod account commingling — either migrate NextDaySod data out or implement a formal data separation strategy (Meg Logan approval required)
- Establish a formal user onboarding and offboarding checklist that includes license review, permission assignment, and credential revocation
- Deactivate the 2011 Salesforce.com CRM Dashboards legacy package after confirming no active dependencies
- Evaluate Clientell AI for upgrade to a stable release or removal from production (Meg Logan approval required)

---

## Items Requiring Meg Logan Approval Before Any Action

The following decisions involve production changes, data modification, personnel access changes, or business model choices that require explicit written authorization from Meg Logan before any action is taken:

1. **Frank Realmuto permission revocation** — removing permission sets from a deactivated user
2. **Deactivation or modification of any cron jobs** — 70 active scheduled jobs; deactivating any could break running workflows
3. **DailyAsyncApexExecutions remediation** — any action that pauses or removes async job submissions
4. **Deployment to production** — all deployment actions require the repo/org reconciliation plan to be reviewed and approved
5. **Case management remediation** — any automation or bulk update that touches 2,065 stuck Cases
6. **Crew resource reactivation** — activating crew resources determines who can receive work assignments
7. **Past-due service appointment resolution** — completing, canceling, or rescheduling 8 overdue appointments that may have customer impact
8. **Work Order ownership reassignment** — reassigning Work Orders from inactive users (Mahak Soni)
9. **WO 00000011 resolution** — this Work Order has been stuck for 22+ days; resolution may require customer communication
10. **Dual Work Order model decision** — designating WorkOrder vs Work_Order__c as authoritative is a fundamental business architecture decision
11. **NextDaySod data separation** — any action that moves, archives, or restricts access to NextDaySod records
12. **UAT test data removal** — bulk deletion of records from production
13. **License reclamation from never-logged-in users** — deactivating users who have never logged in
14. **Permission set rationalization project** — restructuring the org's permission model
15. **Role hierarchy restructuring** — any change to the role hierarchy affects record visibility and sharing for all users
16. **Clientell AI evaluation or removal** — a pre-release AI package with undisclosed data access scope
17. **Salesforce.com CRM Dashboards package removal** — deinstalling any managed package requires confirmation of no active dependencies

---

## Stop Conditions and Things Refused During Audit

The following actions were intentionally not taken during this audit:

- **No metadata was deployed to production.** This audit was conducted entirely in read-only mode. No `sf project deploy start` command was issued.
- **No org records were created, modified, or deleted.** All inspection was performed using `sf` CLI retrieval and query commands only.
- **No authentication credentials were stored or committed.** All org authentication tokens exist only in the container session and will not persist.
- **No changes were made to permission sets, profiles, or user access.** Frank Realmuto's permissions and all other access issues were documented only — not remediated.
- **No flows were activated, deactivated, or modified.** InvalidDraft flow issues were identified and documented only.
- **No cron jobs were paused or deactivated.** The 70 active scheduled jobs were counted and identified but not touched.
- **The repo was not deployed.** The repo/org mismatch was identified and documented. No attempt was made to reconcile or deploy the diverged codebase.
- **No bulk data operations were run.** The 2,065 stuck Cases and other data quality issues were identified through queries only.

All findings in this document are based on inspection of the production org's current state as of 2026-05-19. No production changes were made. All remediation actions require separate authorization and execution.
