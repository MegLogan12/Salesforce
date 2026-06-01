/**
 * LovingWorkOrderPageController
 *
 * Thin @AuraEnabled controller for the Work Order page LWC.
 * Delegates all data assembly to LovingWorkOrderPageService; this class
 * exists solely to expose the AuraEnabled surface and handle null checks
 * before entering the service layer.
 *
 * cacheable=false: the page supports inline mutations (time entries,
 * job health updates, QI completion, etc.) so the Lightning Data Service
 * cache must not serve stale data.
 *
 * @group Work Order Page
 */
public with sharing class LovingWorkOrderPageController {

    /**
     * Returns the full WorkOrderPageDTO for the given Work Order record.
     *
     * @param workOrderId  Id of the Work_Order__c to load. Must not be null.
     * @return             WorkOrderPageDTO populated by LovingWorkOrderPageService.
     * @throws AuraHandledException when workOrderId is null.
     */
    @AuraEnabled(cacheable=false)
    public static WorkOrderPageDTO getWorkOrderPageData(Id workOrderId) {
        if (workOrderId == null) {
            throw new AuraHandledException('workOrderId is required');
        }
        // LovingWorkOrderPageService.build() never throws — all errors are
        // captured in dto.errors, so no try-catch needed here.
        return LovingWorkOrderPageService.build(workOrderId);
    }
}