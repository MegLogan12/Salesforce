public with sharing class ODL_TaskController {

    // ── Home Owner account IDs (used to scope all task queries) ───────────────
    private static Set<Id> homeOwnerAccountIds() {
        Set<Id> ids = new Set<Id>();
        for (Account a : [SELECT Id FROM Account WHERE Type = 'Home Owner']) {
            ids.add(a.Id);
        }
        return ids;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTaskDashboard() {
        Date today = Date.today();
        Set<Id> acctIds = homeOwnerAccountIds();

        List<Task> overdueTasks = [
            SELECT Id, Subject, ActivityDate, Status, Type, WhatId, What.Name,
                   OwnerId, Owner.Name, Description
            FROM Task
            WHERE Status != 'Completed' AND ActivityDate < :today
              AND WhatId IN :acctIds
            ORDER BY ActivityDate ASC
            LIMIT 50
        ];

        List<Task> todayTasks = [
            SELECT Id, Subject, ActivityDate, Status, Type, WhatId, What.Name,
                   OwnerId, Owner.Name, Description
            FROM Task
            WHERE Status != 'Completed' AND ActivityDate = :today
              AND WhatId IN :acctIds
            ORDER BY ActivityDate ASC
            LIMIT 50
        ];

        List<Task> upcomingTasks = [
            SELECT Id, Subject, ActivityDate, Status, Type, WhatId, What.Name,
                   OwnerId, Owner.Name, Description
            FROM Task
            WHERE Status != 'Completed' AND ActivityDate > :today
              AND WhatId IN :acctIds
            ORDER BY ActivityDate ASC
            LIMIT 50
        ];

        List<Task> completedTodayTasks = [
            SELECT Id, Subject, ActivityDate, Status, Type, WhatId, What.Name,
                   OwnerId, Owner.Name, Description
            FROM Task
            WHERE Status = 'Completed' AND ActivityDate = :today
              AND WhatId IN :acctIds
            ORDER BY ActivityDate ASC
            LIMIT 50
        ];

        return new Map<String, Object>{
            'overdueTasks'        => overdueTasks,
            'todayTasks'          => todayTasks,
            'upcomingTasks'       => upcomingTasks,
            'completedTodayTasks' => completedTodayTasks,
            'overdueCount'        => overdueTasks.size(),
            'todayCount'          => todayTasks.size(),
            'completedTodayCount' => completedTodayTasks.size()
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Id> getAdjacentTaskIds(Id currentTaskId) {
        Set<Id> acctIds = homeOwnerAccountIds();
        List<Task> allTasks = [
            SELECT Id, ActivityDate
            FROM Task
            WHERE Status != 'Completed'
              AND WhatId IN :acctIds
            ORDER BY ActivityDate ASC, Id ASC
            LIMIT 200
        ];
        Id prevId = null;
        Id nextId = null;
        for (Integer i = 0; i < allTasks.size(); i++) {
            if (allTasks[i].Id == currentTaskId) {
                if (i > 0)                      prevId = allTasks[i - 1].Id;
                if (i < allTasks.size() - 1)    nextId = allTasks[i + 1].Id;
                break;
            }
        }
        return new Map<String, Id>{ 'prevId' => prevId, 'nextId' => nextId };
    }

    @AuraEnabled
    public static Id createTask(String subject, String relatedToId, Date dueDate, String type) {
        Task t = new Task(
            Subject = subject,
            ActivityDate = dueDate,
            Status = 'Not Started',
            Priority = 'Normal',
            Type = type
        );
        if (String.isNotBlank(relatedToId)) {
            t.WhatId = relatedToId;
        }
        insert t;
        return t.Id;
    }
}