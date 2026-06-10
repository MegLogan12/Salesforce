/**
 * VpEscalationsController
 * @AuraEnabled methods for the vpEscalationsTab LWC.
 *
 * Surfaces two escalation streams to the VP:
 *   1. Hire_Request__c records in Submitted / Under VP Review status
 *   2. Open high-priority Tasks on Work Orders (system-generated alerts)
 *
 * Action methods (non-cacheable) allow the VP to approve, deny, or defer
 * hire requests directly from the dashboard.
 */
public with sharing class VpEscalationsController {

    // ─────────────────────────────────────────────
    // WRAPPERS
    // ─────────────────────────────────────────────
    public class HireRequestRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String url;
        @AuraEnabled public String submittedByName;
        @AuraEnabled public String serviceLine;
        @AuraEnabled public String roleType;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public Decimal totalAnnualCost;
        @AuraEnabled public Decimal y1ROI;
        @AuraEnabled public String justification;
        @AuraEnabled public String driverCommunities;
        @AuraEnabled public String status;
        @AuraEnabled public Date   createdDate;
    }

    public class EscalationTaskRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String subject;
        @AuraEnabled public String type;
        @AuraEnabled public Date   activityDate;
        @AuraEnabled public String relatedToName;
        @AuraEnabled public Id     relatedToId;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String description;
        @AuraEnabled public String statusLabel;  // 'Overdue' / 'Due Today' / 'Open'
        @AuraEnabled public String statusClass;  // chip-red / chip-amber / chip-blue
    }

    // ─────────────────────────────────────────────
    // GET OPEN HIRE REQUESTS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<HireRequestRow> getOpenHireRequests() {
        List<HireRequestRow> rows = new List<HireRequestRow>();
        try {
            for (Hire_Request__c hr : [
                SELECT Id, Name, Submitted_By_FM__r.Name, Service_Line__c,
                       Role_Type__c, Quantity__c, Total_Annual_Cost__c,
                       Y1_ROI__c, Justification__c, Driver_Communities__c,
                       Status__c, CreatedDate
                FROM Hire_Request__c
                WHERE Status__c IN ('Submitted', 'Under VP Review', 'Under COO Review')
                ORDER BY CreatedDate ASC
                LIMIT 50
            ]) {
                HireRequestRow r = new HireRequestRow();
                r.id               = hr.Id;
                r.name             = hr.Name;
                r.url              = '/' + hr.Id;
                r.submittedByName  = hr.Submitted_By_FM__r != null ? hr.Submitted_By_FM__r.Name : '—';
                r.serviceLine      = hr.Service_Line__c;
                r.roleType         = hr.Role_Type__c;
                r.quantity         = hr.Quantity__c != null ? (Integer)hr.Quantity__c : 1;
                r.totalAnnualCost  = hr.Total_Annual_Cost__c;
                r.y1ROI            = hr.Y1_ROI__c != null ? hr.Y1_ROI__c.setScale(0) : null;
                r.justification    = hr.Justification__c;
                r.driverCommunities = hr.Driver_Communities__c;
                r.status           = hr.Status__c;
                r.createdDate      = hr.CreatedDate.date();
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('VpEscalationsController', 'getOpenHireRequests', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // GET HIGH-PRIORITY ESCALATION TASKS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<EscalationTaskRow> getEscalationTasks() {
        List<EscalationTaskRow> rows = new List<EscalationTaskRow>();
        try {
            for (Task t : [
                SELECT Id, Subject, Type, ActivityDate, What.Name, WhatId,
                       Owner.Name, Description, Status
                FROM Task
                WHERE Priority = 'High'
                  AND Status != 'Completed'
                  AND Type IN ('Escalation', 'GP Breach', 'NFI Alert',
                               'Schedule Review', 'QI Alert', 'Invoice Alert',
                               'Takeoff Overdue', 'Aqua Alert')
                ORDER BY ActivityDate ASC NULLS LAST, CreatedDate DESC
                LIMIT 25
            ]) {
                EscalationTaskRow r = new EscalationTaskRow();
                r.id           = t.Id;
                r.subject      = t.Subject;
                r.type         = t.Type;
                r.activityDate = t.ActivityDate;
                r.relatedToName = t.What != null ? t.What.Name : null;
                r.relatedToId  = t.WhatId;
                r.ownerName    = t.Owner != null ? t.Owner.Name : '—';
                r.description  = t.Description;

                Date today = Date.today();
                if (t.ActivityDate != null && t.ActivityDate < today) {
                    r.statusLabel = 'Overdue';
                    r.statusClass = 'chip-red';
                } else if (t.ActivityDate != null && t.ActivityDate == today) {
                    r.statusLabel = 'Due Today';
                    r.statusClass = 'chip-amber';
                } else {
                    r.statusLabel = 'Open';
                    r.statusClass = 'chip-blue';
                }
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('VpEscalationsController', 'getEscalationTasks', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // ACTIONS — HIRE REQUEST
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void approveHireRequest(Id hrId, String decisionNotes) {
        try {
            update new Hire_Request__c(
                Id             = hrId,
                Status__c      = 'Approved',
                Decision_By__c = UserInfo.getUserId(),
                Decision_Date__c = Date.today(),
                Decision_Notes__c = decisionNotes
            );
        } catch (Exception e) {
            ErrorLogService.log('VpEscalationsController', 'approveHireRequest', hrId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void denyHireRequest(Id hrId, String decisionNotes) {
        try {
            update new Hire_Request__c(
                Id             = hrId,
                Status__c      = 'Denied',
                Decision_By__c = UserInfo.getUserId(),
                Decision_Date__c = Date.today(),
                Decision_Notes__c = decisionNotes
            );
        } catch (Exception e) {
            ErrorLogService.log('VpEscalationsController', 'denyHireRequest', hrId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deferHireRequest(Id hrId, String decisionNotes) {
        try {
            update new Hire_Request__c(
                Id             = hrId,
                Status__c      = 'Deferred',
                Decision_By__c = UserInfo.getUserId(),
                Decision_Date__c = Date.today(),
                Decision_Notes__c = decisionNotes
            );
        } catch (Exception e) {
            ErrorLogService.log('VpEscalationsController', 'deferHireRequest', hrId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // ACTIONS — COMPLETE TASK
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void markTaskComplete(Id taskId) {
        try {
            update new Task(Id = taskId, Status = 'Completed');
        } catch (Exception e) {
            ErrorLogService.log('VpEscalationsController', 'markTaskComplete', taskId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}