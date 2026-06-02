@IsTest
private class ODLSvcApptCalCtrlTest {
    @IsTest
    static void returnsCalendarData() {
        Account acct = new Account(Name = 'ODL Calendar Test');
        insert acct;

        OperatingHours hours = new OperatingHours(Name = 'ODL Calendar Hours', TimeZone = 'America/New_York');
        insert hours;

        ServiceTerritory territory = new ServiceTerritory(
            Name = 'ODL Calendar Territory',
            OperatingHoursId = hours.Id,
            IsActive = true
        );
        insert territory;

        WorkType consultType = new WorkType(Name = 'Consult Visit', EstimatedDuration = 60, DurationType = 'Minutes');
        WorkType siteType = new WorkType(Name = 'Site Visit', EstimatedDuration = 60, DurationType = 'Minutes');
        WorkType installType = new WorkType(Name = 'Production Install', EstimatedDuration = 120, DurationType = 'Minutes');
        insert new List<WorkType>{ consultType, siteType, installType };

        Id workOrderRtId = Schema.SObjectType.WorkOrder.getRecordTypeInfosByDeveloperName().get('Production_Install').getRecordTypeId();
        WorkOrder wo = new WorkOrder(
            AccountId = acct.Id,
            Subject = 'ODL Calendar WO',
            Status = 'New',
            RecordTypeId = workOrderRtId,
            Work_Order_Type__c = 'Production Install',
            ServiceTerritoryId = territory.Id
        );
        insert wo;

        Datetime baseStart = System.now().addDays(1);
        List<ServiceAppointment> appointments = new List<ServiceAppointment>{
            new ServiceAppointment(
                ParentRecordId = wo.Id,
                Subject = 'Consult stop',
                Status = 'Scheduled',
                WorkTypeId = consultType.Id,
                ServiceTerritoryId = territory.Id,
                EarliestStartTime = baseStart,
                Duration = 60,
                DurationType = 'Minutes',
                SchedStartTime = baseStart,
                SchedEndTime = baseStart.addHours(1)
            ),
            new ServiceAppointment(
                ParentRecordId = wo.Id,
                Subject = 'Site stop',
                Status = 'Scheduled',
                WorkTypeId = siteType.Id,
                ServiceTerritoryId = territory.Id,
                EarliestStartTime = baseStart.addDays(1),
                Duration = 60,
                DurationType = 'Minutes',
                SchedStartTime = baseStart.addDays(1),
                SchedEndTime = baseStart.addDays(1).addHours(1)
            ),
            new ServiceAppointment(
                ParentRecordId = wo.Id,
                Subject = 'Install stop',
                Status = 'Scheduled',
                WorkTypeId = installType.Id,
                ServiceTerritoryId = territory.Id,
                EarliestStartTime = baseStart.addDays(2),
                Duration = 120,
                DurationType = 'Minutes',
                SchedStartTime = baseStart.addDays(2),
                SchedEndTime = baseStart.addDays(2).addHours(2)
            ),
            new ServiceAppointment(
                ParentRecordId = acct.Id,
                Subject = 'General follow-up stop',
                Status = 'Scheduled',
                ServiceTerritoryId = territory.Id,
                EarliestStartTime = baseStart.addDays(3),
                Duration = 30,
                DurationType = 'Minutes',
                SchedStartTime = baseStart.addDays(3),
                SchedEndTime = baseStart.addDays(3).addMinutes(30)
            )
        };
        insert appointments;

        insert new List<Task>{
            new Task(
                WhatId = appointments[0].Id,
                Subject = 'Voicemail follow-up',
                ActivityDate = Date.today().addDays(1),
                Status = 'Open',
                TaskSubtype = 'Call',
                CallDisposition = 'Left Voicemail'
            ),
            new Task(
                WhatId = appointments[1].Id,
                Subject = 'Completed reminder',
                ActivityDate = Date.today().addDays(2),
                Status = 'Completed'
            )
        };

        Test.startTest();
        ODLServiceAppointmentCalendarController.PageData data = ODLServiceAppointmentCalendarController.getPageData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assertEquals(1, data.consultCount);
        System.assertEquals(1, data.siteVisitCount);
        System.assertEquals(1, data.installCount);
        System.assertEquals(1, data.followUpCount);
        System.assertEquals(7, data.calendarDays.size());
        System.assertEquals(4, data.rows.size());
        System.assertNotEquals('No recent activity', data.lastTouch);
        System.assert(data.voicemailStatus.contains('Left'));
        System.assertNotEquals('No open follow-up task', data.nextFollowUp);
        System.assertEquals(1, data.openTasks);
    }
}