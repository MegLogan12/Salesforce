@IsTest
private class TakeoffWorkOrderServiceTest {

    @IsTest
    static void testCreatesTradeWorkOrders() {
        Takeoff__c tk = new Takeoff__c(Scheduled_Date__c = Date.today().addDays(10));
        insert tk;
        insert new List<Takeoff_Line__c>{
            new Takeoff_Line__c(Takeoff__c = tk.Id, Item_Name__c = 'Sod Pallet', Measured_Qty__c = 100, Unit_Price__c = 2),
            new Takeoff_Line__c(Takeoff__c = tk.Id, Item_Name__c = 'Mulch', Measured_Qty__c = 10, Unit_Price__c = 30)
        };

        Test.startTest();
        TakeoffWorkOrderService.createFromTakeoff(new List<Id>{ tk.Id });
        Test.stopTest();

        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Subject LIKE :('%Takeoff ' + tk.Id + '%')];
        System.assert(!wos.isEmpty(), 'At least one trade Work Order should be created');
        Set<Id> woIds = new Map<Id, WorkOrder>(wos).keySet();
        Integer woli = [SELECT COUNT() FROM WorkOrderLineItem WHERE WorkOrderId IN :woIds];
        System.assertEquals(2, woli, 'A line item per takeoff line');
    }

    @IsTest
    static void testInvocableAndEmptySafe() {
        Test.startTest();
        TakeoffWorkOrderService.createFromTakeoff(new List<Id>());
        TakeoffWorkOrderService.createFromTakeoffInvocable(new List<Id>());
        Test.stopTest();
        System.assert(true, 'Empty input is handled safely');
    }
}