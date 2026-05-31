/**
 * TakeoffWorkOrderService
 * On takeoff approval, turns Takeoff_Line__c rows into trade Work Orders.
 *
 * Model (no parent WO):
 *   - Group takeoff lines by trade. Trade is read from the line's Execution_Scope__c,
 *     else from the line's Order Product -> Product2.category__c.
 *   - Create ONE Work Order per trade (correct record type) with a Work Order Line Item
 *     per takeoff line.
 *   - Sequence/scheduling: Grading (day 0) -> Irrigation (+24h, after grading) ->
 *     Hardscape/Outdoor Living (24h before install) -> Install (install day).
 *   - Multiple trade WOs can later share one Service Appointment via WorkOrder.Service_Appointment__c.
 *
 * Phantom-field safe: line query uses dynamic SOQL with a fallback, so the class compiles
 * and runs even while Execution_Scope__c / Source_Order_Item__c are still materializing.
 */
public with sharing class TakeoffWorkOrderService {

    private static final String DEFAULT_RT = 'Production_Install';

    // Material-keyword -> WorkOrder record type. Classification is driven by the line's
    // material (Item_Name__c / Material_Code__c), which is always accessible.
    //   plants, sod, shrubs, mulch, pine straw, trees, turf  -> Landscape Install (Production_Install)
    //   hoses, sprinklers, in-ground irrigation, drip, valves -> Irrigation (Inground_Irrigation)
    //   aqua                                                  -> Aqua Install (Aqua_New_Install)
    //   grading / grade / soil prep                           -> Grading (Plant_Sod_Grading)
    //   pavers, walls, patio, hardscape, fire pit, pergola    -> Hardscape (Outdoor Living)
    private static String classifyRecordType(String text) {
        if (String.isBlank(text)) return DEFAULT_RT;
        String t = text.toLowerCase();
        if (contains(t, new List<String>{'aqua'})) return 'Aqua_New_Install';
        if (contains(t, new List<String>{'grading','grade','soil prep','rough grade','fine grade'})) return 'Plant_Sod_Grading';
        if (contains(t, new List<String>{'irrigation','sprinkler','hose','drip','valve','rotor','spray head','backflow','irrig'})) return 'Inground_Irrigation';
        if (contains(t, new List<String>{'paver','retaining wall','seat wall','patio','hardscape','fire pit','firepit','fireplace','pergola','grill','stone','travertine'})) return 'Hardscape';
        if (contains(t, new List<String>{'plant','sod','shrub','mulch','pine straw','pinestraw','tree','turf','grass','flower','perennial','annual','landscape'})) return 'Production_Install';
        return DEFAULT_RT;
    }
    private static Boolean contains(String t, List<String> keys) {
        for (String k : keys) { if (t.contains(k)) return true; }
        return false;
    }

    // Record type -> day offset from the anchor (install) date and run sequence.
    // Grading 0, Irrigation +1 (after grading), Hardscape +2 (= install - 1), Install +3.
    private static final Map<String, Integer> RT_OFFSET = new Map<String, Integer>{
        'Plant_Sod_Grading'  => 0,
        'Inground_Irrigation'=> 1,
        'Hardscape'          => 2,
        'Production_Install' => 3,
        'Aqua_New_Install'   => 3,
        'Customer_Care'      => 3
    };
    private static final Map<String, Integer> RT_SEQ = new Map<String, Integer>{
        'Plant_Sod_Grading'  => 1,
        'Inground_Irrigation'=> 2,
        'Hardscape'          => 3,
        'Production_Install' => 4,
        'Aqua_New_Install'   => 4,
        'Customer_Care'      => 5
    };
    // Required Work_Order_Type__c picklist value per record type.
    private static final Map<String, String> RT_WOT = new Map<String, String>{
        'Plant_Sod_Grading'  => 'Grading',
        'Inground_Irrigation'=> 'Irrigation',
        'Hardscape'          => 'Production Install',
        'Production_Install' => 'Production Install',
        'Aqua_New_Install'   => 'Aqua Install',
        'Customer_Care'      => 'Customer Care'
    };

    @InvocableMethod(label='Create Work Orders From Takeoff' description='Creates one trade Work Order per trade from approved takeoff lines.')
    public static void createFromTakeoffInvocable(List<Id> takeoffIds) {
        createFromTakeoff(takeoffIds);
    }

    @AuraEnabled
    public static void createFromTakeoff(List<Id> takeoffIdList) {
        if (takeoffIdList == null || takeoffIdList.isEmpty()) return;
        Set<Id> takeoffIds = new Set<Id>(takeoffIdList);

        Map<String, Id> rtId = new Map<String, Id>();
        for (RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SobjectType = 'WorkOrder' AND IsActive = true]) {
            rtId.put(rt.DeveloperName, rt.Id);
        }

        // Idempotency: skip takeoffs that already generated trade WOs.
        // Dynamic SOQL so this compiles even if Source_Takeoff__c is not yet materialized.
        Set<Id> alreadyDone = new Set<Id>();
        try {
            for (SObject w : Database.query('SELECT Source_Takeoff__c FROM WorkOrder WHERE Source_Takeoff__c IN :takeoffIds')) {
                Id srcId = (Id) w.get('Source_Takeoff__c');
                if (srcId != null) alreadyDone.add(srcId);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'WorkOrder.Source_Takeoff__c not materialized, skipping idempotency check: ' + e.getMessage());
        }
        Set<Id> toProcess = new Set<Id>();
        for (Id tk : takeoffIds) { if (!alreadyDone.contains(tk)) toProcess.add(tk); }
        if (toProcess.isEmpty()) return;
        takeoffIds = toProcess;

        Map<Id, Takeoff__c> tks = new Map<Id, Takeoff__c>([
            SELECT Id, Lot__c, Community__c, Purchase_Order__c, Scheduled_Date__c, Approved_Date__c
            FROM Takeoff__c WHERE Id IN :takeoffIds
        ]);

        List<SObject> lines = queryLines(takeoffIds);

        // Group lines by takeoffId + record type.
        Map<String, List<SObject>> groups = new Map<String, List<SObject>>();
        for (SObject l : lines) {
            String rt = resolveRecordType(l);
            if (!rtId.containsKey(rt)) rt = DEFAULT_RT;
            String key = String.valueOf(l.get('Takeoff__c')) + '|' + rt;
            if (!groups.containsKey(key)) groups.put(key, new List<SObject>());
            groups.get(key).add(l);
        }

        // One WO per (takeoff, trade).
        List<WorkOrder> wos = new List<WorkOrder>();
        Map<String, WorkOrder> woByKey = new Map<String, WorkOrder>();
        for (String key : groups.keySet()) {
            Id tkId = (Id) key.substringBefore('|');
            String rt = key.substringAfter('|');
            Takeoff__c tk = tks.get(tkId);
            Datetime anchor = anchorFor(tk);
            Integer offset = RT_OFFSET.containsKey(rt) ? RT_OFFSET.get(rt) : 3;
            WorkOrder wo = new WorkOrder(
                RecordTypeId = rtId.get(rt),
                Subject = rt.replace('_', ' ') + ' - Takeoff ' + tkId,
                Work_Order_Type__c = RT_WOT.containsKey(rt) ? RT_WOT.get(rt) : 'Production Install',
                StartDate = anchor.addDays(offset)
            );
            putIfHas(wo, 'Trade_Sequence__c', RT_SEQ.containsKey(rt) ? RT_SEQ.get(rt) : 9);
            putIfHas(wo, 'Source_Takeoff__c', tkId);
            putIfHas(wo, 'Lot__c', tk != null ? tk.Lot__c : null);
            putIfHas(wo, 'Community__c', tk != null ? tk.Community__c : null);
            putIfHas(wo, 'Purchase_Order__c', tk != null ? tk.Purchase_Order__c : null);
            putIfHas(wo, 'Scheduled_Date__c', anchor.addDays(offset).date());
            wos.add(wo);
            woByKey.put(key, wo);
        }
        if (wos.isEmpty()) return;
        insert wos;

        // Line items per takeoff line.
        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        for (String key : groups.keySet()) {
            WorkOrder wo = woByKey.get(key);
            for (SObject l : groups.get(key)) {
                Decimal qty = firstNonNull(num(l, 'Verified_Qty__c'), num(l, 'Measured_Qty__c'), num(l, 'PO_Qty__c'));
                String item = (String) safeGet(l, 'Item_Name__c');
                Decimal price = num(l, 'Unit_Price__c');
                String lineDesc = (String.isBlank(item) ? 'Line item' : item)
                    + (qty != null ? ' - Qty ' + qty.setScale(qty.scale() > 0 && qty != qty.round() ? 2 : 0).format() : '')
                    + (price != null ? ' @ $' + price.setScale(2).format() : '');
                // Description-based line item (Quantity/UnitPrice require a product, which the
                // phantom takeoff-line -> Order Product link cannot yet provide). Qty and price
                // are captured in the description; product-based pricing layers on later.
                wolis.add(new WorkOrderLineItem(
                    WorkOrderId = wo.Id,
                    Description = lineDesc.left(255)
                ));
            }
        }
        if (!wolis.isEmpty()) insert wolis;
    }

    // Dynamic, phantom-safe line query. Falls back to base fields if scope/order-item are not yet materialized.
    @TestVisible
    private static List<SObject> queryLines(Set<Id> takeoffIds) {
        try {
            return Database.query(
                'SELECT Id, Takeoff__c, Item_Name__c, Material_Code__c, Measured_Qty__c, PO_Qty__c, Verified_Qty__c, Unit_Price__c, ' +
                'Execution_Scope__c, Source_Order_Item__r.Product2.category__c ' +
                'FROM Takeoff_Line__c WHERE Takeoff__c IN :takeoffIds'
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Takeoff line trade fields not materialized, using base query: ' + e.getMessage());
            return Database.query(
                'SELECT Id, Takeoff__c, Item_Name__c, Material_Code__c, Measured_Qty__c, PO_Qty__c, Verified_Qty__c, Unit_Price__c ' +
                'FROM Takeoff_Line__c WHERE Takeoff__c IN :takeoffIds'
            );
        }
    }

    // Classify a line to a WorkOrder record type from its material text (item name + material
    // code), plus scope/product-category as extra hints when available.
    @TestVisible
    private static String resolveRecordType(SObject l) {
        List<String> parts = new List<String>();
        Object item = safeGet(l, 'Item_Name__c'); if (item != null) parts.add(String.valueOf(item));
        Object mc = safeGet(l, 'Material_Code__c'); if (mc != null) parts.add(String.valueOf(mc));
        Object scope = safeGet(l, 'Execution_Scope__c'); if (scope != null) parts.add(String.valueOf(scope));
        try {
            SObject oi = l.getSObject('Source_Order_Item__r');
            if (oi != null) {
                SObject prod = oi.getSObject('Product2');
                if (prod != null) {
                    Object cat = prod.get('category__c'); if (cat != null) parts.add(String.valueOf(cat));
                }
            }
        } catch (Exception e) { /* relationship not present */ }
        return classifyRecordType(String.join(parts, ' '));
    }

    private static Datetime anchorFor(Takeoff__c tk) {
        if (tk != null && tk.Scheduled_Date__c != null) return Datetime.newInstance(tk.Scheduled_Date__c, Time.newInstance(8, 0, 0, 0));
        if (tk != null && tk.Approved_Date__c != null) return tk.Approved_Date__c;
        return Datetime.now();
    }

    private static Object safeGet(SObject so, String field) {
        try { return so.get(field); } catch (Exception e) { return null; }
    }
    private static Decimal num(SObject so, String field) {
        Object v = safeGet(so, field);
        return (v == null) ? null : (Decimal) v;
    }
    private static Decimal firstNonNull(Decimal a, Decimal b, Decimal c) {
        if (a != null) return a; if (b != null) return b; return c;
    }
    private static void putIfHas(SObject so, String field, Object val) {
        if (val == null) return;
        Schema.SObjectField f = so.getSObjectType().getDescribe().fields.getMap().get(field.toLowerCase());
        if (f == null) return;
        Schema.DescribeFieldResult dfr = f.getDescribe();
        // For lookups, only set when the value's object type matches the field's target.
        if (val instanceof Id) {
            Schema.SObjectType valType = ((Id) val).getSObjectType();
            List<Schema.SObjectType> refs = dfr.getReferenceTo();
            if (refs != null && !refs.isEmpty()) {
                Boolean ok = false;
                for (Schema.SObjectType rt : refs) { if (rt == valType) { ok = true; break; } }
                if (!ok) return;
            }
        }
        try { so.put(field, val); } catch (Exception e) { /* skip */ }
    }
}