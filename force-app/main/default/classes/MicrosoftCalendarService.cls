public with sharing class MicrosoftCalendarService {

    // ── Fetch calendar events for a user (calendarView for proper recurrence expansion) ──

    @AuraEnabled(cacheable=true)
    public static List<CalendarEventItem> getMyEvents() {
        List<User> rows = [SELECT Microsoft_UPN__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (rows.isEmpty() || String.isBlank(rows[0].Microsoft_UPN__c)) {
            return new List<CalendarEventItem>();
        }
        Microsoft_Graph_Config__mdt cfg = MicrosoftGraphService.getConfig();
        Integer daysAhead = cfg?.Sync_Days_Ahead__c != null ? (Integer) cfg.Sync_Days_Ahead__c : 14;
        String startIso = DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String endIso   = DateTime.now().addDays(daysAhead).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        return fetchEvents(rows[0].Microsoft_UPN__c, startIso, endIso);
    }

    // Low-level fetch — used by scheduler and getMyEvents
    public static List<CalendarEventItem> fetchEvents(String upn, String startIso, String endIso) {
        String path = '/users/' + MicrosoftGraphService.encodeUpn(upn)
            + '/calendarView'
            + '?startDateTime=' + EncodingUtil.urlEncode(startIso, 'UTF-8')
            + '&endDateTime='   + EncodingUtil.urlEncode(endIso,   'UTF-8')
            + '&$select=id,subject,start,end,location,organizer,attendees,webLink,isAllDay,bodyPreview'
            + '&$orderby=start/dateTime'
            + '&$top=25';

        HttpResponse res = MicrosoftGraphService.get(path);
        MicrosoftGraphService.requireSuccess(res, 'Fetch calendar events');

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> rawEvents = (List<Object>) parsed.get('value');
        List<CalendarEventItem> result = new List<CalendarEventItem>();
        if (rawEvents != null) {
            for (Object raw : rawEvents) {
                result.add(new CalendarEventItem((Map<String, Object>) raw));
            }
        }
        return result;
    }

    // ── Create event in Outlook + log as Salesforce Event record ─────────────

    @AuraEnabled
    public static Id createEvent(
        String       organizerUpn,
        String       subject,
        String       startIso,       // UTC ISO-8601 e.g. "2026-06-10T14:00:00"
        String       endIso,
        String       location,
        String       body,
        List<String> attendeeEmails,
        Id           whatId          // Salesforce record to relate to
    ) {
        if (String.isBlank(organizerUpn)) { throw new AuraHandledException('Organizer UPN is required.'); }
        if (String.isBlank(subject))      { throw new AuraHandledException('Subject is required.'); }

        List<Map<String, Object>> attendees = new List<Map<String, Object>>();
        for (String email : (attendeeEmails != null ? attendeeEmails : new List<String>())) {
            if (String.isNotBlank(email)) {
                attendees.add(new Map<String, Object>{
                    'emailAddress' => new Map<String, Object>{ 'address' => email.trim() },
                    'type'         => 'required'
                });
            }
        }

        String payload = JSON.serialize(new Map<String, Object>{
            'subject'   => subject,
            'start'     => new Map<String, Object>{ 'dateTime' => startIso, 'timeZone' => 'UTC' },
            'end'       => new Map<String, Object>{ 'dateTime' => endIso,   'timeZone' => 'UTC' },
            'location'  => new Map<String, Object>{ 'displayName' => location ?? '' },
            'body'      => new Map<String, Object>{ 'contentType' => 'HTML', 'content' => body ?? '' },
            'attendees' => attendees
        });

        HttpResponse res = MicrosoftGraphService.post(
            '/users/' + MicrosoftGraphService.encodeUpn(organizerUpn) + '/events', payload);
        MicrosoftGraphService.requireSuccess(res, 'Create calendar event');

        Map<String, Object> created  = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String graphEventId = (String) created.get('id');

        // Upsert Salesforce Event linked back to the same Outlook event
        Event sfEvent = new Event(
            Subject              = subject,
            StartDateTime        = parseIso(startIso),
            EndDateTime          = parseIso(endIso),
            Location             = location,
            Description          = body,
            WhatId               = whatId,
            OwnerId              = UserInfo.getUserId(),
            MS_Graph_Event_ID__c = graphEventId
        );
        insert sfEvent;
        return sfEvent.Id;
    }

    // ── Sync a user's Outlook calendar → Salesforce Events ───────────────────

    public static void syncToSalesforce(String upn, Id ownerId, Integer daysAhead) {
        String startIso = DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String endIso   = DateTime.now().addDays(daysAhead).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        List<CalendarEventItem> events = fetchEvents(upn, startIso, endIso);

        Set<String> graphIds = new Set<String>();
        for (CalendarEventItem item : events) {
            if (String.isNotBlank(item.graphId)) { graphIds.add(item.graphId); }
        }
        if (graphIds.isEmpty()) { return; }

        Map<String, Id> existingByGraphId = new Map<String, Id>();
        for (Event ev : [SELECT Id, MS_Graph_Event_ID__c FROM Event WHERE MS_Graph_Event_ID__c IN :graphIds]) {
            existingByGraphId.put(ev.MS_Graph_Event_ID__c, ev.Id);
        }

        List<Event> toInsert = new List<Event>();
        List<Event> toUpdate = new List<Event>();
        for (CalendarEventItem item : events) {
            if (String.isBlank(item.graphId)) { continue; }
            Event ev = new Event(
                Subject              = item.subject ?? '(No subject)',
                StartDateTime        = item.startDateTime,
                EndDateTime          = item.endDateTime ?? item.startDateTime.addHours(1),
                Location             = item.location,
                Description          = item.bodyPreview,
                OwnerId              = ownerId,
                MS_Graph_Event_ID__c = item.graphId
            );
            if (existingByGraphId.containsKey(item.graphId)) {
                ev.Id = existingByGraphId.get(item.graphId);
                toUpdate.add(ev);
            } else {
                toInsert.add(ev);
            }
        }
        if (!toInsert.isEmpty()) { insert toInsert; }
        if (!toUpdate.isEmpty()) { update toUpdate; }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static DateTime parseIso(String iso) {
        if (String.isBlank(iso)) { return null; }
        // Handle both "2026-06-10T14:00:00" and "2026-06-10T14:00:00Z"
        String normalised = iso.removeEnd('Z').replace('T', ' ').split('\\.')[0];
        return DateTime.valueOfGmt(normalised);
    }

    // ── DTO ───────────────────────────────────────────────────────────────────

    public class CalendarEventItem {
        @AuraEnabled public String  graphId;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  startLabel;
        @AuraEnabled public String  endLabel;
        @AuraEnabled public String  location;
        @AuraEnabled public String  bodyPreview;
        @AuraEnabled public String  organizer;
        @AuraEnabled public String  webLink;
        @AuraEnabled public Boolean isAllDay;
        // Internal use — not exposed to LWC
        public DateTime startDateTime;
        public DateTime endDateTime;

        CalendarEventItem(Map<String, Object> raw) {
            this.graphId     = (String)  raw.get('id');
            this.subject     = (String)  raw.get('subject');
            this.bodyPreview = (String)  raw.get('bodyPreview');
            this.webLink     = (String)  raw.get('webLink');
            this.isAllDay    = (Boolean) raw.get('isAllDay');

            Map<String, Object> loc = (Map<String, Object>) raw.get('location');
            if (loc != null) { this.location = (String) loc.get('displayName'); }

            Map<String, Object> org = (Map<String, Object>) raw.get('organizer');
            if (org != null) {
                Map<String, Object> ea = (Map<String, Object>) org.get('emailAddress');
                if (ea != null) { this.organizer = (String) ea.get('address'); }
            }

            Map<String, Object> start  = (Map<String, Object>) raw.get('start');
            Map<String, Object> endMap = (Map<String, Object>) raw.get('end');

            if (start != null) {
                String dtStr = (String) start.get('dateTime');
                if (dtStr != null) {
                    String norm = dtStr.removeEnd('Z').replace('T', ' ').split('\\.')[0];
                    this.startDateTime = DateTime.valueOfGmt(norm);
                    this.startLabel    = this.startDateTime?.format('EEE MMM d, h:mm a');
                }
            }
            if (endMap != null) {
                String dtStr = (String) endMap.get('dateTime');
                if (dtStr != null) {
                    String norm = dtStr.removeEnd('Z').replace('T', ' ').split('\\.')[0];
                    this.endDateTime = DateTime.valueOfGmt(norm);
                    this.endLabel    = this.endDateTime?.format('h:mm a');
                }
            }
        }
    }
}
