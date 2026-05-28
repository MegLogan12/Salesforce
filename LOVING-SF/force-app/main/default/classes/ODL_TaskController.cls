public with sharing class ODL_TaskController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTaskDashboard() {
        Date today = Date.today();

        List<Task> overdueTasks = [
            SELECT Id, Subject, ActivityDate, Status, WhatId, What.Name,
                   OwnerId, Owner.Name, Description
            FROM Task
            WHERE Status != 'Completed' AND ActivityDate < :today
            ORDER BY ActivityDate ASC
            LIMIT 50
        ];

        List<Task> todayTasks = [
            SELECT Id, Subject, ActivityDate, Status, WhatId, What.Name,
                   OwnerId, Owner.Name, Description
            FROM Task
            WHERE Status != 'Completed' AND ActivityDate = :today
            ORDER BY ActivityDate ASC
            LIMIT 50
        ];

        List<Task> upcomingTasks = [
            SELECT Id, Subject, ActivityDate, Status, WhatId, What.Name,
                   OwnerId, Owner.Name, Description
            FROM Task
            WHERE Status != 'Completed' AND ActivityDate > :today
            ORDER BY ActivityDate ASC
            LIMIT 50
        ];

        return new Map<String, Object>{
            'overdueTasks'  => overdueTasks,
            'todayTasks'    => todayTasks,
            'upcomingTasks' => upcomingTasks,
            'overdueCount'  => overdueTasks.size(),
            'todayCount'    => todayTasks.size()
        };
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
