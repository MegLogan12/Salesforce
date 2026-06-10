/**
 * LeadNotificationService
 * Handles Lead-specific notifications (Dead, Awaiting Decision > 30 days).
 */
public with sharing class LeadNotificationService {

    public static void notifyCOODeadLeads(List<Id> leadIds) {
        List<Lead> leads = [
            SELECT Id, Name, Company, Dead_Reason__c, OwnerId
            FROM Lead WHERE Id IN :leadIds
        ];

        String body = 'The following lead(s) have been marked Dead:\n';
        for (Lead l : leads) {
            body += '• ' + l.Company + ' (' + l.Name + ') — Reason: ' + l.Dead_Reason__c + '\n';
        }

        EscalationService.sendAlert(EscalationService.getCOOId(), 'Lead(s) Marked Dead', body, leadIds[0]);
    }
}