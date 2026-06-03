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

    // KPI fields that must exist on Account before division comparison can function.
    // These are a COO batch prerequisite and are not yet deployed to the org.
    private static final Set<String> KPI_FIELDS = new Set<String>{
        'Revenue_MTD__c', 'On_Time_Pct__c', 'GP_Pct__c'
    };

    @AuraEnabled(cacheable=true)
    public static CompareView getCompare(Id parentAccountId, String metric) {
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Account');
        }

        if (!kpiFieldsExist()) {
            CompareView blocked = new CompareView();
            blocked.blocked      = true;
            blocked.blockerReason = 'KPI batch not yet scheduled — COO build prerequisite';
            blocked.rows         = new List<DivisionRow>();
            return blocked;
        }

        // Reached only when KPI fields are present on Account.
        // Queries child accounts and returns ranked division rows.
        List<Account> divisions = [
            SELECT Id, Name, Division_Region__c
            FROM Account
            WHERE ParentId = :parentAccountId
            ORDER BY Name
        ];

        List<DivisionRow> rows = buildRows(divisions, metric);

        CompareView view = new CompareView();
        view.blocked      = false;
        view.blockerReason = null;
        view.rows         = rows;
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
        Integer rankCounter = 1;
        for (Account a : divisions) {
            DivisionRow r = new DivisionRow();
            r.divisionId  = a.Id;
            r.name        = a.Name;
            r.region      = a.Division_Region__c;
            r.metricLabel = metric;
            // Metric value read dynamically once KPI fields exist
            Object rawVal = a.get(metric);
            r.metricValue = (rawVal instanceof Decimal) ? (Decimal) rawVal : null;
            r.rank        = rankCounter++;
            rows.add(r);
        }
        // Sort descending by metricValue for rank
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
