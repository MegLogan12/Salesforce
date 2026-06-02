public with sharing class ODL_OpportunityController {

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunityList(String odlPath) {
        String query = 'SELECT Id, Name, AccountId, Account.Name, StageName, Amount, ' +
                       'ODL_Path__c, Selected_Package__c, CloseDate, ' +
                       'LastActivityDate, Voicemail_Left__c, Last_Voicemail_Date__c, ' +
                       'OwnerId, Owner.Name ' +
                       'FROM Opportunity WHERE StageName != \'Closed Won\' AND StageName != \'Closed Lost\'';
        if (String.isNotBlank(odlPath)) {
            query += ' AND ODL_Path__c = :odlPath';
        }
        query += ' ORDER BY LastActivityDate DESC NULLS LAST LIMIT 100';
        return Database.query(query);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUmbRecord(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name, StageName, Amount, CloseDate,
                   ODL_Path__c, Design_Status__c, Portal_Published__c, Selected_Package__c,
                   Customer_Viewed_Date__c, Quote_Status__c, Contract_Status__c, Deposit_Due__c,
                   Voicemail_Left__c, Last_Voicemail_Date__c,
                   Homeowner_Property__c, Homeowner_Property__r.Name,
                   Homeowner_Property__r.Access_Type__c, Homeowner_Property__r.Drainage_Risk__c,
                   Homeowner_Property__r.Utility_Review_Status__c,
                   OwnerId, Owner.Name, LastActivityDate
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, IsClosed, OwnerId, Owner.Name,
                   CallDisposition, Description
            FROM Task
            WHERE WhatId = :opportunityId
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 10
        ];

        // Package options come from the live UMB_Product_Option__c catalog — never hardcoded.
        // An empty list renders a clean empty state on the page.
        String selectedPkg = opp.Selected_Package__c;
        List<Map<String, Object>> packageOptions = new List<Map<String, Object>>();
        for (UMB_Product_Option__c po : [SELECT Id, Name FROM UMB_Product_Option__c ORDER BY Name]) {
            packageOptions.add(new Map<String, Object>{
                'id'       => po.Id,
                'name'     => po.Name,
                'selected' => (selectedPkg != null && selectedPkg == po.Name)
            });
        }

        return new Map<String, Object>{
            'opp'            => opp,
            'tasks'          => tasks,
            'packageOptions' => packageOptions
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCustomBuildRecord(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, AccountId, Account.Name, StageName, Amount, CloseDate,
                   ODL_Path__c, Project_Vision__c, Budget_Comfort__c, Decision_Makers__c,
                   Timeline__c, Estimate_Status__c, Projected_Cost__c,
                   Voicemail_Left__c, Last_Voicemail_Date__c,
                   Homeowner_Property__c, Homeowner_Property__r.Name,
                   Homeowner_Property__r.Access_Type__c, Homeowner_Property__r.Drainage_Risk__c,
                   Homeowner_Property__r.Utility_Review_Status__c,
                   OwnerId, Owner.Name, LastActivityDate
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, IsClosed, OwnerId, Owner.Name,
                   CallDisposition, Description
            FROM Task
            WHERE WhatId = :opportunityId
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 10
        ];

        return new Map<String, Object>{
            'opp'   => opp,
            'tasks' => tasks
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLawnCareRecord(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, Type, AccountId, Account.Name, Account.Phone, Account.PersonMobilePhone, Account.PersonEmail,
                   RecordType.Name, RecordType.DeveloperName,
                   StageName, Amount, CloseDate,
                   ODL_Path__c, Billing_Frequency__c, Monthly_Billing__c, Services_Selected__c,
                   Contract_Term__c, Estimate_Status__c,
                   Voicemail_Left__c, Last_Voicemail_Date__c,
                   Homeowner_Property__c, Homeowner_Property__r.Name,
                   Homeowner_Property__r.Lot_Size__c, Homeowner_Property__r.Irrigation__c,
                   Homeowner_Property__r.Gate_Access__c,
                   OwnerId, Owner.Name, LastActivityDate
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, IsClosed, OwnerId, Owner.Name,
                   CallDisposition, Description
            FROM Task
            WHERE WhatId = :opportunityId
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 10
        ];

        return new Map<String, Object>{
            'opp'       => opp,
            'tasks'     => tasks,
            'files'     => relatedFiles(opportunityId),
            'notes'     => relatedNotes(opportunityId),
            'openItems' => lawnCareOpenItems(opp, tasks)
        };
    }

    private static List<RowData> relatedFiles(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        for (ContentDocumentLink linkRow : [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.FileType, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
            ORDER BY SystemModstamp DESC
            LIMIT 10
        ]) {
            if (linkRow.ContentDocument.FileType == 'SNOTE') {
                continue;
            }
            RowData row = new RowData();
            row.id = linkRow.ContentDocumentId;
            row.url = '/' + linkRow.ContentDocumentId;
            row.label = linkRow.ContentDocument.Title;
            row.subtext = linkRow.ContentDocument.FileType;
            row.dateText = linkRow.ContentDocument.LastModifiedDate.format('M/d/yyyy');
            rows.add(row);
        }
        return rows;
    }

    private static List<RowData> relatedNotes(Id opportunityId) {
        List<RowData> rows = new List<RowData>();
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.FileType, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
            ORDER BY SystemModstamp DESC
            LIMIT 10
        ];
        Set<Id> noteIds = new Set<Id>();
        for (ContentDocumentLink linkRow : links) {
            if (linkRow.ContentDocument.FileType == 'SNOTE') {
                noteIds.add(linkRow.ContentDocumentId);
            }
        }

        Map<Id, String> previewById = new Map<Id, String>();
        if (!noteIds.isEmpty()) {
            for (ContentVersion versionRow : [
                SELECT ContentDocumentId, TextPreview
                FROM ContentVersion
                WHERE IsLatest = true
                AND ContentDocumentId IN :noteIds
            ]) {
                if (String.isNotBlank(versionRow.TextPreview)) {
                    previewById.put(versionRow.ContentDocumentId, trimPreview(versionRow.TextPreview));
                }
            }
        }

        for (ContentDocumentLink linkRow : links) {
            if (linkRow.ContentDocument.FileType != 'SNOTE') {
                continue;
            }
            RowData row = new RowData();
            row.id = linkRow.ContentDocumentId;
            row.url = '/' + linkRow.ContentDocumentId;
            row.label = linkRow.ContentDocument.Title;
            row.subtext = 'Salesforce Note';
            row.dateText = linkRow.ContentDocument.LastModifiedDate.format('M/d/yyyy');
            row.notesPreview = previewById.get(linkRow.ContentDocumentId);
            rows.add(row);
        }
        return rows;
    }

    private static List<String> lawnCareOpenItems(Opportunity opp, List<Task> tasks) {
        List<String> items = new List<String>();
        if (opp == null || !isLawnCareOpportunity(opp)) {
            return items;
        }
        if (opp.Homeowner_Property__c == null) {
            items.add('No property is linked to this Lawn Care opportunity.');
        }
        if (String.isBlank(opp.Services_Selected__c)) {
            items.add('No services are selected on this Lawn Care opportunity.');
        }
        if (String.isBlank(opp.Billing_Frequency__c)) {
            items.add('No billing frequency is captured on this Lawn Care opportunity.');
        }
        if (opp.Monthly_Billing__c == null) {
            items.add('No monthly billing amount is captured on this Lawn Care opportunity.');
        }
        Boolean hasOpenTask = false;
        for (Task taskRow : tasks) {
            if (!taskRow.IsClosed) {
                hasOpenTask = true;
                break;
            }
        }
        if (!hasOpenTask) {
            items.add('No open follow-up task is linked to this Lawn Care opportunity.');
        }
        return items;
    }

    private static Boolean isLawnCareOpportunity(Opportunity opp) {
        if (opp == null) {
            return false;
        }
        String recordTypeName = opp.RecordType == null ? null : opp.RecordType.DeveloperName;
        if (recordTypeName == 'UMB' || recordTypeName == 'Design_Build') {
            return false;
        }
        String typeValue = String.valueOf(opp.Type);
        if (typeValue == 'UMB' || typeValue == 'UpgradeMyBackyard' || typeValue == 'Design Build' || typeValue == 'Custom Build') {
            return false;
        }
        return true;
    }

    private static String trimPreview(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        String value = rawValue.replaceAll('\\s+', ' ').trim();
        return value.length() > 180 ? value.substring(0, 177) + '...' : value;
    }

    // ── Package selection ──────────────────────────────────────────────────────
    @AuraEnabled
    public static void updateSelectedPackage(Id opportunityId, String packageName) {
        if (String.isBlank(packageName)) return;
        Opportunity opp = new Opportunity(Id = opportunityId, Selected_Package__c = packageName);
        update opp;
    }

    // ── Stage advancement — sourced live from the OpportunityStage configuration ──
    @AuraEnabled
    public static String advanceStage(Id opportunityId) {
        // Stage ordering is sourced from the live OpportunityStage setup (SortOrder),
        // not a hardcoded list, so it always tracks the org's configured sales path.
        // Lost-closed stages (IsClosed && !IsWon, e.g. "Closed Lost") are excluded from
        // the auto-advance path so the forward button never auto-moves a record to Lost.
        List<String> orderedStages = activeOpportunityStages();
        Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        Integer idx = orderedStages.indexOf(opp.StageName);
        if (idx == -1 || idx >= orderedStages.size() - 1) return opp.StageName; // terminal or unknown
        String next = orderedStages[idx + 1];
        opp.StageName = next;
        update opp;
        return next;
    }

    // Returns the active opportunity stages in configured sort order, excluding
    // lost-closed stages. The won/complete terminal stage (IsClosed && IsWon, e.g.
    // "Job Completed") is retained as the final advance target.
    private static List<String> activeOpportunityStages() {
        List<String> stages = new List<String>();
        for (OpportunityStage stageRow : [
            SELECT ApiName, IsClosed, IsWon
            FROM OpportunityStage
            WHERE IsActive = true
            ORDER BY SortOrder ASC NULLS LAST
        ]) {
            if (stageRow.IsClosed && !stageRow.IsWon) {
                continue; // skip lost-closed stages such as "Closed Lost"
            }
            stages.add(stageRow.ApiName);
        }
        return stages;
    }

    public class RowData {
        @AuraEnabled public String id;
        @AuraEnabled public String url;
        @AuraEnabled public String label;
        @AuraEnabled public String subtext;
        @AuraEnabled public String status;
        @AuraEnabled public String dateText;
        @AuraEnabled public String notesPreview;
    }
}