@IsTest(SeeAllData=true)
private class CCCloseoutAssignerTest {

    private static Group getCloseoutQueue() {
        return [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName = 'Customer_Care_Closeout'
            LIMIT 1
        ];
    }

    @IsTest
    static void assignsToLowestLoadMember() {
        Group q = getCloseoutQueue();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId());
        }

        List<Work_Order__c> news = new List<Work_Order__c>();
        for (Integer i = 0; i < 3; i++) {
            news.add(new Work_Order__c(Work_Order_Type__c = 'Customer Care', Sub_Status__c = 'Triage'));
        }

        Test.startTest();
        CCCloseoutAssigner.assignNew(news);
        Test.stopTest();

        for (Work_Order__c wo : news) {
            System.assertEquals(UserInfo.getUserId(), wo.OwnerId, 'Owner should be assigned to the only queue member');
        }
    }

    @IsTest
    static void skipsWhenNotCustomerCare() {
        Work_Order__c wo = new Work_Order__c(Work_Order_Type__c = 'Install');
        List<Work_Order__c> input = new List<Work_Order__c>{ wo };

        CCCloseoutAssigner.assignNew(input);

        System.assertEquals(null, wo.OwnerId, 'Install WO should not be touched');
    }

    @IsTest
    static void emptyInputIsNoOp() {
        CCCloseoutAssigner.assignNew(null);
        CCCloseoutAssigner.assignNew(new List<Work_Order__c>());
        CCCloseoutAssigner.assignOnPendingCloseout(null);
        CCCloseoutAssigner.assignOnPendingCloseout(new List<Work_Order__c>());
    }

    @IsTest
    static void assignOnPendingCloseout_reassignsToQueueMember() {
        Group q = getCloseoutQueue();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId());
        }

        insert new Work_Order__c(
            Work_Order_Type__c = 'Customer Care',
            Sub_Status__c = 'Triage',
            OwnerId = UserInfo.getUserId()
        );

        Work_Order__c target = new Work_Order__c(
            Work_Order_Type__c = 'Customer Care',
            Sub_Status__c = 'Pending Closeout'
        );
        insert target;

        Test.startTest();
        CCCloseoutAssigner.assignOnPendingCloseout(new List<Work_Order__c>{ target });
        Test.stopTest();

        Work_Order__c refreshed = [SELECT OwnerId FROM Work_Order__c WHERE Id = :target.Id];
        System.assertEquals(UserInfo.getUserId(), refreshed.OwnerId, 'Pending closeout WO should be assigned to the queue member');
    }

    @IsTest
    static void assignNew_withoutUserMembersFallsBackToQueue() {
        Group q = getCloseoutQueue();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            delete [SELECT Id FROM GroupMember WHERE GroupId = :q.Id];
        }

        List<Work_Order__c> news = new List<Work_Order__c>{
            new Work_Order__c(Work_Order_Type__c = 'Customer Care', Sub_Status__c = 'Triage')
        };

        CCCloseoutAssigner.assignNew(news);

        System.assertEquals(q.Id, news[0].OwnerId, 'Queue should own new customer care work order when no user members exist.');
    }

    @IsTest
    static void assignOnPendingCloseout_withoutUserMembersAssignsQueue() {
        Group q = getCloseoutQueue();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            delete [SELECT Id FROM GroupMember WHERE GroupId = :q.Id];
        }

        Work_Order__c target = new Work_Order__c(
            Work_Order_Type__c = 'Customer Care',
            Sub_Status__c = 'Pending Closeout'
        );
        insert target;

        Test.startTest();
        CCCloseoutAssigner.assignOnPendingCloseout(new List<Work_Order__c>{ target });
        Test.stopTest();

        Work_Order__c refreshed = [SELECT OwnerId FROM Work_Order__c WHERE Id = :target.Id];
        System.assertEquals(q.Id, refreshed.OwnerId, 'Pending closeout WO should fall back to queue ownership when no user members exist.');
    }
}