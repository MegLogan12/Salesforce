public with sharing class DivisionCompareController {

    public class CompareView {
        @AuraEnabled public Boolean          blocked;
        @AuraEnabled public String           blockerReason;
        @AuraEnabled public List<DivisionRow> rows;
    }

    public class DivisionRow {
        @AuraEnabled public Id      divisionId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  region;
        @AuraEnabled public String  metricLabel;
        @AuraEnabled public Decimal metricValue;
        @AuraEnabled public Integer rank;
    }

    // KPI fields written by DivisionKpiRecalcBatch onto Builder_Market Account records.
    private static final Set<String> KPI_FIELDS = new Set<String>{
        'Division_Revenue_T12M__c', 'Division_GP_Pct__c', 'On_Time_Completion_Pct__c',
        'Open_WO_Count__c', 'Open_PO_Count__c', 'Open_Warranty_Count__c',
        'Open_NFI_Count__c', 'Active_Communities_Count__c', 'Active_Lot_Count__c'
    };

    // Short aliases the LWC metric selector passes; resolved before field validation.
    private static final Map<String, String> METRIC_ALIAS = new Map<String, String>{
        'revenue' => 'Division_Revenue_T12M__c',
        'ontime'  => 'On_Time_Completion_Pct__c',
        'gp'      => 'Division_GP_Pct__c'
    };

    @AuraEnabled(cacheable=true)
    public static CompareView getCompare(Id parentAccountId, String metric) {
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Account');
        }

        if (!kpiFieldsExist()) {
            CompareView blocked = new CompareView();
            blocked.blocked       = true;
            blocked.blockerReason = 'KPI fields not yet available on Account';
            blocked.rows          = new List<DivisionRow>();
            return blocked;
        }

        // Resolve short alias to full field API name.
        if (METRIC_ALIAS.containsKey(metric)) {
            metric = METRIC_ALIAS.get(metric);
        }
        if (!KPI_FIELDS.contains(metric)) {
            throw new AuraHandledException('Invalid metric: ' + metric);
        }

        // Dynamic SOQL includes all KPI fields so a.get(metric) works for any valid metric.
        String soql = 'SELECT Id, Name, Division_Region__c, ' +
            String.join(new List<String>(KPI_FIELDS), ', ') +
            ' FROM Account WHERE ParentId = :parentAccountId ORDER BY Name';
        List<Account> divisions = Database.query(soql);

        List<DivisionRow> rows = buildRows(divisions, metric);

        CompareView view = new CompareView();
        view.blocked       = false;
        view.blockerReason = null;
        view.rows          = rows;
        return view;
    }

    @TestVisible
    private static Boolean kpiFieldsExist() {
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Account.fields.getMap();
        for (String f : KPI_FIELDS) {
            if (!fields.containsKey(f.toLowerCase())) {
                return false;
            }
        }
        return true;
    }

    @TestVisible
    private static List<DivisionRow> buildRows(List<Account> divisions, String metric) {
        List<DivisionRow> rows = new List<DivisionRow>();
        for (Account a : divisions) {
            DivisionRow r = new DivisionRow();
            r.divisionId  = a.Id;
            r.name        = a.Name;
            r.region      = a.Division_Region__c;
            r.metricLabel = metric;
            Object rawVal = a.get(metric);
            r.metricValue = (rawVal instanceof Decimal) ? (Decimal) rawVal : null;
            r.rank        = 0;
            rows.add(r);
        }
        rows.sort(new DivisionRowComparator());
        Integer i = 1;
        for (DivisionRow r : rows) {
            r.rank = i++;
        }
        return rows;
    }

    private class DivisionRowComparator implements Comparator<DivisionRow> {
        public Integer compare(DivisionRow a, DivisionRow b) {
            Decimal av = (a.metricValue != null) ? a.metricValue : -1;
            Decimal bv = (b.metricValue != null) ? b.metricValue : -1;
            if (av > bv) return -1;
            if (av < bv) return 1;
            return 0;
        }
    }
}
