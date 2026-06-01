@IsTest
private class QIInspectionTriggerTest {

    @TestSetup
    static void bypassTriggers() {
        try {
            Extentia_SIM__MapPlotterTriggerSettings__c s =
                Extentia_SIM__MapPlotterTriggerSettings__c.getOrgDefaults();
            s.Extentia_SIM__Bypass_Trigger__c = true;
            upsert s;
        } catch (Exception e) {
            // Bypass setting not relevant in this org context; ignore.
        }
    }

    @IsTest
    static void insertAndUpdateFiresTriggerWithoutErrors() {
        Test.startTest();

        QI_Inspection__c qi = new QI_Inspection__c(
            Score_Overall__c = 80
        );
        insert qi;

        qi.Submitted__c = true;
        qi.Score_Overall__c = 85;
        update qi;

        Test.stopTest();

        QI_Inspection__c reloaded = [SELECT Id, Score_Overall__c, Submitted__c FROM QI_Inspection__c WHERE Id = :qi.Id];
        System.assertEquals(85, reloaded.Score_Overall__c, 'Update should persist');
        System.assertEquals(true, reloaded.Submitted__c, 'Submit checkbox should persist');
    }
}
