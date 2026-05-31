public with sharing class PurchaseOrderPipelineBucketScheduler implements Schedulable {
    public static final Integer BATCH_LIMIT = 5000;

    public void execute(SchedulableContext context) {
        runBatch();
    }

    public static void runBatch() {
        List<Purchase_Order__c> purchaseOrders = [
            SELECT Id,
                   Status__c,
                   Pipeline_Stage__c,
                   Requested_Install_Date__c,
                   Estimated_Start_Date__c,
                   Takeoff_Status__c,
                   Package_BMG_Status__c,
                   Work_Order__c
            FROM Purchase_Order__c
            WHERE Status__c NOT IN ('Cancelled', 'Closed')
              AND Division_Account__c != null
            LIMIT :BATCH_LIMIT
        ];

        List<Purchase_Order__c> updates =
            PurchaseOrderTimingService.recalculatePurchaseOrders(purchaseOrders);

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}