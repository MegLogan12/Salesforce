@isTest
private class OpportunityNoteNotificationHandlerTest {

    private static User createUser(String prefix, String lastName) {
        String uniquePart = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        String usernameValue = prefix + '.' + uniquePart + '@example.com';
        String nicknameValue = prefix + uniquePart;

        if (nicknameValue.length() > 40) {
            nicknameValue = nicknameValue.substring(0, 40);
        }

        User u = new User(
            FirstName = 'Test',
            LastName = lastName,
            Alias = prefix.length() > 8 ? prefix.substring(0, 8) : prefix,
            Email = usernameValue,
            Username = usernameValue,
            CommunityNickname = nicknameValue,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/New_York',
            ProfileId = UserInfo.getProfileId()
        );
        insert u;
        return u;
    }

    @isTest
    static void testOpportunityOwnerGetsEmailWhenNoteAdded() {
        User ownerUser = createUser('ownerA', 'Owner');
        User noteUser = createUser('noteA', 'NoteCreator');

        Account acct = new Account(Name = 'Test Account A');
        insert acct;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity A',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acct.Id,
            OwnerId = ownerUser.Id
        );
        insert opp;

        Test.startTest();
        System.runAs(noteUser) {
            ContentNote note = new ContentNote(
                Title = 'Test Note A',
                Content = Blob.valueOf('This is a test note.')
            );
            insert note;

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = note.Id,
                LinkedEntityId = opp.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
        }
        Test.stopTest();

        System.assertEquals(
            1,
            OpportunityNoteNotificationHandler.lastEmailsPrepared,
            'Expected the handler to prepare one email when a different user adds a note.'
        );
    }

    @isTest
    static void testNoEmailWhenOwnerAddsOwnNote() {
        User ownerUser = createUser('ownerB', 'SelfOwner');

        Account acct = new Account(Name = 'Test Account B');
        insert acct;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity B',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acct.Id,
            OwnerId = ownerUser.Id
        );
        insert opp;

        Test.startTest();
        System.runAs(ownerUser) {
            ContentNote note = new ContentNote(
                Title = 'Owner Note B',
                Content = Blob.valueOf('Owner created this note.')
            );
            insert note;

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = note.Id,
                LinkedEntityId = opp.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
        }
        Test.stopTest();

        System.assertEquals(
            0,
            OpportunityNoteNotificationHandler.lastEmailsPrepared,
            'Expected zero emails when the opportunity owner adds their own note.'
        );
    }
}