/**
 * Flow-invocable wrapper: send email via Microsoft Graph.
 *
 * Usage in Flow:
 *   Action: "Microsoft Graph: Send Email"
 */
public with sharing class MicrosoftGraphFlowActions {

    public class SendEmailInput {
        @InvocableVariable(label='From (mailbox UPN)' required=true
            description='e.g. megan.logan@thelovingcompanies.com — must be a licensed M365 mailbox allowed by the ApplicationAccessPolicy')
        public String fromUpn;

        @InvocableVariable(label='To (semicolon-separated emails)' required=true)
        public String toEmails;

        @InvocableVariable(label='Subject' required=true)
        public String subject;

        @InvocableVariable(label='HTML Body' required=true)
        public String htmlBody;
    }

    public class SendEmailOutput {
        @InvocableVariable(label='HTTP Status Code')
        public Integer statusCode;
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(label='Microsoft Graph: Send Email'
        description='Send an email from a licensed M365 mailbox via Microsoft Graph using the Microsoft_Graph Named Credential.'
        category='Microsoft Graph')
    public static List<SendEmailOutput> sendEmails(List<SendEmailInput> inputs) {
        List<SendEmailOutput> outs = new List<SendEmailOutput>();
        for (SendEmailInput i : inputs) {
            SendEmailOutput o = new SendEmailOutput();
            try {
                List<String> toList = new List<String>();
                if (String.isNotBlank(i.toEmails)) {
                    for (String t : i.toEmails.split(';')) {
                        t = t.trim();
                        if (String.isNotBlank(t)) toList.add(t);
                    }
                }
                Integer code = MicrosoftGraphService.sendMail(i.fromUpn, toList, i.subject, i.htmlBody);
                o.statusCode = code;
                o.success = (code == 202);
            } catch (Exception e) {
                o.success = false;
                o.errorMessage = e.getMessage();
                o.statusCode = 0;
            }
            outs.add(o);
        }
        return outs;
    }
}