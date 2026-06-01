/**
 * ODLEmailViewController
 * Backend for the odlEmailViewCard LWC.
 * Returns recent email Task records related to a given record (WhatId).
 */
public with sharing class ODLEmailViewController {

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public class EmailRow {
        @AuraEnabled public String id;
        @AuraEnabled public String subject;
        @AuraEnabled public String createdDateLabel;
        @AuraEnabled public String snippet;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String direction;   // 'Inbound' / 'Outbound' / ''
    }

    // ── Main query ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<EmailRow> getEmails(Id recordId) {
        try {
            List<EmailRow> rows = new List<EmailRow>();
            for (Task t : [
                SELECT Id, Subject, CreatedDate, Description, Owner.Name,
                       TaskSubtype
                FROM Task
                WHERE WhatId  = :recordId
                  AND Type    = 'Email'
                ORDER BY CreatedDate DESC
                LIMIT 20
            ]) {
                EmailRow r = new EmailRow();
                r.id               = t.Id;
                r.subject          = t.Subject != null ? t.Subject : '(No subject)';
                r.createdDateLabel = t.CreatedDate != null
                    ? t.CreatedDate.format('M/d/yyyy h:mm a')
                    : '';
                // Truncate description to 200 chars
                String desc = t.Description != null ? t.Description : '';
                r.snippet  = desc.length() > 200 ? desc.substring(0, 200) + '…' : desc;
                r.ownerName = t.Owner != null ? t.Owner.Name : '';
                r.direction = t.TaskSubtype != null ? t.TaskSubtype : '';
                rows.add(r);
            }
            return rows;

        } catch (Exception e) {
            throw new AuraHandledException('Unable to load email history: ' + e.getMessage());
        }
    }
}
