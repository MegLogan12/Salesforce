/** Flow-callable: sends the UMB nurture re-engagement email to a Lead. */
public with sharing class MCNurtureEmailAction {
    @InvocableMethod(label='MC Send Nurture Email' description='Sends the UMB Nurture re-engagement email to a Lead via Apex Messaging')
    public static void execute(List<Id> leadIds) {
        MCEmailService.sendNurtureEmail(leadIds);
    }
}