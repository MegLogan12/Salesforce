/**
 * RecordTypeHelper
 * Cached Record Type ID lookup by SObject and developer name.
 * Avoids repeated SOQL queries across service classes.
 */
public with sharing class RecordTypeHelper {

    private static Map<String, Id> cache = new Map<String, Id>();

    public static Id getAccountRT(String developerName) {
        return getRecordTypeId('Account', developerName);
    }

    public static Id getOpportunityRT(String developerName) {
        return getRecordTypeId('Opportunity', developerName);
    }

    public static Id getWorkOrderRT(String developerName) {
        return getRecordTypeId('Work_Order__c', developerName);
    }

    private static Id getRecordTypeId(String sObjectType, String developerName) {
        String key = sObjectType + ':' + developerName;
        if (!cache.containsKey(key)) {
            List<RecordType> rts = [
                SELECT Id FROM RecordType
                WHERE SObjectType = :sObjectType
                AND DeveloperName = :developerName
                LIMIT 1
            ];
            cache.put(key, rts.isEmpty() ? null : rts[0].Id);
        }
        return cache.get(key);
    }
}