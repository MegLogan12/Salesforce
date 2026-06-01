@IsTest(SeeAllData=true)
private class ForemanMobileControllerBridgeTest {
    @IsTest
    static void resolvesAppointmentsThroughBuilderBridge() {
        OperatingHours operatingHours = new OperatingHours(
            Name = 'Foreman Bridge Test Hours',
            TimeZone = 'America/New_York'
        );
        insert operatingHours;

        ServiceTerritory territory = new ServiceTerritory(
            Name = 'Foreman Bridge Territory',
            IsActive = true,
            OperatingHoursId = operatingHours.Id
        );
        insert territory;
        Id productionInstallRtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'WorkOrder'
              AND DeveloperName = 'Production_Install'
            LIMIT 1
        ].Id;

        Account builderMarket = new Account(Name = 'Foreman Bridge Market');
        insert builderMarket;

        Community__c community = new Community__c(
            Name = 'Foreman Bridge Community',
            Builder_Account__c = builderMarket.Id,
            ServiceTerritory__c = territory.Id
        );
        insert community;

        Lot__c lot = new Lot__c(
            Name = 'Foreman Bridge Lot 001',
            Community__c = community.Id,
            Lot_Number__c = '001',
            Lot_Status__c = 'Open'
        );
        insert lot;

        String poNumber = 'PO-FM-BRIDGE-' + String.valueOf(System.now().getTime());
        Builder_PO__c builderPo = new Builder_PO__c(
            PO_Number__c = poNumber,
            Builder_Account__c = builderMarket.Id,
            Division_Account__c = builderMarket.Id,
            Community__c = community.Id,
            Lot__c = lot.Id,
            Builder_Name__c = 'Lennar'
        );
        insert builderPo;

        Work_Order__c customParent = new Work_Order__c(
            Status__c = 'Scheduled',
            Community__c = community.Id,
            Lot__c = lot.Id,
            FM_Assignment__c = UserInfo.getUserId(),
            Work_Order_Type__c = 'Production Install',
            Scheduled_Date__c = Date.today(),
            Schedule_Locked__c = true,
            Builder_PO__c = builderPo.Id
        );
        insert customParent;

        WorkOrder standardParent = new WorkOrder(
            Subject = 'Bridge Parent WorkOrder',
            Status = 'Ready to Schedule',
            RecordTypeId = productionInstallRtId,
            Work_Order_Type__c = 'Production Install',
            ServiceTerritoryId = territory.Id,
            Sod_Square_Footage__c = 100
        );
        insert standardParent;

        insert new Purchase_Order__c(
            PO_Number__c = poNumber,
            Builder_Account__c = builderMarket.Id,
            Division_Account__c = builderMarket.Id,
            Community__c = community.Id,
            Lot__c = lot.Id,
            Quantity__c = 100,
            Total_Amount__c = 2500,
            Status__c = 'Pending CS Review',
            Work_Order__c = standardParent.Id
        );

        WorkOrder childExecution = new WorkOrder(
            Subject = 'Bridge Child Install',
            Status = 'Ready to Schedule',
            RecordTypeId = productionInstallRtId,
            ParentWorkOrderId = standardParent.Id,
            Work_Order_Type__c = 'Production Install',
            ServiceTerritoryId = territory.Id,
            Sod_Square_Footage__c = 100
        );
        insert childExecution;

        Datetime start = System.now().addHours(2);
        ServiceAppointment appointment = new ServiceAppointment(
            ParentRecordId = childExecution.Id,
            Subject = 'Bridge Install Stop',
            Status = 'Ready to Schedule',
            ServiceTerritoryId = territory.Id,
            EarliestStartTime = start,
            Duration = 120,
            DurationType = 'Minutes',
            SchedStartTime = start,
            SchedEndTime = start.addHours(2)
        );
        insert appointment;
        appointment = [
            SELECT Id, AppointmentNumber, Status
            FROM ServiceAppointment
            WHERE Id = :appointment.Id
        ];

        Test.startTest();
        ForemanMobileController.JobDto job = ForemanMobileController.getJob(customParent.Id);
        ForemanMobileController.MobileContextDto context = ForemanMobileController.getMobileContext(customParent.Id);
        Test.stopTest();

        System.assertEquals(appointment.AppointmentNumber, job.appointmentNumber);
        System.assertEquals('Ready to Schedule', job.appointmentStatus);
        Boolean apptFound = false;
        for (ForemanMobileController.ScheduleCardDto card : context.schedule) {
            if (card.serviceAppointmentId == appointment.Id) {
                apptFound = true;
                System.assertEquals(appointment.AppointmentNumber, card.serviceAppointmentNumber);
                System.assertEquals('Ready to Schedule', card.serviceAppointmentStatus);
                break;
            }
        }
        System.assert(apptFound, 'The foreman schedule should contain the bridge appointment.');
    }
}