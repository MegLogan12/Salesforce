/**
 * CooCommandCenterController
 * Provides executive-level operational data for the COO Command Center
 * (Screen 27): active WO counts by division, exception list, and open gates.
 *
 * Notes:
 *  - onTimePct and gpPct are placeholders (0 / null). They require the
 *    COO KPI batch and On_Time_Pct__c / GP_Pct__c fields on Account.
 *  - Open gates are hardcoded business gates known at build time.
 *  - Builder_PO__c is queried for held-PO exceptions; if the object or
 *    fields are inaccessible in the running user's profile the exception
 *    row gracefully reports 0.
 */
public with sharing class CooCommandCenterController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class DivisionKpi {
        @AuraEnabled public String  division;
        @AuraEnabled public Integer activeWOs;
        @AuraEnabled public Integer completedThisMonth;
        @AuraEnabled public Decimal onTimePct;    // placeholder — COO KPI batch gate
        @AuraEnabled public Decimal gpPct;         // placeholder — COO KPI batch gate
        @AuraEnabled public String  health;        // "good" | "watch" | "alert"
    }

    public class ExceptionRow {
        @AuraEnabled public String  description;
        @AuraEnabled public String  severity;  // "amber" | "red" | "green"
        @AuraEnabled public Integer count;
    }

    public class OpenGate {
        @AuraEnabled public String gate;
        @AuraEnabled public String owner;
        @AuraEnabled public String action;
        @AuraEnabled public String impact;
    }

    public class CooView {
        @AuraEnabled public Integer            totalActiveWOs;
        @AuraEnabled public Integer            totalOpenGates;
        @AuraEnabled public List<DivisionKpi>  divisions;
        @AuraEnabled public List<ExceptionRow> exceptions;
        @AuraEnabled public List<OpenGate>     gates;
    }

    // ─── Hardcoded open gates (known business gates) ─────────────────────────

    private static final List<OpenGate> OPEN_GATES = buildOpenGates();

    private static List<OpenGate> buildOpenGates() {
        List<OpenGate> gates = new List<OpenGate>();

        OpenGate g5 = new OpenGate();
        g5.gate   = 'G5 · Accounting Export';
        g5.owner  = 'Finance / Meg';
        g5.action = 'Resolve G5 to enable direct export from Invoice Console';
        g5.impact = 'Blocks automated G5 accounting export';
        gates.add(g5);

        OpenGate g6 = new OpenGate();
        g6.gate   = 'G6 · FM Assignment';
        g6.owner  = 'Ops / Division VP';
        g6.action = 'Field_Manager__c FLS must be granted to enable FM column';
        g6.impact = 'FM name hidden on WO views due to FLS restriction';
        gates.add(g6);

        OpenGate kpiBatch = new OpenGate();
        kpiBatch.gate   = 'COO KPI Batch';
        kpiBatch.owner  = 'Dev / Megan';
        kpiBatch.action = 'Build Revenue_MTD__c, On_Time_Pct__c, GP_Pct__c on Account';
        kpiBatch.impact = 'On-time % and GP % blocked on Division KPI panel';
        gates.add(kpiBatch);

        return gates;
    }

    // ─── AuraEnabled entry point ─────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static CooView getDashboard() {

        // FLS: WorkOrder
        Schema.DescribeSObjectResult woDesc = Schema.SObjectType.WorkOrder;
        if (!woDesc.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to WorkOrder object.');
        }

        // Active WOs (all open statuses)
        List<WorkOrder> activeWOs = [
            SELECT Id, Division__c, Status
            FROM   WorkOrder
            WHERE  Status IN ('New','Ready to Schedule','Scheduled','In Progress')
        ];

        // Pending closeout: Completed but Invoice_Amount__c not set
        List<WorkOrder> pendingCloseout = [
            SELECT Id, Division__c
            FROM   WorkOrder
            WHERE  Status = 'Completed'
            AND    Invoice_Amount__c = null
        ];

        // Held POs: query Builder_PO__c if object is accessible
        List<Builder_PO__c> heldPOs = new List<Builder_PO__c>();
        if (Schema.SObjectType.Builder_PO__c.isAccessible()) {
            heldPOs = [
                SELECT Id
                FROM   Builder_PO__c
                WHERE  Price_Check_Result__c != 'Pass'
                OR     NFI_Count__c > 0
                LIMIT  500
            ];
        }

        return buildDashboard(activeWOs, heldPOs, pendingCloseout);
    }

    // ─── Testable builder ─────────────────────────────────────────────────────

    @TestVisible
    private static CooView buildDashboard(
            List<WorkOrder>     activeWOs,
            List<Builder_PO__c> heldPOs,
            List<WorkOrder>     pendingCloseout) {

        CooView v           = new CooView();
        v.totalActiveWOs    = activeWOs.size();
        v.gates             = OPEN_GATES;
        v.totalOpenGates    = OPEN_GATES.size();

        // ── Division KPIs: group active WOs by Division__c ───────────────────
        Map<String, Integer> activeByDiv = new Map<String, Integer>();
        for (WorkOrder wo : activeWOs) {
            String div = String.isNotBlank(wo.Division__c) ? wo.Division__c : '(None)';
            Integer cur = activeByDiv.containsKey(div) ? activeByDiv.get(div) : 0;
            activeByDiv.put(div, cur + 1);
        }

        v.divisions = new List<DivisionKpi>();
        for (String div : activeByDiv.keySet()) {
            DivisionKpi kpi       = new DivisionKpi();
            kpi.division          = div;
            kpi.activeWOs         = activeByDiv.get(div);
            kpi.completedThisMonth = 0; // populated separately if needed
            kpi.onTimePct         = null; // blocked — COO KPI batch required
            kpi.gpPct             = null; // blocked — COO KPI batch required
            // Health: alert if > 20 active, watch if > 10, else good
            kpi.health = (kpi.activeWOs > 20) ? 'alert'
                       : (kpi.activeWOs > 10)  ? 'watch'
                       :                         'good';
            v.divisions.add(kpi);
        }

        // ── Exceptions ───────────────────────────────────────────────────────
        v.exceptions = new List<ExceptionRow>();

        ExceptionRow heldPoRow = new ExceptionRow();
        heldPoRow.description = 'Held POs (price check failed or NFI items)';
        heldPoRow.severity    = 'red';
        heldPoRow.count       = heldPOs.size();
        v.exceptions.add(heldPoRow);

        ExceptionRow closeoutRow = new ExceptionRow();
        closeoutRow.description = 'Closeout pending (Completed — invoice not set)';
        closeoutRow.severity    = 'amber';
        closeoutRow.count       = pendingCloseout.size();
        v.exceptions.add(closeoutRow);

        ExceptionRow activeRow = new ExceptionRow();
        activeRow.description = 'Total active work orders';
        activeRow.severity    = (activeWOs.size() > 50) ? 'amber' : 'green';
        activeRow.count       = activeWOs.size();
        v.exceptions.add(activeRow);

        return v;
    }
}
