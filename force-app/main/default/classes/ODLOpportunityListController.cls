public with sharing class ODLOpportunityListController {
    public class RowData {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String oppHref;
        @AuraEnabled public String label;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountUrl;
        @AuraEnabled public String accountHref;
        @AuraEnabled public String lob;
        @AuraEnabled public String lobChipClass;
        @AuraEnabled public String stageName;
        @AuraEnabled public String amountDisplay;
        @AuraEnabled public String packageDisplay;
        @AuraEnabled public String lastAction;
        @AuraEnabled public String lastActivityDate;
        @AuraEnabled public String voicemailStatus;
        @AuraEnabled public String voicemailDate;
        @AuraEnabled public String followUpTask;
        @AuraEnabled public String followUpDue;
        @AuraEnabled public Date followUpDueDate;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String openItem;
        @AuraEnabled public String voicemailChipClass;
        @AuraEnabled public String openItemChipClass;
    }

    public class PageData {
        @AuraEnabled public List<RowData> rows;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer umbCount;
        @AuraEnabled public Integer designBuildCount;
        @AuraEnabled public Integer lawnCareCount;
        @AuraEnabled public Integer voicemailCount;
        @AuraEnabled public Integer followUpDueCount;
        @AuraEnabled public String latestUmbUrl;
        @AuraEnabled public String latestCustomUrl;
        @AuraEnabled public String latestLawnUrl;
    }

    private class InteractionSnapshot {
        String label;
        Date activityDate;
        Boolean voicemail;
    }

    private class FollowUpSnapshot {
        String subject;
        Date activityDate;
    }

    @AuraEnabled(cacheable=true)
    public static PageData getPageData() {
        PageData data = new PageData();
        data.rows = new List<RowData>();
        data.totalCount = 0;
        data.umbCount = 0;
        data.designBuildCount = 0;
        data.lawnCareCount = 0;
        data.voicemailCount = 0;
        data.followUpDueCount = 0;

        List<Opportunity> candidates = [
            SELECT Id, Name, AccountId, Account.Name, Type, StageName, Amount, Owner.Name,
                   RecordType.DeveloperName, LastActivityDate, BMG_Package__c
            FROM Opportunity
            WHERE IsClosed = false
              AND Account.Type = 'Home Owner'
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ];

        List<Opportunity> opportunities = new List<Opportunity>();
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity row : candidates) {
            String lane = laneForOpportunity(row);
            if (String.isBlank(lane)) {
                continue;
            }
            opportunities.add(row);
            oppIds.add(row.Id);
            if (opportunities.size() == 75) {
                break;
            }
        }

        Map<Id, InteractionSnapshot> latestInteractionByOpp = latestInteractionByOpportunity(oppIds);
        Map<Id, FollowUpSnapshot> nextFollowUpByOpp = nextFollowUpByOpportunity(oppIds);

        for (Opportunity row : opportunities) {
            String lane = laneForOpportunity(row);
            RowData out = new RowData();
            out.id = row.Id;
            out.url = '/' + row.Id;
            out.oppHref = '/lightning/r/Opportunity/' + row.Id + '/view';
            out.label = row.Name;
            out.accountName = row.Account != null ? row.Account.Name : null;
            out.accountUrl = row.AccountId != null ? '/' + row.AccountId : null;
            out.accountHref = row.AccountId != null ? '/lightning/r/Account/' + row.AccountId + '/view' : null;
            out.lob = lane;
            out.lobChipClass = laneChipClass(lane);
            out.stageName = row.StageName;
            out.amountDisplay = row.Amount == null ? null : '$' + String.valueOf(row.Amount.setScale(0));
            out.packageDisplay = normalizePackageName(row.BMG_Package__c);
            out.ownerName = row.Owner != null ? row.Owner.Name : null;

            InteractionSnapshot latest = latestInteractionByOpp.get(row.Id);
            FollowUpSnapshot followUp = nextFollowUpByOpp.get(row.Id);
            if (latest != null) {
                out.lastAction = latest.label;
                out.lastActivityDate = formatDisplayDate(latest.activityDate);
                out.voicemailStatus = latest.voicemail ? 'Yes' : 'No';
                out.voicemailDate = latest.voicemail ? formatDisplayDate(latest.activityDate) : null;
                if (latest.voicemail) {
                    data.voicemailCount++;
                }
            } else {
                out.lastAction = row.LastActivityDate == null ? null : 'Recent activity';
                out.lastActivityDate = formatDisplayDate(row.LastActivityDate);
                out.voicemailStatus = 'No';
            }

            if (followUp != null) {
                out.followUpTask = followUp.subject;
                out.followUpDueDate = followUp.activityDate;
                out.followUpDue = formatDisplayDate(followUp.activityDate);
                if (followUp.activityDate != null && followUp.activityDate <= Date.today()) {
                    data.followUpDueCount++;
                }
            }

            out.openItem = deriveOpenItem(out, row);
            out.voicemailChipClass = out.voicemailStatus == 'Yes' ? 'chip chip-amber' : 'chip chip-gray';
            out.openItemChipClass = openItemChipClass(out.openItem);
            data.rows.add(out);
            data.totalCount++;
            if (lane == 'UMB') {
                data.umbCount++;
                if (String.isBlank(data.latestUmbUrl)) {
                    data.latestUmbUrl = out.url;
                }
            } else if (lane == 'Custom') {
                data.designBuildCount++;
                if (String.isBlank(data.latestCustomUrl)) {
                    data.latestCustomUrl = out.url;
                }
            } else if (lane == 'Lawn Care') {
                data.lawnCareCount++;
                if (String.isBlank(data.latestLawnUrl)) {
                    data.latestLawnUrl = out.url;
                }
            }
        }

        return data;
    }

    private static Map<Id, InteractionSnapshot> latestInteractionByOpportunity(Set<Id> oppIds) {
        Map<Id, InteractionSnapshot> results = new Map<Id, InteractionSnapshot>();
        if (oppIds.isEmpty()) {
            return results;
        }

        for (Task taskRow : [
            SELECT WhatId, Subject, Status, ActivityDate, CreatedDate
            FROM Task
            WHERE WhatId IN :oppIds
            ORDER BY CreatedDate DESC
            LIMIT 400
        ]) {
            if (!isCompletedStatus(taskRow.Status) || results.containsKey(taskRow.WhatId)) {
                continue;
            }
            InteractionSnapshot snapshot = new InteractionSnapshot();
            snapshot.label = String.isBlank(taskRow.Subject) ? 'Completed task' : taskRow.Subject;
            snapshot.activityDate = taskRow.ActivityDate;
            snapshot.voicemail = isVoicemail(taskRow.Subject);
            results.put(taskRow.WhatId, snapshot);
        }

        return results;
    }

    private static Map<Id, FollowUpSnapshot> nextFollowUpByOpportunity(Set<Id> oppIds) {
        Map<Id, FollowUpSnapshot> results = new Map<Id, FollowUpSnapshot>();
        if (oppIds.isEmpty()) {
            return results;
        }

        for (Task taskRow : [
            SELECT WhatId, Subject, Status, ActivityDate
            FROM Task
            WHERE WhatId IN :oppIds
            ORDER BY ActivityDate ASC NULLS LAST, CreatedDate ASC
            LIMIT 400
        ]) {
            if (isCompletedStatus(taskRow.Status) || results.containsKey(taskRow.WhatId)) {
                continue;
            }
            FollowUpSnapshot snapshot = new FollowUpSnapshot();
            snapshot.subject = String.isBlank(taskRow.Subject) ? 'Follow-up' : taskRow.Subject;
            snapshot.activityDate = taskRow.ActivityDate;
            results.put(taskRow.WhatId, snapshot);
        }

        return results;
    }

    private static Boolean isCompletedStatus(String status) {
        if (String.isBlank(status)) {
            return false;
        }
        String normalized = status.trim().toLowerCase();
        return normalized == 'completed' || normalized == 'done';
    }

    private static Boolean isVoicemail(String subject) {
        return !String.isBlank(subject) && subject.toLowerCase().contains('voicemail');
    }

    private static String laneForOpportunity(Opportunity row) {
        String recordTypeName = row.RecordType != null ? row.RecordType.DeveloperName : null;
        if (recordTypeName == 'UMB' || row.Type == 'UMB' || row.Type == 'UpgradeMyBackyard') {
            return 'UMB';
        }
        if (recordTypeName == 'Design_Build' || row.Type == 'Design Build' || row.Type == 'Custom Build') {
            return 'Custom';
        }
        if (row.Type == 'Lawn Care') {
            return 'Lawn Care';
        }
        return null;
    }

    private static String laneChipClass(String lane) {
        if (lane == 'UMB') return 'chip chip-lob-umb';
        if (lane == 'Custom') return 'chip chip-lob-custom-build';
        if (lane == 'Lawn Care') return 'chip chip-lob-lawn-care';
        return 'chip chip-lob-default';
    }

    private static String normalizePackageName(String rawValue) {
        if (String.isBlank(rawValue)) {
            return rawValue;
        }
        String normalized = rawValue.trim().toLowerCase();
        if (normalized == 'good' || normalized == 'retreat') return 'Retreat';
        if (normalized == 'better' || normalized == 'entertainer') return 'Entertainer';
        if (normalized == 'best' || normalized == 'signature') return 'Signature';
        return rawValue;
    }

    private static String deriveOpenItem(RowData row, Opportunity opp) {
        if (row.followUpDueDate != null && row.followUpDueDate <= Date.today()) {
            return 'Follow-up due';
        }
        if (row.voicemailStatus == 'Yes') {
            return 'Customer callback';
        }
        if (!String.isBlank(opp.StageName) && opp.StageName.toLowerCase().contains('quote')) {
            return 'Quote follow-up';
        }
        if (opp.LastActivityDate != null && opp.LastActivityDate <= Date.today().addDays(-7)) {
            return 'Needs touch';
        }
        return 'On track';
    }

    private static String openItemChipClass(String openItem) {
        if (openItem == 'Customer callback' || openItem == 'Follow-up due') {
            return 'chip chip-amber';
        }
        if (openItem == 'Site visit decision' || openItem == 'Quote follow-up') {
            return 'chip chip-blue';
        }
        if (openItem == 'Awaiting approval' || openItem == 'On track') {
            return 'chip chip-green';
        }
        return 'chip chip-gray';
    }

    private static String formatDisplayDate(Date value) {
        if (value == null) {
            return null;
        }
        List<String> monthNames = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        String month = value.month() < 10 ? '0' + String.valueOf(value.month()) : String.valueOf(value.month());
        String day = value.day() < 10 ? '0' + String.valueOf(value.day()) : String.valueOf(value.day());
        return month + '-' + day + '-' + String.valueOf(value.year());
    }
}