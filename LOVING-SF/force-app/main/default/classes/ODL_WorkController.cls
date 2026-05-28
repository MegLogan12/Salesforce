public with sharing class ODL_WorkController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWorkOrderRecord(Id workOrderId) {
        WorkOrder wo = [
            SELECT Id, WorkOrderNumber, AccountId, Account.Name, Status,
                   Division__c, Job_Type__c, Customer_Visible_Status__c,
                   Homeowner_Property__c, Homeowner_Property__r.Name,
                   ODL_Opportunity__c, ODL_Opportunity__r.Name,
                   StartDate, EndDate, OwnerId, Owner.Name,
                   Description, Subject
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        List<WorkOrderLineItem> lineItems = [
            SELECT Id, Subject, Status, Duration, DurationType,
                   OwnerId, Owner.Name, EndDate
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :workOrderId
            LIMIT 20
        ];

        List<ServiceAppointment> appointments = [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime
            FROM ServiceAppointment
            WHERE ParentRecordId = :workOrderId
            ORDER BY SchedStartTime ASC NULLS LAST
            LIMIT 5
        ];

        return new Map<String, Object>{
            'workOrder'    => wo,
            'lineItems'    => lineItems,
            'appointments' => appointments
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<WorkOrder> getWorkOrderList() {
        return [
            SELECT Id, WorkOrderNumber, AccountId, Account.Name, Status,
                   Division__c, Job_Type__c, StartDate, EndDate, OwnerId, Owner.Name
            FROM WorkOrder
            WHERE Status NOT IN ('Closed', 'Canceled')
            ORDER BY StartDate ASC NULLS LAST
            LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ServiceAppointment> getServiceCalendar() {
        Date startDate = Date.today().toStartOfWeek();
        Date endDate = startDate.addDays(13);
        return [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime,
                   Subject, ServiceTerritoryId, ParentRecordId, ParentRecordType,
                   OwnerId, Owner.Name
            FROM ServiceAppointment
            WHERE SchedStartTime >= :DateTime.newInstance(startDate, Time.newInstance(0,0,0,0))
              AND SchedStartTime <= :DateTime.newInstance(endDate, Time.newInstance(23,59,59,0))
            ORDER BY SchedStartTime ASC
            LIMIT 100
        ];
    }
}
