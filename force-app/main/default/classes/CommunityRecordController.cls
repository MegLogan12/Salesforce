public with sharing class CommunityRecordController {

    // ── Shared page data ────────────────────────────────────────────────────

    public class PageDataDTO {
        @AuraEnabled public Community__c community;
        @AuraEnabled public List<WorkOrderSummaryDTO> openWorkOrders;
        @AuraEnabled public Integer openWorkOrderCount;
        @AuraEnabled public List<TaskSummaryDTO> recentActivity;
        @AuraEnabled public List<ChangeOrderDTO> changeOrders;
    }

    public class WorkOrderSummaryDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String workType;
        @AuraEnabled public Date scheduledDate;
    }

    public class TaskSummaryDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public Date activityDate;
        @AuraEnabled public String ownerName;
    }

    public class ChangeOrderDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Date createdDate;
    }

    public class WorkOrderResultDTO {
        @AuraEnabled public List<WorkOrderRowDTO> rows;
        @AuraEnabled public Integer completeCount;
        @AuraEnabled public Integer scheduledCount;
        @AuraEnabled public Integer qiDueCount;
    }

    public class WorkOrderRowDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String subject;
        @AuraEnabled public String workType;
        @AuraEnabled public Date scheduledDate;
        @AuraEnabled public String lotName;
    }

    public class LotRowDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String lotNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean hasActiveWo;
    }

    // ── getPageData ─────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static PageDataDTO getPageData(Id communityId) {
        if (communityId == null) {
            throw new AuraHandledException('communityId is required.');
        }

        PageDataDTO result = new PageDataDTO();

        // Community record — safe fields only
        List<Community__c> communities = [
            SELECT Id, Name, Builder_Account__c, CreatedDate
            FROM Community__c
            WHERE Id = :communityId
            LIMIT 1
        ];
        if (communities.isEmpty()) {
            throw new AuraHandledException('Community record not found: ' + communityId);
        }
        result.community = communities[0];

        // Open work orders
        List<WorkOrder> openWos = [
            SELECT Id, WorkOrderNumber, Status, WorkTypeId, WorkType.Name, StartDate
            FROM WorkOrder
            WHERE Community__c = :communityId
              AND Status NOT IN ('Completed', 'Closed', 'Cancelled')
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
        result.openWorkOrderCount = openWos.size();
        result.openWorkOrders = new List<WorkOrderSummaryDTO>();
        for (WorkOrder wo : openWos) {
            WorkOrderSummaryDTO dto = new WorkOrderSummaryDTO();
            dto.id = wo.Id;
            dto.workOrderNumber = wo.WorkOrderNumber;
            dto.status = wo.Status;
            dto.workType = wo.WorkType != null ? wo.WorkType.Name : null;
            dto.scheduledDate = wo.StartDate;
            result.openWorkOrders.add(dto);
        }

        // Recent tasks
        List<Task> tasks = [
            SELECT Id, Subject, Status, ActivityDate, Owner.Name
            FROM Task
            WHERE WhatId = :communityId
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
        result.recentActivity = new List<TaskSummaryDTO>();
        for (Task t : tasks) {
            TaskSummaryDTO dto = new TaskSummaryDTO();
            dto.id = t.Id;
            dto.subject = t.Subject;
            dto.status = t.Status;
            dto.activityDate = t.ActivityDate;
            dto.ownerName = t.Owner != null ? t.Owner.Name : null;
            result.recentActivity.add(dto);
        }

        // Change orders (safe — wrapped in try/catch since object may not exist)
        result.changeOrders = new List<ChangeOrderDTO>();
        try {
            List<SObject> cos = Database.query(
                'SELECT Id, Name, Status__c, CreatedDate ' +
                'FROM Change_Order__c ' +
                'WHERE Community__c = :communityId ' +
                'ORDER BY CreatedDate DESC ' +
                'LIMIT 5'
            );
            for (SObject co : cos) {
                ChangeOrderDTO dto = new ChangeOrderDTO();
                dto.id = (Id) co.get('Id');
                dto.name = (String) co.get('Name');
                dto.status = (String) co.get('Status__c');
                dto.createdDate = ((DateTime) co.get('CreatedDate')).date();
                result.changeOrders.add(dto);
            }
        } catch (Exception ex) {
            // Change_Order__c may not exist in org — silently skip
        }

        return result;
    }

    // ── getWorkOrders (used by communityWorkOrders) ─────────────────────────

    @AuraEnabled(cacheable=true)
    public static WorkOrderResultDTO getWorkOrders(Id communityId) {
        if (communityId == null) {
            throw new AuraHandledException('communityId is required.');
        }

        WorkOrderResultDTO result = new WorkOrderResultDTO();
        result.rows = new List<WorkOrderRowDTO>();
        result.completeCount = 0;
        result.scheduledCount = 0;
        result.qiDueCount = 0;

        List<WorkOrder> wos = [
            SELECT Id, WorkOrderNumber, Status, Subject, WorkTypeId, WorkType.Name,
                   StartDate, Lot__r.Name
            FROM WorkOrder
            WHERE Community__c = :communityId
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        for (WorkOrder wo : wos) {
            WorkOrderRowDTO dto = new WorkOrderRowDTO();
            dto.id = wo.Id;
            dto.workOrderNumber = wo.WorkOrderNumber;
            dto.status = wo.Status;
            dto.subject = wo.Subject;
            dto.workType = wo.WorkType != null ? wo.WorkType.Name : null;
            dto.scheduledDate = wo.StartDate;
            dto.lotName = wo.Lot__r != null ? wo.Lot__r.Name : null;
            result.rows.add(dto);

            if (wo.Status == 'Completed') result.completeCount++;
            if (wo.Status == 'Scheduled') result.scheduledCount++;
        }

        return result;
    }

    // ── getLots (used by communityLotTracker) ───────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<LotRowDTO> getLots(Id communityId) {
        if (communityId == null) {
            throw new AuraHandledException('communityId is required.');
        }

        List<Lot__c> lots = [
            SELECT Id, Name, Lot_Number__c, Lot_Status__c
            FROM Lot__c
            WHERE Community__c = :communityId
            ORDER BY Lot_Number__c ASC NULLS LAST
            LIMIT 10
        ];

        // Check active WOs for these lots
        Set<Id> lotIds = new Set<Id>();
        for (Lot__c l : lots) { lotIds.add(l.Id); }

        Set<Id> lotsWithActiveWo = new Set<Id>();
        for (WorkOrder wo : [
            SELECT Lot__c
            FROM WorkOrder
            WHERE Lot__c IN :lotIds
              AND Status NOT IN ('Completed', 'Closed', 'Cancelled')
        ]) {
            lotsWithActiveWo.add(wo.Lot__c);
        }

        List<LotRowDTO> result = new List<LotRowDTO>();
        for (Lot__c l : lots) {
            LotRowDTO dto = new LotRowDTO();
            dto.id = l.Id;
            dto.name = l.Name;
            dto.lotNumber = l.Lot_Number__c;
            dto.status = l.Lot_Status__c;
            dto.hasActiveWo = lotsWithActiveWo.contains(l.Id);
            result.add(dto);
        }
        return result;
    }
}
