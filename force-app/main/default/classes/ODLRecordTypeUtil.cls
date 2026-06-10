public without sharing class ODLRecordTypeUtil {
    public static void assignUMBToOpps(List<Id> oppIds) {
        Id umbRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'UMB' LIMIT 1].Id;
        List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Id IN :oppIds];
        for (Opportunity o : opps) { o.RecordTypeId = umbRtId; }
        update opps;
    }
}