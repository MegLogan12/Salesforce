/**
 * MCEmailService — sends Marketing Cloud journey emails to Leads via Apex.
 * Uses Salesforce Messaging.sendEmail with OrgWideEmailAddress.
 * Called from LOVING_MC_UMB_Welcome_Journey and LOVING_MC_UMB_Nurture_Journey flows.
 */
public with sharing class MCEmailService {

    private static final String SENDER_ADDRESS = 'no-reply@upgrademybackyard.com';

    // ── Invocable: Welcome email (called from Welcome Journey flow) ────────────

    public static void sendWelcomeEmail(List<Id> leadIds) {
        List<Lead> leads = [SELECT Id, FirstName, Email, HasOptedOutOfEmail FROM Lead
                            WHERE Id IN :leadIds AND Email != null AND HasOptedOutOfEmail = false LIMIT 200];
        if (leads.isEmpty()) return;
        sendEmails(leads, 'Welcome to Upgrade My Backyard',
            'Hi {first_name},\n\nThank you for your interest in Upgrade My Backyard. ' +
            'Our design team will reach out within 24 hours to schedule your free consultation. ' +
            'We look forward to helping you create the outdoor space you have always wanted.\n\n' +
            'The Upgrade My Backyard Team\n' +
            'upgrademybackyard.com');
    }

    // ── Invocable: Nurture email (called from Nurture Journey flow) ──────────────

    public static void sendNurtureEmail(List<Id> leadIds) {
        List<Lead> leads = [SELECT Id, FirstName, Email, HasOptedOutOfEmail FROM Lead
                            WHERE Id IN :leadIds AND Email != null AND HasOptedOutOfEmail = false LIMIT 200];
        if (leads.isEmpty()) return;
        sendEmails(leads, 'We noticed you went quiet — still interested in your backyard?',
            'Hi {first_name},\n\nWe know life gets busy. We are still here when you are ready. ' +
            'Reply to this email or call us anytime and we will pick up right where we left off.\n\n' +
            'The Upgrade My Backyard Team\n' +
            'upgrademybackyard.com');
    }

    // ── Core send logic ────────────────────────────────────────────────────────

    @future
    public static void sendEmailsAsync(List<Id> leadIds, String subject, String bodyTemplate) {
        List<Lead> leads = [SELECT Id, FirstName, Email, HasOptedOutOfEmail FROM Lead
                            WHERE Id IN :leadIds AND Email != null AND HasOptedOutOfEmail = false LIMIT 200];
        sendEmails(leads, subject, bodyTemplate);
    }

    private static void sendEmails(List<Lead> leads, String subject, String bodyTemplate) {
        // Find OrgWideEmailAddress for the UMB sender
        OrgWideEmailAddress sender;
        List<OrgWideEmailAddress> senders = [
            SELECT Id, Address FROM OrgWideEmailAddress
            WHERE Address = :SENDER_ADDRESS LIMIT 1
        ];
        Id senderId = senders.isEmpty() ? null : senders[0].Id;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Lead l : leads) {
            String body = bodyTemplate.replace('{first_name}', String.isBlank(l.FirstName) ? 'there' : l.FirstName);
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ l.Email });
            msg.setSubject(subject);
            msg.setPlainTextBody(body);
            msg.setHtmlBody('<p>' + body.replace('\n\n', '</p><p>').replace('\n', '<br/>') + '</p>');
            msg.setSaveAsActivity(true);
            msg.setWhatId(l.Id);
            if (senderId != null) msg.setOrgWideEmailAddressId(senderId);
            emails.add(msg);
        }
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false); // false = don't throw on partial failure
        }
    }
}