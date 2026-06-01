/**
 * ODLWorkOrderController
 *
 * Controller for the Outdoor Living Work Order Field Execution page (Spec page 14).
 * Built on the STANDARD Salesforce WorkOrder + FSL objects.
 *
 * Gate fields added to WorkOrder this session:
 *   QI_Complete__c, QI_Held__c, QI_Score__c
 *   Takeoff_Photo_Count__c, Closeout_Photo_Count__c
 *   Crew_Completed__c, Field_Complete_Date__c, Loading_Check_Completed__c
 *
 * Pre-existing standard WorkOrder fields used:
 *   Crew__c (Lookup → Crew__c custom object, Crew__r.Name)
 *   Field_Manager__c (Lookup → User)
 *   ODL_Opportunity__c (pre-existing Opportunity lookup — canonical for OL WOs)
 *   Lot_Address__c (Text 255 — pre-existing formatted site address)
 *   ServiceTerritoryId (Lookup → ServiceTerritory)
 *   StartDate / EndDate (Datetime), Duration (Number)
 *
 * Flagged gaps:
 *   - Customer signoff: no signoff datetime field exists — gate is informational only.
 *   - Progress photo count: no dedicated count field — shown as "Ongoing".
 */
public with sharing class ODLWorkOrderController {

    private static final Integer TAKEOFF_MIN  = 1;
    private static final Integer CLOSEOUT_MIN = 4;

    private static final Map<String, String> STATUS_TO_STAGE = new Map<String, String>{
        'New'             => 'Setup',
        'In Progress'     => 'In Progress',
        'On Hold'         => 'Closeout',
        'Cannot Complete' => 'Closeout',
        'Completed'       => 'Closed',
        'Cancelled'       => 'Closed'
    };

    private static final Set<String> TERMINAL_STATUSES = new Set<String>{
        'Completed', 'Cancelled'
    };

    @AuraEnabled(cacheable=true)
    public static WorkOrderView getWorkOrder(Id recordId) {
        if (!Schema.sObjectType.WorkOrder.isAccessible()) {
            throw new AuraHandledException('You do not have access to view this information.');
        }

        WorkOrder wo = queryWorkOrder(recordId);
        if (wo == null) {
            throw new AuraHandledException('This work order could not be found or you do not have access to it.');
        }

        return buildView(wo, buildScope(recordId));
    }

    @TestVisible
    private static WorkOrderView buildView(WorkOrder wo, List<ScopeLine> scope) {
        WorkOrderView v = new WorkOrderView();
        v.header      = buildHeader(wo);
        v.stepper     = buildStepper(wo.Status);
        v.gates       = buildGates(wo);
        v.photos      = buildPhotos(wo);
        v.scope       = scope;
        v.schedule    = buildSchedule(wo);
        v.customer    = buildCustomer(wo);
        v.nextAction  = buildNextAction(wo, v.gates);

        v.readyToComplete = true;
        v.blocker = null;
        for (Gate g : v.gates) {
            if (g.required && !g.passed) {
                v.readyToComplete = false;
                if (v.blocker == null) v.blocker = g.blockerReason;
            }
        }
        return v;
    }

    /**
     * Marks the work order field-complete. Server-side re-checks EVERY required gate so
     * completion can never bypass a gate regardless of what the client sends (Spec §5/§10).
     */
    @AuraEnabled
    public static WorkOrderView completeJob(Id recordId) {
        if (!Schema.sObjectType.WorkOrder.isUpdateable()) {
            throw new AuraHandledException('Work order edit access is missing.');
        }
        WorkOrderView v = getWorkOrder(recordId);
        if (!v.readyToComplete) {
            throw new AuraHandledException(
                'Blocked until install, closeout photos, and QI are complete: ' + v.blocker
            );
        }
        WorkOrder wo = new WorkOrder(Id = recordId);
        if (Schema.sObjectType.WorkOrder.fields.Field_Complete_Date__c.isUpdateable()) {
            wo.Field_Complete_Date__c = System.now();
        }
        if (Schema.sObjectType.WorkOrder.fields.Crew_Completed__c.isUpdateable()) {
            wo.Crew_Completed__c = true;
        }
        update wo;
        return getWorkOrder(recordId);
    }

    // ---- query helpers -------------------------------------------------------

    private static WorkOrder queryWorkOrder(Id recordId) {
        List<WorkOrder> rows = [
            SELECT Id, WorkOrderNumber, Subject, Status,
                   AccountId, Account.Name,
                   ContactId, Contact.Name, Contact.Phone,
                   Lot_Address__c,
                   ServiceTerritoryId, ServiceTerritory.Name,
                   StartDate, EndDate, Duration,
                   Crew__c, Crew__r.Name,
                   ODL_Opportunity__c, ODL_Opportunity__r.Name,
                   QI_Complete__c, QI_Held__c, QI_Score__c,
                   Takeoff_Photo_Count__c, Closeout_Photo_Count__c,
                   Crew_Completed__c, Field_Complete_Date__c,
                   Loading_Check_Completed__c
            FROM WorkOrder
            WHERE Id = :recordId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static List<ScopeLine> buildScope(Id recordId) {
        List<ScopeLine> lines = new List<ScopeLine>();
        for (WorkOrderLineItem woli : [
            SELECT Id, LineItemNumber, Status, Subject, Description
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :recordId
            ORDER BY LineItemNumber
            LIMIT 200
        ]) {
            ScopeLine l = new ScopeLine();
            l.name   = String.isNotBlank(woli.Subject) ? woli.Subject : woli.LineItemNumber;
            l.detail = woli.Description;
            l.status = woli.Status;
            lines.add(l);
        }
        return lines;
    }

    // ---- builders -----------------------------------------------------------

    private static Header buildHeader(WorkOrder wo) {
        Header h = new Header();
        h.workOrderName      = String.isNotBlank(wo.Subject) ? wo.Subject : wo.WorkOrderNumber;
        h.status             = wo.Status;
        h.pipelineStage      = STATUS_TO_STAGE.get(wo.Status);
        h.territory          = wo.ServiceTerritory != null ? wo.ServiceTerritory.Name : null;
        h.builderName        = wo.Account != null ? wo.Account.Name : null;
        h.scheduledStart     = wo.StartDate;
        h.scheduledEnd       = wo.EndDate;
        h.crew               = wo.Crew__r != null ? wo.Crew__r.Name : null;
        h.qiStatus           = qiLabel(wo);
        h.closeoutPhotoCount = intOf(wo.Closeout_Photo_Count__c);
        h.closeoutPhotoMin   = CLOSEOUT_MIN;
        return h;
    }

    private static List<Step> buildStepper(String status) {
        String currentStage = STATUS_TO_STAGE.get(status);
        List<String> stages = new List<String>{ 'Setup', 'Scheduled', 'In Progress', 'Closeout', 'Closed' };
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
        if (currentStage == null) {
            for (Step s : steps) { s.state = 'upcoming'; }
        }
        return steps;
    }

    private static List<Gate> buildGates(WorkOrder wo) {
        List<Gate> gates = new List<Gate>();
        String crewName = wo.Crew__r != null ? wo.Crew__r.Name : null;

        gates.add(gate('Crew assigned', String.isNotBlank(crewName),
            true, String.isNotBlank(crewName) ? crewName : 'No crew assigned',
            'A crew must be assigned before proceeding.'));

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

        Gate signoff = gate('Customer signoff', false, false, 'Field not confirmed', null);
        signoff.flag = 'Requires a customer-signoff field on WorkOrder (e.g. Customer_Signoff_DateTime__c).';
        gates.add(signoff);

        return gates;
    }

    private static Photos buildPhotos(WorkOrder wo) {
        Photos p = new Photos();
        p.takeoffCount   = intOf(wo.Takeoff_Photo_Count__c);
        p.takeoffMin     = TAKEOFF_MIN;
        p.takeoffStatus  = p.takeoffCount >= TAKEOFF_MIN ? 'Met' : 'Pending';
        p.progressCount  = null;
        p.progressStatus = 'Ongoing';
        p.closeoutCount  = intOf(wo.Closeout_Photo_Count__c);
        p.closeoutMin    = CLOSEOUT_MIN;
        p.closeoutStatus = p.closeoutCount >= CLOSEOUT_MIN ? 'Met' : 'Pending';
        return p;
    }

    private static Schedule buildSchedule(WorkOrder wo) {
        Schedule s = new Schedule();
        s.start           = wo.StartDate;
        s.finish          = wo.EndDate;
        s.scheduledDate   = wo.StartDate != null ? wo.StartDate.date() : null;
        s.durationMinutes = wo.Duration;
        s.territory       = wo.ServiceTerritory != null ? wo.ServiceTerritory.Name : null;
        s.crew            = wo.Crew__r != null ? wo.Crew__r.Name : null;
        s.proposalStatus  = null; // FSL scheduling status lives on ServiceAppointment, not WorkOrder
        return s;
    }

    private static Customer buildCustomer(WorkOrder wo) {
        Customer c = new Customer();
        if (wo.Contact != null) {
            c.contactName = wo.Contact.Name;
            c.phone       = wo.Contact.Phone;
        }
        c.siteAddress     = wo.Lot_Address__c;
        c.lotNumber       = null;
        c.builderName     = wo.Account != null ? wo.Account.Name : null;
        c.opportunityName = wo.ODL_Opportunity__r != null ? wo.ODL_Opportunity__r.Name : null;
        return c;
    }

    private static NextAction buildNextAction(WorkOrder wo, List<Gate> gates) {
        Map<String, Gate> byName = new Map<String, Gate>();
        for (Gate g : gates) { byName.put(g.label, g); }
        Boolean installDone = byName.get('Install complete').passed;
        Boolean closeoutMet = byName.get('Closeout photos').passed;
        Boolean qiPass      = byName.get('QI inspection').passed;
        Boolean isTerminal  = TERMINAL_STATUSES.contains(wo.Status);

        NextAction na = new NextAction();
        if (isTerminal) {
            na.text = 'Job closed'; na.button = null;
        } else if (qiPass) {
            na.text = 'Close work order'; na.button = 'Close';
        } else if (installDone && closeoutMet) {
            na.text = 'Run QI inspection'; na.button = 'Start QI';
        } else if (installDone) {
            na.text = 'Capture closeout photos'; na.button = 'Field app';
        } else if (wo.Field_Complete_Date__c == null && wo.Status == 'In Progress') {
            na.text = 'Continue install'; na.button = 'Open field app';
        } else if (wo.StartDate != null) {
            na.text = 'Dispatch crew'; na.button = 'Dispatch';
        } else {
            na.text = 'Schedule the appointment'; na.button = 'Schedule';
        }
        return na;
    }

    // ---- helpers ------------------------------------------------------------

    private static String qiLabel(WorkOrder wo) {
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
        g.label         = label;
        g.passed        = passed;
        g.required      = required;
        g.detail        = detail;
        g.blockerReason = blockerReason;
        return g;
    }

    // ---- DTOs ---------------------------------------------------------------

    public class WorkOrderView {
        @AuraEnabled public Header         header;
        @AuraEnabled public List<Step>     stepper;
        @AuraEnabled public List<Gate>     gates;
        @AuraEnabled public Photos         photos;
        @AuraEnabled public List<ScopeLine> scope;
        @AuraEnabled public Schedule       schedule;
        @AuraEnabled public Customer       customer;
        @AuraEnabled public NextAction     nextAction;
        @AuraEnabled public Boolean        readyToComplete;
        @AuraEnabled public String         blocker;
    }

    public class Header {
        @AuraEnabled public String   workOrderName;
        @AuraEnabled public String   status;
        @AuraEnabled public String   pipelineStage;
        @AuraEnabled public String   territory;
        @AuraEnabled public String   builderName;
        @AuraEnabled public Datetime scheduledStart;
        @AuraEnabled public Datetime scheduledEnd;
        @AuraEnabled public String   crew;
        @AuraEnabled public String   qiStatus;
        @AuraEnabled public Integer  closeoutPhotoCount;
        @AuraEnabled public Integer  closeoutPhotoMin;
    }

    public class Step {
        @AuraEnabled public String label;
        @AuraEnabled public String state; // done | current | upcoming
    }

    public class Gate {
        @AuraEnabled public String  label;
        @AuraEnabled public Boolean passed;
        @AuraEnabled public Boolean required;
        @AuraEnabled public String  detail;
        @AuraEnabled public String  blockerReason;
        @AuraEnabled public String  flag; // non-null when a source field is missing/unconfirmed
    }

    public class Photos {
        @AuraEnabled public Integer takeoffCount;
        @AuraEnabled public Integer takeoffMin;
        @AuraEnabled public String  takeoffStatus;
        @AuraEnabled public Integer progressCount;
        @AuraEnabled public String  progressStatus;
        @AuraEnabled public Integer closeoutCount;
        @AuraEnabled public Integer closeoutMin;
        @AuraEnabled public String  closeoutStatus;
    }

    public class ScopeLine {
        @AuraEnabled public String name;
        @AuraEnabled public String detail;
        @AuraEnabled public String status;
    }

    public class Schedule {
        @AuraEnabled public Datetime start;
        @AuraEnabled public Datetime finish;
        @AuraEnabled public Date     scheduledDate;
        @AuraEnabled public Decimal  durationMinutes;
        @AuraEnabled public String   territory;
        @AuraEnabled public String   crew;
        @AuraEnabled public String   proposalStatus;
    }

    public class Customer {
        @AuraEnabled public String contactName;
        @AuraEnabled public String phone;
        @AuraEnabled public String siteAddress;
        @AuraEnabled public String lotNumber;
        @AuraEnabled public String builderName;
        @AuraEnabled public String opportunityName;
    }

    public class NextAction {
        @AuraEnabled public String text;
        @AuraEnabled public String button;
    }
}
