/**
 * LovingWorkOrderListController
 *
 * Backs the lovingWorkOrderListView LWC (Work Orders list view).
 * Returns filtered Work Order rows and filter option sets.
 * Revenue KPI data is served by LovingWorkOrderRevenueService.
 *
 * @group Work Order Page
 */
public with sharing class LovingWorkOrderListController {

    // ─────────────────────────────────────────────────────────────────────────
    // Inner DTOs
    // ─────────────────────────────────────────────────────────────────────────

    public class WorkOrderRowDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;            // WO #
        @AuraEnabled public String  workOrderType;
        @AuraEnabled public String  accountName;     // Parent Account / Builder
        @AuraEnabled public String  communityName;
        @AuraEnabled public String  lotName;
        @AuraEnabled public String  fmName;
        @AuraEnabled public String  status;
        @AuraEnabled public Decimal goalHrs;         // null if not yet available (WLR pending)
        @AuraEnabled public Decimal actualHrs;       // SUM Rippling_Time_Entry__c.Hours__c
        @AuraEnabled public Date    scheduledDate;
        @AuraEnabled public String  typeChipClass;
        @AuraEnabled public String  statusChipClass;
        @AuraEnabled public String  rowClass;        // 'row-fj-triggered' when FJ Triggered
    }

    public class FilterOptionsDTO {
        @AuraEnabled public List<SelectOption> fmOptions;
        @AuraEnabled public List<SelectOption> statusOptions;
    }

    public class SelectOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public SelectOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class WorkOrderListResultDTO {
        @AuraEnabled public List<WorkOrderRowDTO>       rows;
        @AuraEnabled public List<Id>                   workOrderIds;  // for revenue service
        @AuraEnabled public String                     filterLabel;
        @AuraEnabled public Integer                    totalCount;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main query method
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static WorkOrderListResultDTO getWorkOrders(
        String typeFilter,
        String fmFilter,
        String statusFilter,
        String search
    ) {
        WorkOrderListResultDTO result = new WorkOrderListResultDTO();
        result.rows = new List<WorkOrderRowDTO>();
        result.workOrderIds = new List<Id>();

        // ── Build dynamic SOQL ────────────────────────────────────────────────
        String baseQuery = 'SELECT Id, Name, Work_Order_Type__c, Status__c, Scheduled_Date__c, '
            + 'Field_Manager__r.Name, Field_Manager__c, '
            + 'Parent_Account__r.Name, '
            + 'Community__r.Name, '
            + 'Lot__r.Name '
            + 'FROM Work_Order__c '
            + 'WHERE Status__c != \'Closed\'';

        List<String> filters = new List<String>();
        List<String> labelParts = new List<String>();

        if (String.isNotBlank(typeFilter) && typeFilter != 'All Types') {
            filters.add('Work_Order_Type__c = :typeFilter');
            labelParts.add(typeFilter);
        }
        if (String.isNotBlank(fmFilter) && fmFilter != 'All FMs') {
            filters.add('Field_Manager__r.Name = :fmFilter');
            labelParts.add(fmFilter);
        }
        if (String.isNotBlank(statusFilter) && statusFilter != 'All Statuses') {
            filters.add('Status__c = :statusFilter');
            labelParts.add(statusFilter);
        }
        if (String.isNotBlank(search)) {
            String likeVal = '%' + String.escapeSingleQuotes(search) + '%';
            filters.add('(Name LIKE :likeVal OR Community__r.Name LIKE :likeVal OR Lot__r.Name LIKE :likeVal)');
            labelParts.add('Search: ' + search);
        }

        String likeVal = String.isNotBlank(search) ? '%' + String.escapeSingleQuotes(search) + '%' : null;

        if (!filters.isEmpty()) {
            baseQuery += ' AND (' + String.join(filters, ' AND ') + ')';
        }

        baseQuery += ' ORDER BY Scheduled_Date__c DESC NULLS LAST LIMIT 200';

        List<Work_Order__c> wos;
        try {
            wos = Database.query(baseQuery);
        } catch (Exception e) {
            result.rows = new List<WorkOrderRowDTO>();
            result.workOrderIds = new List<Id>();
            result.filterLabel = 'Error loading work orders';
            result.totalCount = 0;
            return result;
        }

        // ── Actual hours map: WO Id → SUM hours ──────────────────────────────
        Set<Id> woIds = new Set<Id>();
        for (Work_Order__c w : wos) { woIds.add(w.Id); }

        Map<Id, Decimal> actualHrsMap = new Map<Id, Decimal>();
        if (!woIds.isEmpty()) {
            try {
                for (AggregateResult ar : [
                    SELECT Work_Order__c woId, SUM(Hours__c) total
                    FROM Rippling_Time_Entry__c
                    WHERE Work_Order__c IN :woIds
                    GROUP BY Work_Order__c
                ]) {
                    actualHrsMap.put(
                        (Id) ar.get('woId'),
                        (Decimal)(ar.get('total') != null ? ar.get('total') : 0)
                    );
                }
            } catch (Exception e) {
                // Time entries may not exist yet — default to 0
            }
        }

        // ── Build rows ────────────────────────────────────────────────────────
        for (Work_Order__c w : wos) {
            WorkOrderRowDTO row = new WorkOrderRowDTO();
            row.id            = w.Id;
            row.name          = w.Name;
            row.workOrderType = w.Work_Order_Type__c;
            row.accountName   = w.Parent_Account__r != null ? w.Parent_Account__r.Name : '';
            row.communityName = w.Community__r != null  ? w.Community__r.Name : '';
            row.lotName       = w.Lot__r != null        ? w.Lot__r.Name : '';
            row.fmName        = w.Field_Manager__r != null ? w.Field_Manager__r.Name : '';
            row.status        = w.Status__c;
            row.goalHrs       = null;  // WLR aggregation deferred
            row.actualHrs     = actualHrsMap.containsKey(w.Id) ? actualHrsMap.get(w.Id) : null;
            row.scheduledDate = w.Scheduled_Date__c;
            row.typeChipClass = typeChipClass(w.Work_Order_Type__c);
            row.statusChipClass = statusChipClass(w.Status__c);
            row.rowClass      = (w.Status__c == 'FJ Triggered') ? 'row-fj-triggered' : '';

            result.rows.add(row);
            result.workOrderIds.add(w.Id);
        }

        result.totalCount  = result.rows.size();
        result.filterLabel = labelParts.isEmpty()
            ? 'All Active Work Orders'
            : 'Filtered: ' + String.join(labelParts, ' · ');

        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Filter options
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static FilterOptionsDTO getFilterOptions() {
        FilterOptionsDTO opts = new FilterOptionsDTO();
        opts.fmOptions     = new List<SelectOption>();
        opts.statusOptions = new List<SelectOption>();

        opts.fmOptions.add(new SelectOption('All FMs', 'All FMs'));
        opts.statusOptions.add(new SelectOption('All Statuses', 'All Statuses'));

        // FM options from active Work_Order__c Field_Manager__c users
        Set<String> fmNames = new Set<String>();
        for (AggregateResult ar : [
            SELECT Field_Manager__r.Name fmName
            FROM Work_Order__c
            WHERE Field_Manager__c != null
              AND Status__c != 'Closed'
            GROUP BY Field_Manager__r.Name
            ORDER BY Field_Manager__r.Name
            LIMIT 50
        ]) {
            String nm = (String) ar.get('fmName');
            if (String.isNotBlank(nm)) {
                fmNames.add(nm);
            }
        }
        for (String n : fmNames) {
            opts.fmOptions.add(new SelectOption(n, n));
        }

        // Status options from Status__c picklist
        Schema.DescribeFieldResult dfr = Work_Order__c.Status__c.getDescribe();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                opts.statusOptions.add(new SelectOption(pe.getLabel(), pe.getValue()));
            }
        }

        return opts;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Chip class helpers
    // ─────────────────────────────────────────────────────────────────────────

    private static String typeChipClass(String woType) {
        if (woType == null) return 'jt-chip';
        if (woType == 'Production Install') return 'jt-chip jt-install';
        if (woType == 'Finished Job')       return 'jt-chip jt-fj';
        if (woType == 'Warranty')           return 'jt-chip jt-warranty';
        if (woType == 'Customer Care')      return 'jt-chip jt-cc';
        if (woType == 'Site Visit')         return 'chip cb2';
        if (woType == 'Lawn Care')          return 'chip cg';
        if (woType == 'Aqua Service')       return 'chip ct';
        return 'chip cgr';
    }

    private static String statusChipClass(String status) {
        if (status == null) return 'chip cgr';
        String s = status.toLowerCase();
        if (s.contains('closed') || s.contains('complete') || s.contains('approved')) return 'chip cg';
        if (s.contains('scheduled') || s.contains('in progress') || s.contains('progress')) return 'chip cb2';
        if (s.contains('hold') || s.contains('blocked') || s.contains('breach') || s.contains('red')) return 'chip cr';
        if (s.contains('pending') || s.contains('triggered') || s.contains('review')) return 'chip ca';
        return 'chip cgr';
    }
}