public with sharing class LovingPoPipelinePageController {
    public List<StageColumn> stages { get; private set; }
    public Integer openCount { get; private set; }
    public Integer reviewCount { get; private set; }
    public Integer forecastCount { get; private set; }
    public Integer clearCount { get; private set; }
    public Integer schedulingCount { get; private set; }
    public String totalValueLabel { get; private set; }

    private static final List<StageDef> STAGE_DEFS = new List<StageDef>{
        new StageDef('received', '1', 'PO Received', 'PO is in Salesforce and ready for package review.', 'stage'),
        new StageDef('packageCheck', '2', 'Package Match Check', 'PO line work is being checked against the package source of truth.', 'stage warn'),
        new StageDef('csmReview', '3', 'CSM Review', 'Mismatch or missing data is waiting on Customer Success.', 'stage warn'),
        new StageDef('takeoffRequested', '4', 'Takeoff Requested', 'Package matched or approved exception; create the FM takeoff.', 'stage forecast'),
        new StageDef('takeoffScheduled', '5', 'Takeoff Scheduled', 'Field Manager takeoff appointment is on the calendar.', 'stage forecast'),
        new StageDef('takeoffProgress', '6', 'Takeoff In Progress', 'Field Manager is measuring and confirming scope.', 'stage forecast'),
        new StageDef('takeoffComplete', '7', 'Takeoff Complete', 'Takeoff is complete and work is ready for WorkOrder creation.', 'stage clear'),
        new StageDef('workOrderCreated', '8', 'WorkOrder Created', 'Standard WorkOrder has been created from the completed takeoff.', 'stage schedule'),
        new StageDef('clear', '9', 'Clear for Schedule', 'Scheduler can place the work on the field calendar.', 'stage clear')
    };

    public LovingPoPipelinePageController() {
        load();
    }

    private void load() {
        stages = new List<StageColumn>();
        Map<String, StageColumn> byKey = new Map<String, StageColumn>();
        for (StageDef def : STAGE_DEFS) {
            StageColumn col = new StageColumn(def);
            stages.add(col);
            byKey.put(def.key, col);
        }

        Decimal totalValue = 0;
        for (Purchase_Order__c po : [
            SELECT Id, Name, Status__c, Pipeline_Stage__c, Pipeline_Bucket__c,
                   Package_BMG_Status__c, Total_Amount__c, Requested_Install_Date__c,
                   Estimated_Start_Date__c, Builder_Account__r.Name, Community_Name__c,
                   Community__r.Name, Lot_Number__c, Lot__r.Name
            FROM Purchase_Order__c
            WHERE (Status__c NOT IN ('Cancelled', 'Closed', 'NFI') OR Status__c = null)
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            String key = mapToBoardColumn(po.Pipeline_Stage__c, po.Status__c, po.Pipeline_Bucket__c);
            if (!byKey.containsKey(key)) {
                key = 'received';
            }
            byKey.get(key).cards.add(new Card(po));
            if (po.Total_Amount__c != null) {
                totalValue += po.Total_Amount__c;
            }
        }

        openCount = 0;
        for (StageColumn col : stages) {
            col.count = col.cards.size();
            openCount += col.count;
        }
        reviewCount = byKey.get('csmReview').count + byKey.get('packageCheck').count;
        forecastCount = byKey.get('takeoffRequested').count
            + byKey.get('takeoffScheduled').count
            + byKey.get('takeoffProgress').count
            + byKey.get('takeoffComplete').count;
        clearCount = byKey.get('clear').count;
        schedulingCount = byKey.get('workOrderCreated').count;
        totalValueLabel = formatMoney(totalValue);
    }

    private static String mapToBoardColumn(String pipelineStage, String status, String bucket) {
        return PurchaseOrderTimingService.mapStageToBoardColumn(
            String.isBlank(pipelineStage)
                ? PurchaseOrderTimingService.calculatePipelineStage(
                    new Purchase_Order__c(
                        Status__c = status,
                        Pipeline_Bucket__c = bucket
                    )
                )
                : pipelineStage,
            status
        );
    }

    private static String formatMoney(Decimal amount) {
        if (amount == null || amount == 0) return '$0';
        if (amount >= 1000000) return '$' + String.valueOf((amount / 1000000).setScale(1)) + 'M';
        if (amount >= 1000) return '$' + String.valueOf((amount / 1000).setScale(1)) + 'k';
        return '$' + String.valueOf(amount.setScale(0));
    }

    private class StageDef {
        String key;
        String numberLabel;
        String label;
        String rule;
        String cssClass;
        StageDef(String key, String numberLabel, String label, String rule, String cssClass) {
            this.key = key;
            this.numberLabel = numberLabel;
            this.label = label;
            this.rule = rule;
            this.cssClass = cssClass;
        }
    }

    public class StageColumn {
        public String key { get; private set; }
        public String numberLabel { get; private set; }
        public String label { get; private set; }
        public String rule { get; private set; }
        public String cssClass { get; private set; }
        public Integer count { get; set; }
        public List<Card> cards { get; private set; }
        public Boolean getHasCards() {
            return !cards.isEmpty();
        }
        StageColumn(StageDef def) {
            key = def.key;
            numberLabel = def.numberLabel;
            label = def.label;
            rule = def.rule;
            cssClass = def.cssClass;
            count = 0;
            cards = new List<Card>();
        }
    }

    public class Card {
        public Id id { get; private set; }
        public String name { get; private set; }
        public String recordUrl { get; private set; }
        public String builder { get; private set; }
        public String community { get; private set; }
        public String lot { get; private set; }
        public String amount { get; private set; }
        public String status { get; private set; }
        public String packageStatus { get; private set; }
        public String dateLabel { get; private set; }

        Card(Purchase_Order__c po) {
            id = po.Id;
            name = po.Name;
            recordUrl = '/lightning/r/Purchase_Order__c/' + po.Id + '/view';
            builder = po.Builder_Account__r != null ? po.Builder_Account__r.Name : 'No builder';
            community = po.Community__r != null ? po.Community__r.Name : po.Community_Name__c;
            if (String.isBlank(community)) community = 'No community';
            lot = po.Lot__r != null ? po.Lot__r.Name : po.Lot_Number__c;
            if (String.isBlank(lot)) lot = 'No lot';
            amount = formatMoney(po.Total_Amount__c);
            status = String.isBlank(po.Status__c) ? 'No status' : po.Status__c;
            packageStatus = String.isBlank(po.Package_BMG_Status__c) ? 'No package status' : po.Package_BMG_Status__c;
            Date displayDate = po.Estimated_Start_Date__c != null ? po.Estimated_Start_Date__c : po.Requested_Install_Date__c;
            dateLabel = displayDate == null ? 'No date' : displayDate.format();
        }
    }
}