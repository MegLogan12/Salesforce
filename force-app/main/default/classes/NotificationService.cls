/**
 * NotificationService
 * Unified push alert / Chatter / email dispatch.
 * Wraps EscalationService.sendAlert for mobile FSL push notifications.
 */
public with sharing class NotificationService {

    public static void sendPushAlert(Id userId, String title, String body, Id recordId) {
        EscalationService.sendAlert(userId, title, body, recordId);
    }

    public static void sendEmail(Id userId, String subject, String htmlBody) {
        List<User> users = [SELECT Email FROM User WHERE Id = :userId LIMIT 1];
        if (users.isEmpty() || String.isBlank(users[0].Email)) return;

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ users[0].Email });
        email.setSubject(subject);
        email.setHtmlBody(htmlBody);
        email.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }
}