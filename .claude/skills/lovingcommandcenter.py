#!/usr/bin/env python3
"""
Loving Command Center — generates /tmp/loving_command_center.xlsx
Covers every process area, Salesforce automation, object, and gap.
"""

import openpyxl
from openpyxl.styles import (
    PatternFill, Font, Alignment, Border, Side, GradientFill
)
from openpyxl.utils import get_column_letter

wb = openpyxl.Workbook()

# ── Colour palette ──────────────────────────────────────────────────────────
C_HEADER_BG   = "1F3864"   # dark navy
C_HEADER_FG   = "FFFFFF"
C_SECTION_BG  = "2E75B6"   # mid blue
C_SECTION_FG  = "FFFFFF"

C_RED_BG      = "FCE4D6"   # critical gap
C_RED_FG      = "C00000"
C_AMB_BG      = "FFF2CC"   # partial / warn
C_AMB_FG      = "7F6000"
C_GRN_BG      = "E2EFDA"   # live / covered
C_GRN_FG      = "375623"
C_BLU_BG      = "DDEEFF"   # info
C_BLU_FG      = "1F497D"
C_ALT_BG      = "F2F2F2"   # alternating row

PRIORITY_COLOR = {
    "Critical":  (C_RED_BG, C_RED_FG),
    "High":      ("FDEBD0", "BA4A00"),
    "Medium":    (C_AMB_BG, C_AMB_FG),
    "Low":       (C_GRN_BG, C_GRN_FG),
    "Done":      (C_GRN_BG, C_GRN_FG),
    "Monitor":   (C_BLU_BG, C_BLU_FG),
}

STATUS_COLOR = {
    "Gap":       (C_RED_BG, C_RED_FG),
    "Partial":   (C_AMB_BG, C_AMB_FG),
    "Live":      (C_GRN_BG, C_GRN_FG),
    "Inactive":  ("EDEDED", "7F7F7F"),
    "Missing":   (C_RED_BG, C_RED_FG),
}

def hfill(hex_color):
    return PatternFill("solid", fgColor=hex_color)

def hfont(hex_color, bold=False, size=10):
    return Font(color=hex_color, bold=bold, size=size, name="Calibri")

def thin_border():
    s = Side(style="thin", color="CCCCCC")
    return Border(left=s, right=s, top=s, bottom=s)

def wrap():
    return Alignment(wrap_text=True, vertical="top")

def write_header_row(ws, headers, widths, row=1):
    for col, (h, w) in enumerate(zip(headers, widths), 1):
        cell = ws.cell(row=row, column=col, value=h)
        cell.fill = hfill(C_HEADER_BG)
        cell.font = hfont(C_HEADER_FG, bold=True, size=10)
        cell.alignment = Alignment(horizontal="center", vertical="center",
                                   wrap_text=True)
        cell.border = thin_border()
        ws.column_dimensions[get_column_letter(col)].width = w
    ws.row_dimensions[row].height = 28

def write_section_row(ws, label, num_cols, row):
    ws.cell(row=row, column=1, value=label).fill = hfill(C_SECTION_BG)
    ws.cell(row=row, column=1).font = hfont(C_SECTION_FG, bold=True, size=10)
    ws.cell(row=row, column=1).alignment = Alignment(horizontal="left",
                                                      vertical="center")
    ws.merge_cells(start_row=row, start_column=1,
                   end_row=row, end_column=num_cols)
    ws.row_dimensions[row].height = 18

def write_data_row(ws, values, row, status_col=None, priority_col=None,
                   alt=False):
    bg = C_ALT_BG if alt else "FFFFFF"
    for col, val in enumerate(values, 1):
        cell = ws.cell(row=row, column=col, value=val)
        cell.fill = hfill(bg)
        cell.font = hfont("000000", size=9)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        cell.border = thin_border()

    # colour status cell
    if status_col and status_col <= len(values):
        v = str(values[status_col - 1])
        for key, (bg2, fg2) in STATUS_COLOR.items():
            if key.lower() in v.lower():
                c = ws.cell(row=row, column=status_col)
                c.fill = hfill(bg2)
                c.font = hfont(fg2, bold=True, size=9)
                break

    # colour priority cell
    if priority_col and priority_col <= len(values):
        v = str(values[priority_col - 1])
        for key, (bg2, fg2) in PRIORITY_COLOR.items():
            if key.lower() in v.lower():
                c = ws.cell(row=row, column=priority_col)
                c.fill = hfill(bg2)
                c.font = hfont(fg2, bold=True, size=9)
                break

# ═══════════════════════════════════════════════════════════════════════════
# SHEET 1 — GAP ANALYSIS
# ═══════════════════════════════════════════════════════════════════════════

ws1 = wb.active
ws1.title = "Gap Analysis"
ws1.freeze_panes = "A2"

HEADERS = ["#", "Topic / Area", "Description",
           "NXXT Process Docs Say", "Salesforce Currently Has",
           "Gap / Difference", "Recommendation", "Priority", "Status"]
WIDTHS  = [4, 22, 28, 38, 38, 38, 38, 12, 10]
write_header_row(ws1, HEADERS, WIDTHS)

GAP_ROWS = [
    # ── SALES & LEAD ──────────────────────────────────────────────────────
    ("SALES & LEAD PIPELINE",),
    (1, "Lead Assignment",
     "All new leads default-routed to TR Haynes catch-all rule",
     "Unmatched leads automatically route to TR Haynes via a catch-all assignment rule",
     "ODL_Default_Assignment rule deployed and active; TR Haynes assigned",
     "Live. Web-to-Lead routing should be verified separately",
     "Verify web form leads hit the assignment rule; confirm lead record shows TR Haynes on creation",
     "Monitor", "Live"),
    (2, "Lead Conversion: Record Type Split",
     "On conversion, Opp RecordType and Type set from Lead Source via CMDT",
     "LeadConversionService reads ODL_Source_Record_Type__mdt to set RecordType (UMB or Design_Build) + Type",
     "LeadConversionService updated; 6 CMDT records deployed; unmapped sources default to Design_Build",
     "Only 6 lead sources mapped. Any new or unlisted source silently defaults to Design_Build",
     "Add remaining lead source values to ODL_Source_Record_Type__mdt; add Megan alert for unmapped hits",
     "Medium", "Partial"),
    (3, "Lead Escalation — Stuck Leads",
     "Leads in Awaiting Decision >30 days trigger COO push notification",
     "LeadEscalationScheduler runs nightly; escalates stale leads via EscalationService",
     "Class in repo. No CronTrigger confirmed — scheduler may not be active in org",
     "Scheduler may be dormant; stale leads silently age past 30 days with no alert",
     "Run SELECT Id FROM CronTrigger to confirm; schedule via anonymous Apex if missing",
     "High", "Partial"),
    (4, "SMS Consent Auto-Stamp",
     "When SMS_Consent__c checked, SMS_Opt_In_Date__c stamps today's date",
     "Opt-In Date should auto-populate when rep checks SMS Consent on Contact record",
     "No Contact trigger or before-save flow stamps SMS_Opt_In_Date__c",
     "Date field is always blank on opted-in contacts; compliance record is incomplete",
     "Add before-save flow on Contact: if SMS_Consent__c = true AND Opt_In_Date is blank → set = TODAY()",
     "Critical", "Gap"),
    (5, "OrgWide Email — no-reply@upgrademybackyard.com",
     "Welcome and Nurture journey emails send from ODL brand domain",
     "LOVING_MC_UMB_Welcome_Journey and Nurture_Journey flows fire Messaging.sendEmail",
     "OWE address configuration unverified; emails may silently fall back to Salesforce default sender",
     "Brand email delivery risk; customers may see noreply@salesforce.com",
     "Run SELECT Address FROM OrgWideEmailAddress; add no-reply@upgrademybackyard.com if missing",
     "Critical", "Gap"),
    (6, "Opportunity Auto-Response Emails",
     "Opp created or updated triggers automated email to prospect",
     "Auto-response emails fire on new/updated Opportunities",
     "All_Opportunity_Auto_Response_Email and Opportunity_Autoresponse_Email flows active",
     "Two flows with overlapping names may double-send on same event",
     "Audit both flows for trigger conditions; deactivate or merge the duplicate",
     "Medium", "Partial"),
    (7, "Post-Consultation Decision Task",
     "After consultation meeting, task auto-created for rep follow-up decision",
     "Opportunity_Post_Consultation_Decision_Task_Trigger flow fires after consultation stage",
     "Flow is active",
     "Covered",
     "Confirm task is assigned to correct owner (Opp owner vs. rep)",
     "Monitor", "Live"),
    (8, "Deposit Invoice Email",
     "When deposit amount paid, invoice email auto-sent to customer",
     "Opportunity_Send_Deposit_Invoice_Email fires when deposit captured",
     "Flow active; Opportunity_Deposit_Amount_Paid_Actions before-save flow also active",
     "Covered. Verify email template is branded",
     "Review deposit email template for logo, branding, correct reply-to address",
     "Low", "Live"),
    (9, "Closed Won Survey",
     "Customer satisfaction survey sent on Closed Won",
     "Opportunity_Closed_Won_Survey flow fires on stage = Closed Won",
     "Flow active",
     "Covered",
     "Verify survey response records back in Salesforce or external tool",
     "Monitor", "Live"),
    (10, "Lead Source → CMDT Mapping Coverage",
     "All active lead sources mapped to correct RecordType in CMDT",
     "Every lead source should map to UMB or Design_Build via ODL_Source_Record_Type__mdt",
     "6 records: Lennar Voucher, UMB Builder Pop Up, Homebuilder Event, Web-Design Form, Web-Consultation Form, Website",
     "Sources like 'Referral', 'Cold Call', 'Event' not mapped; these default to Design_Build silently",
     "Inventory all distinct Lead Source values in org; add missing mappings to CMDT",
     "Medium", "Partial"),

    # ── WORK ORDER LIFECYCLE ───────────────────────────────────────────────
    ("WORK ORDER LIFECYCLE",),
    (11, "Work Order Status Picklist Values",
     "Status picklist values must match the 7 documented states",
     "Docs define: Pending Take Off → Pending Scheduling → Scheduled → In Progress → Job Completed → Ready to Invoice → Closed",
     "LOVING_PI_Orchestrator and PI flows manage WO status; exact picklist values unconfirmed",
     "Status names may differ from documented names causing FM confusion",
     "Query WorkOrder.Status picklist via Metadata API; add/rename missing values to match docs",
     "High", "Partial"),
    (12, "Work Order Record Types / Subtypes",
     "Different WO types: Sod Install, Grading, Hardscape, QI, Site Visit, Customer Care, Lawn Care",
     "Docs require distinct WO types for routing, scheduling, and reporting",
     "Single WorkOrder object; Takeoff__c is separate; QI trigger exists; no confirmed record types",
     "All WOs look identical — no visual or routing differentiation by type",
     "Add WorkOrder record types: Standard Install, Grading, Hardscape, QI, Site Visit, Customer Care, Lawn Care",
     "High", "Gap"),
    (13, "PI Orchestrator — Core Automation",
     "Production install WO orchestrates from receipt to closeout",
     "LOVING_PI_Orchestrator flow drives WO from Pending → Scheduled → Executed → Closeout",
     "7 PI flows active: PI_Orchestrator, PI_Approved_Automation, PI_Schedule_Automation, PI_RedFlag_Automation, PI_Closeout_Automation, PI_NFI_Loop, PI_Auto_Close",
     "Core production install pipeline is live and automated",
     "Verify PI_RedFlag_Automation alerts reach the correct recipient (FM or scheduling lead)",
     "Monitor", "Live"),
    (14, "Sod Take-Off Workflow",
     "Take-Off WO created on PO receipt; FM confirms quantities before ordering",
     "Take-Off WO auto-created; FM marks Site Visit Completed; WO job description updated with actual qty; billed qty stays per PO",
     "TakeoffFieldManagerMobileSync + TakeoffExecutionBridge triggers active; LOVING_Create_Takeoff_From_PO flow active",
     "Takeoff is live. EPO/Subjob path (when FM flags additional work) may be manual",
     "Trace TakeoffExecutionBridge for Needs Additional Work → Subjob WO path; automate if manual",
     "Medium", "Partial"),
    (15, "Billed vs. Field Quantities (Two Sections)",
     "WO shows two separate quantity sets: Billed (from PO for invoicing) and Field (from take-off for crews)",
     "Invoice notes must stay locked to PO quantities; crew sees actual take-off quantities in separate section",
     "No evidence of two distinct quantity sections on WorkOrder in repo field metadata",
     "Invoicing likely uses a single quantity set — risk of billing based on field qty instead of PO qty",
     "Add Billed_Quantity__c (locked to PO) and Field_Quantity__c (from take-off) to WorkOrder; update invoicing logic",
     "High", "Gap"),
    (16, "EPO / Subjob Work Order",
     "Extra Purchase Order work when site conditions require scope beyond original PO",
     "FM flags additional work → quote generated → EPO from builder → Subjob WO created in Pending Approval → Ready to Schedule on EPO receipt",
     "No Subjob WO record type or EPO object found in repo",
     "Extra work is handled outside Salesforce; no tracking, no EPO status, no Subjob WO linkage",
     "Create Subjob WO record type; build EPO intake + Subjob WO creation flow; auto-transition on EPO receipt",
     "High", "Gap"),
    (17, "Closeout Approval Queue",
     "FM reviews completed jobs and approves or sends back as finish job",
     "After Job Completed, WO enters FM's Closeout Approval Queue; FM clicks Approve (→ Ready to Invoice) or red Finish Job button (→ scheduling notification)",
     "LOVING_PI_Closeout_Automation, LOVING_Closeout_Close_Gate, LOVING_Closeout_Auto_Create flows active",
     "Closeout automation is live. Finish Job notification to scheduling team path needs verification",
     "Confirm Finish Job button triggers scheduling team notification; add if missing",
     "Medium", "Partial"),
    (18, "Quality Inspection Auto-Scheduling",
     "QI WO auto-created next business day after install WO is FM-approved",
     "QI WO created for FM the business day after installation completion; linked to parent install WO",
     "LOVING_QI_Auto_Schedule flow active",
     "Covered. Verify QI WO is linked back to parent Install WO and FM is correctly assigned",
     "Spot-check: find recent Install WO, confirm QI WO created next day with correct FM",
     "Monitor", "Live"),
    (19, "Grading Phase Sequencing",
     "Three sequential WOs: Rough Grade → Mid Grade → Final Grade",
     "Each grading phase has its own WO; phases are sequential; Final Grade immediately precedes landscaping",
     "WorkOrder exists with status tracking; no grading-specific record type or phase-sequencing flow found",
     "Grading phases not separated; no enforcement of sequencing; scheduling can overlap phases",
     "Add Grading record type on WorkOrder; build sequencing flow (Mid Grade only schedules after Rough Grade complete)",
     "Medium", "Gap"),
    (20, "Health Check Daily Flow",
     "Daily health check monitors crew/foreman status and alerts on issues",
     "LOVING_Health_Check_Daily scheduled flow reviews daily crew status and alerts",
     "LOVING_Health_Check_Daily flow exists but is INACTIVE",
     "Monitoring is fully disabled — no automated daily crew health checks running",
     "Investigate deactivation reason; fix underlying issue and reactivate flow",
     "High", "Inactive"),
    (21, "SA Customer Notification",
     "Customer notification fired on specific work order event",
     "LOVING_SA_Customer_Notification fires customer notification on WO status update",
     "Flow exists but is INACTIVE",
     "Customers not receiving automated status notifications",
     "Review flow, fix trigger condition, reactivate",
     "Medium", "Inactive"),

    # ── CLIENT FLOW TYPES ─────────────────────────────────────────────────
    ("CLIENT FLOW TYPES & PO INTAKE",),
    (22, "Client Flow Type Classification",
     "Every builder account has a Client Flow Type that controls PO processing",
     "Account field Client_Flow_Type__c with values: Standard (DR Horton), MPO (Lennar/Ryan), Exact (Yellowstone), Custom D&B",
     "No Client_Flow_Type__c or equivalent field found on Account object",
     "All builder accounts treated identically at intake; wrong WO creation path used for MPO and Exact clients",
     "Add Client_Flow_Type__c picklist to Account; add routing logic in WO creation flow",
     "High", "Gap"),
    (23, "Vendor Suite Portal Integration",
     "POs from DR Horton, Lennar, Ryan, Pulte received via Vendor Suite portal",
     "System auto-recognizes new PO from Vendor Suite or supports manual upload to create Builder PO",
     "LOVING_Create_Takeoff_From_PO and LOVING_BuilderPO_Derive_From_Lot flows exist; PO intake appears manual",
     "No API or email-parsing integration with Vendor Suite portal; all POs entered manually",
     "Investigate Vendor Suite API; build inbound REST endpoint or email-to-record flow for auto-PO creation",
     "Medium", "Gap"),
    (24, "MPO Parsing & Consolidation (Lennar / Ryan)",
     "Single MPO document contains multiple line items that spawn multiple linked WOs",
     "MPO record created on receipt; parsed into line items by work type; each type gets its own WO; all WOs linked to MPO parent; MPO tracked from Received to Completed",
     "LOVING_BuilderPO_Derive_From_Lot flow active; Builder PO object exists; no MPO parent record or multi-WO consolidation",
     "No MPO parent record; no multi-WO grouping; no MPO lifecycle status",
     "Create MPO parent record type on Builder_PO__c; add multi-WO child links; add status lifecycle",
     "High", "Gap"),
    (25, "Community Package Validation",
     "Alert when PO quantities differ from the standard community package",
     "Rule: if PO received differs from community package → red flag alert",
     "LOVING_Lot_Derive_Effective_Package flow active; LOVING_BuilderPO_Derive_From_Lot active",
     "Effective package derivation is live. Alert on PO vs. package discrepancy is unconfirmed",
     "Verify that a validation or alert fires when incoming PO line items deviate from community package",
     "Medium", "Partial"),

    # ── MATERIAL & INVENTORY ──────────────────────────────────────────────
    ("MATERIAL, INVENTORY & PO MANAGEMENT",),
    (26, "Night Loading Queue",
     "Material staging and loading process the night before a scheduled job",
     "When WO moves to Scheduled, system generates a night loading ticket placed in a queue; materials moved from Available to Assigned Inventory; ticket controls delivery logistics",
     "No Night_Loading_Ticket__c object, queue, or flow found in org or repo",
     "Entire night loading workflow is absent from Salesforce; managed manually outside the system",
     "Create Night_Loading_Ticket__c object with queue-based assignment; trigger on WO → Scheduled status change",
     "Critical", "Gap"),
    (27, "Inventory Reservation (Assigned Inventory)",
     "When materials are available, WO scheduling moves them from Available to Assigned",
     "System checks inventory on WO scheduling; in-stock items move to Assigned Inventory status to prevent double-booking; generates Internal PO",
     "Material_allocation_prod flow active; Inventory__c object likely exists",
     "Material_allocation_prod may handle allocation, but Assigned Inventory status flag and double-booking prevention are unconfirmed",
     "Trace Material_allocation_prod to confirm it sets Assigned status and prevents re-allocation of same inventory to another WO",
     "High", "Partial"),
    (28, "Vendor PO Auto-Generation (Out of Stock)",
     "System auto-creates Vendor PO when inventory is insufficient",
     "If material not in stock: Vendor PO created with vendor SKUs, quantities, pricing, delivery date (job start − lead time); vendor acknowledges; schedule delay flagged if unavailable",
     "No automated Vendor PO creation flow found; PO object exists",
     "Out-of-stock situations handled manually; no automatic schedule delay alert to scheduling team",
     "Build Vendor PO creation flow triggered on failed inventory check; include lead time calc, schedule delay flag on WO",
     "High", "Gap"),
    (29, "Internal PO Auto-Generation (In Stock)",
     "System auto-creates Internal PO from inventory when materials are available",
     "Internal PO created with item SKU, source location, destination (job site/night loading), expected pickup; Assigned Inventory flag set",
     "Material_allocation_prod flow handles some of this",
     "Unclear if Internal PO record is formally created and linked to WO and night loading ticket",
     "Confirm Material_allocation_prod creates a formal Internal PO record; add night loading ticket linkage",
     "Medium", "Partial"),
    (30, "Quantity Variance Alert",
     "Alert fires when delivered quantity differs from PO quantity",
     "System triggers Quantity Variance Alert on delivery discrepancy; variance tracked in report",
     "LOVING_Delivery_QC_Flag_Issue flow active; LOVING_Delivery_QC_Submit flow INACTIVE",
     "QC flag flow fires but Submit flow is inactive; variance tracking pipeline is broken",
     "Activate LOVING_Delivery_QC_Submit; confirm Flag_Issue flow captures PO qty vs. actual qty delta",
     "High", "Partial"),
    (31, "Backorder PO",
     "Partial deliveries trigger a backorder PO for remaining quantity",
     "When delivery is partial, system creates backorder PO for shortage; original PO marked Partially Delivered; backorder tracked to closure",
     "No backorder PO automation found",
     "Partial deliveries managed manually; no backorder tracking in Salesforce",
     "Add backorder PO creation logic in Delivery QC flow when quantity received < ordered",
     "Medium", "Gap"),
    (32, "Bid Request / RFQ Process",
     "TR's bid creation and vendor evaluation before issuing a PO",
     "Bid Request created with scope/specs; sent to vendor list as RFQ; bids received, compared, scored; winning vendor selected; PO issued",
     "No bid request object, RFQ workflow, or vendor evaluation process in Salesforce",
     "Entire vendor selection and bidding process is outside Salesforce",
     "Create Bid__c object linked to Vendor Account; add RFQ send + bid receipt tracking; connect approved bid to PO creation",
     "Medium", "Gap"),
    (33, "3-Way Match (PO / Receiving / Invoice)",
     "Vendor invoices matched to PO and receiving record before payment authorized",
     "Vendor invoice matched to PO (price/qty), Receiving record (qty delivered), Invoice (amount); payment only authorized on full match; pay only for qty actually delivered",
     "No 3-way match logic in Salesforce; no Invoice → PO → Receiving linkage",
     "Payment authorization is entirely manual; risk of over-payment on partial deliveries",
     "Add Invoice object with lookup to PO and Receiving record; build 3-way match validation logic",
     "Medium", "Gap"),

    # ── CREW & EQUIPMENT ──────────────────────────────────────────────────
    ("CREW, EQUIPMENT & SCHEDULING",),
    (34, "Crew Time Tracking (In Route / Arrived / Complete)",
     "Structured time capture at each phase of the crew workday",
     "In Route to Site starts drive time; Arrived at Site starts on-site clock; Job Complete stops it; drive time, on-site time, break time tracked separately",
     "WorkOrderFieldManagerMobileSync trigger syncs field status; FSL mobile app likely has these buttons",
     "Time tracking buttons may exist via FSL mobile. Drive time, on-site time, and break time as distinct fields are unconfirmed",
     "Verify ServiceAppointment has ActualStartTime, ActualEndTime, DriveTime; add WO rollup fields for reporting",
     "Medium", "Partial"),
    (35, "Crew Arrival & Completion Checklists",
     "Arrival checklist verifies materials, equipment, site condition before work; completion checklist verifies all tasks done, site cleaned",
     "Two checklists: arrival (material/equipment/site/safety check) and completion (tasks/quality/cleanup/leftover materials)",
     "LOVING_Create_Site_Readiness_Checklist and Site_Readiness_Prod flows active",
     "Site readiness checklist is live. Completion checklist status is unconfirmed",
     "Confirm completion checklist is created on WO → Job Completed status; verify both checklists are in FSL mobile app",
     "Medium", "Partial"),
    (36, "Timesheet / Payroll Integration",
     "Crew daily timesheet feeds into payroll system",
     "Crew lead submits timesheet (date, crew members, in/out, drive time, on-site time, WO ref); approved by supervisor; sent to payroll",
     "LOVING_Rippling_ResourceAbsence_Sync flow active; Rippling is the HR/payroll system",
     "Rippling sync handles absences. Actual timesheet capture and payroll export path unconfirmed",
     "Confirm whether Rippling handles crew timesheets; if not, build Timesheet__c object with Rippling export",
     "Medium", "Partial"),
    (37, "Crew & Equipment Board (Visual Scheduler)",
     "Drag-and-drop scheduling board with real-time crew and equipment status",
     "Visual board: crew roster, equipment list, calendar, job assignments; drag WO to crew; conflict detection (double-booking, insufficient travel time); color-coded; real-time updates from crew clock-in",
     "No custom Crew & Equipment Board LWC in repo; odlTasks LWC is scaffolded but not deployed; FSL Dispatcher Console may exist",
     "No custom scheduling board. FSL Dispatcher Console is the closest but lacks custom conflict detection and drag-and-drop WO assignment",
     "Build custom LWC Dispatch Board extending started odlTasks scaffold; integrate FSL ServiceAppointment data; add conflict detection Apex",
     "High", "Gap"),
    (38, "Equipment Maintenance Scheduling",
     "Equipment maintenance visible on scheduling board; alerts for upcoming service",
     "Equipment records show maintenance schedule; board alerts when maintenance due; equipment status changes to Maintenance",
     "No maintenance scheduling flow or Equipment maintenance fields confirmed in repo",
     "Equipment maintenance is not tracked or alerted in Salesforce",
     "Add Next_Maintenance_Date__c and Maintenance_Status__c to Equipment object; add scheduled flow for maintenance alerts",
     "Low", "Gap"),
    (39, "Foreman 1-on-1 Auto-Generation",
     "Weekly 1-on-1 records created automatically for foreman management reviews",
     "1-on-1 records auto-generated every Monday for each foreman",
     "LOVING_1on1_Auto_Generate_Monday scheduled flow is active",
     "Live and working",
     "No action needed; monitor that records are generating each Monday",
     "Monitor", "Live"),

    # ── CUSTOMER CARE ─────────────────────────────────────────────────────
    ("CUSTOMER CARE & WARRANTY",),
    (40, "Customer Care Request Intake",
     "Customer submits warranty/care request; triage determines site visit vs. direct repair",
     "Customer Care WO created with type (warranty, paid service, free estimate); triage step; Field Service Tech assigned; confirmation email to customer",
     "LOVING_FJ_Customer_Care_Notify flow active; Case object in use",
     "Notification flow is live. Triage field (warranty vs. paid vs. free) and customer confirmation email are unconfirmed",
     "Verify LOVING_FJ_Customer_Care_Notify sends email to customer; add triage picklist to Case",
     "Medium", "Partial"),
    (41, "Site Visit Work Order (Customer Care)",
     "Site Visit WO created when care request needs on-site assessment",
     "Site Visit WO created; Field Service Tech assigned; visit date scheduled; time tracked via FSL mobile",
     "FSL ServiceAppointment handles site visit scheduling; no dedicated Customer Care Site Visit WO record type confirmed",
     "No distinct Site Visit WO type — blends with standard WOs in reporting and scheduling views",
     "Add Site Visit record type to WorkOrder; filter scheduling board to show Customer Care separately",
     "Low", "Gap"),
    (42, "Quote → WO Auto-Creation (Customer Care)",
     "Approved quote from customer care automatically spawns a repair/replacement WO",
     "Customer approves quote → WO auto-created from quote with all details; Site Visit WO marked Complete",
     "LOVING_Quote_Approved_Create_Work_Order flow active",
     "Covered. Verify Site Visit WO is closed when repair WO is created",
     "Confirm flow closes/marks Complete the parent Site Visit WO when repair WO is created",
     "Monitor", "Live"),
    (43, "Customer Portal (Quote Delivery)",
     "Quotes delivered to customers via a self-service portal for review and e-approval",
     "Customer approves quote via customer portal OR email; approval triggers WO creation",
     "No Experience Cloud portal exists; quotes are sent via email only",
     "Customers cannot self-service approve quotes; all approvals are manual email/phone confirmations",
     "Consider Experience Cloud portal for quote self-service; short-term: add DocuSign or email approval tracking",
     "Low", "Gap"),

    # ── AQUA / IRRIGATION ─────────────────────────────────────────────────
    ("AQUA / IRRIGATION",),
    (44, "Aqua Watering Schedule Automation",
     "Automated watering schedule management across communities with duplicate prevention",
     "Watering schedules created and updated per community; duplicate records blocked; schedule adjustments on lot status changes",
     "LOVING_Aqua_Watering_Schedule_Update, LOVING_Aqua_Watering_Duplicate_Guard flows active",
     "Covered",
     "Confirm schedule links certification status back to related Lot/Homeowner_Property__c record",
     "Monitor", "Live"),
    (45, "Aqua Check Ticket Auto-Generation",
     "Scheduled flow auto-generates Aqua check tickets per community",
     "Check tickets generated on schedule for field team to verify irrigation system health",
     "LOVING_Aqua_Check_Ticket_Generator scheduled flow is active",
     "Covered",
     "Verify check ticket generation frequency matches community contract terms",
     "Monitor", "Live"),
    (46, "Aqua Pickup on Lot Close",
     "When lot is closed, irrigation equipment pickup ticket auto-created",
     "On lot close event, pickup ticket created for retrieval of temporary irrigation equipment",
     "LOVING_Aqua_Pickup_On_Lot_Close flow active",
     "Covered",
     "Spot-check a recently closed lot to confirm pickup ticket was created",
     "Monitor", "Live"),
    (47, "Aqua Inventory Adjustment",
     "Aqua equipment inventory adjusted automatically on pickup/delivery events",
     "Inventory counts updated when equipment is checked out or returned for aqua jobs",
     "LOVING_Aqua_Inventory_Adjustment flow active",
     "Covered",
     "Verify inventory counts on Aqua_Pickup_Ticket__c are accurate against physical count",
     "Monitor", "Live"),

    # ── LAWN CARE ─────────────────────────────────────────────────────────
    ("LAWN CARE",),
    (48, "Lawn Care WO Auto-Generation from PO",
     "When PO includes Spec Maintenance, a Lawn Care WO auto-creates",
     "If PO has Spec Maintenance line, system auto-creates Lawn Care WO (Ready to Schedule) with first service date = 2 weeks after install completion",
     "No Lawn Care WO auto-generation flow found; Aqua and QI auto-creation exist but not lawn care",
     "Lawn care WO creation is entirely manual; risk of missed recurring service",
     "Add flow on Builder PO receipt: if Spec Maintenance in scope → create Lawn Care WO; set start date = install complete + 14 days",
     "High", "Gap"),
    (49, "Recurring Lawn Care Schedule",
     "Recurring lawn care maintenance follows community calendar with seasonal adjustments",
     "After initial install, recurring Lawn Care WOs created on community schedule; seasonal adjustments made",
     "LOVING_Aqua_Check_Ticket_Generator shows the pattern; no equivalent lawn care recurring flow",
     "Recurring lawn care is not automated; crews may miss scheduled visits",
     "Build scheduled flow to generate Lawn Care WOs per community calendar; clone pattern from Aqua Check Ticket Generator",
     "High", "Gap"),

    # ── FORECASTING ───────────────────────────────────────────────────────
    ("FORECASTING & REPORTING",),
    (50, "Revenue Forecast from WO Pipeline",
     "Monthly/quarterly revenue forecast built from scheduled WOs and sales pipeline",
     "Forecasted revenue = sum of Total Contract Value on Scheduled WOs; revenue by work type and client; pipeline probability weighting from Opp stages",
     "330 reports and 26 dashboards exist; WorkOrder has contract value fields; Opportunity has Amount",
     "Reports may exist but whether WO cost fields (material cost, labor cost) for profit margin are populated is unconfirmed",
     "Verify WorkOrder Total_Price__c and cost fields are populated; build Revenue Forecast report combining WO pipeline + Opp pipeline",
     "Medium", "Partial"),
    (51, "Crew Utilization & Capacity Dashboard",
     "Crew utilization % and scheduling gap identification displayed in dashboard",
     "Crew utilization = assigned hours / available capacity; scheduling gaps identified weeks ahead; equipment utilization tracked",
     "26 dashboards exist; FSL resource capacity exists but utilization KPI dashboard unconfirmed",
     "No crew utilization % dashboard confirmed; capacity planning is ad-hoc",
     "Build Crew Utilization dashboard using ServiceResource + ServiceAppointment hours vs. available hours per period",
     "Medium", "Gap"),
    (52, "Actual vs. Forecast Variance Analysis",
     "Weekly/monthly comparison of actual revenue vs. forecast",
     "System tracks actual invoiced vs. forecasted revenue; variance analysis run; adjustments published",
     "No forecast variance automation or Forecast record object found",
     "Variance tracking is absent; no Actual vs. Budget comparison report",
     "Build Forecasting__c object to capture monthly targets; link Invoices to month; create variance report",
     "Medium", "Gap"),
    (53, "Profitability by Work Type / Client",
     "Profit margin calculated per work type and per client",
     "Profit margin = Revenue − (Material + Labor + Equipment costs); broken down by work type (landscaping, hardscape, grading) and client",
     "Cost fields on WorkOrder likely exist but profitability rollup report unconfirmed",
     "Profitability dashboard may be incomplete or absent",
     "Build Profitability dashboard on WO cost vs. revenue fields; filter by Work Type and Client",
     "Medium", "Partial"),
    (54, "Forecasting Dashboards — 5 Types",
     "5 specific dashboards: Financial Forecast, Operational Capacity, Profitability, Pipeline, Execution",
     "Docs specify: (1) Financial Forecast, (2) Operational Capacity, (3) Profitability, (4) Pipeline, (5) Execution dashboards with specific charts",
     "26 dashboards exist in org; which match the 5 specified is unconfirmed",
     "Dashboard coverage against spec is unverified",
     "Map the 26 existing dashboards against the 5 documented dashboard types; identify gaps and build missing ones",
     "Low", "Partial"),

    # ── ACCOUNTING ────────────────────────────────────────────────────────
    ("ACCOUNTING & INVOICING",),
    (55, "Accounting Upload / Integration",
     "WO closeout triggers automatic data push to accounting system for invoicing",
     "On FM approval of WO, data automatically added to accounting upload including materials, quantities, pricing per PO, labor; sent to accounting system",
     "No accounting integration or export automation found in org or repo",
     "Zero connection between Salesforce and accounting; closeout creates manual data re-entry",
     "Implement accounting upload: scheduled batch job exporting Ready to Invoice WOs to CSV or direct QuickBooks/accounting API via named credential",
     "Critical", "Gap"),
    (56, "Invoice Creation from WO",
     "Invoice generated automatically from approved WO with PO quantities and pricing",
     "Invoice pulls MPO line items, actual quantities, pricing per PO; invoice sent to client per payment terms",
     "Invoice_Line_Item__c and InvoiceLineTrigger exist in org (trigger not in repo)",
     "Invoice object exists but auto-creation from WO closeout is unconfirmed; InvoiceLineTrigger not in repo",
     "Retrieve InvoiceLineTrigger to repo; verify auto-invoice creation on WO → Ready to Invoice; confirm pricing source (PO not field qty)",
     "High", "Partial"),
    (57, "Payment Terms Per Client",
     "Each client has specific payment terms applied to invoices",
     "Invoice payment terms follow builder contract: DR Horton terms, Lennar terms, Ryan terms, Pulte terms",
     "No Payment_Terms__c field confirmed on Account or Invoice object",
     "Payment terms may be tracked outside Salesforce or manually referenced",
     "Add Payment_Terms__c to Account; populate per client; reference in invoice generation logic",
     "Medium", "Gap"),

    # ── SOURCE CONTROL GAPS ───────────────────────────────────────────────
    ("REPO / SOURCE CONTROL GAPS",),
    (58, "InvoiceLineTrigger Not in Repo",
     "Active trigger in org but missing from source control",
     "InvoiceLineTrigger is active on Invoice_Line_Item__c in production",
     "Not in /triggers/ folder in repo; code exists only in org",
     "Deployment would wipe this trigger; it will be lost on next deploy if not retrieved",
     "Run: sf project retrieve start --metadata ApexTrigger:InvoiceLineTrigger",
     "Critical", "Gap"),
    (59, "ODLCampaignTrigger Not in Repo",
     "Active trigger in org but missing from source control",
     "ODLCampaignTrigger is active on Campaign in production",
     "Not in repo",
     "Deployment would wipe this trigger",
     "Run: sf project retrieve start --metadata ApexTrigger:ODLCampaignTrigger",
     "Critical", "Gap"),
    (60, "ODLPaymentMilestoneTrigger Not in Repo",
     "Active trigger in org but missing from source control",
     "ODLPaymentMilestoneTrigger is active on Payment_Milestone__c",
     "Not in repo",
     "Deployment would wipe this trigger",
     "Run: sf project retrieve start --metadata ApexTrigger:ODLPaymentMilestoneTrigger",
     "Critical", "Gap"),
    (61, "ODLQuoteTrigger Not in Repo",
     "Active trigger in org but missing from source control",
     "ODLQuoteTrigger is active on Quote (standard) in production",
     "Not in repo",
     "Deployment would wipe this trigger",
     "Run: sf project retrieve start --metadata ApexTrigger:ODLQuoteTrigger",
     "Critical", "Gap"),
    (62, "ODLQuoteLineItemTrigger Not in Repo",
     "Active trigger in org but missing from source control",
     "ODLQuoteLineItemTrigger is active on QuoteLineItem in production",
     "Not in repo",
     "Deployment would wipe this trigger",
     "Run: sf project retrieve start --metadata ApexTrigger:ODLQuoteLineItemTrigger",
     "Critical", "Gap"),
    (63, "OpportunityNoteNotificationTrigger Not in Repo",
     "Active trigger in org but missing from source control",
     "OpportunityNoteNotificationTrigger is active on ContentDocumentLink in production",
     "Not in repo",
     "Deployment would wipe this trigger",
     "Run: sf project retrieve start --metadata ApexTrigger:OpportunityNoteNotificationTrigger",
     "Critical", "Gap"),
]

row_num = 2
alt = False
for item in GAP_ROWS:
    if len(item) == 1:
        write_section_row(ws1, item[0], len(HEADERS), row_num)
        ws1.row_dimensions[row_num].height = 18
        row_num += 1
        alt = False
    else:
        write_data_row(ws1, list(item), row_num,
                       status_col=9, priority_col=8, alt=alt)
        ws1.row_dimensions[row_num].height = 72
        row_num += 1
        alt = not alt

ws1.auto_filter.ref = f"A1:{get_column_letter(len(HEADERS))}1"

# ═══════════════════════════════════════════════════════════════════════════
# SHEET 2 — TRIGGERS
# ═══════════════════════════════════════════════════════════════════════════

ws2 = wb.create_sheet("Triggers")
ws2.freeze_panes = "A2"
T_HEADERS = ["Object", "Trigger Name", "Org Status", "In Repo?", "Notes"]
T_WIDTHS  = [28, 40, 14, 12, 45]
write_header_row(ws2, T_HEADERS, T_WIDTHS)

TRIGGERS = [
    ("Quote__c",              "QuoteTrigger",                                "Active",  "No",  "Custom Quote object trigger; not in repo — CRITICAL"),
    ("Aqua_Check_Ticket__c",  "AquaCheckFieldManagerMobileSync",             "Active",  "Yes", "Syncs check ticket to FSL mobile"),
    ("Aqua_Pickup_Ticket__c", "AquaPickupFieldManagerMobileSync",            "Active",  "Yes", "Syncs pickup ticket to FSL mobile"),
    ("Quote_Line_Item__c",    "QuoteLineTrigger",                            "Active",  "No",  "Custom Quote Line object trigger; not in repo — CRITICAL"),
    ("Takeoff__c",            "TakeoffFieldManagerMobileSync",               "Active",  "Yes", "Syncs take-off to FSL mobile app"),
    ("Takeoff__c",            "TakeoffExecutionBridge",                      "Active",  "Yes", "Bridges take-off completion to WO job description update"),
    ("Invoice_Line_Item__c",  "InvoiceLineTrigger",                          "Active",  "No",  "Invoice line trigger; not in repo — CRITICAL"),
    ("Homeowner_Property__c", "ODLHomeownerPropertyIdentityProperty",        "Active",  "Yes", "Links property to contact identity on insert/update"),
    ("Payment_Milestone__c",  "ODLPaymentMilestoneTrigger",                  "Active",  "No",  "Payment milestone trigger; not in repo — CRITICAL"),
    ("Voucher__c",            "ODLVoucherTrigger",                           "Active",  "Yes", "Fires ODLVoucherLifecycleService on voucher insert/update"),
    ("Campaign",              "ODLCampaignTrigger",                          "Active",  "No",  "Campaign trigger; not in repo — CRITICAL"),
    ("ContentDocumentLink",   "OpportunityNoteNotificationTrigger",          "Active",  "No",  "File attachment notification; not in repo — CRITICAL"),
    ("EmailMessage",          "ODLEmailMessageTrigger",                      "Active",  "Yes", "Processes inbound email messages"),
    ("Event",                 "ODLEventTrigger",                             "Active",  "Yes", "Handles event insert/update for consultation tracking"),
    ("Lead",                  "LeadTrigger",                                 "Active",  "Yes", "Handles lead routing, conversion events"),
    ("Opportunity",           "ODLOpportunityTrigger",                       "Active",  "Yes", "Central Opp trigger; fires ODLOpportunityService"),
    ("Opportunity",           "ODLHomeownerPropertyIdentityOpportunity",     "Active",  "Yes", "Links opportunity to homeowner property"),
    ("Quote (standard)",      "ODLQuoteTrigger",                             "Active",  "No",  "Standard Quote trigger; not in repo — CRITICAL"),
    ("QuoteLineItem",         "ODLQuoteLineItemTrigger",                     "Active",  "No",  "Standard QuoteLineItem trigger; not in repo — CRITICAL"),
    ("Task",                  "ODLTaskTrigger",                              "Active",  "Yes", "Handles task create/update for activity tracking"),
    ("WorkOrder",             "LOVING_WorkOrderTrigger",                     "Active",  "Yes", "Main WO trigger; fires LOVING_WorkOrderTriggerHandler"),
    ("WorkOrder",             "WorkOrderFieldManagerMobileSync",             "Active",  "Yes", "Syncs WO status to FSL field manager mobile app"),
]

for i, row in enumerate(TRIGGERS):
    vals = list(row)
    alt_row = i % 2 == 1
    cell_row = i + 2
    for col, val in enumerate(vals, 1):
        cell = ws2.cell(row=cell_row, column=col, value=val)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        cell.border = thin_border()
        cell.font = hfont("000000", size=9)
        cell.fill = hfill(C_ALT_BG if alt_row else "FFFFFF")
    # colour Org Status
    status_val = vals[2]
    c = ws2.cell(row=cell_row, column=3)
    c.fill = hfill(C_GRN_BG if status_val == "Active" else "EDEDED")
    c.font = hfont(C_GRN_FG if status_val == "Active" else "7F7F7F", bold=True, size=9)
    # colour In Repo
    repo_val = vals[3]
    r = ws2.cell(row=cell_row, column=4)
    if repo_val == "No":
        r.fill = hfill(C_RED_BG)
        r.font = hfont(C_RED_FG, bold=True, size=9)
    else:
        r.fill = hfill(C_GRN_BG)
        r.font = hfont(C_GRN_FG, bold=True, size=9)
    ws2.row_dimensions[cell_row].height = 36

ws2.auto_filter.ref = f"A1:{get_column_letter(len(T_HEADERS))}1"

# ═══════════════════════════════════════════════════════════════════════════
# SHEET 3 — FLOWS
# ═══════════════════════════════════════════════════════════════════════════

ws3 = wb.create_sheet("Flows")
ws3.freeze_panes = "A2"
F_HEADERS = ["Area", "Flow API Name", "Label", "Type", "Active?", "Notes"]
F_WIDTHS  = [22, 46, 40, 20, 10, 45]
write_header_row(ws3, F_HEADERS, F_WIDTHS)

FLOWS = [
    ("Production Install", "LOVING_PI_Orchestrator",                         "PI Orchestrator",                            "RecordAfterSave", "Yes", "Master WO orchestration flow"),
    ("Production Install", "LOVING_PI_Approved_Automation",                  "PI Approved Automation",                     "RecordAfterSave", "Yes", "Fires when WO is approved by FM"),
    ("Production Install", "LOVING_PI_Schedule_Automation",                  "PI Schedule Automation",                     "RecordAfterSave", "Yes", "Fires when WO moves to Scheduled"),
    ("Production Install", "LOVING_PI_RedFlag_Automation",                   "PI Red Flag Automation",                     "RecordAfterSave", "Yes", "Alerts on WO red flags"),
    ("Production Install", "LOVING_PI_Closeout_Automation",                  "PI Closeout Automation",                     "RecordAfterSave", "Yes", "Drives WO closeout → Ready to Invoice"),
    ("Production Install", "LOVING_PI_NFI_Loop",                             "PI NFI Loop",                                "RecordAfterSave", "Yes", "Handles NFI (Not Fully Installed) loop"),
    ("Production Install", "LOVING_PI_Auto_Close",                           "PI Auto Close",                              "RecordAfterSave", "Yes", "Auto-closes WO under certain conditions"),
    ("Aqua",               "LOVING_Aqua_Inventory_Adjustment",               "Aqua Inventory Adjustment",                  "RecordAfterSave", "Yes", "Adjusts inventory on aqua ticket events"),
    ("Aqua",               "LOVING_Aqua_Pickup_On_Lot_Close",                "Aqua Pickup On Lot Close",                   "RecordAfterSave", "Yes", "Creates pickup ticket on lot close"),
    ("Aqua",               "LOVING_Aqua_Watering_Duplicate_Guard",           "Aqua Watering Duplicate Guard",              "RecordBeforeSave","Yes", "Prevents duplicate watering schedules"),
    ("Aqua",               "LOVING_Aqua_Watering_Schedule_Update",           "Aqua Watering Schedule Update",              "RecordAfterSave", "Yes", "Updates schedule on lot/community changes"),
    ("Aqua",               "LOVING_Aqua_Check_Ticket_Generator",             "Aqua Check Ticket Generator",                "Scheduled",       "Yes", "Generates Aqua check tickets on schedule"),
    ("Takeoff/WO",         "LOVING_Create_Takeoff_From_PO",                  "Create Takeoff From PO",                     "RecordAfterSave", "Yes", "Creates Takeoff WO on Builder PO receipt"),
    ("Takeoff/WO",         "LOVING_Takeoff_To_WO_Creation",                  "Takeoff To WO Creation",                     "RecordAfterSave", "No",  "INACTIVE — Takeoff → WO creation disabled"),
    ("Takeoff/WO",         "LOVING_Quote_Approved_Create_Work_Order",        "Quote Approved Create Work Order",           "RecordAfterSave", "Yes", "Creates WO when Quote is approved"),
    ("Checklists",         "LOVING_Create_Site_Readiness_Checklist",         "Create Site Readiness Checklist",            "RecordAfterSave", "Yes", "Creates site readiness checklist on WO"),
    ("Checklists",         "LOVING_Create_Closeout_Checklist",               "Create Closeout Checklist",                  "RecordAfterSave", "Yes", "Creates closeout checklist on WO"),
    ("Checklists",         "LOVING_Closeout_Close_Gate",                     "Closeout Close Gate",                        "RecordBeforeSave","Yes", "Blocks WO close if closeout incomplete"),
    ("Checklists",         "LOVING_Closeout_Auto_Create",                    "Closeout Auto Create",                       "RecordAfterSave", "Yes", "Auto-creates closeout record"),
    ("Checklists",         "Site_Readiness_Prod",                            "Site Readiness Prod",                        "RecordAfterSave", "Yes", "Production site readiness flow"),
    ("Material",           "LOVING_BuilderPO_Derive_From_Lot",               "Builder PO Derive From Lot",                 "RecordBeforeSave","Yes", "Derives Builder PO details from Lot record"),
    ("Material",           "Material_allocation_prod",                       "Material Allocation Prod",                   "RecordAfterSave", "Yes", "Allocates materials to WO"),
    ("QI",                 "LOVING_QI_Auto_Schedule",                        "QI Auto Schedule",                           "RecordAfterSave", "Yes", "Auto-schedules Quality Inspection WO next biz day"),
    ("Health/Mgmt",        "LOVING_Health_Check_Daily",                      "Health Check Daily",                         "Scheduled",       "No",  "INACTIVE — daily crew health check disabled"),
    ("Health/Mgmt",        "LOVING_1on1_Auto_Generate_Monday",               "1on1 Auto Generate Monday",                  "Scheduled",       "Yes", "Generates weekly 1-on-1 records for foremen"),
    ("Delivery QC",        "LOVING_Delivery_QC_Photo_Gate",                  "Delivery QC Photo Gate",                     "RecordAfterSave", "Yes", "Blocks delivery close if no photo"),
    ("Delivery QC",        "LOVING_Delivery_QC_Flag_Issue",                  "Delivery QC Flag Issue",                     "RecordAfterSave", "Yes", "Flags QC issues on delivery"),
    ("Delivery QC",        "LOVING_Delivery_QC_Submit",                      "Delivery QC Submit",                         "RecordAfterSave", "No",  "INACTIVE — delivery QC submit pipeline broken"),
    ("Documents",          "LOVING_Document_Uploaded",                       "Document Uploaded",                          "RecordAfterSave", "Yes", "Fires on ContentDocumentLink creation"),
    ("Customer Care",      "LOVING_FJ_Customer_Care_Notify",                 "FJ Customer Care Notify",                    "RecordAfterSave", "Yes", "Notifies on customer care WO creation"),
    ("Customer Care",      "LOVING_SA_Customer_Notification",                "SA Customer Notification",                   "RecordAfterSave", "No",  "INACTIVE — customer status notification disabled"),
    ("Builder/Lot",        "LOVING_Lot_Derive_Effective_Package",            "Lot Derive Effective Package",               "RecordBeforeSave","Yes", "Derives effective landscape package for lot"),
    ("HR/Staffing",        "LOVING_Rippling_ResourceAbsence_Sync",           "Rippling Resource Absence Sync",             "RecordAfterSave", "Yes", "Syncs Rippling absences to FSL resource records"),
    ("Sales/Opp",          "All_Opportunity_Auto_Response_Email",            "All Opportunity Auto Response Email",        "RecordAfterSave", "Yes", "Auto-response email on Opp create/update"),
    ("Sales/Opp",          "Opportunity_After_Update_Flow",                  "Opportunity After Update Flow",              "RecordAfterSave", "Yes", "Post-update Opp automation"),
    ("Sales/Opp",          "Opportunity_Autoresponse_Email",                 "Opportunity Autoresponse Email",             "RecordAfterSave", "Yes", "Auto-response email — possible duplicate of above"),
    ("Sales/Opp",          "Opportunity_Closed_Won_Survey",                  "Opportunity Closed Won Survey",              "RecordAfterSave", "Yes", "Sends satisfaction survey on Closed Won"),
    ("Sales/Opp",          "Opportunity_Deposit_Amount_Paid_Actions",        "Opportunity Deposit Amount Paid Actions",    "RecordBeforeSave","Yes", "Actions on deposit payment capture"),
    ("Sales/Opp",          "Opportunity_Post_Consultation_Decision_Task_Trigger","Post Consultation Decision Task",        "RecordAfterSave", "Yes", "Creates follow-up task after consultation"),
    ("Sales/Opp",          "Opportunity_Send_Deposit_Invoice_Email",         "Send Deposit Invoice Email",                 "RecordAfterSave", "Yes", "Sends deposit invoice email to customer"),
    ("Lead",               "Lead_After_Save_Notify_Owner",                   "Lead After Save Notify Owner",               "RecordAfterSave", "Yes", "Notifies lead owner on new assignment"),
    ("Task/Event",         "Before_Save_Flow_on_Task",                       "Before Save Flow on Task",                   "RecordBeforeSave","Yes", "Task defaulting and validation"),
    ("Task/Event",         "Event_After_Insert_Flow",                        "Event After Insert Flow",                    "RecordAfterSave", "Yes", "Post-insert event processing"),
    ("Task/Event",         "Event_Consultation_Meeting_Reminders",           "Event Consultation Meeting Reminders",       "RecordAfterSave", "Yes", "Sends reminders for consultation meetings"),
    ("Builder",            "Lennar_Standard_Grilling_Island",                "Lennar Standard Grilling Island",            "RecordBeforeSave","Yes", "Lennar-specific grilling island package logic"),
    ("Builder",            "Lennar_Voucher_Claim_Validation",                "Lennar Voucher Claim Validation",            "RecordBeforeSave","Yes", "Validates Lennar voucher claim on Opp"),
    ("Builder",            "Create_CO",                                      "Create CO",                                  "RecordAfterSave", "Yes", "Creates Change Order record"),
    ("Builder",            "Create_PE",                                      "Create PE (Platform Event)",                 "PlatformEvent",   "Yes", "Publishes platform event for builder integration"),
    ("Marketing",          "LOVING_MC_UMB_Welcome_Journey",                  "MC UMB Welcome Journey",                     "RecordAfterSave", "Yes", "Sends UMB welcome email via Salesforce Email"),
    ("Marketing",          "LOVING_MC_UMB_Nurture_Journey",                  "MC UMB Nurture Journey",                     "RecordAfterSave", "Yes", "Sends UMB nurture email via Salesforce Email"),
]

for i, row in enumerate(FLOWS):
    vals = list(row)
    alt_row = i % 2 == 1
    cell_row = i + 2
    for col, val in enumerate(vals, 1):
        cell = ws3.cell(row=cell_row, column=col, value=val)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        cell.border = thin_border()
        cell.font = hfont("000000", size=9)
        cell.fill = hfill(C_ALT_BG if alt_row else "FFFFFF")
    # colour Active column
    active_val = vals[4]
    c = ws3.cell(row=cell_row, column=5)
    if active_val == "Yes":
        c.fill = hfill(C_GRN_BG)
        c.font = hfont(C_GRN_FG, bold=True, size=9)
    else:
        c.fill = hfill(C_RED_BG)
        c.font = hfont(C_RED_FG, bold=True, size=9)
    ws3.row_dimensions[cell_row].height = 32

ws3.auto_filter.ref = f"A1:{get_column_letter(len(F_HEADERS))}1"

# ═══════════════════════════════════════════════════════════════════════════
# SHEET 4 — KEY OBJECTS
# ═══════════════════════════════════════════════════════════════════════════

ws4 = wb.create_sheet("Key Objects")
ws4.freeze_panes = "A2"
O_HEADERS = ["Object API Name", "Label", "Purpose", "Key Fields", "Automation Coverage", "Gap / Notes"]
O_WIDTHS  = [32, 28, 35, 40, 35, 35]
write_header_row(ws4, O_HEADERS, O_WIDTHS)

OBJECTS = [
    ("WorkOrder",             "Work Order",              "Field service job record — sod install, hardscape, grading, QI, etc.",
     "Status, Subject, AccountId, Expected_Start_Date__c, Total_Price__c",
     "7 PI flows + 2 WO triggers + QI auto-schedule + Site Readiness + Closeout flows",
     "Needs record types for WO subtypes; no Night Loading or EPO linkage"),
    ("Takeoff__c",            "Takeoff",                 "Site take-off assessment before sod install; records actual field quantities",
     "Status, Field_Qty__c, Street_Tree_Count__c, Work_Order__c",
     "TakeoffFieldManagerMobileSync + TakeoffExecutionBridge + Create_Takeoff_From_PO",
     "Needs Additional Work → EPO/Subjob path may be manual"),
    ("Builder_PO__c",         "Builder PO",              "Purchase order received from builder clients (DR Horton, Lennar, Ryan, Pulte)",
     "PO_Number__c, Client__c, Status__c, Community__c, Amount__c",
     "LOVING_BuilderPO_Derive_From_Lot; LOVING_Lot_Derive_Effective_Package",
     "No MPO parent grouping; no Vendor Suite portal integration"),
    ("Opportunity",           "Opportunity",             "Sales deal record — UMB or Design Build pipeline",
     "StageName, Amount, RecordType, LeadSource, CloseDate",
     "ODLOpportunityTrigger; 7 Opp flows; ODLOpportunityService canonical check",
     "Record types split live; CMDT mapping for 6 sources only"),
    ("Lead",                  "Lead",                    "Inbound prospect before conversion",
     "Status, LeadSource, OwnerId, SMS_Consent__c",
     "LeadTrigger; Lead_After_Save_Notify_Owner; LeadConversionService",
     "SMS_Opt_In_Date__c never auto-stamps; escalation scheduler status unverified"),
    ("Contact",               "Contact",                 "Homeowner or prospect person record",
     "AccountId, Email, Phone, SMS_Consent__c, SMS_Opt_In_Date__c",
     "ODLContactRecordController; Contact record page LWC live",
     "No Contact trigger for SMS stamp; no Home_Owner account record type"),
    ("Account",               "Account (Household)",     "Homeowner household or builder company account",
     "Name, RecordType, BillingAddress",
     "ODLHomeownerPropertyIdentityProperty; Opportunity rollup",
     "No Client_Flow_Type__c field; 47 Person Accounts are actual homeowners"),
    ("Voucher__c",            "Voucher",                 "Lennar/builder voucher entitlement record",
     "Status__c, Opportunity__c, CampaignMember__c",
     "ODLVoucherTrigger → ODLVoucherLifecycleService; Lennar_Voucher_Claim_Validation",
     "Fires on Voucher__c only, not on every Opp save — correct behaviour"),
    ("Homeowner_Property__c", "Homeowner Property",      "Specific lot/property linked to a homeowner contact",
     "Contact__c, Opportunity__c, Community__c, Status__c",
     "ODLHomeownerPropertyIdentityProperty + ODLHomeownerPropertyIdentityOpportunity triggers",
     "47 Person Accounts are actual homeowners; no Home_Owner record type on Account"),
    ("Payment_Milestone__c",  "Payment Milestone",       "Scheduled payment checkpoint on a project",
     "Status__c, Due_Date__c, Amount__c, Opportunity__c",
     "ODLPaymentMilestoneTrigger (active but NOT in repo)",
     "Trigger must be retrieved to repo before next deploy"),
    ("Quote__c",              "Quote (Custom)",          "Custom quote object for project pricing",
     "Status__c, Total__c, Opportunity__c",
     "QuoteTrigger (active but NOT in repo); LOVING_Quote_Approved_Create_Work_Order",
     "Both Quote__c QuoteTrigger and standard Quote ODLQuoteTrigger exist — may conflict"),
    ("Aqua_Check_Ticket__c",  "Aqua Check Ticket",       "Irrigation check task for field team",
     "Status__c, Community__c, Assigned_To__c",
     "AquaCheckFieldManagerMobileSync trigger; LOVING_Aqua_Check_Ticket_Generator",
     "Well-covered; verify community schedule alignment"),
    ("Aqua_Pickup_Ticket__c", "Aqua Pickup Ticket",      "Irrigation equipment pickup task on lot close",
     "Status__c, Lot__c, Equipment__c",
     "AquaPickupFieldManagerMobileSync; LOVING_Aqua_Pickup_On_Lot_Close",
     "Well-covered"),
    ("Invoice_Line_Item__c",  "Invoice Line Item",       "Individual line on a client invoice",
     "Invoice__c, Quantity__c, Unit_Price__c, Total__c",
     "InvoiceLineTrigger (active but NOT in repo)",
     "Trigger must be retrieved immediately; no accounting export automation"),
    ("Campaign",              "Campaign",                "Marketing campaign for tracking lead sources",
     "Name, Type, Status, StartDate",
     "ODLCampaignTrigger (active but NOT in repo)",
     "Trigger must be retrieved immediately"),
]

for i, row in enumerate(OBJECTS):
    vals = list(row)
    alt_row = i % 2 == 1
    cell_row = i + 2
    for col, val in enumerate(vals, 1):
        cell = ws4.cell(row=cell_row, column=col, value=val)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        cell.border = thin_border()
        cell.font = hfont("000000", size=9)
        cell.fill = hfill(C_ALT_BG if alt_row else "FFFFFF")
    ws4.row_dimensions[cell_row].height = 52

ws4.auto_filter.ref = f"A1:{get_column_letter(len(O_HEADERS))}1"

# ═══════════════════════════════════════════════════════════════════════════
# SHEET 5 — PROCESS MAP
# ═══════════════════════════════════════════════════════════════════════════

ws5 = wb.create_sheet("Process Map")
ws5.freeze_panes = "A2"
P_HEADERS = ["#", "Process Name", "Process Source Doc", "Key Steps Summary",
             "Owner Role(s)", "Salesforce Objects Used",
             "Automation Coverage", "Status in Salesforce"]
P_WIDTHS  = [4, 25, 30, 50, 22, 30, 35, 14]
write_header_row(ws5, P_HEADERS, P_WIDTHS)

PROCESSES = [
    (1, "Standard PO Install (DR Horton)",
     "Average Client detailed flow",
     "Receive PO → Create Sod+Plant Install WO (Pending Take Off) → Create Sod Take-Off WO (Scheduled) → FM site visit → confirm quantities → Ready to Schedule → Crew assigned → Night loading → Install → Closeout → FM approves → Ready to Invoice → QI created",
     "Scheduling (Dan), Field Manager, Crew",
     "Builder_PO__c, WorkOrder, Takeoff__c, Inventory__c",
     "PI Orchestrator (7 flows), Takeoff flows, QI_Auto_Schedule, Closeout flows",
     "Partial"),
    (2, "Client Flow Type Classification",
     "Custom D & B Detailed Flow",
     "Assign each builder account a Client Flow Type (Standard, MPO, Exact/Yellowstone, Custom D&B) → default settings applied → WO creation uses correct flow template",
     "Admin / Ops Lead",
     "Account",
     "None — no routing logic based on client type exists",
     "Gap"),
    (3, "MPO Processing — Lennar Homes",
     "MPO 1 - Lennar",
     "MPO received via email/Vendor Suite → parsed into line items → MPO Record created → multiple WOs created per work type → all linked to MPO parent → resources allocated → job executed → MPO marked Complete when all WOs complete",
     "Scheduling (Dan), Field Manager, Crew",
     "Builder_PO__c (no MPO parent), WorkOrder",
     "LOVING_Create_Takeoff_From_PO; LOVING_BuilderPO_Derive_From_Lot",
     "Partial"),
    (4, "MPO Processing — Ryan Homes",
     "MPO2 - Ryan Homes",
     "MPO received → Sod Install WO created → Sod Take-Off WO created → quantities confirmed → materials sourced → scheduled → executed → closeout → invoiced",
     "Scheduling, Field Manager, Crew",
     "Builder_PO__c, WorkOrder, Takeoff__c",
     "Same as Standard flow; MPO parent linkage missing",
     "Partial"),
    (5, "Exact / Yellowstone Client Flow",
     "Exact (Yellowstone) - Client flow Type Details",
     "Project received → classified → WO created → labor/cost estimate → quote approval (if needed) → scheduled → crew executes → QI optional → closeout → invoiced per Yellowstone contract terms",
     "Project Manager, FM, Crew",
     "WorkOrder, Quote__c, Account",
     "Quote_Approved_Create_Work_Order; QI_Auto_Schedule",
     "Partial"),
    (6, "DR Horton Hardscape WO",
     "DR Horton ODL Hardscape Work Order Creation",
     "ODL/Hardscape PO received → Hardscape WO created → hardscape crew assigned → equipment reserved → night loading → install → closeout → FM approves → invoice",
     "Scheduling, Hardscape Crew, FM",
     "Builder_PO__c, WorkOrder",
     "PI Orchestrator; no hardscape-specific WO type",
     "Partial"),
    (7, "Grading Phase WOs (DR Horton)",
     "DR Horton Grading Work Orders Creation",
     "Grading project identified → Rough Grade WO created → Mid Grade WO created → Final Grade WO created → each phase scheduled sequentially → grading crew + equipment (dozers/graders) assigned → each phase executed and closed → Final Grade immediately before landscaping",
     "Scheduling, Grading Crew, FM",
     "WorkOrder",
     "PI Orchestrator; no grading record type; no phase sequencing enforcement",
     "Gap"),
    (8, "Pulte ODL Hardscape WO",
     "Pulte ODL Hardscape WorkOrder Creation",
     "Pulte ODL PO received → Hardscape WO created → hardscape crew + equipment → night loading → install → closeout → Pulte invoice per payment terms",
     "Scheduling, Hardscape Crew, FM",
     "Builder_PO__c, WorkOrder",
     "Same as DR Horton hardscape; Pulte client type unclassified",
     "Partial"),
    (9, "Customer Care Request",
     "Customer Care Work",
     "Customer submits request (plant replacement, irrigation repair, hardscape adjustment) → Customer Care WO created → triage → Site Visit WO created → tech assesses → warranty vs. paid determination → quote (if paid) → customer approves → repair WO created → executed → invoiced or warranty-closed",
     "Field Service Tech, FM, Customer",
     "Case, WorkOrder, Quote__c",
     "LOVING_FJ_Customer_Care_Notify; Quote_Approved_Create_Work_Order",
     "Partial"),
    (10, "Customer Care Site Visit & Quote",
     "Customer Care - Site Visit & Quote Process",
     "Request intake → triage → Site Visit WO → tech arrives → site assessment checklist → photos taken → root cause documented → quote prepared → FM reviews → quote sent to customer → customer approves → repair WO created → Site Visit WO closed",
     "Field Service Tech, FM, Office Staff, Customer",
     "WorkOrder, Quote__c",
     "Quote_Approved_Create_Work_Order; no customer portal for self-service approval",
     "Partial"),
    (11, "PO Bid & Vendor Selection (TR's Process)",
     "PO Overview Work Details",
     "Scope documented → vendor list identified → RFQ/RFP issued to vendors → bids received → bid comparison → winning vendor selected → PO issued → vendor acknowledges → materials delivered → receiving checklist → 3-way match → payment processed",
     "TR (Procurement), Vendors, Receiving Team, Accounting",
     "No dedicated Bid or Vendor Evaluation object",
     "None — entire process outside Salesforce",
     "Gap"),
    (12, "Material Ordering When Scheduling",
     "PO Process - Material Ordering When Scheduling",
     "WO → Scheduled → material list reviewed → inventory check → if in stock: Internal PO + Night Loading Ticket + Assign Inventory → if out of stock: Vendor PO + lead time calc + schedule delay flag → delivery → quantities verified → PO closed → backorder if partial",
     "Scheduling, Materials Team, Night Loading, Vendors",
     "WorkOrder, Inventory__c, Builder_PO__c",
     "Material_allocation_prod; no Night Loading Ticket; no auto Vendor PO",
     "Partial"),
    (13, "Crew Member Daily Workflow",
     "Crew Member Workflow DETAILED",
     "Assignment notification → pre-job checklist → In Route to Site → Arrived at Site (job clock starts) → arrival checklist → work execution → break time logged → completion checklist → Job Complete button → timesheet submitted → supervisor approves → payroll processed",
     "Crew Lead, Crew Members, Supervisor, Payroll",
     "WorkOrder, ServiceAppointment, Timesheet__c (if exists)",
     "WorkOrderFieldManagerMobileSync; FSL mobile app; Rippling absence sync",
     "Partial"),
    (14, "Crew & Equipment Board",
     "Crew and Equipment Board Detailed",
     "Visual board shows crew roster + equipment list + calendar → scheduling team drag-drops WO onto crew → system checks conflicts (double-booking, travel time) → real-time updates as crews clock in/out → capacity planning visible",
     "Scheduling Team, Managers",
     "WorkOrder, ServiceAppointment, ServiceResource (FSL)",
     "FSL Dispatcher Console partially; no custom LWC board",
     "Gap"),
    (15, "Forecasting — Revenue from WOs",
     "Forecasting Process Detailed",
     "All scheduled WOs pulled → revenue calculated by status, work type, client → monthly/quarterly/annual forecast → pipeline quotes weighted by probability → best/realistic/worst scenarios → dashboard published → actual vs. forecast variance → leadership decisions",
     "Finance/Forecasting, Leadership, Sales, Scheduling",
     "WorkOrder, Opportunity, Quote__c, Report, Dashboard",
     "330 reports and 26 dashboards; specific forecasting coverage unconfirmed",
     "Partial"),
    (16, "Forecasting Dashboards (5 Types)",
     "Forecasting Process & Dashboards",
     "5 dashboards: (1) Financial Forecast with monthly revenue chart, gross profit, actual vs. budget; (2) Operational Capacity with crew/equipment utilization gauges; (3) Profitability by work type and client; (4) Pipeline summary with stage probabilities; (5) Execution tracking",
     "Finance, Leadership, Operations",
     "Report, Dashboard",
     "26 dashboards exist; mapping to 5 required types unconfirmed",
     "Partial"),
    (17, "Lawn Care Recurring Service",
     "Lawn Care Details",
     "If PO has Spec Maintenance → Lawn Care WO auto-created → first service 2 weeks after install → recurring schedule per community calendar → seasonal adjustments → each visit: crew arrives, completes, marks complete → invoiced or included in maintenance contract",
     "Scheduling, Lawn Crew, FM",
     "WorkOrder, Builder_PO__c",
     "No lawn care auto-generation flow; Aqua pattern exists but not cloned for lawn",
     "Gap"),
    (18, "Aqua / Irrigation Service",
     "Aqua Work",
     "Temporary irrigation installed on lot → check tickets generated on schedule → field team checks system health → lot closed → pickup ticket created → equipment retrieved → inventory adjusted → permanent irrigation handoff if applicable",
     "Aqua Team, FM",
     "Aqua_Check_Ticket__c, Aqua_Pickup_Ticket__c, Inventory__c",
     "5 Aqua flows all active; most complete process in Salesforce",
     "Live"),
    (19, "Inventory Management",
     "Inventory",
     "Item catalog maintained → materials received → stock levels updated → WO scheduled → inventory check (Available/Assigned/Not-in-Stock) → internal PO for in-stock → vendor PO for out-of-stock → delivery verification → inventory adjusted → backorder if partial",
     "Materials Team, Scheduling, Vendors",
     "Inventory__c, Builder_PO__c, WorkOrder",
     "Material_allocation_prod; LOVING_Aqua_Inventory_Adjustment; no Night Loading or Vendor PO automation",
     "Partial"),
    (20, "Accounting & Invoicing",
     "Accounting Overview",
     "Item catalog maintained in accounting system → WO closeout triggers data push → invoice created with PO quantities and pricing → 3-way match performed → payment terms applied per client → AP: vendor invoices received, matched to PO, payment authorized → GL entries recorded → financial reports generated",
     "Accounting/Finance, FM",
     "WorkOrder, Invoice_Line_Item__c, Builder_PO__c",
     "InvoiceLineTrigger (not in repo); no accounting integration; no 3-way match",
     "Gap"),
]

for i, row in enumerate(PROCESSES):
    vals = list(row)
    alt_row = i % 2 == 1
    cell_row = i + 2
    for col, val in enumerate(vals, 1):
        cell = ws5.cell(row=cell_row, column=col, value=val)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        cell.border = thin_border()
        cell.font = hfont("000000", size=9)
        cell.fill = hfill(C_ALT_BG if alt_row else "FFFFFF")
    # colour Status column (col 8)
    status_v = vals[7]
    c = ws5.cell(row=cell_row, column=8)
    for key, (bg2, fg2) in STATUS_COLOR.items():
        if key.lower() in status_v.lower():
            c.fill = hfill(bg2)
            c.font = hfont(fg2, bold=True, size=9)
            break
    ws5.row_dimensions[cell_row].height = 80

ws5.auto_filter.ref = f"A1:{get_column_letter(len(P_HEADERS))}1"

# ═══════════════════════════════════════════════════════════════════════════
# SHEET 6 — PRIORITY ACTION PLAN
# ═══════════════════════════════════════════════════════════════════════════

ws6 = wb.create_sheet("Action Plan")
ws6.freeze_panes = "A2"
A_HEADERS = ["Priority", "Action Item", "Why It Matters", "Effort", "Owner", "Status"]
A_WIDTHS  = [12, 45, 45, 12, 20, 12]
write_header_row(ws6, A_HEADERS, A_WIDTHS)

ACTIONS = [
    ("Critical", "Retrieve 6 missing Apex triggers to repo (InvoiceLineTrigger, ODLCampaignTrigger, ODLPaymentMilestoneTrigger, ODLQuoteTrigger, ODLQuoteLineItemTrigger, OpportunityNoteNotificationTrigger)",
     "A future deployment will delete all 6 from production; business processes will break silently",
     "30 min", "Megan / Dev", "Open"),
    ("Critical", "Add SMS_Opt_In_Date__c auto-stamp via before-save flow on Contact",
     "Every opted-in contact has a blank Opt-In Date; compliance record is incomplete",
     "2 hrs", "Dev", "Open"),
    ("Critical", "Verify no-reply@upgrademybackyard.com OrgWide Email Address and add if missing",
     "Welcome and Nurture journey emails may be sending from Salesforce default sender; brand risk",
     "1 hr", "Admin", "Open"),
    ("Critical", "Build Night Loading Ticket object and trigger from WO → Scheduled",
     "Entire night loading workflow is manual and outside Salesforce; crew can receive wrong materials",
     "1 week", "Dev", "Open"),
    ("Critical", "Implement accounting upload from Ready to Invoice WOs",
     "Zero automation between Salesforce closeout and invoicing; every invoice is manual re-entry",
     "2 weeks", "Dev + Accounting", "Open"),
    ("High", "Reactivate LOVING_Health_Check_Daily and LOVING_SA_Customer_Notification flows",
     "Daily crew monitoring and customer status notifications are fully disabled",
     "2 hrs", "Admin", "Open"),
    ("High", "Activate LOVING_Delivery_QC_Submit flow",
     "Delivery QC pipeline is broken; variance tracking is incomplete",
     "1 hr", "Admin", "Open"),
    ("High", "Verify LeadEscalationScheduler CronTrigger is active in org",
     "Stale leads may age past 30 days without COO alert",
     "30 min", "Admin", "Open"),
    ("High", "Add Client_Flow_Type__c field to Account and routing logic for MPO/Exact/Custom clients",
     "All builder accounts treated identically; wrong WO creation path used for MPO and Exact clients",
     "1 week", "Dev", "Open"),
    ("High", "Build MPO parent record linking multiple WOs to one MPO number",
     "Lennar and Ryan MPOs have no parent consolidation; MPO status is untraceable",
     "1 week", "Dev", "Open"),
    ("High", "Add WorkOrder record types (Standard, Grading, Hardscape, QI, Site Visit, Customer Care, Lawn Care)",
     "All WOs look identical; no routing, reporting, or scheduling differentiation by type",
     "3 days", "Dev", "Open"),
    ("High", "Add Billed_Quantity__c and Field_Quantity__c to WorkOrder",
     "Invoicing may be using field quantities instead of PO quantities; billing accuracy risk",
     "2 days", "Dev", "Open"),
    ("High", "Build Vendor PO auto-generation on inventory shortage",
     "Out-of-stock situations handled manually; schedule delays not flagged automatically",
     "2 weeks", "Dev", "Open"),
    ("High", "Build Lawn Care WO auto-generation from PO (Spec Maintenance scope)",
     "Recurring lawn care is fully manual; service visits can be missed",
     "1 week", "Dev", "Open"),
    ("Medium", "Add EPO / Subjob Work Order record type and creation flow",
     "Extra scope work at site is untracked; no EPO intake, no Subjob WO linkage",
     "1 week", "Dev", "Open"),
    ("Medium", "Add remaining lead sources to ODL_Source_Record_Type__mdt CMDT",
     "Unmapped sources silently default to Design_Build; Opp record type may be wrong",
     "2 hrs", "Admin", "Open"),
    ("Medium", "Build recurring Lawn Care WO schedule (clone Aqua Check Ticket pattern)",
     "Recurring maintenance visits are not tracked or automated in Salesforce",
     "1 week", "Dev", "Open"),
    ("Medium", "Audit Opportunity auto-response flow duplication (two similar flows may double-send)",
     "All_Opportunity_Auto_Response_Email and Opportunity_Autoresponse_Email may both fire on same event",
     "2 hrs", "Admin", "Open"),
    ("Medium", "Add Payment_Terms__c to Account and reference in invoice generation",
     "Client-specific payment terms not tracked in Salesforce; invoice timing managed manually",
     "1 day", "Dev", "Open"),
    ("Medium", "Build Crew Utilization dashboard from FSL ServiceResource capacity data",
     "No crew utilization % metric exists; capacity planning is ad-hoc",
     "3 days", "Dev", "Open"),
    ("Medium", "Build Actual vs. Forecast variance report (Forecast__c record + Invoice rollup)",
     "No comparison of actual revenue vs. forecast; financial review is manual",
     "1 week", "Dev", "Open"),
    ("Medium", "Build Bid / RFQ workflow for TR's vendor selection process",
     "Entire vendor bidding and selection process is outside Salesforce; no audit trail",
     "3 weeks", "Dev", "Open"),
    ("Medium", "Confirm timesheet capture path via Rippling; build Timesheet__c if not covered",
     "Crew time data may not flow back to Salesforce for job costing",
     "1 week", "Dev + HR", "Open"),
    ("Low", "Build Grading phase sequencing (Rough → Mid → Final Grade WOs with dependency enforcement)",
     "Grading phases can overlap or be skipped; no sequence enforcement",
     "1 week", "Dev", "Open"),
    ("Low", "Add Equipment maintenance scheduling (Next_Maintenance_Date__c + alert flow)",
     "Equipment maintenance is not tracked; breakdowns during jobs are not predictable",
     "3 days", "Dev", "Open"),
    ("Low", "Map 26 existing dashboards against the 5 required forecast dashboard types; build missing",
     "Dashboard coverage against business spec is unverified",
     "1 week", "Admin", "Open"),
    ("Low", "Investigate Experience Cloud portal for customer quote self-service approval",
     "Customers cannot self-service approve quotes; all approvals are manual",
     "4 weeks", "Dev", "Open"),
    ("Low", "Investigate Vendor Suite API for PO auto-intake",
     "All builder POs are entered manually; high data-entry burden on intake team",
     "4 weeks", "Dev + Ops", "Open"),
    ("Low", "Add 3-way match (PO/Receiving/Invoice) validation before payment authorization",
     "Risk of over-payment on partial deliveries; no system check",
     "3 weeks", "Dev + Accounting", "Open"),
]

for i, row in enumerate(ACTIONS):
    vals = list(row)
    alt_row = i % 2 == 1
    cell_row = i + 2
    for col, val in enumerate(vals, 1):
        cell = ws6.cell(row=cell_row, column=col, value=val)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        cell.border = thin_border()
        cell.font = hfont("000000", size=9)
        cell.fill = hfill(C_ALT_BG if alt_row else "FFFFFF")
    # colour priority
    pri_v = vals[0]
    c = ws6.cell(row=cell_row, column=1)
    for key, (bg2, fg2) in PRIORITY_COLOR.items():
        if key.lower() == pri_v.lower():
            c.fill = hfill(bg2)
            c.font = hfont(fg2, bold=True, size=9)
            break
    ws6.row_dimensions[cell_row].height = 56

ws6.auto_filter.ref = f"A1:{get_column_letter(len(A_HEADERS))}1"

# ── Title sheet ─────────────────────────────────────────────────────────────
ws0 = wb.create_sheet("README", 0)
ws0.column_dimensions["A"].width = 80
ws0.row_dimensions[1].height = 40
title = ws0.cell(row=1, column=1,
    value="LOVING COMMAND CENTER — Process & Salesforce Audit")
title.fill = hfill(C_HEADER_BG)
title.font = Font(color=C_HEADER_FG, bold=True, size=16, name="Calibri")
title.alignment = Alignment(horizontal="center", vertical="center")

rows = [
    (3, "Generated: June 2, 2026"),
    (4, "Org: megan.logan@thelovingcompanies.com (loving-prod)"),
    (5, "Source: 19 NXXT process documents + live org audit"),
    (7, "SHEETS IN THIS WORKBOOK:"),
    (8, "  1. README         — This page"),
    (9, "  2. Gap Analysis   — 63 rows: every process area vs. Salesforce; what's missing, what's live, what needs building"),
    (10,"  3. Triggers       — All 22 active Apex triggers; repo coverage status; 6 critical missing from source control"),
    (11,"  4. Flows          — All 50 flows; active/inactive; area tagging"),
    (12,"  5. Key Objects    — 15 key custom objects; fields; automation coverage; gaps"),
    (13,"  6. Process Map    — 20 end-to-end business processes; steps; owner roles; Salesforce coverage status"),
    (14,"  7. Action Plan    — 29 prioritised action items with effort estimates"),
    (16,"PRIORITY KEY:"),
    (17,"  CRITICAL  — Data loss risk or broken compliance; fix immediately"),
    (18,"  HIGH      — Core business process is manual or broken; build next sprint"),
    (19,"  MEDIUM    — Process partially automated; gaps cause manual work"),
    (20,"  LOW       — Nice-to-have; build when bandwidth allows"),
    (22,"STATUS KEY:"),
    (23,"  Live      — Process is fully automated in Salesforce"),
    (24,"  Partial   — Some automation exists; gaps remain"),
    (25,"  Gap       — Process is entirely absent from Salesforce"),
    (26,"  Inactive  — Flow/trigger exists but is deactivated"),
]
for r_num, text in rows:
    cell = ws0.cell(row=r_num, column=1, value=text)
    if r_num in (7, 16, 22):
        cell.font = Font(bold=True, size=11, name="Calibri", color="1F3864")
    else:
        cell.font = Font(size=10, name="Calibri")
    ws0.row_dimensions[r_num].height = 18

# ── Save ────────────────────────────────────────────────────────────────────
out = "/tmp/loving_command_center.xlsx"
wb.save(out)
print(f"Saved: {out}")
