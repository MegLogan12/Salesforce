/**
 * AquaController
 * @AuraEnabled methods for lovingAquaConsole LWC.
 *
 * Serves the Aqua Service Console used by Scott (Aqua Program Manager).
 * Covers the full Aqua parallel workflow:
 *   1. Install Ticket  — auto-created when sod WO is scheduled for Aqua community
 *   2. Check Tickets   — weekly service visits with 3 close questions
 *   3. Pickup Ticket   — equipment retrieval on WO close
 *   4. Inventory       — 3-location view (Shop / On-Site / Master)
 *   5. Watering Schedules — weekly program definitions by community
 */
public with sharing class AquaController {

    // ─────────────────────────────────────────────
    // WRAPPERS
    // ─────────────────────────────────────────────
    public class AquaKpis {
        @AuraEnabled public Integer openInstallTickets;
        @AuraEnabled public Integer overdueCheckTickets;
        @AuraEnabled public Integer openCheckTickets;
        @AuraEnabled public Integer openPickupTickets;
        @AuraEnabled public Integer activeAquaWOs;
        @AuraEnabled public Integer totalControllersDeployed;
    }

    public class InstallTicketRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String url;
        @AuraEnabled public Id     workOrderId;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public Id     communityId;
        @AuraEnabled public String communityName;
        @AuraEnabled public Date   scheduledDate;
        @AuraEnabled public String scheduledDateDisplay;
        @AuraEnabled public String status;
        @AuraEnabled public String statusCss;
        @AuraEnabled public Decimal controllerCount;
        @AuraEnabled public Decimal headsCount;
        @AuraEnabled public Decimal flagsRequired;
        @AuraEnabled public String fmName;
        @AuraEnabled public String crewName;
    }

    public class CheckTicketRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String url;
        @AuraEnabled public Id     workOrderId;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public Id     communityId;
        @AuraEnabled public String communityName;
        @AuraEnabled public Date   scheduledDate;
        @AuraEnabled public String scheduledDateDisplay;
        @AuraEnabled public Integer checkNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String urgency;      // Overdue / Due Today / Upcoming
        @AuraEnabled public String urgencyCss;
        @AuraEnabled public String wateringInstructions;
        @AuraEnabled public String assignedToName;
        @AuraEnabled public Decimal turfScore;
        @AuraEnabled public Decimal landscapeScore;
        @AuraEnabled public Boolean systemTampered;
    }

    public class PickupTicketRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String url;
        @AuraEnabled public Id     workOrderId;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public Id     communityId;
        @AuraEnabled public String communityName;
        @AuraEnabled public Date   scheduledDate;
        @AuraEnabled public String scheduledDateDisplay;
        @AuraEnabled public String status;
        @AuraEnabled public String statusCss;
        @AuraEnabled public String assignedToName;
        @AuraEnabled public Decimal controllersRetrieved;
        @AuraEnabled public Decimal headsRetrieved;
        @AuraEnabled public String pickupNotes;
    }

    public class InventoryRow {
        @AuraEnabled public String itemType;
        @AuraEnabled public String location;    // Shop / On-Site / Master
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Id     workOrderId;
        @AuraEnabled public String workOrderName;
    }

    public class MasterInventoryRow {
        @AuraEnabled public String itemType;
        @AuraEnabled public Decimal totalPurchased;
        @AuraEnabled public Decimal atShop;
        @AuraEnabled public Decimal onSite;
        @AuraEnabled public Decimal deployed;
        @AuraEnabled public Decimal variance;   // totalPurchased - atShop - onSite - deployed
    }

    public class WateringScheduleRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public Id     communityId;
        @AuraEnabled public String communityName;
        @AuraEnabled public String scheduleType;  // Establishment / Seasonal
        @AuraEnabled public Integer weekNumber;
        @AuraEnabled public String month;
        @AuraEnabled public Decimal runDurationMin;
        @AuraEnabled public String runFrequency;
        @AuraEnabled public Decimal runTimePct;
        @AuraEnabled public String notes;
        @AuraEnabled public Integer effectiveYear;
    }

    // ─────────────────────────────────────────────
    // KPI OVERVIEW
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static AquaKpis getAquaKpis() {
        AquaKpis k = new AquaKpis();
        try {
            Date today = Date.today();
            k.openInstallTickets = [SELECT COUNT() FROM Aqua_Install_Ticket__c
                WHERE Status__c != 'Closed'];
            k.overdueCheckTickets = [SELECT COUNT() FROM Aqua_Check_Ticket__c
                WHERE Status__c != 'Closed'
                  AND Scheduled_Date__c < :today];
            k.openCheckTickets = [SELECT COUNT() FROM Aqua_Check_Ticket__c
                WHERE Status__c != 'Closed'];
            k.openPickupTickets = [SELECT COUNT() FROM Aqua_Pickup_Ticket__c
                WHERE Status__c != 'Closed'];
            k.activeAquaWOs = [SELECT COUNT() FROM Work_Order__c
                WHERE Aqua_Community__c = true
                  AND Schedule_Locked__c = true
                  AND Status__c != 'Approved'
                  AND Status__c != 'Closed'];
            // Count controllers from Aqua_Inventory__c at On-Site location
            List<AggregateResult> ar = [
                SELECT SUM(Quantity__c) tot FROM Aqua_Inventory__c
                WHERE Item_Type__c = 'Controller'
                  AND Location__c = 'On-Site'
            ];
            k.totalControllersDeployed = ar[0].get('tot') != null
                ? Integer.valueOf((Decimal)ar[0].get('tot')) : 0;
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'getAquaKpis', null, e.getMessage());
        }
        return k;
    }

    // ─────────────────────────────────────────────
    // INSTALL TICKETS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<InstallTicketRow> getOpenInstallTickets() {
        List<InstallTicketRow> rows = new List<InstallTicketRow>();
        try {
            Date today = Date.today();
            for (Aqua_Install_Ticket__c t : [
                SELECT Id, Name, Work_Order__c, Aqua_Community__c, Aqua_Community__r.Name,
                       Scheduled_Date__c, Status__c, Controller_Count__c,
                       Heads_Count__c, Aqua_Flags_Required__c,
                       FM_Assignment__r.Name, Crew__c
                FROM Aqua_Install_Ticket__c
                WHERE Status__c != 'Closed'
                ORDER BY Scheduled_Date__c ASC NULLS LAST
                LIMIT 100
            ]) {
                InstallTicketRow r = new InstallTicketRow();
                r.id              = t.Id;
                r.name            = t.Name;
                r.url             = '/' + t.Id;
                r.workOrderId     = t.Work_Order__c;
                r.communityId     = t.Aqua_Community__c;
                r.communityName   = t.Aqua_Community__r != null ? t.Aqua_Community__r.Name : '—';
                r.scheduledDate   = t.Scheduled_Date__c;
                r.scheduledDateDisplay = t.Scheduled_Date__c != null
                    ? t.Scheduled_Date__c.format() : '—';
                r.status          = t.Status__c;
                r.controllerCount = t.Controller_Count__c;
                r.headsCount      = t.Heads_Count__c;
                r.flagsRequired   = t.Aqua_Flags_Required__c;
                r.fmName          = t.FM_Assignment__r != null ? t.FM_Assignment__r.Name : '—';
                r.crewName        = String.isNotBlank(t.Crew__c) ? t.Crew__c : '—';

                // Status chip
                if (t.Status__c == 'Scheduled') {
                    r.statusCss = t.Scheduled_Date__c != null && t.Scheduled_Date__c < today
                        ? 'chip chip-red' : 'chip chip-blue';
                } else if (t.Status__c == 'In Progress') {
                    r.statusCss = 'chip chip-amber';
                } else {
                    r.statusCss = 'chip chip-gray';
                }
                rows.add(r);
            }

            // Resolve Work_Order__c names separately (avoids WorkOrder.Name polymorphic issue)
            Set<Id> woIds = new Set<Id>();
            for (InstallTicketRow r : rows) { if (r.workOrderId != null) woIds.add(r.workOrderId); }
            if (!woIds.isEmpty()) {
                Map<Id, String> woNames = new Map<Id, String>();
                for (Work_Order__c wo : [SELECT Id, Name FROM Work_Order__c WHERE Id IN :woIds]) {
                    woNames.put(wo.Id, wo.Name);
                }
                for (InstallTicketRow r : rows) {
                    r.workOrderName = woNames.containsKey(r.workOrderId)
                        ? woNames.get(r.workOrderId) : '—';
                }
            }
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'getOpenInstallTickets', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // CHECK TICKETS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<CheckTicketRow> getOpenCheckTickets() {
        List<CheckTicketRow> rows = new List<CheckTicketRow>();
        try {
            Date today = Date.today();
            for (Aqua_Check_Ticket__c t : [
                SELECT Id, Name, Work_Order__c, Aqua_Community__c, Aqua_Community__r.Name,
                       Scheduled_Date__c, Check_Number__c, Status__c,
                       Watering_Instructions__c, Assigned_To__r.Name,
                       Turf_Condition_Score__c, Landscape_Score__c, System_Tampered__c
                FROM Aqua_Check_Ticket__c
                WHERE Status__c != 'Closed'
                ORDER BY Scheduled_Date__c ASC NULLS LAST
                LIMIT 200
            ]) {
                CheckTicketRow r = new CheckTicketRow();
                r.id                  = t.Id;
                r.name                = t.Name;
                r.url                 = '/' + t.Id;
                r.workOrderId         = t.Work_Order__c;
                r.communityId         = t.Aqua_Community__c;
                r.communityName       = t.Aqua_Community__r != null ? t.Aqua_Community__r.Name : '—';
                r.scheduledDate       = t.Scheduled_Date__c;
                r.scheduledDateDisplay = t.Scheduled_Date__c != null
                    ? t.Scheduled_Date__c.format() : '—';
                r.checkNumber         = t.Check_Number__c != null
                    ? Integer.valueOf(t.Check_Number__c) : null;
                r.status              = t.Status__c;
                r.wateringInstructions = t.Watering_Instructions__c;
                r.assignedToName      = t.Assigned_To__r != null ? t.Assigned_To__r.Name : '—';
                r.turfScore           = t.Turf_Condition_Score__c;
                r.landscapeScore      = t.Landscape_Score__c;
                r.systemTampered      = t.System_Tampered__c;

                // Urgency
                if (t.Scheduled_Date__c != null && t.Scheduled_Date__c < today) {
                    r.urgency    = 'Overdue';
                    r.urgencyCss = 'chip chip-red';
                } else if (t.Scheduled_Date__c != null && t.Scheduled_Date__c == today) {
                    r.urgency    = 'Due Today';
                    r.urgencyCss = 'chip chip-amber';
                } else {
                    r.urgency    = 'Upcoming';
                    r.urgencyCss = 'chip chip-blue';
                }
                rows.add(r);
            }

            // Resolve WO names
            Set<Id> woIds = new Set<Id>();
            for (CheckTicketRow r : rows) { if (r.workOrderId != null) woIds.add(r.workOrderId); }
            if (!woIds.isEmpty()) {
                Map<Id, String> woNames = new Map<Id, String>();
                for (Work_Order__c wo : [SELECT Id, Name FROM Work_Order__c WHERE Id IN :woIds]) {
                    woNames.put(wo.Id, wo.Name);
                }
                for (CheckTicketRow r : rows) {
                    r.workOrderName = woNames.containsKey(r.workOrderId)
                        ? woNames.get(r.workOrderId) : '—';
                }
            }
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'getOpenCheckTickets', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // PICKUP TICKETS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<PickupTicketRow> getOpenPickupTickets() {
        List<PickupTicketRow> rows = new List<PickupTicketRow>();
        try {
            for (Aqua_Pickup_Ticket__c t : [
                SELECT Id, Name, Work_Order__c, Aqua_Community__c, Aqua_Community__r.Name,
                       Scheduled_Date__c, Status__c, Assigned_To__r.Name,
                       Controllers_Retrieved__c, Heads_Retrieved__c, Pickup_Notes__c
                FROM Aqua_Pickup_Ticket__c
                WHERE Status__c != 'Closed'
                ORDER BY Scheduled_Date__c ASC NULLS LAST
                LIMIT 100
            ]) {
                PickupTicketRow r = new PickupTicketRow();
                r.id                   = t.Id;
                r.name                 = t.Name;
                r.url                  = '/' + t.Id;
                r.workOrderId          = t.Work_Order__c;
                r.communityId          = t.Aqua_Community__c;
                r.communityName        = t.Aqua_Community__r != null ? t.Aqua_Community__r.Name : '—';
                r.scheduledDate        = t.Scheduled_Date__c;
                r.scheduledDateDisplay = t.Scheduled_Date__c != null
                    ? t.Scheduled_Date__c.format() : '—';
                r.status               = t.Status__c;
                r.statusCss            = t.Status__c == 'Scheduled' ? 'chip chip-blue'
                                       : t.Status__c == 'In Progress' ? 'chip chip-amber'
                                       : 'chip chip-gray';
                r.assignedToName       = t.Assigned_To__r != null ? t.Assigned_To__r.Name : '—';
                r.controllersRetrieved = t.Controllers_Retrieved__c;
                r.headsRetrieved       = t.Heads_Retrieved__c;
                r.pickupNotes          = t.Pickup_Notes__c;
                rows.add(r);
            }

            // Resolve WO names
            Set<Id> woIds = new Set<Id>();
            for (PickupTicketRow r : rows) { if (r.workOrderId != null) woIds.add(r.workOrderId); }
            if (!woIds.isEmpty()) {
                Map<Id, String> woNames = new Map<Id, String>();
                for (Work_Order__c wo : [SELECT Id, Name FROM Work_Order__c WHERE Id IN :woIds]) {
                    woNames.put(wo.Id, wo.Name);
                }
                for (PickupTicketRow r : rows) {
                    r.workOrderName = woNames.containsKey(r.workOrderId)
                        ? woNames.get(r.workOrderId) : '—';
                }
            }
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'getOpenPickupTickets', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // INVENTORY — 3-Location Flat List
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<InventoryRow> getInventoryByLocation() {
        List<InventoryRow> rows = new List<InventoryRow>();
        try {
            Set<Id> woIds = new Set<Id>();
            List<Aqua_Inventory__c> invList = [
                SELECT Id, Item_Type__c, Location__c, Quantity__c, Work_Order__c
                FROM Aqua_Inventory__c
                ORDER BY Location__c, Item_Type__c
                LIMIT 500
            ];
            for (Aqua_Inventory__c inv : invList) {
                if (inv.Work_Order__c != null) woIds.add(inv.Work_Order__c);
            }
            Map<Id, String> woNames = new Map<Id, String>();
            if (!woIds.isEmpty()) {
                for (Work_Order__c wo : [SELECT Id, Name FROM Work_Order__c WHERE Id IN :woIds]) {
                    woNames.put(wo.Id, wo.Name);
                }
            }
            for (Aqua_Inventory__c inv : invList) {
                InventoryRow r = new InventoryRow();
                r.itemType      = inv.Item_Type__c;
                r.location      = inv.Location__c;
                r.quantity      = inv.Quantity__c;
                r.workOrderId   = inv.Work_Order__c;
                r.workOrderName = woNames.containsKey(inv.Work_Order__c)
                    ? woNames.get(inv.Work_Order__c) : null;
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'getInventoryByLocation', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // MASTER INVENTORY — aggregated 3-location summary
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<MasterInventoryRow> getMasterInventory() {
        List<MasterInventoryRow> rows = new List<MasterInventoryRow>();
        try {
            // Aggregate from Aqua_Inventory__c by item type and location
            Map<String, MasterInventoryRow> byType = new Map<String, MasterInventoryRow>();
            for (AggregateResult ar : [
                SELECT Item_Type__c iType, Location__c loc, SUM(Quantity__c) qty
                FROM Aqua_Inventory__c
                GROUP BY Item_Type__c, Location__c
            ]) {
                String iType = (String)ar.get('iType');
                String loc   = (String)ar.get('loc');
                Decimal qty  = ar.get('qty') != null ? (Decimal)ar.get('qty') : 0;
                if (!byType.containsKey(iType)) {
                    byType.put(iType, new MasterInventoryRow());
                    byType.get(iType).itemType = iType;
                }
                MasterInventoryRow row = byType.get(iType);
                if (loc == 'Shop')    row.atShop   = (row.atShop  != null ? row.atShop  : 0) + qty;
                if (loc == 'On-Site') row.onSite   = (row.onSite  != null ? row.onSite  : 0) + qty;
                if (loc == 'Deployed')row.deployed = (row.deployed != null ? row.deployed : 0) + qty;
            }

            // Total purchased from master table
            for (Aqua_Master_Inventory__c m : [
                SELECT Item_Type__c, Total_Purchased__c FROM Aqua_Master_Inventory__c
            ]) {
                if (byType.containsKey(m.Item_Type__c)) {
                    byType.get(m.Item_Type__c).totalPurchased = m.Total_Purchased__c;
                } else {
                    MasterInventoryRow row = new MasterInventoryRow();
                    row.itemType      = m.Item_Type__c;
                    row.totalPurchased = m.Total_Purchased__c;
                    byType.put(m.Item_Type__c, row);
                }
            }

            // Calculate variance: totalPurchased - (atShop + onSite + deployed)
            for (MasterInventoryRow row : byType.values()) {
                Decimal shop     = row.atShop    != null ? row.atShop    : 0;
                Decimal onSite   = row.onSite    != null ? row.onSite    : 0;
                Decimal deployed = row.deployed  != null ? row.deployed  : 0;
                Decimal total    = row.totalPurchased != null ? row.totalPurchased : 0;
                row.variance = total - shop - onSite - deployed;
            }
            rows.addAll(byType.values());
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'getMasterInventory', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // WATERING SCHEDULES
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<WateringScheduleRow> getWateringSchedules(Id communityId) {
        List<WateringScheduleRow> rows = new List<WateringScheduleRow>();
        try {
            String q = 'SELECT Id, Community__c, Community__r.Name, Schedule_Type__c, '
                     + 'Week_Number__c, Month__c, Run_Duration_Min__c, Run_Frequency__c, '
                     + 'Run_Time_Pct__c, Notes__c, Effective_Year__c '
                     + 'FROM Aqua_Watering_Schedule__c ';
            if (communityId != null) {
                q += 'WHERE Community__c = :communityId ';
            }
            q += 'ORDER BY Schedule_Type__c, Week_Number__c ASC NULLS LAST LIMIT 200';

            for (Aqua_Watering_Schedule__c s : Database.query(q)) {
                WateringScheduleRow r = new WateringScheduleRow();
                r.id             = s.Id;
                r.communityId    = s.Community__c;
                r.communityName  = s.Community__r != null ? s.Community__r.Name : '—';
                r.scheduleType   = s.Schedule_Type__c;
                r.weekNumber     = s.Week_Number__c != null ? Integer.valueOf(s.Week_Number__c) : null;
                r.month          = s.Month__c;
                r.runDurationMin = s.Run_Duration_Min__c;
                r.runFrequency   = s.Run_Frequency__c;
                r.runTimePct     = s.Run_Time_Pct__c;
                r.notes          = s.Notes__c;
                r.effectiveYear  = s.Effective_Year__c != null
                    ? Integer.valueOf(s.Effective_Year__c) : null;
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'getWateringSchedules', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // ACTION: CLOSE INSTALL TICKET
    // AquaService.closeInstallTicket(Id, Decimal, Decimal, String)
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void closeInstallTicket(Id ticketId, Decimal controllerCount,
                                          Decimal headsCount, String notes) {
        try {
            AquaService.closeInstallTicket(ticketId, controllerCount, headsCount, notes);
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'closeInstallTicket', ticketId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // ACTION: CLOSE CHECK TICKET
    // AquaService.closeCheckTicket(Id, Boolean, Decimal, Decimal, String)
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void closeCheckTicket(
        Id ticketId, Boolean systemTampered,
        Decimal turfScore, Decimal landscapeScore,
        String notes
    ) {
        try {
            AquaService.closeCheckTicket(ticketId, systemTampered, turfScore, landscapeScore, notes);
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'closeCheckTicket', ticketId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // ACTION: CLOSE PICKUP TICKET
    // AquaService.closePickupTicket(Id, Decimal, Decimal, String)
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void closePickupTicket(Id ticketId, Decimal controllersRetrieved,
                                         Decimal headsRetrieved, String notes) {
        try {
            AquaService.closePickupTicket(ticketId, controllersRetrieved, headsRetrieved, notes);
        } catch (Exception e) {
            ErrorLogService.log('AquaController', 'closePickupTicket', ticketId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}