public with sharing class ODLInboundResponseService {

    public static void stampFromEmailMessages(List<EmailMessage> emails) {
        Map<Id, Date> oppToDate = new Map<Id, Date>();
        for (EmailMessage em : emails) {
            if (!em.Incoming) continue;
            if (em.RelatedToId == null) continue;
            String objType = em.RelatedToId.getSObjectType().getDescribe().getName();
            if (objType != 'Opportunity') continue;
            Date msgDate = em.MessageDate != null ? em.MessageDate.date() : Date.today();
            if (!oppToDate.containsKey(em.RelatedToId) || oppToDate.get(em.RelatedToId) < msgDate) {
                oppToDate.put(em.RelatedToId, msgDate);
            }
        }
        stampOpportunities(oppToDate);
    }

    public static void stampFromTasks(List<Task> tasks) {
        Map<Id, Date> oppToDate = new Map<Id, Date>();
        for (Task t : tasks) {
            if (t.WhatId == null) continue;
            String objType = t.WhatId.getSObjectType().getDescribe().getName();
            if (objType != 'Opportunity') continue;
            if (!isInboundTask(t)) continue;
            Date taskDate = t.ActivityDate != null ? t.ActivityDate : Date.today();
            if (!oppToDate.containsKey(t.WhatId) || oppToDate.get(t.WhatId) < taskDate) {
                oppToDate.put(t.WhatId, taskDate);
            }
        }
        stampOpportunities(oppToDate);
    }

    public static void stampFromEvents(List<Event> events) {
        Map<Id, Date> oppToDate = new Map<Id, Date>();
        for (Event ev : events) {
            if (ev.WhatId == null) continue;
            String objType = ev.WhatId.getSObjectType().getDescribe().getName();
            if (objType != 'Opportunity') continue;
            if (!isAttendedEvent(ev)) continue;
            Date evDate = ev.ActivityDate != null ? ev.ActivityDate : Date.today();
            if (!oppToDate.containsKey(ev.WhatId) || oppToDate.get(ev.WhatId) < evDate) {
                oppToDate.put(ev.WhatId, evDate);
            }
        }
        stampOpportunities(oppToDate);
    }

    private static Boolean isInboundTask(Task t) {
        if (t.Status != 'Completed') return false;
        String callType = (String) t.get('CallType');
        if (callType == 'Inbound') return true;
        if (callType == 'Internal' && t.Subject != null && t.Subject.containsIgnoreCase('returned')) return true;
        String subject = t.Subject != null ? t.Subject.toLowerCase() : '';
        return subject.contains('inbound') || subject.contains('returned call') || subject.contains('customer called');
    }

    private static Boolean isAttendedEvent(Event ev) {
        if (ev.EndDateTime == null || ev.EndDateTime > System.now()) return false;
        String subject = ev.Subject != null ? ev.Subject.toLowerCase() : '';
        return subject.contains('consult') || subject.contains('meeting') || subject.contains('call') || subject.contains('discovery');
    }

    private static void stampOpportunities(Map<Id, Date> oppToDate) {
        if (oppToDate.isEmpty()) return;
        List<Opportunity> opps = [
            SELECT Id, Last_Customer_Response_Date__c, RecordType.DeveloperName
            FROM Opportunity
            WHERE Id IN :oppToDate.keySet()
            AND RecordType.DeveloperName IN ('UMB', 'Design_Build')
            WITH SECURITY_ENFORCED
        ];
        List<Opportunity> toUpdate = new List<Opportunity>();
        for (Opportunity opp : opps) {
            Date newDate = oppToDate.get(opp.Id);
            if (opp.Last_Customer_Response_Date__c == null || opp.Last_Customer_Response_Date__c < newDate) {
                toUpdate.add(new Opportunity(Id = opp.Id, Last_Customer_Response_Date__c = newDate));
            }
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}
