public with sharing class HomeBuilderAutoCloseService {
    private static final String STANDARD_INVOICE_PREFIX = 'HB-WO:';
    private static final String AQUA_INVOICE_PREFIX = 'HB-AQUA:';
    private static final String QI_TASK_PREFIX = 'QI Inspection';

    public static Boolean isStandardHomeBuilderInvoice(Invoice__c invoiceRecord) {
        if (invoiceRecord == null || String.isBlank(invoiceRecord.External_Invoice_ID__c)) {
            return false;
        }
        return invoiceRecord.External_Invoice_ID__c.startsWith(STANDARD_INVOICE_PREFIX)
            || invoiceRecord.External_Invoice_ID__c.startsWith(AQUA_INVOICE_PREFIX);
    }

    public static void onInvoicePaid(List<Invoice__c> paidInvoices) {
        Set<Id> standardPaidWorkOrderIds = new Set<Id>();
        for (Invoice__c invoiceRecord : paidInvoices) {
            Id standardWorkOrderId = resolveStandardWorkOrderId(invoiceRecord);
            if (standardWorkOrderId != null) {
                standardPaidWorkOrderIds.add(standardWorkOrderId);
            }
        }
        processStandardWorkOrders(standardPaidWorkOrderIds, true);
    }

    public static void checkAutoCloseConditions(Id workOrderId) {
        if (workOrderId == null || !isStandardWorkOrderId(workOrderId)) {
            return;
        }
        processStandardWorkOrders(new Set<Id>{ workOrderId }, true);
    }

    public static void runNightlyAutoClose() {
        processStandardWorkOrders(getAllPaidStandardWorkOrderIds(), false);
    }

    private static void processStandardWorkOrders(Set<Id> workOrderIds, Boolean sendAlerts) {
        if (workOrderIds == null || workOrderIds.isEmpty()) {
            return;
        }

        Map<Id, WorkOrder> seedById = new Map<Id, WorkOrder>([
            SELECT Id, Status, ParentWorkOrderId, Field_Manager__c
            FROM WorkOrder
            WHERE Id IN :workOrderIds
        ]);
        if (seedById.isEmpty()) {
            return;
        }

        Set<Id> parentScopeIds = new Set<Id>();
        for (WorkOrder seed : seedById.values()) {
            parentScopeIds.add(seed.ParentWorkOrderId != null ? seed.ParentWorkOrderId : seed.Id);
        }

        Set<Id> builderParentIds = new Set<Id>();
        for (Purchase_Order__c po : [
            SELECT Work_Order__c
            FROM Purchase_Order__c
            WHERE Work_Order__c IN :parentScopeIds
        ]) {
            if (po.Work_Order__c != null) {
                builderParentIds.add(po.Work_Order__c);
            }
        }
        if (builderParentIds.isEmpty()) {
            return;
        }

        Set<Id> paidStandardWorkOrderIds = getAllPaidStandardWorkOrderIds();
        List<WorkOrder> scopedRecords = [
            SELECT Id, Status, ParentWorkOrderId, Field_Manager__c
            FROM WorkOrder
            WHERE Id IN :builderParentIds
               OR ParentWorkOrderId IN :builderParentIds
        ];
        if (scopedRecords.isEmpty()) {
            return;
        }

        Map<Id, WorkOrder> workOrderById = new Map<Id, WorkOrder>();
        Map<Id, List<WorkOrder>> childrenByParent = new Map<Id, List<WorkOrder>>();
        Set<Id> qiCandidateIds = new Set<Id>();

        for (WorkOrder record : scopedRecords) {
            workOrderById.put(record.Id, record);
            Id scopeParentId = record.ParentWorkOrderId != null ? record.ParentWorkOrderId : record.Id;
            if (!childrenByParent.containsKey(scopeParentId)) {
                childrenByParent.put(scopeParentId, new List<WorkOrder>());
            }
            if (record.ParentWorkOrderId != null) {
                childrenByParent.get(scopeParentId).add(record);
            }
            qiCandidateIds.add(record.Id);
        }

        Set<Id> completedQiWhatIds = new Set<Id>();
        for (Task task : [
            SELECT WhatId
            FROM Task
            WHERE WhatId IN :qiCandidateIds
              AND Subject LIKE :QI_TASK_PREFIX + '%'
              AND Status = 'Completed'
        ]) {
            completedQiWhatIds.add(task.WhatId);
        }

        List<WorkOrder> toUpdate = new List<WorkOrder>();
        Set<Id> alertedWorkOrderIds = new Set<Id>();

        for (Id parentId : builderParentIds) {
            WorkOrder parent = workOrderById.get(parentId);
            if (parent == null) {
                continue;
            }

            Boolean parentPaid = paidStandardWorkOrderIds.contains(parent.Id);
            List<WorkOrder> children = childrenByParent.containsKey(parentId)
                ? childrenByParent.get(parentId)
                : new List<WorkOrder>();

            Boolean allChildrenComplete = true;
            if (!children.isEmpty()) {
                for (WorkOrder child : children) {
                    Boolean childPaid = parentPaid || paidStandardWorkOrderIds.contains(child.Id);
                    if (!childPaid) {
                        allChildrenComplete = false;
                        continue;
                    }

                    if (completedQiWhatIds.contains(child.Id)) {
                        if (child.Status != 'Closed') {
                            toUpdate.add(new WorkOrder(Id = child.Id, Status = 'Closed'));
                        }
                    } else {
                        allChildrenComplete = false;
                        if (sendAlerts && !alertedWorkOrderIds.contains(child.Id)) {
                            alertStandardFieldManagerQiRequired(child.Id);
                            alertedWorkOrderIds.add(child.Id);
                        }
                    }
                }
            } else if (!parentPaid || !completedQiWhatIds.contains(parent.Id)) {
                allChildrenComplete = false;
                if (parentPaid && sendAlerts && !alertedWorkOrderIds.contains(parent.Id)) {
                    alertStandardFieldManagerQiRequired(parent.Id);
                    alertedWorkOrderIds.add(parent.Id);
                }
            }

            if (parentPaid && allChildrenComplete && parent.Status != 'Closed') {
                toUpdate.add(new WorkOrder(Id = parent.Id, Status = 'Closed'));
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static Set<Id> getAllPaidStandardWorkOrderIds() {
        Set<Id> result = new Set<Id>();
        for (Invoice__c invoiceRecord : [
            SELECT External_Invoice_ID__c
            FROM Invoice__c
            WHERE Status__c = 'Paid'
              AND External_Invoice_ID__c LIKE 'HB-%'
        ]) {
            Id workOrderId = resolveStandardWorkOrderId(invoiceRecord);
            if (workOrderId != null) {
                result.add(workOrderId);
            }
        }
        return result;
    }

    private static Id resolveStandardWorkOrderId(Invoice__c invoiceRecord) {
        if (!isStandardHomeBuilderInvoice(invoiceRecord)) {
            return null;
        }

        String key = invoiceRecord.External_Invoice_ID__c;
        if (key.startsWith(STANDARD_INVOICE_PREFIX)) {
            return tryParseId(key.substring(STANDARD_INVOICE_PREFIX.length()));
        }

        Integer delimiter = key.indexOf(':', AQUA_INVOICE_PREFIX.length());
        String idToken = delimiter > -1
            ? key.substring(AQUA_INVOICE_PREFIX.length(), delimiter)
            : key.substring(AQUA_INVOICE_PREFIX.length());
        return tryParseId(idToken);
    }

    private static Id tryParseId(String rawId) {
        if (String.isBlank(rawId)) {
            return null;
        }
        try {
            return (Id) rawId.trim();
        } catch (Exception e) {
            return null;
        }
    }

    private static Boolean isStandardWorkOrderId(Id recordId) {
        return recordId != null
            && String.valueOf(recordId).startsWith(WorkOrder.SObjectType.getDescribe().getKeyPrefix());
    }

    private static void alertStandardFieldManagerQiRequired(Id workOrderId) {
        List<WorkOrder> workOrders = [
            SELECT Id, Field_Manager__c
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];
        if (workOrders.isEmpty()) {
            return;
        }

        EscalationService.sendAlert(
            workOrders[0].Field_Manager__c,
            'Invoice Paid — QI Inspection Required to Close',
            'Payment received. This Builder WorkOrder cannot auto-close until the QI task is completed.',
            workOrderId
        );
    }
}