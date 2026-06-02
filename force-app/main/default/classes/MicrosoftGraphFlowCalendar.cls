/**
 * Flow-invocable wrapper: create a calendar event via Microsoft Graph.
 *
 * Usage in Flow:
 *   Action: "Microsoft Graph: Create Calendar Event"
 */
public with sharing class MicrosoftGraphFlowCalendar {

    public class CreateEventInput {
        @InvocableVariable(label='Owner Mailbox (UPN)' required=true
            description='Mailbox the event is created on')
        public String ownerUpn;

        @InvocableVariable(label='Subject' required=true)
        public String subject;

        @InvocableVariable(label='HTML Body')
        public String bodyHtml;

        @InvocableVariable(label='Start (UTC)' required=true)
        public Datetime startUtc;

        @InvocableVariable(label='End (UTC)' required=true)
        public Datetime endUtc;

        @InvocableVariable(label='Attendees (semicolon-separated emails)')
        public String attendeesCsv;

        @InvocableVariable(label='Location')
        public String location;
    }

    public class CreateEventOutput {
        @InvocableVariable(label='Event ID')
        public String eventId;
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(label='Microsoft Graph: Create Calendar Event'
        description='Create a calendar event on a user mailbox via Microsoft Graph.'
        category='Microsoft Graph')
    public static List<CreateEventOutput> createEvents(List<CreateEventInput> inputs) {
        List<CreateEventOutput> outs = new List<CreateEventOutput>();
        for (CreateEventInput i : inputs) {
            CreateEventOutput o = new CreateEventOutput();
            try {
                List<String> att = new List<String>();
                if (String.isNotBlank(i.attendeesCsv)) {
                    for (String a : i.attendeesCsv.split(';')) {
                        a = a.trim();
                        if (String.isNotBlank(a)) att.add(a);
                    }
                }
                String id = MicrosoftGraphService.createEvent(
                    i.ownerUpn, i.subject, i.bodyHtml, i.startUtc, i.endUtc, att, i.location
                );
                o.eventId = id;
                o.success = true;
            } catch (Exception e) {
                o.success = false;
                o.errorMessage = e.getMessage();
            }
            outs.add(o);
        }
        return outs;
    }
}