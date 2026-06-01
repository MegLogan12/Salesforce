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
            Id rtId = null;
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(sObjectType);
            if (sot != null) {
                RecordTypeInfo rti = sot.getDescribe().getRecordTypeInfosByDeveloperName().get(developerName);
                rtId = (rti != null && rti.isAvailable()) ? rti.getRecordTypeId() : null;
            }
            cache.put(key, rtId);
        }
        return cache.get(key);
    }
}