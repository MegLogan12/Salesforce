/**
 * AquaInventoryService
 * Manages the 3-location Aqua inventory balance.
 *
 * A Work Order = the lot/job. Inventory is tracked per Work Order (on-site location).
 *
 * Inventory always tracked across:
 *   Location 1 — Shop (309 Morningside Rd)       → Aqua_Inventory__c where Location__c = 'Shop'
 *   Location 2 — Van (Scott/Jimbo truck)          → Aqua_Inventory__c where Location__c = 'Van'
 *   Location 3 — On-Site (per Work Order)         → Aqua_Inventory__c where Location__c = 'On-Site' + Work_Order__c
 *
 * The sum of all three must always balance against Aqua_Master_Inventory__c.
 * Imbalance triggers an alert to Scott.
 */
public with sharing class AquaInventoryService {

    private static final String LOC_SHOP    = 'Shop';
    private static final String LOC_VAN     = 'Van';
    private static final String LOC_ON_SITE = 'On-Site';

    // ─────────────────────────────────────────────
    // ALLOCATE: Shop → Van when Install Ticket opens
    // ─────────────────────────────────────────────
    public static void allocateInstallInventory(Aqua_Install_Ticket__c ticket) {
        // Move controller and heads from Shop to Van
        adjustInventory(null, LOC_SHOP, 'Controller', -1 * ticket.Controller_Count__c);
        adjustInventory(null, LOC_VAN,  'Controller',  1 * ticket.Controller_Count__c);
        adjustInventory(null, LOC_SHOP, 'Heads',       -1 * ticket.Heads_Count__c);
        adjustInventory(null, LOC_VAN,  'Heads',        1 * ticket.Heads_Count__c);

        reconcileGlobal();
    }

    // ─────────────────────────────────────────────
    // CONFIRM: Van → On-Site when install complete
    // workOrderId = the job/lot where equipment is installed
    // ─────────────────────────────────────────────
    public static void confirmOnSiteInventory(Id workOrderId, Decimal controllers, Decimal heads) {
        adjustInventory(null,        LOC_VAN,     'Controller', -controllers);
        adjustInventory(workOrderId, LOC_ON_SITE, 'Controller',  controllers);
        adjustInventory(null,        LOC_VAN,     'Heads',       -heads);
        adjustInventory(workOrderId, LOC_ON_SITE, 'Heads',        heads);

        reconcileGlobal();
    }

    // ─────────────────────────────────────────────
    // RETURN: On-Site → Shop on Pickup
    // ─────────────────────────────────────────────
    public static void returnInventoryToShop(Id workOrderId, Decimal controllers, Decimal heads) {
        adjustInventory(workOrderId, LOC_ON_SITE, 'Controller', -controllers);
        adjustInventory(null,        LOC_SHOP,    'Controller',  controllers);
        adjustInventory(workOrderId, LOC_ON_SITE, 'Heads',       -heads);
        adjustInventory(null,        LOC_SHOP,    'Heads',        heads);

        reconcileGlobal();
    }

    // ─────────────────────────────────────────────
    // WARRANTY REPLACEMENT — no billing, track swap
    // ─────────────────────────────────────────────
    public static void createWarrantyReplacement(Id workOrderId, String notes) {
        Aqua_Warranty_Record__c warranty = new Aqua_Warranty_Record__c(
            LOVING_Work_Order__c = workOrderId,
            Replacement_Date__c = Date.today(),
            Notes__c            = notes,
            Billed__c           = false
        );
        insert warranty;
        // No inventory movement — replacement is a swap; net neutral
    }

    // ─────────────────────────────────────────────
    // 3-LOCATION RECONCILIATION
    // Per Work Order: verifies On-Site matches install records
    // ─────────────────────────────────────────────
    public static void reconcileThreeLocations(Id workOrderId) {
        // Get installed quantities from Install Ticket for this Work Order
        List<Aqua_Install_Ticket__c> installs = [
            SELECT Installed_Controller_Count__c, Installed_Heads_Count__c
            FROM Aqua_Install_Ticket__c
            WHERE LOVING_Work_Order__c = :workOrderId AND Status__c = 'Closed'
            ORDER BY Closed_Date__c DESC LIMIT 1
        ];

        if (installs.isEmpty()) return;

        // Get current On-Site inventory for this Work Order
        List<Aqua_Inventory__c> onSite = [
            SELECT Item_Type__c, Quantity__c
            FROM Aqua_Inventory__c
            WHERE LOVING_Work_Order__c = :workOrderId AND Location__c = :LOC_ON_SITE
        ];

        Map<String, Decimal> onSiteQtys = new Map<String, Decimal>();
        for (Aqua_Inventory__c inv : onSite) {
            onSiteQtys.put(inv.Item_Type__c, inv.Quantity__c);
        }

        Decimal expectedControllers = installs[0].Installed_Controller_Count__c;
        Decimal expectedHeads       = installs[0].Installed_Heads_Count__c;
        Decimal actualControllers   = onSiteQtys.containsKey('Controller') ? onSiteQtys.get('Controller') : 0;
        Decimal actualHeads         = onSiteQtys.containsKey('Heads') ? onSiteQtys.get('Heads') : 0;

        if (expectedControllers != actualControllers || expectedHeads != actualHeads) {
            EscalationService.alertAquaInventoryMismatch(
                workOrderId,
                expectedControllers, actualControllers,
                expectedHeads, actualHeads
            );
        }
    }

    // Global reconciliation: Shop + Van + all On-Site totals must balance
    public static void reconcileGlobal() {
        AggregateResult[] totals = [
            SELECT Location__c, Item_Type__c, SUM(Quantity__c) totalQty
            FROM Aqua_Inventory__c
            GROUP BY Location__c, Item_Type__c
        ];

        Map<String, Decimal> byItemType = new Map<String, Decimal>();
        for (AggregateResult ar : totals) {
            String key  = (String)ar.get('Item_Type__c');
            Decimal qty = (Decimal)ar.get('totalQty');
            if (!byItemType.containsKey(key)) byItemType.put(key, 0);
            byItemType.put(key, byItemType.get(key) + qty);
        }

        for (String itemType : byItemType.keySet()) {
            Decimal masterTotal  = getMasterInventoryTotal(itemType);
            Decimal currentTotal = byItemType.get(itemType);
            if (masterTotal != currentTotal) {
                EscalationService.alertAquaGlobalInventoryImbalance(itemType, masterTotal, currentTotal);
            }
        }
    }

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────
    // workOrderId = null for Shop/Van rows (not tied to a specific job)
    private static void adjustInventory(Id workOrderId, String location, String itemType, Decimal delta) {
        List<Aqua_Inventory__c> existing = [
            SELECT Id, Quantity__c FROM Aqua_Inventory__c
            WHERE Location__c         = :location
            AND   Item_Type__c        = :itemType
            AND   LOVING_Work_Order__c = :workOrderId
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            existing[0].Quantity__c += delta;
            update existing[0];
        } else {
            insert new Aqua_Inventory__c(
                Location__c          = location,
                Item_Type__c         = itemType,
                LOVING_Work_Order__c = workOrderId,
                Quantity__c          = delta
            );
        }
    }

    private static Decimal getMasterInventoryTotal(String itemType) {
        List<Aqua_Master_Inventory__c> master = [
            SELECT Total_Purchased__c FROM Aqua_Master_Inventory__c
            WHERE Item_Type__c = :itemType LIMIT 1
        ];
        return master.isEmpty() ? 0 : master[0].Total_Purchased__c;
    }
}