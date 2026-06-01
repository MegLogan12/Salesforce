@IsTest
private class AquaWateringScheduleResolverTest {

    private static Opportunity newCommunity(String name) {
        Account a = new Account(Name = name + ' Builder');
        insert a;
        Opportunity o = new Opportunity(
            Name = name,
            AccountId = a.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert o;
        return o;
    }

    @IsTest
    static void emptyInputsReturnEmpty() {
        System.assertEquals('', AquaWateringScheduleResolver.resolve(null, null, Date.today()));
    }

    @IsTest
    static void noScheduleRowsReturnsDefault() {
        Opportunity c = newCommunity('Resolver Test Community');

        Test.startTest();
        String s = AquaWateringScheduleResolver.resolve(c.Id, null, Date.today());
        Test.stopTest();

        System.assertNotEquals('', s);
        System.assert(s.contains('water') || s.contains('Week'), 'Expect default text mentioning water/Week, got: ' + s);
    }

    @IsTest
    static void seasonalMonthlyMatch() {
        Opportunity c = newCommunity('Resolver Seasonal Community');

        Date target = Date.newInstance(2026, 7, 15);
        Aqua_Watering_Schedule__c sched = new Aqua_Watering_Schedule__c(
            Community__c       = c.Id,
            Schedule_Type__c   = 'Seasonal Monthly',
            Month__c           = 'July',
            Run_Frequency__c   = 'Daily',
            Run_Duration_Min__c = 25,
            Run_Time_Pct__c    = 80
        );
        insert sched;

        Test.startTest();
        String s = AquaWateringScheduleResolver.resolve(c.Id, null, target);
        Test.stopTest();

        System.assert(s.contains('July'), 'Expected July in output: ' + s);
        System.assert(s.contains('Daily'), 'Expected Daily: ' + s);
        System.assert(s.contains('25'), 'Expected duration 25: ' + s);
        System.assert(s.contains('80'), 'Expected pct 80: ' + s);
    }

    @IsTest
    static void rampWeekMatch() {
        Opportunity c = newCommunity('Resolver Ramp Community');

        Date installDate = Date.today().addDays(-10);
        Date serviceDate = Date.today();
        Aqua_Watering_Schedule__c sched = new Aqua_Watering_Schedule__c(
            Community__c       = c.Id,
            Schedule_Type__c   = 'New Install Ramp',
            Week_Number__c     = 2,
            Run_Frequency__c   = '3x Per Week',
            Run_Duration_Min__c = 20
        );
        insert sched;

        Test.startTest();
        String s = AquaWateringScheduleResolver.resolveWithInstallDate(c.Id, installDate, serviceDate);
        Test.stopTest();

        System.assert(s.contains('Ramp Week 2'), 'Expected Ramp Week 2 in output: ' + s);
        System.assert(s.contains('20'), 'Expected duration 20 in output: ' + s);
    }
}