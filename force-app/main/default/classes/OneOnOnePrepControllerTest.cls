@IsTest
private class OneOnOnePrepControllerTest {

    @IsTest
    static void getPrepViewWithNullReturnsEmpty() {
        OneOnOnePrepController.PrepView v = OneOnOnePrepController.getPrepView(null);
        System.assertNotEquals(null, v);
        System.assertEquals(0, v.openActionItems.size());
        System.assertEquals(0, v.suggestedTopics.size());
    }

    @IsTest
    static void getPrepViewWithRealRecordReturnsData() {
        User u1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        OneOnOne__c o = new OneOnOne__c(
            Manager__c = u1.Id,
            Direct_Report__c = u1.Id,
            Meeting_Date__c = DateTime.now(),
            Cadence__c = 'Weekly',
            Status__c = 'Scheduled'
        );
        insert o;

        Test.startTest();
        OneOnOnePrepController.PrepView v = OneOnOnePrepController.getPrepView(o.Id);
        Test.stopTest();
        System.assertNotEquals(null, v);
        System.assertNotEquals(null, v.suggestedTopics);
    }

    @IsTest
    static void createActionItemReturnsId() {
        User u1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        OneOnOne__c o = new OneOnOne__c(
            Manager__c = u1.Id,
            Direct_Report__c = u1.Id,
            Meeting_Date__c = DateTime.now(),
            Cadence__c = 'Weekly',
            Status__c = 'Scheduled'
        );
        insert o;

        Test.startTest();
        Id aiId = OneOnOnePrepController.createActionItem(o.Id, u1.Id, 'Test action', null);
        Test.stopTest();
        System.assertNotEquals(null, aiId);
    }

    @IsTest
    static void createActionItemWithExplicitDueDate() {
        User u1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        OneOnOne__c o = new OneOnOne__c(
            Manager__c = u1.Id,
            Direct_Report__c = u1.Id,
            Meeting_Date__c = DateTime.now(),
            Cadence__c = 'Weekly',
            Status__c = 'Scheduled'
        );
        insert o;

        Date due = Date.today().addDays(14);
        Test.startTest();
        Id aiId = OneOnOnePrepController.createActionItem(o.Id, u1.Id, 'Test', due);
        Test.stopTest();
        Action_Item__c ai = [SELECT Due_Date__c FROM Action_Item__c WHERE Id = :aiId];
        System.assertEquals(due, ai.Due_Date__c);
    }

    @IsTest
    static void saveNotesUpdatesRecord() {
        User u1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        OneOnOne__c o = new OneOnOne__c(
            Manager__c = u1.Id,
            Direct_Report__c = u1.Id,
            Meeting_Date__c = DateTime.now(),
            Cadence__c = 'Weekly',
            Status__c = 'Scheduled'
        );
        insert o;

        Test.startTest();
        OneOnOnePrepController.saveNotes(o.Id, 'Test notes');
        Test.stopTest();

        OneOnOne__c updated = [SELECT Topics_Discussed__c FROM OneOnOne__c WHERE Id = :o.Id];
        System.assertEquals('Test notes', updated.Topics_Discussed__c);
    }

    @IsTest
    static void markActionItemDoneSetsStatus() {
        User u1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        OneOnOne__c o = new OneOnOne__c(
            Manager__c = u1.Id,
            Direct_Report__c = u1.Id,
            Meeting_Date__c = DateTime.now(),
            Cadence__c = 'Weekly',
            Status__c = 'Scheduled'
        );
        insert o;

        Action_Item__c ai = new Action_Item__c(
            OneOnOne__c = o.Id,
            Owner_User__c = u1.Id,
            Description__c = 'Test',
            Due_Date__c = Date.today().addDays(7),
            Status__c = 'Open'
        );
        insert ai;

        Test.startTest();
        OneOnOnePrepController.markActionItemDone(ai.Id);
        Test.stopTest();

        Action_Item__c updated = [SELECT Status__c, Completed_Date__c FROM Action_Item__c WHERE Id = :ai.Id];
        System.assertEquals('Done', updated.Status__c);
        System.assertEquals(Date.today(), updated.Completed_Date__c);
    }
}