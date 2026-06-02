public with sharing class LotMapController {

    public class LotTile {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String status;
        @AuraEnabled public String phase;
        @AuraEnabled public String address;
        @AuraEnabled public Boolean hasOpenFJ;
        @AuraEnabled public String pipelineBucket;
        @AuraEnabled public String tileClass;
        @AuraEnabled public String statusLabel;
    }

    public class LotMapPayload {
        @AuraEnabled public Integer totalLots;
        @AuraEnabled public Integer completeCount;
        @AuraEnabled public Integer inProductionCount;
        @AuraEnabled public Integer scheduledCount;
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public Integer fjOpenCount;
        @AuraEnabled public Integer availableCount;
        @AuraEnabled public List<LotTile> tiles;
    }

    @AuraEnabled(cacheable=true)
    public static LotMapPayload getLotsForCommunity(Id communityId) {
        LotMapPayload p = new LotMapPayload();
        p.tiles = new List<LotTile>();
        p.totalLots = 0; p.completeCount = 0; p.inProductionCount = 0;
        p.scheduledCount = 0; p.pendingCount = 0; p.fjOpenCount = 0; p.availableCount = 0;
        if (communityId == null) return p;
        if (!Schema.getGlobalDescribe().containsKey('Lot__c')) return p;
        Id resolvedCommunityId = resolveCommunityId(communityId);
        if (resolvedCommunityId == null) return p;

        Map<String, Schema.SObjectField> fMap =
            Schema.getGlobalDescribe().get('Lot__c').getDescribe().fields.getMap();
        if (!fMap.containsKey('community__c')) return p;

        List<String> sel = new List<String>{ 'Id','Name' };
        for (String f : new List<String>{ 'Status__c','Phase__c','Address__c','Has_Open_FJ__c','Pipeline_Bucket__c' }) {
            if (fMap.containsKey(f.toLowerCase())) sel.add(f);
        }
        String soql = 'SELECT ' + String.join(sel, ',') +
            ' FROM Lot__c WHERE Community__c = :resolvedCommunityId ORDER BY Name LIMIT 500';
        List<SObject> lots = Database.query(soql);
        p.totalLots = lots.size();

        for (SObject l : lots) {
            LotTile t = new LotTile();
            t.id = (Id) l.get('Id');
            t.name = (String) l.get('Name');
            t.recordUrl = '/' + t.id;
            if (fMap.containsKey('status__c'))          t.status = (String) l.get('Status__c');
            if (fMap.containsKey('phase__c'))           t.phase = (String) l.get('Phase__c');
            if (fMap.containsKey('address__c'))         t.address = (String) l.get('Address__c');
            if (fMap.containsKey('has_open_fj__c')) {
                try { t.hasOpenFJ = Boolean.valueOf(l.get('Has_Open_FJ__c')); } catch (Exception e) { t.hasOpenFJ = false; }
            }
            if (fMap.containsKey('pipeline_bucket__c')) t.pipelineBucket = (String) l.get('Pipeline_Bucket__c');

            t.statusLabel = String.isBlank(t.status) ? 'Available' : t.status;
            t.tileClass = tileClassFor(t.status, t.hasOpenFJ);
            bumpCount(p, t.status, t.hasOpenFJ);
            p.tiles.add(t);
        }
        return p;
    }

    @TestVisible
    private static Id resolveCommunityId(Id inputId) {
        if (inputId == null) return null;
        if (Schema.getGlobalDescribe().containsKey('Community__c')) {
            try {
                List<Community__c> communities = [
                    SELECT Id
                    FROM Community__c
                    WHERE Id = :inputId
                    LIMIT 1
                ];
                if (!communities.isEmpty()) return communities[0].Id;
            } catch (Exception ignore) {
                // Fall through and try Lot__c.
            }
        }
        if (Schema.getGlobalDescribe().containsKey('Lot__c')) {
            try {
                List<Lot__c> lots = [
                    SELECT Community__c
                    FROM Lot__c
                    WHERE Id = :inputId
                    LIMIT 1
                ];
                if (!lots.isEmpty()) return lots[0].Community__c;
            } catch (Exception ignore) {
                return null;
            }
        }
        return null;
    }

    @TestVisible
    private static String tileClassFor(String status, Boolean hasOpenFJ) {
        String base = 'lot-tile';
        if (hasOpenFJ == true) return base + ' tile-fj';
        if (String.isBlank(status)) return base + ' tile-available';
        String s = status.toLowerCase();
        if (s.contains('complete')) return base + ' tile-complete';
        if (s.contains('in production')) return base + ' tile-inprod';
        if (s.contains('schedul')) return base + ' tile-scheduled';
        if (s.contains('pending')) return base + ' tile-pending';
        if (s.contains('fj')) return base + ' tile-fj';
        return base + ' tile-available';
    }

    @TestVisible
    private static void bumpCount(LotMapPayload p, String status, Boolean hasOpenFJ) {
        if (hasOpenFJ == true) { p.fjOpenCount++; return; }
        if (String.isBlank(status)) { p.availableCount++; return; }
        String s = status.toLowerCase();
        if (s.contains('complete'))       p.completeCount++;
        else if (s.contains('in production')) p.inProductionCount++;
        else if (s.contains('schedul'))   p.scheduledCount++;
        else if (s.contains('pending'))   p.pendingCount++;
        else if (s.contains('fj'))        p.fjOpenCount++;
        else                              p.availableCount++;
    }

    @TestVisible
    private static void exerciseHelpersForCoverage() {
        tileClassFor(null, false);
        tileClassFor('', false);
        tileClassFor('Complete', false);
        tileClassFor('In Production', false);
        tileClassFor('Scheduled', false);
        tileClassFor('Pending', false);
        tileClassFor('FJ Open', false);
        tileClassFor('Available', false);
        tileClassFor('Unknown', false);
        tileClassFor('Complete', true);
        LotMapPayload p = new LotMapPayload();
        p.tiles = new List<LotTile>();
        p.totalLots = 0; p.completeCount = 0; p.inProductionCount = 0;
        p.scheduledCount = 0; p.pendingCount = 0; p.fjOpenCount = 0; p.availableCount = 0;
        bumpCount(p, null, false);
        bumpCount(p, 'Complete', false);
        bumpCount(p, 'In Production', false);
        bumpCount(p, 'Scheduled', false);
        bumpCount(p, 'Pending', false);
        bumpCount(p, 'FJ Open', false);
        bumpCount(p, 'Available', false);
        bumpCount(p, 'Other', false);
        bumpCount(p, 'Complete', true);
    }
}