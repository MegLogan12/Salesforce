/**
 * LovingAccountHierarchyController
 * New methods for ACL addendum: Files tab + Service Scope Detail card.
 */
public with sharing class LovingAccountHierarchyController {

    // ---- File DTO ----
    public class FileRow {
        @AuraEnabled public Id id;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String category;
        @AuraEnabled public String uploadedBy;
        @AuraEnabled public Datetime contentModifiedDate;
        @AuraEnabled public Long contentSize;
        @AuraEnabled public Boolean isPinned;
    }

    /**
     * Returns ContentDocumentLink records linked to the given Account.
     */
    @AuraEnabled(cacheable=true)
    public static List<FileRow> getAccountFiles(Id accountId) {
        List<FileRow> rows = new List<FileRow>();
        if (accountId == null) return rows;

        Map<String, Schema.SObjectField> cvFields = ContentVersion.SObjectType.getDescribe().fields.getMap();
        Boolean hasCategory = cvFields.containsKey('category__c');
        Boolean hasPinned   = cvFields.containsKey('is_pinned__c');
        List<String> want = new List<String>{ 'Id', 'Title', 'ContentDocumentId', 'ContentModifiedDate', 'ContentSize', 'CreatedById' };
        if (hasCategory) want.add('Category__c');
        if (hasPinned)   want.add('Is_Pinned__c');

        List<ContentDocumentLink> links;
        try {
            links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :accountId
                ORDER BY SystemModstamp DESC
                LIMIT 200
            ];
        } catch (Exception e) { return rows; }
        if (links.isEmpty()) return rows;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

        List<ContentVersion> versions;
        try {
            String soql = 'SELECT ' + String.join(want, ', ') + ', CreatedBy.Name'
                + ' FROM ContentVersion'
                + ' WHERE ContentDocumentId IN :docIds AND IsLatest = true'
                + ' ORDER BY ContentModifiedDate DESC'
                + ' LIMIT 200';
            versions = Database.query(soql);
        } catch (Exception e) { return rows; }

        for (ContentVersion cv : versions) {
            FileRow r      = new FileRow();
            r.id           = cv.Id;
            r.contentDocumentId = cv.ContentDocumentId;
            r.title        = cv.Title;
            r.category     = hasCategory ? (String) cv.get('Category__c') : 'Other';
            if (String.isBlank(r.category)) r.category = 'Other';
            r.contentModifiedDate = cv.ContentModifiedDate;
            r.contentSize  = cv.ContentSize;
            r.isPinned     = hasPinned ? (Boolean) cv.get('Is_Pinned__c') : false;
            if (r.isPinned == null) r.isPinned = false;
            SObject createdByObj = cv.getSObject('CreatedBy');
            r.uploadedBy   = createdByObj != null ? (String) createdByObj.get('Name') : '';
            rows.add(r);
        }
        return rows;
    }

    // ---- Service Scope Detail DTO ----
    public class ScopeDetailRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String serviceLine;
        @AuraEnabled public String scopeIncluded;
        @AuraEnabled public String specialTerms;
        @AuraEnabled public String notes;
    }

    /**
     * Returns Service Scope Detail rows for a Division Account from Scope_of_Work__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<ScopeDetailRow> getScopeDetail(Id divisionId) {
        List<ScopeDetailRow> rows = new List<ScopeDetailRow>();
        if (divisionId == null) return rows;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Scope_of_Work__c')) return rows;

        Map<String, Schema.SObjectField> sowFields = gd.get('Scope_of_Work__c').getDescribe().fields.getMap();
        if (!sowFields.containsKey('account__c')) return rows;

        List<String> want = new List<String>{ 'Id', 'Name' };
        Boolean hasLob  = sowFields.containsKey('line_of_business__c');
        Boolean hasStat = sowFields.containsKey('status__c');
        Boolean hasNote = sowFields.containsKey('notes__c');
        Boolean hasTier = sowFields.containsKey('package_tier__c');
        Boolean hasFreq = sowFields.containsKey('frequency__c');
        if (hasLob)  want.add('Line_of_Business__c');
        if (hasStat) want.add('Status__c');
        if (hasNote) want.add('Notes__c');
        if (hasTier) want.add('Package_Tier__c');
        if (hasFreq) want.add('Frequency__c');

        try {
            String soql = 'SELECT ' + String.join(want, ', ')
                + ' FROM Scope_of_Work__c WHERE Account__c = :divisionId'
                + ' ORDER BY Name ASC NULLS LAST LIMIT 100';
            List<SObject> results = Database.query(soql);
            for (SObject s : results) {
                ScopeDetailRow r  = new ScopeDetailRow();
                r.id              = (Id) s.get('Id');
                r.serviceLine     = hasLob ? (String) s.get('Line_of_Business__c') : (String) s.get('Name');
                String tier       = hasTier ? (String) s.get('Package_Tier__c') : '';
                String freq       = hasFreq ? (String) s.get('Frequency__c') : '';
                r.scopeIncluded   = (String.isNotBlank(tier) ? tier : '') + (String.isNotBlank(freq) ? ' — ' + freq : '');
                r.specialTerms    = hasStat ? (String) s.get('Status__c') : '';
                r.notes           = hasNote ? (String) s.get('Notes__c') : '';
                rows.add(r);
            }
        } catch (Exception e) { /* ignore */ }
        return rows;
    }
}