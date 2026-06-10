/** Flow-callable: sends the UMB welcome email to a new Lead. */
public with sharing class MCWelcomeEmailAction {
    @InvocableMethod(label='MC Send Welcome Email' description='Sends the UMB Welcome email to a new Lead via Apex Messaging')
    public static void execute(List<Id> leadIds) {
        MCEmailService.sendWelcomeEmail(leadIds);
    }
}