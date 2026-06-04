/**
 * Scheduled job: syncs each active Salesforce user's Outlook calendar to
 * Salesforce Event records via Microsoft Graph.
 *
 * Schedule from Setup → Apex Classes → Schedule Apex, or via Anonymous Apex:
 *   System.schedule('MS Calendar Sync', '0 0 * * * ?', new MicrosoftCalendarSync());
 */
public class MicrosoftCalendarSync implements Schedulable {

    public void execute(SchedulableContext ctx) {
        Microsoft_Graph_Config__mdt cfg;
        try {
            cfg = MicrosoftGraphService.getConfig();
        } catch (Exception e) { return; }

        if (cfg == null || !cfg.Enabled__c) { return; }
        Integer daysAhead = cfg.Sync_Days_Ahead__c != null ? (Integer) cfg.Sync_Days_Ahead__c : 14;

        List<User> users = [
            SELECT Id, Microsoft_UPN__c
            FROM   User
            WHERE  IsActive        = true
            AND    Microsoft_UPN__c != null
            LIMIT  50
        ];

        for (User u : users) {
            try {
                MicrosoftCalendarService.syncToSalesforce(u.Microsoft_UPN__c, u.Id, daysAhead);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'MicrosoftCalendarSync: sync failed for ' + u.Microsoft_UPN__c + ' — ' + e.getMessage());
            }
        }
    }
}
