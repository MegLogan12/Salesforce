/**
 * SiteReadinessController
 * Provides site readiness checklist data for a ServiceAppointment record page.
 * Navigates SA → WorkOrder and evaluates the four readiness gates.
 */
public with sharing class SiteReadinessController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class GateRow {
        @AuraEnabled public String  label;
        @AuraEnabled public Boolean passed;
        @AuraEnabled public String  detail;
    }

    public class SiteReadinessView {
        @AuraEnabled public String       woNumber;
        @AuraEnabled public String       subject;
        @AuraEnabled public Date         siteReadinessDate;
        @AuraEnabled public Date         scheduledDate;
        @AuraEnabled public String       communityName;
        @AuraEnabled public Boolean      allGatesPassed;
        @AuraEnabled public List<GateRow> gates;
    }

    // ─── AuraEnabled entry point ─────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static SiteReadinessView getView(Id serviceAppointmentId) {

        // FLS: verify ServiceAppointment fields
        Schema.DescribeSObjectResult saDescribe =
            Schema.SObjectType.ServiceAppointment;
        if (!saDescribe.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to ServiceAppointment object.');
        }
        Map<String, Schema.SObjectField> saFields =
            Schema.SObjectType.ServiceAppointment.fields.getMap();
        for (String f : new List<String>{ 'Id', 'ParentRecordId' }) {
            if (saFields.containsKey(f)
                    && !saFields.get(f).getDescribe().isAccessible()) {
                throw new AuraHandledException(
                    'Insufficient field access on ServiceAppointment: ' + f);
            }
        }

        List<ServiceAppointment> saList = [
            SELECT Id, ParentRecordId
            FROM   ServiceAppointment
            WHERE  Id = :serviceAppointmentId
            LIMIT  1
        ];
        if (saList.isEmpty()) {
            throw new AuraHandledException(
                'ServiceAppointment not found: ' + serviceAppointmentId);
        }
        ServiceAppointment sa = saList[0];
        if (sa.ParentRecordId == null) {
            throw new AuraHandledException(
                'This Service Appointment is not linked to a Work Order.');
        }

        // FLS: verify WorkOrder fields
        Schema.DescribeSObjectResult woDescribe =
            Schema.SObjectType.WorkOrder;
        if (!woDescribe.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to WorkOrder object.');
        }

        List<WorkOrder> wos = [
            SELECT Id, WorkOrderNumber, Subject, Status,
                   Scheduled_Date__c, Community__r.Name,
                   Site_Readiness_Date__c,
                   Morning_Check_Complete__c,
                   Delivery_QC_Complete__c,
                   Loading_Check_Completed__c,
                   Crew__c, Crew__r.Name
            FROM   WorkOrder
            WHERE  Id = :sa.ParentRecordId
            LIMIT  1
        ];
        if (wos.isEmpty()) {
            throw new AuraHandledException(
                'Linked Work Order not found.');
        }

        return buildView(wos[0]);
    }

    // ─── Testable builder ────────────────────────────────────────────────────

    @TestVisible
    private static SiteReadinessView buildView(WorkOrder wo) {
        SiteReadinessView v = new SiteReadinessView();
        v.woNumber         = wo.WorkOrderNumber;
        v.subject          = wo.Subject;
        v.siteReadinessDate = wo.Site_Readiness_Date__c;
        v.scheduledDate     = wo.Scheduled_Date__c;
        v.communityName     = (wo.Community__r != null)
                                ? wo.Community__r.Name
                                : null;

        v.gates = new List<GateRow>();

        GateRow morning = new GateRow();
        morning.label   = 'Morning Check';
        morning.passed  = wo.Morning_Check_Complete__c == true;
        morning.detail  = morning.passed ? 'Complete' : 'Pending';
        v.gates.add(morning);

        GateRow delivery = new GateRow();
        delivery.label  = 'Delivery QC';
        delivery.passed = wo.Delivery_QC_Complete__c == true;
        delivery.detail = delivery.passed ? 'Complete' : 'Pending';
        v.gates.add(delivery);

        GateRow loading = new GateRow();
        loading.label   = 'Loading Check';
        loading.passed  = wo.Loading_Check_Completed__c == true;
        loading.detail  = loading.passed ? 'Complete' : 'Pending';
        v.gates.add(loading);

        GateRow siteReady = new GateRow();
        siteReady.label  = 'Site Readiness Confirmed';
        siteReady.passed = wo.Site_Readiness_Date__c != null;
        siteReady.detail = siteReady.passed
                            ? String.valueOf(wo.Site_Readiness_Date__c)
                            : 'Not confirmed';
        v.gates.add(siteReady);

        Boolean allPassed = true;
        for (GateRow g : v.gates) {
            if (g.passed != true) { allPassed = false; break; }
        }
        v.allGatesPassed = allPassed;

        return v;
    }
}
