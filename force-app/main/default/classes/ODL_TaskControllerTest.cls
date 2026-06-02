@isTest
private class ODL_TaskControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'ODL Task Test Account', Type = 'Home Owner');
        insert acc;

        List<Task> tasks = new List<Task>{
            new Task(Subject='Overdue Task', WhatId=acc.Id,
                     ActivityDate=Date.today().addDays(-2), Status='Not Started'),
            new Task(Subject='Today Task', WhatId=acc.Id,
                     ActivityDate=Date.today(), Status='Not Started'),
            new Task(Subject='Upcoming Task', WhatId=acc.Id,
                     ActivityDate=Date.today().addDays(3), Status='Not Started')
        };
        insert tasks;
    }

    @isTest
    static void testGetTaskDashboard() {
        Test.startTest();
        Map<String, Object> result = ODL_TaskController.getTaskDashboard();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('overdueTasks'));
        System.assert(result.containsKey('todayTasks'));
        System.assert(result.containsKey('upcomingTasks'));
        System.assert(result.containsKey('overdueCount'));
        System.assert(result.containsKey('todayCount'));
    }

    @isTest
    static void testGetAdjacentTaskIds() {
        List<Task> tasks = [SELECT Id FROM Task WHERE Subject IN ('Overdue Task','Today Task','Upcoming Task') ORDER BY ActivityDate ASC];
        System.assertEquals(3, tasks.size());
        Test.startTest();
        Map<String, Id> adj = ODL_TaskController.getAdjacentTaskIds(tasks[1].Id);
        Test.stopTest();
        System.assertNotEquals(null, adj);
        System.assertEquals(tasks[0].Id, adj.get('prevId'));
        System.assertEquals(tasks[2].Id, adj.get('nextId'));
    }

    @isTest
    static void testCreateTask_withRelatedTo() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'ODL Task Test Account' LIMIT 1];
        Test.startTest();
        Id taskId = ODL_TaskController.createTask(
            'New Follow Up', acc.Id, Date.today().addDays(1), 'Call'
        );
        Test.stopTest();
        System.assertNotEquals(null, taskId);
        Task t = [SELECT WhatId FROM Task WHERE Id = :taskId LIMIT 1];
        System.assertEquals(acc.Id, t.WhatId);
    }

    @isTest
    static void testCreateTask_withoutRelatedTo() {
        Test.startTest();
        Id taskId = ODL_TaskController.createTask('Standalone Task', null, Date.today(), 'Email');
        Test.stopTest();
        System.assertNotEquals(null, taskId);
    }
}