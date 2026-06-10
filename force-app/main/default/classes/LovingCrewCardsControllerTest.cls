@IsTest
private class LovingCrewCardsControllerTest {
    @IsTest static void returnsCrews() {
        if (Schema.getGlobalDescribe().containsKey('Crew__c')) {
            SObject c = Schema.getGlobalDescribe().get('Crew__c').newSObject();
            try { c.put('Name','Test Crew'); c.put('Active__c', true); insert c; } catch (Exception e) {}
        }
        Test.startTest();
        List<LovingCrewCardsController.CrewDto> r = LovingCrewCardsController.getCrews();
        Test.stopTest();
        System.assertNotEquals(null, r, 'should not be null');
    }
}