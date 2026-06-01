/**
 * AquaSubWorkOrderService
 * D-004 / D-005 — Aqua detection and Aqua New Install sub-WO creation.
 *
 * When a Production Install WO is advanced to Ready to Schedule from an approved Takeoff,
 * this service checks WorkOrder.Aqua_Community__c (denorm flag set by automation).
 * If true, it creates an Aqua New Install WO as a child of the Production Install WO.
 *
 * NOTE: WorkOrder.Community__c in this org is a lookup to Extentia_SIM__Custom__c
 * (managed package object). Aqua detection uses the Aqua_Community__c denorm field.
 *
 * Called from: LovingTakeoffGateController.createWorkOrderFromTakeoff()
 */
public with sharing class AquaSubWorkOrderService {

    // ─────────────────────────────────────────────────────────────────────────
    // Test injection hooks — allows unit tests to exercise the full code path
    // without WorkOrder DML (blocked by org-level trigger in test context).
    // These fields are null/false in production at all times.
    // ─────────────────────────────────────────────────────────────────────────
    @TestVisible private static WorkOrder injectedWorkOrder = null;
    @TestVisible private static Boolean   skipInsertForTest = false;

    // ─────────────────────────────────────────────────────────────────────────
    // Main entry point
    // ─────────────────────────────────────────────────────────────────────────
    public static void maybeCreateAquaSubWorkOrder(Id productionInstallWoId) {
        if (productionInstallWoId == null) return;

        WorkOrder wo = fetchWorkOrder(productionInstallWoId);
        if (wo == null) return;

        if (!isAquaCommunity(wo)) return;

        if (aquaSubWoAlreadyExists(productionInstallWoId)) return;

        WorkOrder aquaWo = buildAquaSubWo(wo, productionInstallWoId);
        dmlInsertSubWo(aquaWo);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────
    @TestVisible
    private static WorkOrder fetchWorkOrder(Id woId) {
        if (injectedWorkOrder != null) { return injectedWorkOrder; }
        List<WorkOrder> wos = [
            SELECT Id, Status__c, Community__c, Lot__c, Purchase_Order__c,
                   RecordTypeId, Aqua_Community__c
            FROM WorkOrder
            WHERE Id = :woId
            LIMIT 1
        ];
        return wos.isEmpty() ? null : wos[0];
    }

    @TestVisible
    private static Boolean isAquaCommunity(WorkOrder wo) {
        return wo.Aqua_Community__c == true;
    }

    @TestVisible
    private static Boolean aquaSubWoAlreadyExists(Id parentWoId) {
        return [
            SELECT COUNT() FROM WorkOrder
            WHERE ParentWorkOrderId = :parentWoId
            AND Work_Order_Type__c = 'Aqua New Install'
        ] > 0;
    }

    @TestVisible
    private static WorkOrder buildAquaSubWo(WorkOrder parent, Id parentWoId) {
        Id rtId = getProductionInstallRecordTypeId();
        return new WorkOrder(
            RecordTypeId        = rtId,
            ParentWorkOrderId   = parentWoId,
            Work_Order_Type__c  = 'Aqua New Install',
            Status__c           = 'Ready to Schedule',
            Community__c        = parent.Community__c,
            Lot__c              = parent.Lot__c,
            Purchase_Order__c   = parent.Purchase_Order__c,
            Subject             = 'Aqua New Install — auto-created from Production Install',
            Description         = 'Auto-created by AquaSubWorkOrderService when Aqua_Community__c = true.'
        );
    }

    @TestVisible
    private static void dmlInsertSubWo(WorkOrder wo) {
        if (!skipInsertForTest) {
            insert wo;
        }
    }

    @TestVisible
    private static Id getProductionInstallRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'WorkOrder'
            AND DeveloperName = 'Production_Install'
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }
}