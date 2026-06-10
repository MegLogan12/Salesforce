public with sharing class ODLLeadListController {
    private static final Integer ROW_LIMIT = 200;
    private static final Integer CHILD_LIMIT = 500;
    private static final Set<String> HOMEOWNER_SOURCES = new Set<String>{
        'Website',
        'Web - Design Form',
        'Web - Consultation Form',
        'Google',
        'Social Media',
        'External Referral',
        'Employee Referral',
        'Homebuilder Event',
        'Lennar Voucher',
        'Inbound Call'
    };

    public class WorkspaceData {
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String generatedAt;
        @AuraEnabled public Integer totalRows;
        @AuraEnabled public List<KpiCard> kpis;
        @AuraEnabled public List<FilterOption> filters;
        @AuraEnabled public List<WorkspaceRow> rows;
        @AuraEnabled public List<String> warnings;
    }

    public class KpiCard {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public String meta;
        @AuraEnabled public String accent;
        @AuraEnabled public String step;
    }

    public class FilterOption {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
    }

    public class WorkspaceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String url;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String market;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public String odPath;
        @AuraEnabled public String odPathLabel;
        @AuraEnabled public String interest;
        @AuraEnabled public String leadSource;
        @AuraEnabled public String campaignName;
        @AuraEnabled public String campaignStatus;
        @AuraEnabled public String mcStatus;
        @AuraEnabled public String mcJourney;
        @AuraEnabled public String scoreLabel;
        @AuraEnabled public String grade;
        @AuraEnabled public String captureState;
        @AuraEnabled public String lastAction;
        @AuraEnabled public String lastActionCategory;
        @AuraEnabled public String lastActionDate;
        @AuraEnabled public String dateOfAction;
        @AuraEnabled public String voicemail;
        @AuraEnabled public String followUpTask;
        @AuraEnabled public String followUpDue;
        @AuraEnabled public Integer lastActivityAgeDays;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String ownerInitials;
        @AuraEnabled public String nextAction;
        @AuraEnabled public String nextActionVerb;
        @AuraEnabled public Boolean canConvert;
        @AuraEnabled public Boolean isConverted;
        @AuraEnabled public String searchText;
    }

    private class ActivitySnapshot {
        Datetime occurredAt;
        String label;
        String category;
    }

    private class CampaignSnapshot {
        String name;
        String status;
    }

    private class FollowUpSnapshot {
        Date dueDate;
        String subject;
    }

    @AuraEnabled(cacheable=true)
    public static WorkspaceData getWorkspaceData() {
        if (!Schema.sObjectType.Lead.isAccessible()) {
            throw new AuraHandledException('You do not have access to Lead records.');
        }

        WorkspaceData data = new WorkspaceData();
        data.title = 'Outdoor Living Leads';
        data.subtitle = 'Live homeowner lead capture queue. Open rows are captured Leads that have not converted into homeowner Accounts, Contacts, and Opportunities yet.';
        data.generatedAt = Datetime.now().format('MMM d, yyyy h:mm a');
        data.rows = new List<WorkspaceRow>();
        data.kpis = new List<KpiCard>();
        data.filters = new List<FilterOption>();
        data.warnings = new List<String>();
        data.warnings.add('Homeowner lifecycle starts on Lead. Account lifecycle begins after conversion; Lead is not an Account lifecycle stage.');
        data.warnings.add('Marketing Cloud score and journey fields were not found on Lead; the workspace shows attribution only, not fabricated engagement.');

        List<Lead> rawLeads = [
            SELECT Id, Name, FirstName, LastName, Company, Email, Phone, MobilePhone, Status, LeadSource,
                   Lead_Type__c, Market__c, ODL_Path__c, Service_Interest__c, Package_Fit__c,
                   Selected_Products_CSV__c, Budget_Range__c, Desired_Timeline__c, Start_Window__c,
                   Voicemail_Left__c, Last_Voicemail_Date__c, Owner.Name, CreatedDate, LastActivityDate,
                   Service_Flag_Aqua__c, Service_Flag_Grading__c, Service_Flag_Irrigation__c,
                   Service_Flag_Lawn_Care__c, Service_Flag_Refreshes__c
            FROM Lead
            WHERE IsDeleted = false
            AND IsConverted = false
            AND (
                Lead_Type__c = 'Homeowner'
                OR ODL_Path__c IN ('UMB', 'Custom Build', 'Lawn Care')
                OR LeadSource IN :HOMEOWNER_SOURCES
                OR Company = 'Homeowner'
            )
            ORDER BY LastModifiedDate DESC
            LIMIT :ROW_LIMIT
        ];

        List<Lead> leads = (List<Lead>) Security.stripInaccessible(AccessType.READABLE, rawLeads).getRecords();
        Set<Id> leadIds = new Set<Id>();
        for (Lead leadRow : leads) {
            leadIds.add(leadRow.Id);
        }

        Map<Id, ActivitySnapshot> activityByLead = latestActivityByLead(leadIds);
        Map<Id, CampaignSnapshot> campaignByLead = latestCampaignByLead(leadIds);
        Map<Id, FollowUpSnapshot> followUpByLead = nextFollowUpByLead(leadIds);

        for (Lead leadRow : leads) {
            WorkspaceRow row = buildRow(leadRow, activityByLead.get(leadRow.Id), campaignByLead.get(leadRow.Id), followUpByLead.get(leadRow.Id));
            data.rows.add(row);
        }

        data.totalRows = data.rows.size();
        data.kpis = buildKpis(data.rows);
        data.filters = buildFilters(data.rows);
        return data;
    }

    private static WorkspaceRow buildRow(Lead leadRow, ActivitySnapshot activity, CampaignSnapshot campaign, FollowUpSnapshot followUp) {
        WorkspaceRow row = new WorkspaceRow();
        row.id = leadRow.Id;
        row.url = '/' + leadRow.Id;
        row.name = leadRow.Name;
        row.email = leadRow.Email;
        row.phone = firstNonBlank(new List<String>{ leadRow.MobilePhone, leadRow.Phone });
        row.isConverted = false;
        row.market = firstNonBlank(new List<String>{ leadRow.Market__c, 'Unassigned market' });
        row.status = firstNonBlank(new List<String>{ leadRow.Status, 'No status' });
        row.statusClass = statusClass(row.status);
        String rawPath = firstNonBlank(new List<String>{ leadRow.ODL_Path__c, derivePathFromSource(leadRow) });
        row.odPath = pathLabel(rawPath);
        row.odPathLabel = row.odPath;
        row.interest = deriveInterest(leadRow);
        row.leadSource = firstNonBlank(new List<String>{ leadRow.LeadSource, 'No source' });
        row.campaignName = campaign != null ? campaign.name : 'No campaign member';
        row.campaignStatus = campaign != null ? campaign.status : null;
        row.mcStatus = 'Attribution only';
        row.mcJourney = 'No verified Marketing Cloud journey field on Lead';
        row.scoreLabel = 'No synced score';
        row.grade = 'N/A';
        row.captureState = 'Captured, not converted';
        row.ownerName = leadRow.Owner != null ? leadRow.Owner.Name : 'Unassigned';
        row.ownerInitials = initials(row.ownerName);

        if (activity != null) {
            row.lastAction = activity.label;
            row.lastActionCategory = activity.category;
            row.lastActionDate = activity.occurredAt.format('MMM d');
            row.dateOfAction = activity.occurredAt.format('M/d/yyyy');
            row.lastActivityAgeDays = daysBetween(activity.occurredAt.date(), Date.today());
        } else if (leadRow.LastActivityDate != null) {
            row.lastAction = 'Activity logged';
            row.lastActionCategory = 'task';
            row.lastActionDate = leadRow.LastActivityDate.format();
            row.dateOfAction = row.lastActionDate;
            row.lastActivityAgeDays = daysBetween(leadRow.LastActivityDate, Date.today());
        } else if (leadRow.Voicemail_Left__c == true && leadRow.Last_Voicemail_Date__c != null) {
            row.lastAction = 'Left voicemail';
            row.lastActionCategory = 'voicemail';
            row.lastActionDate = leadRow.Last_Voicemail_Date__c.format();
            row.dateOfAction = row.lastActionDate;
            row.lastActivityAgeDays = daysBetween(leadRow.Last_Voicemail_Date__c, Date.today());
        } else {
            row.lastAction = 'No activity';
            row.lastActionCategory = 'none';
            row.lastActionDate = 'Created ' + leadRow.CreatedDate.format('MMM d');
            row.dateOfAction = 'No activity';
            row.lastActivityAgeDays = daysBetween(leadRow.CreatedDate.date(), Date.today());
        }
        row.voicemail = row.lastActionCategory == 'voicemail' ? 'Yes' : 'No';
        if (followUp != null) {
            row.followUpTask = followUp.subject;
            row.followUpDue = followUp.dueDate != null ? String.valueOf(followUp.dueDate) : 'No due date';
        } else {
            row.followUpTask = 'No follow-up task';
            row.followUpDue = row.lastActivityAgeDays != null && row.lastActivityAgeDays >= 7 ? 'Due now' : 'No follow-up due';
        }

        applyNextAction(row);
        row.searchText = String.join(new List<String>{
            row.name, row.email, row.phone, row.market, row.status, row.odPathLabel,
            row.interest, row.leadSource, row.campaignName, row.ownerName, row.nextAction, row.captureState
        }, ' ').toLowerCase();
        return row;
    }

    private static List<KpiCard> buildKpis(List<WorkspaceRow> rows) {
        return new List<KpiCard>{
            kpi('new', 'Captured, Not Converted', countRows(rows, 'new'), 'finished step 1, needs human follow-up or step 2', 'blue', '1 Capture'),
            kpi('nurturing', 'Nurturing Leads', countRows(rows, 'nurturing'), 'active sales nurture status', 'purple', '2 Nurture'),
            kpi('qualified', 'Ready to Convert', countRows(rows, 'qualified'), 'qualified lead status', 'green', '3 Convert'),
            kpi('umb', 'UpgradeMyBackyard', countRows(rows, 'umb'), 'UMB path', 'orange', 'Path'),
            kpi('design', 'Design Build', countRows(rows, 'design'), 'custom build path', 'amber', 'Path'),
            kpi('noact', 'No Activity 7+ Days', countRows(rows, 'noact'), 'stalled follow-up', 'slate', 'Stalled')
        };
    }

    private static List<FilterOption> buildFilters(List<WorkspaceRow> rows) {
        return new List<FilterOption>{
            filter('all', 'All Open Leads', rows.size()),
            filter('new', 'New', countRows(rows, 'new')),
            filter('nurturing', 'Nurturing', countRows(rows, 'nurturing')),
            filter('qualified', 'Ready to Convert', countRows(rows, 'qualified')),
            filter('umb', 'UpgradeMyBackyard', countRows(rows, 'umb')),
            filter('design', 'Design Build', countRows(rows, 'design')),
            filter('lawn', 'Lawn Care', countRows(rows, 'lawn')),
            filter('builder', 'Builder-Sourced', countRows(rows, 'builder')),
            filter('noact', 'No Activity 7d', countRows(rows, 'noact'))
        };
    }

    private static Integer countRows(List<WorkspaceRow> rows, String key) {
        Integer total = 0;
        for (WorkspaceRow row : rows) {
            if (matches(row, key)) {
                total++;
            }
        }
        return total;
    }

    private static Boolean matches(WorkspaceRow row, String key) {
        if (key == 'all') return true;
        if (key == 'new') return row.status == 'New';
        if (key == 'nurturing') return row.status == 'Nurturing';
        if (key == 'qualified') return row.status == 'Qualified';
        if (key == 'umb') return row.odPathLabel == 'UpgradeMyBackyard';
        if (key == 'design') return row.odPathLabel == 'Design Build';
        if (key == 'lawn') return row.odPathLabel == 'Lawn Care';
        if (key == 'builder') return row.leadSource == 'Homebuilder Event' || row.leadSource == 'Lennar Voucher' || row.leadSource == 'UMB Builder Pop Up';
        if (key == 'noact') return row.lastActivityAgeDays != null && row.lastActivityAgeDays >= 7;
        return false;
    }

    private static KpiCard kpi(String key, String label, Integer count, String meta, String accent, String step) {
        KpiCard card = new KpiCard();
        card.key = key;
        card.label = label;
        card.count = count;
        card.meta = meta;
        card.accent = accent;
        card.step = step;
        return card;
    }

    private static FilterOption filter(String key, String label, Integer count) {
        FilterOption option = new FilterOption();
        option.key = key;
        option.label = label;
        option.count = count;
        return option;
    }

    private static void applyNextAction(WorkspaceRow row) {
        row.canConvert = row.status == 'Qualified';
        if (row.canConvert) {
            row.nextAction = 'Convert through standard Lead conversion';
            row.nextActionVerb = 'Convert';
        } else if (row.status == 'New' && row.lastActionCategory == 'none') {
            row.nextAction = 'Call homeowner and complete step 2';
            row.nextActionVerb = 'Call';
        } else if (row.status == 'Nurturing') {
            row.nextAction = 'Review nurture status';
            row.nextActionVerb = 'Open';
        } else if (row.lastActivityAgeDays != null && row.lastActivityAgeDays >= 7) {
            row.nextAction = 'Re-engage';
            row.nextActionVerb = 'Follow Up';
        } else {
            row.nextAction = 'Open lead';
            row.nextActionVerb = 'Open';
        }
    }

    private static Map<Id, ActivitySnapshot> latestActivityByLead(Set<Id> leadIds) {
        Map<Id, ActivitySnapshot> snapshots = new Map<Id, ActivitySnapshot>();
        if (leadIds.isEmpty()) {
            return snapshots;
        }

        for (Task taskRow : [
            SELECT Id, WhoId, Subject, Status, TaskSubtype, ActivityDate, CreatedDate
            FROM Task
            WHERE WhoId IN :leadIds
            ORDER BY CreatedDate DESC
            LIMIT :CHILD_LIMIT
        ]) {
            if (!isCompletedTask(taskRow)) {
                continue;
            }
            Datetime occurredAt = taskRow.ActivityDate != null
                ? Datetime.newInstance(taskRow.ActivityDate, Time.newInstance(12, 0, 0, 0))
                : taskRow.CreatedDate;
            String category = taskRow.TaskSubtype == 'Call' ? 'call'
                : taskRow.TaskSubtype == 'Email' ? 'email'
                : subjectContains(taskRow.Subject, 'voicemail') ? 'voicemail'
                : subjectContains(taskRow.Subject, 'call') ? 'call'
                : 'task';
            considerSnapshot(snapshots, taskRow.WhoId, occurredAt, deriveActionLabel(category, taskRow.Subject), category);
        }

        for (Event eventRow : [
            SELECT Id, WhoId, Subject, Type, ActivityDateTime, CreatedDate
            FROM Event
            WHERE WhoId IN :leadIds
            ORDER BY CreatedDate DESC
            LIMIT :CHILD_LIMIT
        ]) {
            Datetime occurredAt = eventRow.ActivityDateTime != null ? eventRow.ActivityDateTime : eventRow.CreatedDate;
            String category = subjectContains(eventRow.Subject, 'voicemail') ? 'voicemail'
                : subjectContains(eventRow.Subject, 'call') || eventRow.Type == 'Call' ? 'call'
                : subjectContains(eventRow.Subject, 'email') ? 'email'
                : 'event';
            considerSnapshot(snapshots, eventRow.WhoId, occurredAt, deriveActionLabel(category, eventRow.Subject), category);
        }
        return snapshots;
    }

    private static Map<Id, CampaignSnapshot> latestCampaignByLead(Set<Id> leadIds) {
        Map<Id, CampaignSnapshot> snapshots = new Map<Id, CampaignSnapshot>();
        if (leadIds.isEmpty() || !Schema.sObjectType.CampaignMember.isAccessible()) {
            return snapshots;
        }

        for (CampaignMember member : [
            SELECT LeadId, Status, Campaign.Name, CreatedDate
            FROM CampaignMember
            WHERE LeadId IN :leadIds
            ORDER BY CreatedDate DESC
            LIMIT :CHILD_LIMIT
        ]) {
            if (member.LeadId == null || snapshots.containsKey(member.LeadId)) {
                continue;
            }
            CampaignSnapshot snapshot = new CampaignSnapshot();
            snapshot.name = member.Campaign != null ? member.Campaign.Name : null;
            snapshot.status = member.Status;
            snapshots.put(member.LeadId, snapshot);
        }
        return snapshots;
    }

    private static Map<Id, FollowUpSnapshot> nextFollowUpByLead(Set<Id> leadIds) {
        Map<Id, FollowUpSnapshot> followUps = new Map<Id, FollowUpSnapshot>();
        if (leadIds.isEmpty()) {
            return followUps;
        }
        for (Task taskRow : [
            SELECT Id, WhoId, Subject, ActivityDate
            FROM Task
            WHERE WhoId IN :leadIds
            AND IsClosed = false
            ORDER BY ActivityDate ASC, CreatedDate ASC
            LIMIT :CHILD_LIMIT
        ]) {
            if (!followUps.containsKey(taskRow.WhoId)) {
                FollowUpSnapshot snapshot = new FollowUpSnapshot();
                snapshot.dueDate = taskRow.ActivityDate;
                snapshot.subject = taskRow.Subject;
                followUps.put(taskRow.WhoId, snapshot);
            }
        }
        return followUps;
    }

    private static void considerSnapshot(Map<Id, ActivitySnapshot> snapshots, Id leadId, Datetime occurredAt, String label, String category) {
        if (leadId == null || occurredAt == null) {
            return;
        }
        ActivitySnapshot current = snapshots.get(leadId);
        if (current == null || occurredAt.getTime() > current.occurredAt.getTime()) {
            ActivitySnapshot snapshot = new ActivitySnapshot();
            snapshot.occurredAt = occurredAt;
            snapshot.label = label;
            snapshot.category = category;
            snapshots.put(leadId, snapshot);
        }
    }

    private static Boolean isCompletedTask(Task taskRow) {
        return taskRow != null
            && !String.isBlank(taskRow.Status)
            && taskRow.Status.toLowerCase().contains('complete');
    }

    private static String deriveActionLabel(String category, String subject) {
        if (category == 'voicemail') return 'Left Voicemail - Initial';
        if (category == 'email') return 'Sent Email - Initial';
        if (category == 'call') return 'Call Complete - Initial';
        if (category == 'event') return firstNonBlank(new List<String>{ subject, 'Event' });
        return firstNonBlank(new List<String>{ subject, 'Activity logged' });
    }

    private static String derivePathFromSource(Lead leadRow) {
        if (leadRow.Service_Flag_Lawn_Care__c == true) {
            return 'Lawn Care';
        }
        if (leadRow.LeadSource == 'Web - Consultation Form') {
            return 'Custom Build';
        }
        if (HOMEOWNER_SOURCES.contains(leadRow.LeadSource) || leadRow.Lead_Type__c == 'Homeowner') {
            return 'UMB';
        }
        return 'Not captured';
    }

    private static String pathLabel(String pathValue) {
        if (pathValue == 'UMB') return 'UpgradeMyBackyard';
        if (pathValue == 'Custom Build') return 'Design Build';
        return firstNonBlank(new List<String>{ pathValue, 'Not captured' });
    }

    private static String deriveInterest(Lead leadRow) {
        List<String> values = new List<String>();
        if (!String.isBlank(leadRow.Service_Interest__c)) values.add(leadRow.Service_Interest__c);
        if (!String.isBlank(leadRow.Selected_Products_CSV__c)) values.add(leadRow.Selected_Products_CSV__c);
        if (leadRow.Service_Flag_Lawn_Care__c == true) values.add('Lawn Care');
        if (leadRow.Service_Flag_Irrigation__c == true) values.add('Irrigation');
        if (leadRow.Service_Flag_Grading__c == true) values.add('Grading');
        if (leadRow.Service_Flag_Aqua__c == true) values.add('Aqua');
        if (leadRow.Service_Flag_Refreshes__c == true) values.add('Refreshes');
        if (!String.isBlank(leadRow.Package_Fit__c)) values.add('Package Fit: ' + leadRow.Package_Fit__c);
        return values.isEmpty() ? pathLabel(firstNonBlank(new List<String>{ leadRow.ODL_Path__c, derivePathFromSource(leadRow) })) : String.join(values, ', ');
    }

    private static String statusClass(String status) {
        if (status == 'Qualified') return 'status-qualified';
        if (status == 'Nurturing') return 'status-nurturing';
        if (status == 'New') return 'status-new';
        return 'status-default';
    }

    private static Integer daysBetween(Date startDate, Date endDate) {
        if (startDate == null || endDate == null) {
            return null;
        }
        return startDate.daysBetween(endDate);
    }

    private static String initials(String value) {
        if (String.isBlank(value) || value == 'Unassigned') {
            return '?';
        }
        List<String> parts = value.split('\\s+');
        String output = '';
        for (String part : parts) {
            if (!String.isBlank(part)) {
                output += part.substring(0, 1).toUpperCase();
            }
            if (output.length() == 2) break;
        }
        return output;
    }

    private static Boolean subjectContains(String subject, String token) {
        return !String.isBlank(subject) && subject.toLowerCase().contains(token);
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }
}