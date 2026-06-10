/**
 * LotRecordController
 * Backs the Lot record page LWCs.
 */
public with sharing class LotRecordController {

    public class LotHeader {
        @AuraEnabled public String lotName;
        @AuraEnabled public String address;
        @AuraEnabled public String phase;
        @AuraEnabled public String status;
        @AuraEnabled public String pipelineBucket;
        @AuraEnabled public Boolean hasOpenFJ;
        @AuraEnabled public Integer daysUntilInstall;
        @AuraEnabled public String builderPONumber;
        @AuraEnabled public String communityName;
        @AuraEnabled public Id communityId;
    }

    public class LotScope {
        @AuraEnabled public Decimal sodSqft;
        @AuraEnabled public Integer trees;
        @AuraEnabled public Integer shrubs;
        @AuraEnabled public String plantPackage;
        @AuraEnabled public Decimal aquaAddOn;
        @AuraEnabled public String specType;
    }

    public class WoRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String woNumber;
        @AuraEnabled public String jobType;
        @AuraEnabled public String status;
        @AuraEnabled public Date scheduledDate;
        @AuraEnabled public String foreman;
        @AuraEnabled public String url;
    }

    public class FjRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String woNumber;
        @AuraEnabled public String jobType;
        @AuraEnabled public String status;
        @AuraEnabled public Date scheduledDate;
        @AuraEnabled public String foreman;
        @AuraEnabled public String url;
    }

    @AuraEnabled(cacheable=true)
    public static LotHeader getHeader(Id lotId) {
        if (lotId == null) return new LotHeader();

        List<Lot__c> lots = [
            SELECT Id, Name, Address__c, Phase__c, Status__c, Pipeline_Bucket__c,
                   Has_Open_FJ__c, Builder_PO_Number__c, Install_Date__c,
                   Community__c, Community__r.Name
            FROM Lot__c
            WHERE Id = :lotId
            LIMIT 1
        ];
        if (lots.isEmpty()) return new LotHeader();
        return buildHeader(lots[0]);
    }

    @TestVisible
    private static LotHeader buildHeader(Lot__c lot) {
        LotHeader h = new LotHeader();
        h.lotName = lot.Name;
        h.address = lot.Address__c;
        h.phase = lot.Phase__c;
        h.status = lot.Status__c;
        h.pipelineBucket = lot.Pipeline_Bucket__c;
        h.hasOpenFJ = lot.Has_Open_FJ__c;
        h.builderPONumber = lot.Builder_PO_Number__c;
        h.communityName = lot.Community__r != null ? lot.Community__r.Name : '';
        h.communityId = lot.Community__c;
        if (lot.Install_Date__c != null) {
            h.daysUntilInstall = Date.today().daysBetween(lot.Install_Date__c);
        }
        return h;
    }

    @AuraEnabled(cacheable=true)
    public static LotScope getScope(Id lotId) {
        if (lotId == null) return new LotScope();

        List<Lot__c> lots = [
            SELECT Sod_SF__c, Trees__c, Shrubs__c, Plant_Package__c,
                   Aqua_Add_On__c, Spec_Type__c
            FROM Lot__c
            WHERE Id = :lotId
            LIMIT 1
        ];
        if (lots.isEmpty()) return new LotScope();
        return buildScope(lots[0]);
    }

    @TestVisible
    private static LotScope buildScope(Lot__c lot) {
        LotScope s = new LotScope();
        s.sodSqft = lot.Sod_SF__c;
        s.trees = lot.Trees__c == null ? 0 : Integer.valueOf(lot.Trees__c);
        s.shrubs = lot.Shrubs__c == null ? 0 : Integer.valueOf(lot.Shrubs__c);
        s.plantPackage = lot.Plant_Package__c;
        s.aquaAddOn = lot.Aqua_Add_On__c;
        s.specType = lot.Spec_Type__c;
        return s;
    }

    @AuraEnabled(cacheable=true)
    public static List<WoRow> getWorkOrders(Id lotId) {
        List<WoRow> result = new List<WoRow>();
        if (lotId == null) return result;

        for (WorkOrder wo : [
            SELECT Id, WorkOrderNumber, Job_Type__c, Status, Requested_Install_Date__c,
                   Field_Manager__r.Name
            FROM WorkOrder
            WHERE Lot__c = :lotId
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            result.add(buildWoRow(wo));
        }
        return result;
    }

    @TestVisible
    private static WoRow buildWoRow(WorkOrder wo) {
        WoRow r = new WoRow();
        r.id = wo.Id;
        r.woNumber = wo.WorkOrderNumber;
        r.jobType = wo.Job_Type__c;
        r.status = wo.Status;
        r.scheduledDate = wo.Requested_Install_Date__c;
        r.foreman = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name : '';
        r.url = '/lightning/r/WorkOrder/' + wo.Id + '/view';
        return r;
    }

    @AuraEnabled(cacheable=true)
    public static List<FjRow> getFinishJobs(Id lotId) {
        List<FjRow> result = new List<FjRow>();
        if (lotId == null) return result;

        for (WorkOrder wo : [
            SELECT Id, WorkOrderNumber, Job_Type__c, Status, Requested_Install_Date__c,
                   Field_Manager__r.Name
            FROM WorkOrder
            WHERE Lot__c = :lotId
            AND Is_Finish_Job__c = true
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            result.add(buildFjRow(wo));
        }
        return result;
    }

    @TestVisible
    private static FjRow buildFjRow(WorkOrder wo) {
        FjRow r = new FjRow();
        r.id = wo.Id;
        r.woNumber = wo.WorkOrderNumber;
        r.jobType = wo.Job_Type__c;
        r.status = wo.Status;
        r.scheduledDate = wo.Requested_Install_Date__c;
        r.foreman = wo.Field_Manager__r != null ? wo.Field_Manager__r.Name : '';
        r.url = '/lightning/r/WorkOrder/' + wo.Id + '/view';
        return r;
    }
}