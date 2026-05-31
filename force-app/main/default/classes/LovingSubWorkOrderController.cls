/**
 * LovingSubWorkOrderController
 *
 * Apex controller for the lovingSubWorkOrderPage LWC.
 * Routes to type-specific service (FJ / Warranty / Customer Care) and
 * returns a SubWorkOrderPageDTO.
 *
 * @group Work Order Page
 */
public with sharing class LovingSubWorkOrderController {

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static SubWorkOrderPageDTO getSubWorkOrderPageData(Id workOrderId) {
        if (workOrderId == null) {
            throw new AuraHandledException('workOrderId is required');
        }

        Work_Order__c wo = queryWorkOrder(workOrderId);

        if (wo == null) {
            throw new AuraHandledException('Work Order not found: ' + workOrderId);
        }

        String woType = wo.Work_Order_Type__c;

        if (woType == 'Finished Job' || wo.Is_Finished_Job__c == true) {
            return LovingFinishedJobService.buildPageData(wo);
        } else if (woType == 'Warranty') {
            return LovingWarrantyService.buildPageData(wo);
        } else if (woType == 'Customer Care' || woType == 'Site Visit') {
            return LovingCustomerCareWorkOrderService.buildPageData(wo);
        }

        // Fallback: return empty FJ DTO with warning
        SubWorkOrderPageDTO fallback = new SubWorkOrderPageDTO();
        fallback.warnings = new List<SubWorkOrderPageDTO.WarningDTO>();
        SubWorkOrderPageDTO.WarningDTO w = new SubWorkOrderPageDTO.WarningDTO();
        w.key      = 'UNSUPPORTED_TYPE';
        w.message  = 'Work Order type "' + woType + '" is not a supported sub-work-order type.';
        w.severity = 'error';
        fallback.warnings.add(w);
        return fallback;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SOQL
    // ─────────────────────────────────────────────────────────────────────────

    private static Work_Order__c queryWorkOrder(Id workOrderId) {
        List<Work_Order__c> results = [
            SELECT
                Id, Name, Work_Order_Type__c, Status__c, Pipeline_Stage__c, Sub_Status__c,
                Job_Health__c, Billable_Type__c, Repair_Scope__c, Notes__c, Closeout_Notes__c,
                Schedule_Locked__c, Scheduled_Date__c,
                Field_Manager__c, Crew__c, Stop_Sequence__c, Foreman__c,
                Parent_Work_Order__c, Parent_Account__c, Community__c, Lot__c,
                Construction_Manager__c, Territory__c,
                Source__c, Request_Received_Date__c,
                Is_Finished_Job__c, Is_Warranty__c,
                FJ_Reason_Code__c, FJ_Reason_Detail__c,
                FJ_Created_By_FM__c, FJ_Original_Foreman__c,
                FJ_Created_By_FM__r.Name,
                FJ_Original_Foreman__r.Name,
                Warranty_Coverage_Status__c, Warranty_Coverage_Type__c,
                Warranty_Start_Date__c, Warranty_End_Date__c,
                Warranty_Voided_Reason__c, Warranty_Determination__c,
                EPO_Status__c, EPO_Sent_Date__c, EPO_Received_Date__c,
                EPO_Days_Outstanding__c, EPO_SLA_Tier__c, EPO_SLA_Breach__c,
                /* Relationship traversal */
                Field_Manager__r.Name,
                Foreman__r.Name,
                Construction_Manager__r.Name,
                Community__r.Name,
                Lot__r.Name,
                /* Parent WO summary (1-level deep only) */
                Parent_Work_Order__r.Id,
                Parent_Work_Order__r.Name,
                Parent_Work_Order__r.Status__c,
                Parent_Work_Order__r.Scheduled_Date__c,
                Parent_Work_Order__r.Field_Manager__r.Name,
                Parent_Work_Order__r.Community__r.Name,
                Parent_Work_Order__r.Lot__r.Name
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }
}