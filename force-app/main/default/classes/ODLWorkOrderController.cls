/**
 * Controller for the Outdoor Living Work Order Field Execution page (Spec page 14).
 *
 * Built on the CUSTOM Work_Order__c object — NOT the standard FSL WorkOrder — per the
 * org-reality override in the build prompt. All values are bound to live fields; nothing
 * here is hardwired. Where a source is not confirmed in the org, the DTO carries a flag
 * and the LWC renders the spec's empty-state copy rather than fabricating a value.
 *
 * Confirmed sources (audited):
 *   Site/customer .. Lot__r.Street_Address__c/City__c/State__c, Construction_Manager__r (Contact)
 *   Scope ......... child Work_Order__c via Parent_Work_Order__c
 *   Photos ........ Takeoff_Photo_Count__c, Closeout_Photo_Count__c (maintained on the WO;
 *                   Photo__c has no Work_Order__c lookup, so counts are the canonical source)
 *   QI ............ QI_Complete__c, QI_Held__c, QI_Score__c
 *   Crew .......... Crew__c (Text)
 *   Schedule ...... Scheduled_Start/End_DateTime__c, Territory__c, Calculated_Duration_Minutes__c
 *   Open/closed ... WO_Status_Mapping__mdt (finance-editable; Is_Terminal__c / Display_Stage__c)
 *
 * Flagged gaps (blank truth over a filled-in lie, Spec §9/§12):
 *   - No Opportunity lookup on Work_Order__c -> Source Opportunity card is empty.
 *   - No dedicated customer-signoff field -> signoff gate is informational, not blocking.
 *   - No confirmed materials object -> Materials panel is empty.
 *   - Division__c is geographic, not OL/Design Build -> page is not division-scoped here.
 */
public with sharing class ODLWorkOrderController {

    private static final Integer TAKEOFF_MIN  = 1;
    private static final Integer CLOSEOUT_MIN = 4;

    @AuraEnabled(cacheable=true)
    public static WorkOrderView getWorkOrder(Id recordId) {
        if (!Schema.sObjectType.Work_Order__c.isAccessible()) {
            throw new AuraHandledException('You do not have access to view this information.');
        }

        Work_Order__c wo = queryWorkOrder(recordId);
        if (wo == null) {
            throw new AuraHandledException('This work order could not be found or you do not have access to it.');
        }

        WorkOrderView v = new WorkOrderView();
        v.header   = buildHeader(wo);
        v.stepper  = buildStepper(wo);
        v.gates    = buildGates(wo);
        v.photos   = buildPhotos(wo);
        v.scope    = buildScope(recordId);
        v.schedule = buildSchedule(wo);
        v.customer = buildCustomer(wo);
        v.nextAction = buildNextAction(wo, v.gates);

        // Readiness: ready only when every REQUIRED gate passes.
        v.readyToComplete = true;
        v.blocker = null;
        for (Gate g : v.gates) {
            if (g.required && !g.passed) {
                v.readyToComplete = false;
                if (v.blocker == null) {
                    v.blocker = g.blockerReason;
                }
            }
        }
        return v;
    }

    /**
     * Marks the work order field-complete. Server-side re-checks EVERY required gate so
     * completion can never bypass a gate, regardless of what the client sends (Spec §5/§10).
     * Does not force a terminal/closed status — that remains a separate, approval-gated step.
     */
    @AuraEnabled
    public static WorkOrderView completeJob(Id recordId) {
        if (!Schema.sObjectType.Work_Order__c.isUpdateable()) {
            throw new AuraHandledException('Work order edit access is missing.');
        }
        WorkOrderView v = getWorkOrder(recordId);
        if (!v.readyToComplete) {
            throw new AuraHandledException(
                'Blocked until install, closeout photos, and QI are complete: ' + v.blocker
            );
        }
        Work_Order__c wo = new Work_Order__c(Id = recordId);
        if (Schema.sObjectType.Work_Order__c.fields.Field_Complete_Date__c.isUpdateable()) {
            wo.Field_Complete_Date__c = System.now();
        }
        if (Schema.sObjectType.Work_Order__c.fields.Crew_Completed__c.isUpdateable()) {
            wo.Crew_Completed__c = true;
        }
        update wo;
        return getWorkOrder(recordId);
    }

    private static Work_Order__c queryWorkOrder(Id recordId) {
        List<Work_Order__c> rows = [
            SELECT Id, Name, Status__c, Pipeline_Stage__c, Division__c, Territory__c,
                   Crew__c, Crew_Completed__c, Loading_Check_Completed__c,
                   Takeoff_Photo_Count__c, Closeout_Photo_Count__c,
                   Field_Complete_Date__c,
                   QI_Complete__c, QI_Held__c, QI_Score__c,
                   Scheduled_Start_DateTime__c, Scheduled_End_DateTime__c,
                   Scheduled_Date__c, Calculated_Duration_Minutes__c,
                   Schedule_Proposal_Status__c,
                   Builder_Market_Account__r.Name,
                   Construction_Manager__r.Name, Construction_Manager__r.Phone,
                   Lot__r.Street_Address__c, Lot__r.City__c, Lot__r.State__c, Lot__r.Lot_Number__c
            FROM Work_Order__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Header buildHeader(Work_Order__c wo) {
        Header h = new Header();
        h.workOrderName = wo.Name;
        h.status = wo.Status__c;
        h.pipelineStage = wo.Pipeline_Stage__c;
        h.territory = wo.Territory__c;
        h.builderName = wo.Builder_Market_Account__r != null ? wo.Builder_Market_Account__r.Name : null;
        h.scheduledStart = wo.Scheduled_Start_DateTime__c;
        h.scheduledEnd = wo.Scheduled_End_DateTime__c;
        h.crew = wo.Crew__c;
        h.qiStatus = qiLabel(wo);
        h.closeoutPhotoCount = intOf(wo.Closeout_Photo_Count__c);
        h.closeoutPhotoMin = CLOSEOUT_MIN;
        return h;
    }

    /**
     * Lifecycle stepper. Display_Stage__c from WO_Status_Mapping__mdt drives the current step;
     * unmapped statuses fall back to "Open" so the stepper never invents a stage.
     */
    private static List<Step> buildStepper(Work_Order__c wo) {
        Map<String, WO_Status_Mapping__mdt> statusMap = mappingByStatus();
        String currentStage = null;
        if (wo.Status__c != null && statusMap.containsKey(wo.Status__c)) {
            currentStage = statusMap.get(wo.Status__c).Display_Stage__c;
        }
        List<String> stages = new List<String>{
            'Setup', 'Scheduled', 'In Progress', 'Closeout', 'Closed'
        };
        List<Step> steps = new List<Step>();
        Boolean passedCurrent = false;
        for (String stage : stages) {
            Step s = new Step();
            s.label = stage;
            if (currentStage != null && stage == currentStage) {
                s.state = 'current';
                passedCurrent = true;
            } else if (!passedCurrent) {
                s.state = 'done';
            } else {
                s.state = 'upcoming';
            }
            steps.add(s);
        }
        // If the status was unmapped, no step is marked current; show all as upcoming.
        if (currentStage == null) {
            for (Step s : steps) { s.state = 'upcoming'; }
        }
        return steps;
    }

    private static List<Gate> buildGates(Work_Order__c wo) {
        List<Gate> gates = new List<Gate>();

        gates.add(gate('Crew assigned', String.isNotBlank(wo.Crew__c),
            true, wo.Crew__c, 'No crew is assigned.'));

        gates.add(gate('Materials loaded', wo.Loading_Check_Completed__c == true,
            true, wo.Loading_Check_Completed__c == true ? 'Loaded or staged' : 'Not loaded',
            'Materials are not loaded or staged.'));

        Integer takeoff = intOf(wo.Takeoff_Photo_Count__c);
        gates.add(gate('Takeoff photos', takeoff >= TAKEOFF_MIN,
            true, takeoff + ' of ' + TAKEOFF_MIN + ' required',
            'At least ' + TAKEOFF_MIN + ' takeoff photo is required.'));

        Boolean installDone = wo.Crew_Completed__c == true || wo.Field_Complete_Date__c != null;
        gates.add(gate('Install complete', installDone,
            true, installDone ? 'Field complete' : 'In progress',
            'Install must be finished.'));

        Integer closeout = intOf(wo.Closeout_Photo_Count__c);
        gates.add(gate('Closeout photos', closeout >= CLOSEOUT_MIN,
            true, closeout + ' of ' + CLOSEOUT_MIN + ' required',
            CLOSEOUT_MIN + ' closeout photos are required.'));

        Boolean qiPass = wo.QI_Complete__c == true && wo.QI_Held__c != true;
        gates.add(gate('QI inspection', qiPass,
            true, qiLabel(wo), 'QI inspection must be recorded and passing.'));

        // Customer signoff: no dedicated homeowner-signoff field exists. Render as informational
        // (NOT required, NOT auto-passed) and flag the missing field rather than fake the gate.
        Gate signoff = gate('Customer signoff', false, false, 'Field not confirmed', null);
        signoff.flag = 'Requires a customer-signoff field. Recommend Customer_Signoff_DateTime__c on Work_Order__c.';
        gates.add(signoff);

        return gates;
    }

    private static Photos buildPhotos(Work_Order__c wo) {
        Photos p = new Photos();
        p.takeoffCount = intOf(wo.Takeoff_Photo_Count__c);
        p.takeoffMin = TAKEOFF_MIN;
        p.takeoffStatus = p.takeoffCount >= TAKEOFF_MIN ? 'Met' : 'Pending';

        // No progress-photo count field is confirmed; show as ongoing without inventing a number.
        p.progressCount = null;
        p.progressStatus = 'Ongoing';

        p.closeoutCount = intOf(wo.Closeout_Photo_Count__c);
        p.closeoutMin = CLOSEOUT_MIN;
        p.closeoutStatus = p.closeoutCount >= CLOSEOUT_MIN ? 'Met' : 'Pending';
        return p;
    }

    private static List<ScopeLine> buildScope(Id recordId) {
        List<ScopeLine> lines = new List<ScopeLine>();
        for (Work_Order__c child : [
            SELECT Id, Name, Status__c, Pipeline_Stage__c, Repair_Scope__c
            FROM Work_Order__c
            WHERE Parent_Work_Order__c = :recordId
            WITH SECURITY_ENFORCED
            ORDER BY Name
            LIMIT 200
        ]) {
            ScopeLine l = new ScopeLine();
            l.name = child.Name;
            l.detail = child.Repair_Scope__c;
            l.status = child.Status__c;
            lines.add(l);
        }
        return lines;
    }

    private static Schedule buildSchedule(Work_Order__c wo) {
        Schedule s = new Schedule();
        s.start = wo.Scheduled_Start_DateTime__c;
        s.finish = wo.Scheduled_End_DateTime__c;
        s.scheduledDate = wo.Scheduled_Date__c;
        s.durationMinutes = wo.Calculated_Duration_Minutes__c;
        s.territory = wo.Territory__c;
        s.crew = wo.Crew__c;
        s.proposalStatus = wo.Schedule_Proposal_Status__c;
        return s;
    }

    private static Customer buildCustomer(Work_Order__c wo) {
        Customer c = new Customer();
        if (wo.Construction_Manager__r != null) {
            c.contactName = wo.Construction_Manager__r.Name;
            c.phone = wo.Construction_Manager__r.Phone;
        }
        if (wo.Lot__r != null) {
            List<String> parts = new List<String>();
            if (String.isNotBlank(wo.Lot__r.Street_Address__c)) parts.add(wo.Lot__r.Street_Address__c);
            if (String.isNotBlank(wo.Lot__r.City__c)) parts.add(wo.Lot__r.City__c);
            if (String.isNotBlank(wo.Lot__r.State__c)) parts.add(wo.Lot__r.State__c);
            c.siteAddress = parts.isEmpty() ? null : String.join(parts, ', ');
            c.lotNumber = wo.Lot__r.Lot_Number__c;
        }
        c.builderName = wo.Builder_Market_Account__r != null ? wo.Builder_Market_Account__r.Name : null;
        return c;
    }

    /** Rule engine, first match wins (Spec §9). */
    private static NextAction buildNextAction(Work_Order__c wo, List<Gate> gates) {
        Map<String, Gate> byName = new Map<String, Gate>();
        for (Gate g : gates) { byName.put(g.label, g); }
        Boolean installDone   = byName.get('Install complete').passed;
        Boolean closeoutMet   = byName.get('Closeout photos').passed;
        Boolean qiPass        = byName.get('QI inspection').passed;
        Boolean isTerminal    = isTerminalStatus(wo.Status__c);

        NextAction na = new NextAction();
        if (isTerminal) {
            na.text = 'Job closed'; na.button = null;
        } else if (qiPass) {
            na.text = 'Close work order'; na.button = 'Close';
        } else if (installDone && closeoutMet) {
            na.text = 'Run QI inspection'; na.button = 'Start QI';
        } else if (installDone) {
            na.text = 'Capture closeout photos'; na.button = 'Field app';
        } else if (wo.Field_Complete_Date__c == null && isInProgress(wo)) {
            na.text = 'Continue install'; na.button = 'Open field app';
        } else if (wo.Scheduled_Start_DateTime__c != null) {
            na.text = 'Dispatch crew'; na.button = 'Dispatch';
        } else {
            na.text = 'Schedule the appointment'; na.button = 'Schedule';
        }
        return na;
    }

    // ---- helpers -----------------------------------------------------------

    private static Boolean isInProgress(Work_Order__c wo) {
        return wo.Status__c == 'In Progress'
            || (wo.Scheduled_Start_DateTime__c != null && wo.Scheduled_Start_DateTime__c <= System.now());
    }

    private static String qiLabel(Work_Order__c wo) {
        if (wo.QI_Held__c == true) return 'On hold';
        if (wo.QI_Complete__c == true) {
            return wo.QI_Score__c != null ? 'Passed (' + wo.QI_Score__c + ')' : 'Passed';
        }
        return 'Not started';
    }

    private static Integer intOf(Decimal d) {
        return d == null ? 0 : d.intValue();
    }

    private static Gate gate(String label, Boolean passed, Boolean required, String detail, String blockerReason) {
        Gate g = new Gate();
        g.label = label;
        g.passed = passed;
        g.required = required;
        g.detail = detail;
        g.blockerReason = blockerReason;
        return g;
    }

    private static Map<String, WO_Status_Mapping__mdt> mappingByStatus() {
        Map<String, WO_Status_Mapping__mdt> byStatus = new Map<String, WO_Status_Mapping__mdt>();
        for (WO_Status_Mapping__mdt m : WO_Status_Mapping__mdt.getAll().values()) {
            if (String.isNotBlank(m.Status_Label__c)) {
                byStatus.put(m.Status_Label__c, m);
            }
        }
        return byStatus;
    }

    private static Boolean isTerminalStatus(String status) {
        if (status == null) return false;
        Map<String, WO_Status_Mapping__mdt> statusMap = mappingByStatus();
        return statusMap.containsKey(status) && statusMap.get(status).Is_Terminal__c == true;
    }

    // ---- DTOs --------------------------------------------------------------

    public class WorkOrderView {
        @AuraEnabled public Header header;
        @AuraEnabled public List<Step> stepper;
        @AuraEnabled public List<Gate> gates;
        @AuraEnabled public Photos photos;
        @AuraEnabled public List<ScopeLine> scope;
        @AuraEnabled public Schedule schedule;
        @AuraEnabled public Customer customer;
        @AuraEnabled public NextAction nextAction;
        @AuraEnabled public Boolean readyToComplete;
        @AuraEnabled public String blocker;
    }

    public class Header {
        @AuraEnabled public String workOrderName;
        @AuraEnabled public String status;
        @AuraEnabled public String pipelineStage;
        @AuraEnabled public String territory;
        @AuraEnabled public String builderName;
        @AuraEnabled public Datetime scheduledStart;
        @AuraEnabled public Datetime scheduledEnd;
        @AuraEnabled public String crew;
        @AuraEnabled public String qiStatus;
        @AuraEnabled public Integer closeoutPhotoCount;
        @AuraEnabled public Integer closeoutPhotoMin;
    }

    public class Step {
        @AuraEnabled public String label;
        @AuraEnabled public String state; // done | current | upcoming
    }

    public class Gate {
        @AuraEnabled public String label;
        @AuraEnabled public Boolean passed;
        @AuraEnabled public Boolean required;
        @AuraEnabled public String detail;
        @AuraEnabled public String blockerReason;
        @AuraEnabled public String flag; // non-null when a source field is missing/unconfirmed
    }

    public class Photos {
        @AuraEnabled public Integer takeoffCount;
        @AuraEnabled public Integer takeoffMin;
        @AuraEnabled public String takeoffStatus;
        @AuraEnabled public Integer progressCount;
        @AuraEnabled public String progressStatus;
        @AuraEnabled public Integer closeoutCount;
        @AuraEnabled public Integer closeoutMin;
        @AuraEnabled public String closeoutStatus;
    }

    public class ScopeLine {
        @AuraEnabled public String name;
        @AuraEnabled public String detail;
        @AuraEnabled public String status;
    }

    public class Schedule {
        @AuraEnabled public Datetime start;
        @AuraEnabled public Datetime finish;
        @AuraEnabled public Date scheduledDate;
        @AuraEnabled public Decimal durationMinutes;
        @AuraEnabled public String territory;
        @AuraEnabled public String crew;
        @AuraEnabled public String proposalStatus;
    }

    public class Customer {
        @AuraEnabled public String contactName;
        @AuraEnabled public String phone;
        @AuraEnabled public String siteAddress;
        @AuraEnabled public String lotNumber;
        @AuraEnabled public String builderName;
    }

    public class NextAction {
        @AuraEnabled public String text;
        @AuraEnabled public String button;
    }
}
