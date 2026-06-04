public with sharing class MicrosoftEmailService {

    // ── Send an email via Microsoft Graph and log it in Salesforce ────────────

    @AuraEnabled
    public static Id sendAndLog(
        String           fromUpn,       // sender's Microsoft UPN (e.g. jane@loving.com)
        List<String>     toAddresses,
        String           subject,
        String           htmlBody,
        Id               whatId,        // Salesforce record to log against (WorkOrder, Account …)
        Id               whoId          // Contact or Lead
    ) {
        if (String.isBlank(fromUpn))                    { throw new AuraHandledException('Sender UPN is required.'); }
        if (toAddresses == null || toAddresses.isEmpty()) { throw new AuraHandledException('At least one recipient is required.'); }
        if (String.isBlank(subject))                    { throw new AuraHandledException('Subject is required.'); }

        // 1 ─ Send via Microsoft Graph
        String payload = buildSendMailPayload(toAddresses, subject, htmlBody);
        HttpResponse res = MicrosoftGraphService.post('/users/' + MicrosoftGraphService.encodeUpn(fromUpn) + '/sendMail', payload);
        MicrosoftGraphService.requireSuccess(res, 'Send email via Outlook');

        // 2 ─ Log as EmailMessage in Salesforce Activity Timeline
        EmailMessage log = new EmailMessage(
            FromAddress = fromUpn,
            FromName    = UserInfo.getName(),
            ToAddress   = String.join(toAddresses, '; '),
            Subject     = subject,
            HtmlBody    = htmlBody,
            TextBody    = htmlBody.stripHtmlTags(),
            Status      = '3',            // Sent
            MessageDate = DateTime.now(),
            RelatedToId = whatId
        );
        insert log;
        return log.Id;
    }

    // ── Retrieve emails logged against a Salesforce record ───────────────────

    @AuraEnabled(cacheable=true)
    public static List<EmailLogItem> getLoggedEmails(Id recordId) {
        if (recordId == null) { return new List<EmailLogItem>(); }
        List<EmailMessage> rows = [
            SELECT Id, Subject, FromAddress, ToAddress, MessageDate, TextBody, HtmlBody
            FROM   EmailMessage
            WHERE  RelatedToId = :recordId
            ORDER BY MessageDate DESC
            LIMIT  25
        ];
        List<EmailLogItem> result = new List<EmailLogItem>();
        for (EmailMessage em : rows) { result.add(new EmailLogItem(em)); }
        return result;
    }

    // ── Current user's Microsoft UPN ──────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static String getCurrentUserUpn() {
        List<User> rows = [SELECT Microsoft_UPN__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return rows.isEmpty() ? null : rows[0].Microsoft_UPN__c;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static String buildSendMailPayload(List<String> toAddresses, String subject, String htmlBody) {
        List<Map<String, Object>> recipients = new List<Map<String, Object>>();
        for (String addr : toAddresses) {
            recipients.add(new Map<String, Object>{
                'emailAddress' => new Map<String, Object>{ 'address' => addr.trim() }
            });
        }
        return JSON.serialize(new Map<String, Object>{
            'message' => new Map<String, Object>{
                'subject'      => subject,
                'body'         => new Map<String, Object>{ 'contentType' => 'HTML', 'content' => htmlBody },
                'toRecipients' => recipients
            },
            'saveToSentItems' => true
        });
    }

    // ── DTO ───────────────────────────────────────────────────────────────────

    public class EmailLogItem {
        @AuraEnabled public String id;
        @AuraEnabled public String subject;
        @AuraEnabled public String fromAddress;
        @AuraEnabled public String toAddress;
        @AuraEnabled public String messageDate;
        @AuraEnabled public String preview;

        EmailLogItem(EmailMessage em) {
            this.id          = em.Id;
            this.subject     = em.Subject;
            this.fromAddress = em.FromAddress;
            this.toAddress   = em.ToAddress;
            this.messageDate = em.MessageDate?.format('MMM d, yyyy h:mm a');
            this.preview     = String.isNotBlank(em.TextBody) ? em.TextBody.left(140) : '';
        }
    }
}
