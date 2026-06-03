public class SiteReadinessHandler {

    // Maps each Site_Readiness_Item__c.Item_Code__c to its WorkOrder checkbox field.
    // These are the 6 criteria audited from WorkOrder.Site_Ready_Overall__c formula:
    //   AND(Grading_OK__c, Access_OK__c, Irrigation_OK__c,
    //       Debris_Clear__c, Builder_Punch_Clear__c, Utilities_Cleared__c)
    @TestVisible
    private static final List<String> ITEM_CODES = new List<String>{
        'Grading', 'Access', 'Irrigation', 'Debris Clear',
        'Builder Punch Clear', 'Utilities Cleared'
    };

    private static final Map<String, SObjectField> ITEM_FIELD_MAP = new Map<String, SObjectField>{
        'Grading'             => WorkOrder.Grading_OK__c,
        'Access'              => WorkOrder.Access_OK__c,
        'Irrigation'          => WorkOrder.Irrigation_OK__c,
        'Debris Clear'        => WorkOrder.Debris_Clear__c,
        'Builder Punch Clear' => WorkOrder.Builder_Punch_Clear__c,
        'Utilities Cleared'   => WorkOrder.Utilities_Cleared__c
    };

    // ── SiteReadinessItemTrigger (after insert/update) ───────────────────────
    // When any Site_Readiness_Item__c.Is_Ready__c changes, re-reads all items for
    // the parent Site_Readiness__c and writes the corresponding WO checkbox fields.
    // Site_Ready_Overall__c is a formula (AND of all 6) — it recalculates automatically.
    public static void syncItemsToWorkOrder(
            List<Site_Readiness_Item__c> newItems,
            Map<Id, Site_Readiness_Item__c> oldMap) {

        // Collect parent Site_Readiness__c Ids where Is_Ready__c changed
        Set<Id> changedSrIds = new Set<Id>();
        for (Site_Readiness_Item__c item : newItems) {
            Boolean wasReady = (oldMap != null && oldMap.containsKey(item.Id))
                               ? oldMap.get(item.Id).Is_Ready__c : false;
            if (item.Is_Ready__c != wasReady) {
                changedSrIds.add(item.Site_Readiness__c);
            }
        }
        if (changedSrIds.isEmpty()) return;

        // Get the WO Id for each SR
        Map<Id, Id> woIdBySrId = new Map<Id, Id>();
        for (Site_Readiness__c sr : [
            SELECT Id, Work_Order__c FROM Site_Readiness__c WHERE Id IN :changedSrIds
        ]) {
            if (sr.Work_Order__c != null) woIdBySrId.put(sr.Id, sr.Work_Order__c);
        }
        if (woIdBySrId.isEmpty()) return;

        // Load ALL items for the affected SRs (to know each item's current state)
        Map<Id, Map<String, Boolean>> readyMapBySrId = new Map<Id, Map<String, Boolean>>();
        for (Id srId : woIdBySrId.keySet()) {
            readyMapBySrId.put(srId, new Map<String, Boolean>());
        }
        for (Site_Readiness_Item__c item : [
            SELECT Id, Site_Readiness__c, Item_Code__c, Is_Ready__c
            FROM Site_Readiness_Item__c
            WHERE Site_Readiness__c IN :changedSrIds
        ]) {
            Map<String, Boolean> m = readyMapBySrId.get(item.Site_Readiness__c);
            if (m == null) continue;
            // Override with in-context value (trigger context takes precedence over DB value)
            Boolean ready = item.Is_Ready__c;
            // Check if this item is in the current trigger's newItems
            for (Site_Readiness_Item__c trigItem : newItems) {
                if (trigItem.Id == item.Id) { ready = trigItem.Is_Ready__c; break; }
            }
            m.put(item.Item_Code__c, ready);
        }

        List<WorkOrder> woUpdates = new List<WorkOrder>();
        for (Id srId : woIdBySrId.keySet()) {
            Id woId = woIdBySrId.get(srId);
            Map<String, Boolean> readyMap = readyMapBySrId.get(srId);

            WorkOrder wo = new WorkOrder(Id = woId);
            wo.Grading_OK__c          = readyMap.containsKey('Grading')             ? readyMap.get('Grading')             : false;
            wo.Access_OK__c           = readyMap.containsKey('Access')              ? readyMap.get('Access')              : false;
            wo.Irrigation_OK__c       = readyMap.containsKey('Irrigation')          ? readyMap.get('Irrigation')          : false;
            wo.Debris_Clear__c        = readyMap.containsKey('Debris Clear')        ? readyMap.get('Debris Clear')        : false;
            wo.Builder_Punch_Clear__c = readyMap.containsKey('Builder Punch Clear') ? readyMap.get('Builder Punch Clear') : false;
            wo.Utilities_Cleared__c   = readyMap.containsKey('Utilities Cleared')   ? readyMap.get('Utilities Cleared')   : false;
            woUpdates.add(wo);
        }
        if (!woUpdates.isEmpty()) update woUpdates;
    }

    // ── Auto-create Site_Readiness__c + 6 items for a WorkOrder ─────────────
    // Called from SiteReadinessAutoCreateBatch. Idempotent: skips if SR already exists.
    // fieldManagerId may be null for G6-blocked zones; FM_Missing__c flags those.
    public static void autoCreate(Id workOrderId, Id fieldManagerId) {
        List<Site_Readiness__c> existing = [
            SELECT Id FROM Site_Readiness__c WHERE Work_Order__c = :workOrderId LIMIT 1
        ];
        if (!existing.isEmpty()) return;

        Site_Readiness__c sr = new Site_Readiness__c(
            Work_Order__c    = workOrderId,
            Field_Manager__c = fieldManagerId,
            Status__c        = 'Pending',
            FM_Missing__c    = (fieldManagerId == null)
        );
        insert sr;

        List<Site_Readiness_Item__c> items = new List<Site_Readiness_Item__c>();
        for (String code : ITEM_CODES) {
            items.add(new Site_Readiness_Item__c(
                Site_Readiness__c = sr.Id,
                Item_Code__c      = code,
                Is_Ready__c       = false
            ));
        }
        insert items;
    }

    // ── Invocable for Record-Triggered Flows ─────────────────────────────────
    @InvocableMethod(label='Auto-Create Site Readiness'
                     description='Creates a Site_Readiness__c with 6 items for the given WorkOrder if one does not exist.')
    public static void autoCreateInvocable(List<Id> woIds) {
        for (Id woId : woIds) {
            autoCreate(woId, null);
        }
    }
}
