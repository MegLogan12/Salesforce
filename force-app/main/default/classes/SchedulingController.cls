/**
 * SchedulingController
 * @AuraEnabled methods for lovingSchedulingConsole LWC.
 *
 * Serves the 15-tab scheduling console used by the Scheduling Manager.
 * Core workflow:
 *   1. AutoScheduleService (daily 2:30pm) creates Pending Review proposals.
 *   2. Manager reviews via Pending Proposals tab → approves per-WO.
 *   3. Approval sets Schedule_Proposal_Status = Manager Approved.
 *   4. WorkOrderHandler.promoteApprovedProposal enforces hard gate (must be
 *      Clear to Schedule bucket) → copies Proposed_* → Scheduled_*, locks WO.
 *   5. SchedulingService.onScheduleLocked fires on trigger to create Pull/Loading
 *      Tickets, Site Readiness Task, and FSL Service Appointment.
 */
public with sharing class SchedulingController {

    // ─────────────────────────────────────────────
    // WRAPPERS
    // ─────────────────────────────────────────────
    public class SchedulingKpis {
        @AuraEnabled public Integer pendingProposals;
        @AuraEnabled public Integer ctsQueue;
        @AuraEnabled public Integer lockedToday;
        @AuraEnabled public Integer siteReadinessOverdue;
        @AuraEnabled public Integer thirtyDayPipeline;
        @AuraEnabled public Integer activeCrews;
        @AuraEnabled public Integer openPullTickets;
        @AuraEnabled public Integer openLoadingTickets;
    }

    public class ProposalRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String url;
        @AuraEnabled public String zone;
        @AuraEnabled public String proposedCrewName;
        @AuraEnabled public Id     proposedCrewId;
        @AuraEnabled public Date   proposedDate;
        @AuraEnabled public String proposedDateDisplay;
        @AuraEnabled public Integer routeStop;
        @AuraEnabled public Decimal routeDistanceMiles;
        @AuraEnabled public String bucket;
        @AuraEnabled public String proposalStatus;
        @AuraEnabled public Datetime proposalCreatedAt;
        @AuraEnabled public Boolean isGateOpen;    // true = CTS bucket → can approve
        @AuraEnabled public String  gateLabel;     // 'Approve' or 'Gate Closed'
        @AuraEnabled public String  chipCss;
        @AuraEnabled public Decimal daysUntilStart;
    }

    public class ScheduledWoRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String url;
        @AuraEnabled public Date   scheduledDate;
        @AuraEnabled public String crewName;
        @AuraEnabled public Id     crewId;
        @AuraEnabled public String zone;
        @AuraEnabled public Integer stopNumber;
        @AuraEnabled public Decimal distanceMiles;
        @AuraEnabled public String status;
        @AuraEnabled public String communityName;
        @AuraEnabled public Decimal sodSqft;
        @AuraEnabled public String siteReadiness; // Completed / Pending / Overdue
        @AuraEnabled public String siteReadinessCss;
    }

    public class CrewRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        @AuraEnabled public String serviceLine;
        @AuraEnabled public String foremanName;
        @AuraEnabled public Integer headcount;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Integer scheduledCount;  // WOs scheduled for target date
        @AuraEnabled public Decimal totalSodSqft;
        @AuraEnabled public String  statusChip;
        @AuraEnabled public String  statusCss;
    }

    public class PullTicketRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public Id     workOrderId;
        @AuraEnabled public Date   scheduledDate;
        @AuraEnabled public Decimal sodSqft;
        @AuraEnabled public String plants;
        @AuraEnabled public Integer trees;
        @AuraEnabled public String status;
        @AuraEnabled public String assignedToName;
        @AuraEnabled public String chipCss;
    }

    public class LoadingTicketRow {
        @AuraEnabled public Id     id;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public Id     workOrderId;
        @AuraEnabled public Integer truckNumber;
        @AuraEnabled public Date   scheduledDate;
        @AuraEnabled public String crewName;
        @AuraEnabled public String fmName;
        @AuraEnabled public Decimal sodExpected;
        @AuraEnabled public Boolean aquaRequired;
        @AuraEnabled public String status;
        @AuraEnabled public String chipCss;
    }

    public class SiteReadinessRow {
        @AuraEnabled public Id     taskId;
        @AuraEnabled public String subject;
        @AuraEnabled public Id     workOrderId;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public Date   dueDate;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String status;
        @AuraEnabled public String urgency;      // Overdue / Due Today / Upcoming
        @AuraEnabled public String urgencyCss;
        @AuraEnabled public Date   scheduledDate;
    }

    // ─────────────────────────────────────────────
    // KPI OVERVIEW
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static SchedulingKpis getSchedulingKpis() {
        SchedulingKpis k = new SchedulingKpis();
        try {
            k.pendingProposals    = [SELECT COUNT() FROM Work_Order__c
                WHERE Schedule_Proposal_Status__c = 'Pending Review'
                  AND Schedule_Locked__c = false];
            k.ctsQueue            = [SELECT COUNT() FROM Work_Order__c
                WHERE Pipeline_Bucket__c = 'Clear to Schedule'
                  AND Schedule_Locked__c = false
                  AND Proposed_Schedule_Date__c = null];
            k.lockedToday         = [SELECT COUNT() FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c = TODAY];
            k.siteReadinessOverdue = [SELECT COUNT() FROM Task
                WHERE Type = 'Site Readiness'
                  AND Status != 'Completed'
                  AND ActivityDate < TODAY];
            k.thirtyDayPipeline   = [SELECT COUNT() FROM Work_Order__c
                WHERE Pipeline_Bucket__c = '30 Days'
                  AND Schedule_Locked__c = false];
            k.activeCrews         = [SELECT COUNT() FROM Crew__c WHERE Active__c = true];
            k.openPullTickets     = [SELECT COUNT() FROM Pull_Ticket__c
                WHERE Status__c = 'Pending Pull'];
            k.openLoadingTickets  = [SELECT COUNT() FROM Loading_Ticket__c
                WHERE Status__c = 'Not Submitted'];
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getSchedulingKpis', null, e.getMessage());
        }
        return k;
    }

    // ─────────────────────────────────────────────
    // PENDING PROPOSALS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<ProposalRow> getPendingProposals() {
        List<ProposalRow> rows = new List<ProposalRow>();
        try {
            for (Work_Order__c wo : [
                SELECT Id, Name, Zone__c, Proposed_Crew__r.Name, Proposed_Crew__c,
                       Proposed_Schedule_Date__c, Route_Stop_Number__c,
                       Route_Distance_Miles__c, Pipeline_Bucket__c,
                       Schedule_Proposal_Status__c, Schedule_Proposal_Created_At__c,
                       Days_Until_Start__c
                FROM Work_Order__c
                WHERE Schedule_Proposal_Status__c = 'Pending Review'
                  AND Schedule_Locked__c = false
                ORDER BY Proposed_Schedule_Date__c ASC NULLS LAST,
                         Route_Stop_Number__c ASC NULLS LAST
                LIMIT 200
            ]) {
                rows.add(buildProposalRow(wo));
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getPendingProposals', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // CLEAR TO SCHEDULE — no proposal yet
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<ProposalRow> getClearToScheduleQueue() {
        List<ProposalRow> rows = new List<ProposalRow>();
        try {
            for (Work_Order__c wo : [
                SELECT Id, Name, Zone__c, Proposed_Crew__r.Name, Proposed_Crew__c,
                       Proposed_Schedule_Date__c, Route_Stop_Number__c,
                       Route_Distance_Miles__c, Pipeline_Bucket__c,
                       Schedule_Proposal_Status__c, Schedule_Proposal_Created_At__c,
                       Days_Until_Start__c
                FROM Work_Order__c
                WHERE Pipeline_Bucket__c = 'Clear to Schedule'
                  AND Schedule_Locked__c = false
                  AND Proposed_Schedule_Date__c = null
                ORDER BY Days_Until_Start__c ASC NULLS LAST
                LIMIT 200
            ]) {
                rows.add(buildProposalRow(wo));
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getClearToScheduleQueue', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // 30-DAY PIPELINE
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<ProposalRow> getThirtyDayPipeline() {
        List<ProposalRow> rows = new List<ProposalRow>();
        try {
            for (Work_Order__c wo : [
                SELECT Id, Name, Zone__c, Proposed_Crew__r.Name, Proposed_Crew__c,
                       Proposed_Schedule_Date__c, Route_Stop_Number__c,
                       Route_Distance_Miles__c, Pipeline_Bucket__c,
                       Schedule_Proposal_Status__c, Schedule_Proposal_Created_At__c,
                       Days_Until_Start__c
                FROM Work_Order__c
                WHERE Pipeline_Bucket__c = '30 Days'
                  AND Schedule_Locked__c = false
                ORDER BY Days_Until_Start__c ASC NULLS LAST
                LIMIT 200
            ]) {
                rows.add(buildProposalRow(wo));
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getThirtyDayPipeline', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // ROUTE BOARD — locked schedule for a date
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<ScheduledWoRow> getRouteBoard(Date schedDate) {
        if (schedDate == null) schedDate = Date.today();
        List<ScheduledWoRow> rows = new List<ScheduledWoRow>();

        try {
            // Note: Crew__c on Work_Order__c is a TEXT field (not a Lookup).
            // Use Stop_Sequence__c (post-lock stop order) for route board.
            List<Work_Order__c> wos = [
                SELECT Id, Name, Scheduled_Date__c, Crew__c,
                       Zone__c, Stop_Sequence__c, Route_Distance_Miles__c,
                       Status__c, Community__r.Name, Sod_Sqft__c
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c = :schedDate
                ORDER BY Crew__c ASC NULLS LAST, Stop_Sequence__c ASC NULLS LAST
                LIMIT 200
            ];
            if (wos.isEmpty()) return rows;

            // Site readiness completion per WO
            Set<Id> woIds = new Map<Id, Work_Order__c>(wos).keySet();
            Set<Id> readinessDone = new Set<Id>();
            Set<Id> readinessPending = new Set<Id>();
            Date today = Date.today();
            for (Task t : [
                SELECT WhatId, Status, ActivityDate FROM Task
                WHERE WhatId IN :woIds
                  AND Type = 'Site Readiness'
                LIMIT 500
            ]) {
                if (t.Status == 'Completed') readinessDone.add(t.WhatId);
                else readinessPending.add(t.WhatId);
            }

            for (Work_Order__c wo : wos) {
                ScheduledWoRow r = new ScheduledWoRow();
                r.id           = wo.Id;
                r.name         = wo.Name;
                r.url          = '/' + wo.Id;
                r.scheduledDate = wo.Scheduled_Date__c;
                r.crewName     = String.isNotBlank(wo.Crew__c) ? wo.Crew__c : '—';
                r.crewId       = null; // Crew__c on Work_Order__c is a TEXT field, not a lookup ID
                r.zone         = wo.Zone__c != null
                                 ? 'Zone ' + String.valueOf(wo.Zone__c.intValue())
                                 : 'Unzoned';
                r.stopNumber   = wo.Stop_Sequence__c != null ? (Integer)wo.Stop_Sequence__c : null;
                r.distanceMiles = wo.Route_Distance_Miles__c;
                r.status       = wo.Status__c;
                r.communityName = wo.Community__r != null ? wo.Community__r.Name : '—';
                r.sodSqft      = wo.Sod_Sqft__c;

                if (readinessDone.contains(wo.Id)) {
                    r.siteReadiness   = 'Complete';
                    r.siteReadinessCss = 'chip chip-green';
                } else if (readinessPending.contains(wo.Id)
                           && schedDate <= today.addDays(2)) {
                    r.siteReadiness   = 'Overdue';
                    r.siteReadinessCss = 'chip chip-red';
                } else {
                    r.siteReadiness   = 'Pending';
                    r.siteReadinessCss = 'chip chip-amber';
                }
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getRouteBoard', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // LOCKED SCHEDULE — date range
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<ScheduledWoRow> getLockedScheduleForRange(Date startDate, Date endDate) {
        if (startDate == null) startDate = Date.today();
        if (endDate == null)   endDate   = startDate.addDays(6);
        List<ScheduledWoRow> rows = new List<ScheduledWoRow>();
        try {
            for (Work_Order__c wo : [
                SELECT Id, Name, Scheduled_Date__c, Crew__c,
                       Zone__c, Stop_Sequence__c, Route_Distance_Miles__c,
                       Status__c, Community__r.Name, Sod_Sqft__c
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c >= :startDate
                  AND Scheduled_Date__c <= :endDate
                ORDER BY Scheduled_Date__c ASC, Crew__c ASC NULLS LAST,
                         Stop_Sequence__c ASC NULLS LAST
                LIMIT 500
            ]) {
                ScheduledWoRow r = new ScheduledWoRow();
                r.id           = wo.Id;
                r.name         = wo.Name;
                r.url          = '/' + wo.Id;
                r.scheduledDate = wo.Scheduled_Date__c;
                r.crewName     = String.isNotBlank(wo.Crew__c) ? wo.Crew__c : '—';
                r.crewId       = null; // Crew__c on Work_Order__c is a TEXT field, not a lookup ID
                r.zone         = wo.Zone__c != null
                                 ? 'Zone ' + String.valueOf(wo.Zone__c.intValue())
                                 : 'Unzoned';
                r.stopNumber   = wo.Stop_Sequence__c != null ? (Integer)wo.Stop_Sequence__c : null;
                r.distanceMiles = wo.Route_Distance_Miles__c;
                r.status       = wo.Status__c;
                r.communityName = wo.Community__r != null ? wo.Community__r.Name : '—';
                r.sodSqft      = wo.Sod_Sqft__c;
                r.siteReadiness = '—';
                r.siteReadinessCss = 'chip chip-gray';
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getLockedScheduleForRange', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // SITE READINESS TASKS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<SiteReadinessRow> getSiteReadinessTasks() {
        List<SiteReadinessRow> rows = new List<SiteReadinessRow>();
        try {
            Date today = Date.today();
            List<Task> tasks = [
                SELECT Id, Subject, WhatId, ActivityDate, Owner.Name, Status
                FROM Task
                WHERE Type = 'Site Readiness'
                  AND Status != 'Completed'
                ORDER BY ActivityDate ASC NULLS LAST
                LIMIT 100
            ];

            // Collect WO IDs and fetch names separately to avoid What.Name polymorphic issue
            Set<Id> woIds2 = new Set<Id>();
            for (Task t : tasks) { if (t.WhatId != null) woIds2.add(t.WhatId); }
            Map<Id, String> woNameMap = new Map<Id, String>();
            for (Work_Order__c wo : [SELECT Id, Name FROM Work_Order__c WHERE Id IN :woIds2]) {
                woNameMap.put(wo.Id, wo.Name);
            }

            for (Task t : tasks) {
                SiteReadinessRow r = new SiteReadinessRow();
                r.taskId       = t.Id;
                r.subject      = t.Subject;
                r.workOrderId  = t.WhatId;
                r.workOrderName = woNameMap.containsKey(t.WhatId) ? woNameMap.get(t.WhatId) : '—';
                r.dueDate      = t.ActivityDate;
                r.ownerName    = t.Owner != null ? t.Owner.Name : '—';
                r.status       = t.Status;

                if (t.ActivityDate != null && t.ActivityDate < today) {
                    r.urgency    = 'Overdue';
                    r.urgencyCss = 'chip chip-red';
                } else if (t.ActivityDate != null && t.ActivityDate == today) {
                    r.urgency    = 'Due Today';
                    r.urgencyCss = 'chip chip-amber';
                } else if (t.ActivityDate != null && t.ActivityDate <= today.addDays(2)) {
                    r.urgency    = 'T-48 Window';
                    r.urgencyCss = 'chip chip-amber';
                } else {
                    r.urgency    = 'Upcoming';
                    r.urgencyCss = 'chip chip-blue';
                }
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getSiteReadinessTasks', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // CREWS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<CrewRow> getCrews(Date schedDate) {
        if (schedDate == null) schedDate = Date.today();
        List<CrewRow> rows = new List<CrewRow>();
        try {
            List<Crew__c> crews = [
                SELECT Id, Name, Service_Line__c, Foreman__r.Name, Headcount__c, Active__c
                FROM Crew__c
                ORDER BY Active__c DESC, Name ASC
                LIMIT 50
            ];
            if (crews.isEmpty()) return rows;

            Set<Id> crewIds = new Map<Id, Crew__c>(crews).keySet();
            Map<Id, Integer> woCount = new Map<Id, Integer>();
            Map<Id, Decimal> sodTotal = new Map<Id, Decimal>();
            for (AggregateResult ar : [
                SELECT Proposed_Crew__c cId, COUNT(Id) cnt, SUM(Sod_Sqft__c) sod
                FROM Work_Order__c
                WHERE Proposed_Crew__c IN :crewIds
                  AND Schedule_Locked__c = true
                  AND Scheduled_Date__c = :schedDate
                GROUP BY Proposed_Crew__c
            ]) {
                Id cId = (Id)ar.get('cId');
                woCount.put(cId, (Integer)ar.get('cnt'));
                sodTotal.put(cId, (Decimal)ar.get('sod'));
            }

            for (Crew__c c : crews) {
                CrewRow r = new CrewRow();
                r.id           = c.Id;
                r.name         = c.Name;
                r.serviceLine  = c.Service_Line__c;
                r.foremanName  = c.Foreman__r != null ? c.Foreman__r.Name : '—';
                r.headcount    = c.Headcount__c != null ? (Integer)c.Headcount__c : 0;
                r.active       = c.Active__c;
                r.scheduledCount = woCount.containsKey(c.Id) ? woCount.get(c.Id) : 0;
                r.totalSodSqft = sodTotal.containsKey(c.Id) ? sodTotal.get(c.Id) : 0;
                r.statusChip   = c.Active__c ? 'Active' : 'Inactive';
                r.statusCss    = c.Active__c ? 'chip chip-green' : 'chip chip-gray';
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getCrews', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // PULL TICKETS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<PullTicketRow> getPullTickets() {
        List<PullTicketRow> rows = new List<PullTicketRow>();
        try {
            List<Pull_Ticket__c> pts = [
                SELECT Id, LOVING_Work_Order__c,
                       Scheduled_Date__c, Sod_Sqft__c, Plants__c,
                       Trees_Count__c, Status__c, Assigned_To__r.Name
                FROM Pull_Ticket__c
                WHERE Status__c != 'Complete'
                ORDER BY Scheduled_Date__c ASC NULLS LAST
                LIMIT 100
            ];
            // Resolve custom Work_Order__c names separately (avoids WorkOrder.Name SOQL issue)
            Set<Id> woIds = new Set<Id>();
            for (Pull_Ticket__c pt : pts) { if (pt.LOVING_Work_Order__c != null) woIds.add(pt.LOVING_Work_Order__c); }
            Map<Id, String> woNameMap = new Map<Id, String>();
            for (Work_Order__c wo : [SELECT Id, Name FROM Work_Order__c WHERE Id IN :woIds]) {
                woNameMap.put(wo.Id, wo.Name);
            }
            for (Pull_Ticket__c pt : pts) {
                PullTicketRow r = new PullTicketRow();
                r.id             = pt.Id;
                r.workOrderName  = woNameMap.containsKey(pt.LOVING_Work_Order__c) ? woNameMap.get(pt.LOVING_Work_Order__c) : '—';
                r.workOrderId    = pt.LOVING_Work_Order__c;
                r.scheduledDate  = pt.Scheduled_Date__c;
                r.sodSqft        = pt.Sod_Sqft__c;
                r.plants         = pt.Plants__c;
                r.trees          = pt.Trees_Count__c != null ? (Integer)pt.Trees_Count__c : 0;
                r.status         = pt.Status__c;
                r.assignedToName = pt.Assigned_To__r != null ? pt.Assigned_To__r.Name : 'Unassigned';
                r.chipCss        = pt.Status__c == 'Pending Pull' ? 'chip chip-amber'
                                 : pt.Status__c == 'In Progress'  ? 'chip chip-blue'
                                 : 'chip chip-green';
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getPullTickets', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // LOADING TICKETS
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<LoadingTicketRow> getLoadingTickets() {
        List<LoadingTicketRow> rows = new List<LoadingTicketRow>();
        try {
            List<Loading_Ticket__c> lts = [
                SELECT Id, LOVING_Work_Order__c,
                       Truck_Number__c, Scheduled_Date__c,
                       Crew__c, FM_Assignment__r.Name,
                       Sod_Sqft_Expected__c, Aqua_Required__c, Status__c
                FROM Loading_Ticket__c
                WHERE Status__c != 'Submitted'
                ORDER BY Scheduled_Date__c ASC NULLS LAST, Truck_Number__c ASC
                LIMIT 100
            ];
            // Resolve custom Work_Order__c names separately
            Set<Id> woIds = new Set<Id>();
            for (Loading_Ticket__c lt : lts) { if (lt.LOVING_Work_Order__c != null) woIds.add(lt.LOVING_Work_Order__c); }
            Map<Id, String> woNameMap = new Map<Id, String>();
            for (Work_Order__c wo : [SELECT Id, Name FROM Work_Order__c WHERE Id IN :woIds]) {
                woNameMap.put(wo.Id, wo.Name);
            }
            for (Loading_Ticket__c lt : lts) {
                LoadingTicketRow r = new LoadingTicketRow();
                r.id           = lt.Id;
                r.workOrderName = woNameMap.containsKey(lt.LOVING_Work_Order__c) ? woNameMap.get(lt.LOVING_Work_Order__c) : '—';
                r.workOrderId  = lt.LOVING_Work_Order__c;
                r.truckNumber  = lt.Truck_Number__c != null ? (Integer)lt.Truck_Number__c : 1;
                r.scheduledDate = lt.Scheduled_Date__c;
                r.crewName     = String.isNotBlank(lt.Crew__c) ? lt.Crew__c : '—';
                r.fmName       = lt.FM_Assignment__r != null ? lt.FM_Assignment__r.Name : '—';
                r.sodExpected  = lt.Sod_Sqft_Expected__c;
                r.aquaRequired = lt.Aqua_Required__c;
                r.status       = lt.Status__c;
                r.chipCss      = lt.Status__c == 'Not Submitted' ? 'chip chip-amber'
                               : lt.Status__c == 'Partial'       ? 'chip chip-blue'
                               : 'chip chip-green';
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getLoadingTickets', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // ACTION: APPROVE PROPOSAL
    // Sets Schedule_Proposal_Status → Manager Approved.
    // WorkOrderHandler.promoteApprovedProposal enforces CTS gate.
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void approveProposal(Id woId) {
        try {
            update new Work_Order__c(
                Id = woId,
                Schedule_Proposal_Status__c = 'Manager Approved'
            );
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'approveProposal', woId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // ACTION: REJECT PROPOSAL
    // Clears proposal fields; WO returns to eligible queue.
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void rejectProposal(Id woId, String reason) {
        try {
            update new Work_Order__c(
                Id = woId,
                Schedule_Proposal_Status__c = null,
                Proposed_Schedule_Date__c   = null,
                Proposed_Crew__c            = null,
                Route_Stop_Number__c        = null,
                Route_Distance_Miles__c     = null
            );
            if (String.isNotBlank(reason)) {
                insert new Task(
                    WhatId      = woId,
                    OwnerId     = UserInfo.getUserId(),
                    Subject     = 'Schedule Proposal Rejected — ' + reason,
                    Status      = 'Completed',
                    Priority    = 'Normal',
                    ActivityDate = Date.today(),
                    Type        = 'Schedule Review',
                    Description = 'Scheduling Manager rejected the auto-proposal. Reason: ' + reason
                );
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'rejectProposal', woId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // ACTION: COMPLETE SITE READINESS TASK
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void completeSiteReadinessTask(Id taskId) {
        try {
            update new Task(Id = taskId, Status = 'Completed');
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'completeSiteReadinessTask', taskId, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // NEW WRAPPERS (spec-aligned tabs)
    // ─────────────────────────────────────────────
    public class DashboardKpis {
        @AuraEnabled public Integer scheduledThisMonth;
        @AuraEnabled public Integer closedThisMonth;
        @AuraEnabled public Integer activeToday;
        @AuraEnabled public Integer readyToSchedule;
        @AuraEnabled public Integer workDaysThisMonth;
        @AuraEnabled public Integer remainingWorkDays;
        @AuraEnabled public Integer workDaysElapsed;
        @AuraEnabled public Decimal stopsPerDayAvg;
        @AuraEnabled public Integer monthProgressPct;
        @AuraEnabled public Integer stopsLeft;
        @AuraEnabled public Integer activeAlertCount;
        @AuraEnabled public List<StatusBar> productionBars;
    }
    public class StatusBar {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public String color;
        @AuraEnabled public Integer widthPct;
    }
    public class CrewWeekRow {
        @AuraEnabled public String crewName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String dotColor;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Integer efficiencyPct;
        @AuraEnabled public String effCss;
        @AuraEnabled public Boolean otRisk;
        @AuraEnabled public String otLabel;
        @AuraEnabled public String otCss;
    }
    public class PendingItems {
        @AuraEnabled public List<PendingRow> inventoryBlocked;
        @AuraEnabled public List<PendingRow> siteReadinessBlocked;
        @AuraEnabled public List<PendingRow> sameDayTickets;
        @AuraEnabled public List<PendingRow> epoAwaiting;
    }
    public class PendingRow {
        @AuraEnabled public Id    id;
        @AuraEnabled public String name;
        @AuraEnabled public String community;
        @AuraEnabled public String blockDetail;
        @AuraEnabled public String chipLabel;
        @AuraEnabled public String chipCss;
        @AuraEnabled public String icon;
        @AuraEnabled public String iconBg;
    }
    public class BoardCrew {
        @AuraEnabled public String crewLabel;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String crewColor;
        @AuraEnabled public Boolean hasFlag;
        @AuraEnabled public String flagNote;
        @AuraEnabled public String summaryChip;
        @AuraEnabled public String summaryChipCss;
        @AuraEnabled public Decimal totalMiles;
        @AuraEnabled public Integer stopCount;
        @AuraEnabled public List<BoardStop> stops;
    }
    public class BoardStop {
        @AuraEnabled public Integer stopNum;
        @AuraEnabled public String woName;
        @AuraEnabled public String url;
        @AuraEnabled public String communityName;
        @AuraEnabled public String workType;
        @AuraEnabled public Decimal distanceMiles;
        @AuraEnabled public Decimal sodSqft;
        @AuraEnabled public Boolean hasWarning;
        @AuraEnabled public String warningNote;
    }
    public class DayOfRow {
        @AuraEnabled public String crewName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String dotColor;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String statusNote;
        @AuraEnabled public String statusCss;
        @AuraEnabled public Integer scheduledCount;
        @AuraEnabled public Boolean isRed;
    }
    public class McSummary {
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal variance;
        @AuraEnabled public Integer variancePct;
        @AuraEnabled public Integer crewsGreen;
        @AuraEnabled public Integer crewsRed;
        @AuraEnabled public Integer totalCrews;
        @AuraEnabled public List<McCrewRow> crewRows;
    }
    public class McCrewRow {
        @AuraEnabled public String crewName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public String dotColor;
        @AuraEnabled public String workSummary;
        @AuraEnabled public Integer stopCount;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal variance;
        @AuraEnabled public String varCss;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String statusCss;
    }
    public class OvertimeRow {
        @AuraEnabled public String resourceName;
        @AuraEnabled public String crewName;
        @AuraEnabled public Decimal weekTotal;
        @AuraEnabled public Boolean otRisk;
        @AuraEnabled public String otLabel;
        @AuraEnabled public String chipCss;
        @AuraEnabled public Boolean isHighlighted;
    }
    public class CrewEffRow {
        @AuraEnabled public String crewName;
        @AuraEnabled public String color;
        @AuraEnabled public Integer stops;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal variance;
        @AuraEnabled public String varLabel;
        @AuraEnabled public String varCss;
        @AuraEnabled public Decimal fjPct;
        @AuraEnabled public Decimal qiScore;
    }
    public class DraftData {
        @AuraEnabled public List<DraftCrewRow> cleared;
        @AuraEnabled public List<DraftCrewRow> blocked;
        @AuraEnabled public String draftTime;
        @AuraEnabled public Boolean hasBlocked;
        @AuraEnabled public Integer clearedCount;
        @AuraEnabled public Integer blockedCount;
    }
    public class DraftCrewRow {
        @AuraEnabled public String crewName;
        @AuraEnabled public String foremanName;
        @AuraEnabled public Integer stops;
        @AuraEnabled public Decimal goalHours;
        @AuraEnabled public Decimal routeMiles;
        @AuraEnabled public String otStatus;
        @AuraEnabled public String otCss;
        @AuraEnabled public String weatherStatus;
        @AuraEnabled public String weatherCss;
        @AuraEnabled public Boolean cleared;
        @AuraEnabled public String blockReason;
        @AuraEnabled public String chipCss;
    }
    public class DecisionRule {
        @AuraEnabled public String condition;
        @AuraEnabled public String systemAction;
        @AuraEnabled public String requiresHuman;
        @AuraEnabled public String foremanNotified;
        @AuraEnabled public String rowCss;
    }

    // ─────────────────────────────────────────────
    // DASHBOARD KPIS (spec Dashboard tab)
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static DashboardKpis getDashboardKpis() {
        DashboardKpis d = new DashboardKpis();
        try {
            Date today        = Date.today();
            Date monthStart   = Date.newInstance(today.year(), today.month(), 1);
            Date monthEnd     = monthStart.addMonths(1).addDays(-1);
            Integer workTotal = countWorkDays(monthStart, monthEnd);
            Integer workElapsed = countWorkDays(monthStart, today);
            d.workDaysThisMonth = workTotal;
            d.workDaysElapsed   = workElapsed;
            d.remainingWorkDays = countWorkDays(today, monthEnd);
            d.monthProgressPct  = workTotal > 0
                                  ? (Integer)((workElapsed * 100) / workTotal) : 0;

            d.scheduledThisMonth = [SELECT COUNT() FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c >= :monthStart
                  AND Scheduled_Date__c <= :monthEnd];
            d.activeToday = [SELECT COUNT() FROM Work_Order__c
                WHERE Schedule_Locked__c = true AND Scheduled_Date__c = TODAY];
            d.readyToSchedule = [SELECT COUNT() FROM Work_Order__c
                WHERE Pipeline_Bucket__c = 'Clear to Schedule'
                  AND Schedule_Locked__c = false];

            // Closed = Approved + downstream statuses this month
            List<String> closedStatuses = new List<String>{
                'Approved','Invoiced','Paid','Closed','Pending Closeout','FM QI Review'};
            d.closedThisMonth = [SELECT COUNT() FROM Work_Order__c
                WHERE Status__c IN :closedStatuses
                  AND Closed_Date__c >= :monthStart
                  AND Closed_Date__c <= :monthEnd];

            d.stopsLeft = d.scheduledThisMonth - d.closedThisMonth;
            if (d.stopsLeft < 0) d.stopsLeft = 0;
            d.stopsPerDayAvg = workElapsed > 0
                               ? (d.closedThisMonth * 1.0 / workElapsed).setScale(1)
                               : 0;

            // OT alerts: crews with scheduled hrs > 40 this week
            d.activeAlertCount = [SELECT COUNT() FROM Work_Order__c
                WHERE Severe_Weather_Hold__c = true AND Schedule_Locked__c = true];

            // Production bars
            d.productionBars = new List<StatusBar>();
            Map<String, Object[]> buckets = new Map<String, Object[]>{
                'Approved / Closed'           => new Object[]{'#2e844a', new List<String>{'Approved','Invoiced','Paid','Closed'}},
                'In Progress / Crew Complete' => new Object[]{'#534ab7', new List<String>{'In Progress','Pending Closeout','FM QI Review'}},
                'Scheduled — upcoming'        => new Object[]{'#0070d2', new List<String>{'Scheduled'}},
                'Ready to Schedule (backlog)' => new Object[]{'#ba7517', new List<String>{'Ready to Schedule'}},
                'Finish Jobs / NFI'           => new Object[]{'#c23934', new List<String>{'Need Further Info (NFI)','Pending Approval'}}
            };
            Integer maxCount = 1;
            List<StatusBar> bars = new List<StatusBar>();
            for (String lbl : buckets.keySet()) {
                Object[] cfg = buckets.get(lbl);
                List<String> statuses = (List<String>)cfg[1];
                Integer cnt = [SELECT COUNT() FROM Work_Order__c
                    WHERE Status__c IN :statuses
                      AND Scheduled_Date__c >= :monthStart
                      AND Scheduled_Date__c <= :monthEnd];
                StatusBar b = new StatusBar();
                b.label  = lbl;
                b.count  = cnt;
                b.color  = (String)cfg[0];
                bars.add(b);
                if (cnt > maxCount) maxCount = cnt;
            }
            for (StatusBar b : bars) {
                b.widthPct = (Integer)((b.count * 100) / maxCount);
                if (b.widthPct < 2 && b.count > 0) b.widthPct = 2;
            }
            d.productionBars = bars;
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getDashboardKpis', null, e.getMessage());
        }
        return d;
    }

    // ─────────────────────────────────────────────
    // CREW WEEKLY UTILIZATION (Dashboard crew table)
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<CrewWeekRow> getCrewWeeklyUtilization() {
        List<CrewWeekRow> rows = new List<CrewWeekRow>();
        try {
            Date today     = Date.today();
            Date weekStart = today.toStartOfWeek().addDays(1); // Mon
            Date weekEnd   = weekStart.addDays(4);             // Fri

            List<Crew__c> crews = [
                SELECT Id, Name, Foreman__r.Name, Weekly_Capacity_Hours__c, Active__c
                FROM Crew__c WHERE Active__c = true ORDER BY Name ASC LIMIT 20
            ];
            if (crews.isEmpty()) return rows;

            // Scheduled WOs this week — use Sod_Sqft__c / 500 as hour proxy
            Map<String, Decimal> crewGoalMap = new Map<String, Decimal>();
            Map<String, Decimal> crewSchedMap = new Map<String, Decimal>();
            for (AggregateResult ar : [
                SELECT Crew__c crName, SUM(Sod_Sqft__c) sqft, COUNT(Id) cnt
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c >= :weekStart
                  AND Scheduled_Date__c <= :weekEnd
                  AND Crew__c != null
                GROUP BY Crew__c
            ]) {
                String cn = (String)ar.get('crName');
                Decimal sqft = ar.get('sqft') != null ? (Decimal)ar.get('sqft') : 0;
                crewSchedMap.put(cn, (sqft / 500).setScale(1));
            }

            String[] colors = new String[]{'#534ab7','#0070d2','#ba7517','#2e844a','#c23934','#0a8aa6'};
            Integer ci = 0;
            for (Crew__c c : crews) {
                CrewWeekRow r = new CrewWeekRow();
                r.crewName   = c.Name;
                r.foremanName = c.Foreman__r != null ? c.Foreman__r.Name : '—';
                r.dotColor   = colors[Math.mod(ci, colors.size())];
                r.goalHours  = c.Weekly_Capacity_Hours__c != null
                               ? c.Weekly_Capacity_Hours__c : 40;
                r.actualHours = crewSchedMap.containsKey(c.Name)
                               ? crewSchedMap.get(c.Name) : 0;
                r.efficiencyPct = r.goalHours > 0
                                  ? (Integer)((r.actualHours / r.goalHours) * 100) : 0;
                r.effCss = r.efficiencyPct > 100 ? 'chip chip-amber'
                         : r.efficiencyPct >= 85  ? 'chip chip-green'
                         : 'chip chip-gray';
                r.otRisk  = r.actualHours > 40;
                r.otLabel = r.otRisk ? c.Foreman__r?.Name : 'None';
                r.otCss   = r.otRisk ? 'chip chip-amber' : 'chip chip-green';
                rows.add(r);
                ci++;
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getCrewWeeklyUtilization', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // PENDING ITEMS (Pending tab — 4 quadrants)
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static PendingItems getPendingItems() {
        PendingItems pi = new PendingItems();
        pi.inventoryBlocked     = new List<PendingRow>();
        pi.siteReadinessBlocked = new List<PendingRow>();
        pi.sameDayTickets       = new List<PendingRow>();
        pi.epoAwaiting          = new List<PendingRow>();
        try {
            // 1. Inventory blocked — Pull Tickets pending
            Set<Id> invWoIds = new Set<Id>();
            for (Pull_Ticket__c pt : [
                SELECT LOVING_Work_Order__c FROM Pull_Ticket__c
                WHERE Status__c = 'Pending Pull' LIMIT 50
            ]) invWoIds.add(pt.LOVING_Work_Order__c);

            for (Work_Order__c wo : [
                SELECT Id, Name, Community__r.Name, Status__c, Sod_Sqft__c, Sod_Species__c
                FROM Work_Order__c WHERE Id IN :invWoIds ORDER BY Name ASC LIMIT 20
            ]) {
                PendingRow r = new PendingRow();
                r.id        = wo.Id;
                r.name      = wo.Name;
                r.community = wo.Community__r != null ? wo.Community__r.Name : '—';
                r.blockDetail = (wo.Sod_Species__c != null ? wo.Sod_Species__c : 'Sod')
                                + (wo.Sod_Sqft__c != null ? ' ' + wo.Sod_Sqft__c.intValue() + ' sf' : '');
                r.chipLabel = 'Pull pending';
                r.chipCss   = 'chip chip-amber';
                r.icon      = '📦';
                r.iconBg    = '#fef3c7';
                pi.inventoryBlocked.add(r);
            }

            // 2. Site Readiness blocked
            Set<Id> srWoIds = new Set<Id>();
            Date today = Date.today();
            for (Task t : [
                SELECT WhatId FROM Task
                WHERE Type = 'Site Readiness' AND Status != 'Completed'
                  AND ActivityDate <= :today.addDays(3)
                LIMIT 50
            ]) if (t.WhatId != null) srWoIds.add(t.WhatId);

            for (Work_Order__c wo : [
                SELECT Id, Name, Community__r.Name, Site_Readiness_Reason__c, Site_Not_Ready_Reason__c
                FROM Work_Order__c WHERE Id IN :srWoIds
                  AND Schedule_Locked__c = false ORDER BY Name ASC LIMIT 20
            ]) {
                PendingRow r = new PendingRow();
                r.id        = wo.Id;
                r.name      = wo.Name;
                r.community = wo.Community__r != null ? wo.Community__r.Name : '—';
                r.blockDetail = String.isNotBlank(wo.Site_Not_Ready_Reason__c)
                                ? wo.Site_Not_Ready_Reason__c
                                : (String.isNotBlank(wo.Site_Readiness_Reason__c)
                                   ? wo.Site_Readiness_Reason__c : 'Pending clearance');
                r.chipLabel = 'Site hold';
                r.chipCss   = 'chip chip-red';
                r.icon      = '🏗';
                r.iconBg    = '#e3f0fb';
                pi.siteReadinessBlocked.add(r);
            }

            // 3. Same-day / urgent tickets (WOs with Sub_Status = Same Day or NFI today)
            for (Work_Order__c wo : [
                SELECT Id, Name, Community__r.Name, Status__c, Sub_Status__c, Work_Order_Type__c
                FROM Work_Order__c
                WHERE (Status__c = 'Need Further Info (NFI)' OR Sub_Status__c = 'Same Day')
                  AND Schedule_Locked__c = true
                  AND Scheduled_Date__c = TODAY
                ORDER BY Name ASC LIMIT 10
            ]) {
                PendingRow r = new PendingRow();
                r.id        = wo.Id;
                r.name      = wo.Name;
                r.community = wo.Community__r != null ? wo.Community__r.Name : '—';
                r.blockDetail = (wo.Work_Order_Type__c != null ? wo.Work_Order_Type__c : '')
                                + ' · ' + (wo.Sub_Status__c != null ? wo.Sub_Status__c : wo.Status__c);
                r.chipLabel = wo.Status__c == 'Need Further Info (NFI)' ? 'Urgent' : 'Same day';
                r.chipCss   = wo.Status__c == 'Need Further Info (NFI)' ? 'chip chip-red' : 'chip chip-amber';
                r.icon      = '🚨';
                r.iconBg    = '#fce8e8';
                pi.sameDayTickets.add(r);
            }

            // 4. EPO awaiting — WOs with open EPO
            for (Work_Order__c wo : [
                SELECT Id, Name, Community__r.Name, EPO_Status__c, EPO_Days_Open__c, EPO_Days_Outstanding__c
                FROM Work_Order__c
                WHERE EPO_Status__c != null
                  AND EPO_Status__c != 'Received'
                  AND EPO_Status__c != 'Not Required'
                ORDER BY EPO_Days_Outstanding__c DESC NULLS LAST LIMIT 10
            ]) {
                PendingRow r = new PendingRow();
                r.id        = wo.Id;
                r.name      = wo.Name;
                r.community = wo.Community__r != null ? wo.Community__r.Name : '—';
                Integer days = wo.EPO_Days_Outstanding__c != null
                               ? (Integer)wo.EPO_Days_Outstanding__c : 0;
                r.blockDetail = 'EPO ' + wo.EPO_Status__c + ' · Day ' + days;
                r.chipLabel = 'Day ' + days;
                r.chipCss   = days >= 3 ? 'chip chip-red' : 'chip chip-amber';
                r.icon      = '📄';
                r.iconBg    = '#e3f0fb';
                pi.epoAwaiting.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getPendingItems', null, e.getMessage());
        }
        return pi;
    }

    // ─────────────────────────────────────────────
    // SCHEDULE BOARD — crew-grouped route strips
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<BoardCrew> getScheduleBoardCrews(Date schedDate) {
        if (schedDate == null) schedDate = Date.today();
        List<BoardCrew> result = new List<BoardCrew>();
        try {
            List<Work_Order__c> wos = [
                SELECT Id, Name, Scheduled_Date__c, Crew__c,
                       Zone__c, Stop_Sequence__c, Route_Distance_Miles__c,
                       Status__c, Community__r.Name, Sod_Sqft__c,
                       Work_Order_Type__c, Severe_Weather_Hold__c,
                       Health_Check_Status__c, Is_Finish_Job__c, FM_Assignment__r.Name
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c = :schedDate
                ORDER BY Crew__c ASC NULLS LAST, Stop_Sequence__c ASC NULLS LAST
                LIMIT 200
            ];

            // Group by crew
            Map<String, List<Work_Order__c>> crewMap = new Map<String, List<Work_Order__c>>();
            for (Work_Order__c wo : wos) {
                String cName = String.isNotBlank(wo.Crew__c) ? wo.Crew__c : 'Unassigned';
                if (!crewMap.containsKey(cName)) crewMap.put(cName, new List<Work_Order__c>());
                crewMap.get(cName).add(wo);
            }

            String[] colors = new String[]{'#534ab7','#0070d2','#ba7517','#2e844a','#c23934','#0a8aa6'};
            Integer ci = 0;
            for (String cName : crewMap.keySet()) {
                List<Work_Order__c> cWos = crewMap.get(cName);
                BoardCrew bc = new BoardCrew();
                bc.crewLabel   = cName;
                bc.crewColor   = colors[Math.mod(ci, colors.size())];
                ci++;
                bc.foremanName = '—';
                for (Work_Order__c w : cWos) {
                    if (w.FM_Assignment__r != null) { bc.foremanName = w.FM_Assignment__r.Name; break; }
                }

                Boolean hasFlag  = false;
                String  flagNote = '';
                Decimal totMiles = 0;
                bc.stops = new List<BoardStop>();

                for (Work_Order__c w : cWos) {
                    BoardStop bs = new BoardStop();
                    bs.stopNum       = w.Stop_Sequence__c != null ? (Integer)w.Stop_Sequence__c : 0;
                    bs.woName        = w.Name;
                    bs.url           = '/' + w.Id;
                    bs.communityName = w.Community__r != null ? w.Community__r.Name : '—';
                    bs.workType      = w.Work_Order_Type__c != null ? w.Work_Order_Type__c : 'PL';
                    bs.distanceMiles = w.Route_Distance_Miles__c;
                    bs.sodSqft       = w.Sod_Sqft__c;
                    bs.hasWarning    = w.Severe_Weather_Hold__c || w.Is_Finish_Job__c;
                    bs.warningNote   = w.Severe_Weather_Hold__c ? 'Weather hold'
                                    : w.Is_Finish_Job__c ? 'Finish Job' : '';
                    if (bs.hasWarning) { hasFlag = true; flagNote = bs.warningNote; }
                    if (w.Route_Distance_Miles__c != null) totMiles += w.Route_Distance_Miles__c;
                    bc.stops.add(bs);
                }

                bc.hasFlag      = hasFlag;
                bc.flagNote     = flagNote;
                bc.totalMiles   = totMiles.setScale(1);
                bc.stopCount    = cWos.size();
                bc.summaryChip  = hasFlag ? flagNote : 'No flags · ' + totMiles.setScale(0) + ' mi';
                bc.summaryChipCss = hasFlag ? 'chip chip-amber' : 'chip chip-green';
                result.add(bc);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getScheduleBoardCrews', null, e.getMessage());
        }
        return result;
    }

    // ─────────────────────────────────────────────
    // DAY-OF MONITOR
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<DayOfRow> getDayOfMonitor() {
        List<DayOfRow> rows = new List<DayOfRow>();
        try {
            List<Crew__c> crews = [
                SELECT Id, Name, Foreman__r.Name, Active__c
                FROM Crew__c WHERE Active__c = true ORDER BY Name ASC LIMIT 20
            ];

            // Today's WOs with health check status per crew
            Map<String, String> crewWorstStatus = new Map<String, String>();
            Map<String, String> crewNotes       = new Map<String, String>();
            Map<String, Integer> crewWoCounts   = new Map<String, Integer>();
            for (Work_Order__c wo : [
                SELECT Crew__c, Health_Check_Status__c, Health_Check_FM_Notes__c
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true AND Scheduled_Date__c = TODAY
                  AND Crew__c != null
                LIMIT 200
            ]) {
                String c = wo.Crew__c;
                crewWoCounts.put(c, (crewWoCounts.containsKey(c) ? crewWoCounts.get(c) : 0) + 1);
                if (wo.Health_Check_Status__c == 'Red') {
                    crewWorstStatus.put(c, 'Red');
                    if (String.isNotBlank(wo.Health_Check_FM_Notes__c))
                        crewNotes.put(c, wo.Health_Check_FM_Notes__c);
                } else if (!crewWorstStatus.containsKey(c)) {
                    crewWorstStatus.put(c, 'Green');
                }
            }

            String[] colors = new String[]{'#534ab7','#0070d2','#ba7517','#2e844a','#c23934','#0a8aa6'};
            Integer ci = 0;
            for (Crew__c c : crews) {
                DayOfRow r = new DayOfRow();
                r.crewName    = c.Name;
                r.foremanName = c.Foreman__r != null ? c.Foreman__r.Name : '—';
                r.dotColor    = colors[Math.mod(ci, colors.size())];
                ci++;
                String st     = crewWorstStatus.containsKey(c.Name) ? crewWorstStatus.get(c.Name) : 'No WOs';
                r.isRed       = st == 'Red';
                r.statusLabel = st;
                r.statusNote  = crewNotes.containsKey(c.Name) ? crewNotes.get(c.Name)
                              : (crewWoCounts.containsKey(c.Name)
                                 ? crewWoCounts.get(c.Name) + ' stops' : 'No stops today');
                r.statusCss   = st == 'Red' ? 'hcard hr' : st == 'Green' ? 'hcard hg' : 'hcard';
                r.scheduledCount = crewWoCounts.containsKey(c.Name) ? crewWoCounts.get(c.Name) : 0;
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getDayOfMonitor', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // MEASURING CUP EMBEDDED SUMMARY
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static McSummary getMeasuringCupSummary() {
        McSummary s = new McSummary();
        s.crewRows = new List<McCrewRow>();
        try {
            List<Crew__c> crews = [
                SELECT Id, Name, Foreman__r.Name, Weekly_Capacity_Hours__c
                FROM Crew__c WHERE Active__c = true ORDER BY Name ASC LIMIT 20
            ];

            // Today's locked WOs grouped by crew (text field)
            Map<String, List<Work_Order__c>> crewWoMap = new Map<String, List<Work_Order__c>>();
            for (Work_Order__c wo : [
                SELECT Crew__c, Sod_Sqft__c, Installed_Sod_Sqft__c, Status__c,
                       Health_Check_Status__c, Community__r.Name, Work_Order_Type__c,
                       Is_Finish_Job__c
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true AND Scheduled_Date__c = TODAY
                  AND Crew__c != null
                LIMIT 200
            ]) {
                String cName = wo.Crew__c;
                if (!crewWoMap.containsKey(cName)) crewWoMap.put(cName, new List<Work_Order__c>());
                crewWoMap.get(cName).add(wo);
            }

            Decimal deptGoal = 0; Decimal deptActual = 0;
            Integer grn = 0; Integer red = 0;
            String[] colors = new String[]{'#534ab7','#0070d2','#ba7517','#2e844a','#c23934','#0a8aa6'};
            Integer ci = 0;

            for (Crew__c c : crews) {
                if (!crewWoMap.containsKey(c.Name)) { ci++; continue; }
                List<Work_Order__c> cWos = crewWoMap.get(c.Name);

                Decimal goalSqft = 0; Decimal actualSqft = 0;
                Boolean hasRed = false; String workSummary = '';
                Set<String> communities = new Set<String>();
                for (Work_Order__c wo : cWos) {
                    if (wo.Sod_Sqft__c != null) goalSqft += wo.Sod_Sqft__c;
                    if (wo.Installed_Sod_Sqft__c != null) actualSqft += wo.Installed_Sod_Sqft__c;
                    else if (wo.Status__c == 'Approved' || wo.Status__c == 'Closed') actualSqft += (wo.Sod_Sqft__c != null ? wo.Sod_Sqft__c : 0);
                    if (wo.Health_Check_Status__c == 'Red') hasRed = true;
                    if (wo.Community__r != null) communities.add(wo.Community__r.Name);
                }
                Decimal gHrs = (goalSqft / 500).setScale(1);
                Decimal aHrs = (actualSqft / 500).setScale(1);
                Decimal var  = (aHrs - gHrs).setScale(1);

                McCrewRow r = new McCrewRow();
                r.crewName    = c.Name;
                r.foremanName = c.Foreman__r != null ? c.Foreman__r.Name : '—';
                r.dotColor    = colors[Math.mod(ci, colors.size())];
                r.stopCount   = cWos.size();
                r.workSummary = String.join(new List<String>(communities), ' + ');
                r.goalHours   = gHrs;
                r.actualHours = aHrs;
                r.variance    = var;
                r.varCss      = var > 0 ? 'var-pos' : 'var-neg';
                r.statusLabel = hasRed ? 'Red' : 'Green';
                r.statusCss   = hasRed ? 'chip chip-red' : 'chip chip-green';
                s.crewRows.add(r);
                deptGoal   += gHrs;
                deptActual += aHrs;
                if (hasRed) red++; else grn++;
                ci++;
            }
            s.goalHours   = deptGoal.setScale(1);
            s.actualHours = deptActual.setScale(1);
            s.variance    = (deptActual - deptGoal).setScale(1);
            s.variancePct = deptGoal > 0 ? (Integer)(((deptActual - deptGoal) / deptGoal) * 100) : 0;
            s.crewsGreen  = grn;
            s.crewsRed    = red;
            s.totalCrews  = grn + red;
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getMeasuringCupSummary', null, e.getMessage());
        }
        return s;
    }

    // ─────────────────────────────────────────────
    // OVERTIME DATA
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<OvertimeRow> getOvertimeData() {
        List<OvertimeRow> rows = new List<OvertimeRow>();
        try {
            Date today     = Date.today();
            Date weekStart = today.toStartOfWeek().addDays(1);
            Date weekEnd   = weekStart.addDays(4);

            List<Crew__c> crews = [
                SELECT Id, Name, Foreman__r.Name, Weekly_Capacity_Hours__c, Active__c
                FROM Crew__c WHERE Active__c = true ORDER BY Name ASC LIMIT 20
            ];

            Map<String, Decimal> crewWeekHours = new Map<String, Decimal>();
            for (AggregateResult ar : [
                SELECT Crew__c crName, SUM(Sod_Sqft__c) sqft
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c >= :weekStart
                  AND Scheduled_Date__c <= :weekEnd
                  AND Crew__c != null
                GROUP BY Crew__c
            ]) {
                String cn = (String)ar.get('crName');
                Decimal sq = ar.get('sqft') != null ? (Decimal)ar.get('sqft') : 0;
                crewWeekHours.put(cn, (sq / 500).setScale(1));
            }

            for (Crew__c c : crews) {
                OvertimeRow r = new OvertimeRow();
                r.resourceName  = c.Foreman__r != null ? c.Foreman__r.Name : c.Name + ' (FM)';
                r.crewName      = c.Name;
                r.weekTotal     = crewWeekHours.containsKey(c.Name) ? crewWeekHours.get(c.Name) : 0;
                r.otRisk        = r.weekTotal > 40;
                r.otLabel       = r.otRisk ? (r.weekTotal - 40).setScale(1) + ' over' : 'No risk';
                r.chipCss       = r.otRisk ? 'chip chip-red' : 'chip chip-green';
                r.isHighlighted = r.otRisk;
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getOvertimeData', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // CREW EFFICIENCY MTD (Crew Optimization tab)
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<CrewEffRow> getCrewEfficiencyMtd() {
        List<CrewEffRow> rows = new List<CrewEffRow>();
        try {
            Date today     = Date.today();
            Date monthStart = Date.newInstance(today.year(), today.month(), 1);

            List<Crew__c> crews = [
                SELECT Id, Name, Weekly_Capacity_Hours__c
                FROM Crew__c WHERE Active__c = true ORDER BY Name ASC LIMIT 20
            ];

            // Aggregate this month's locked/completed WOs by crew name
            Map<String, Decimal> crewGoalSqft   = new Map<String, Decimal>();
            Map<String, Decimal> crewActualSqft  = new Map<String, Decimal>();
            Map<String, Integer> crewStops       = new Map<String, Integer>();
            Map<String, Integer> crewFj          = new Map<String, Integer>();
            Map<String, Decimal> crewQiSum       = new Map<String, Decimal>();
            Map<String, Integer> crewQiCount     = new Map<String, Integer>();

            for (AggregateResult ar : [
                SELECT Crew__c crName,
                       SUM(Sod_Sqft__c) goalSqft,
                       SUM(Installed_Sod_Sqft__c) actSqft,
                       COUNT(Id) cnt,
                       SUM(QI_Score__c) qiSum
                FROM Work_Order__c
                WHERE Crew__c != null
                  AND Scheduled_Date__c >= :monthStart
                  AND Scheduled_Date__c <= :today
                  AND Schedule_Locked__c = true
                GROUP BY Crew__c
            ]) {
                String cn = (String)ar.get('crName');
                crewGoalSqft.put(cn,  ar.get('goalSqft')  != null ? (Decimal)ar.get('goalSqft')  : 0);
                crewActualSqft.put(cn, ar.get('actSqft')  != null ? (Decimal)ar.get('actSqft')   : 0);
                crewStops.put(cn,     ar.get('cnt')        != null ? (Integer)ar.get('cnt')       : 0);
                crewQiSum.put(cn,     ar.get('qiSum')      != null ? (Decimal)ar.get('qiSum')     : 0);
            }

            // FJ count separately (CASE in aggregate not always supported)
            for (AggregateResult ar : [
                SELECT Crew__c crName, COUNT(Id) fjCnt
                FROM Work_Order__c
                WHERE Crew__c != null AND Is_Finish_Job__c = true
                  AND Scheduled_Date__c >= :monthStart
                  AND Scheduled_Date__c <= :today
                GROUP BY Crew__c
            ]) {
                crewFj.put((String)ar.get('crName'), (Integer)ar.get('fjCnt'));
            }

            String[] colors = new String[]{'#534ab7','#0070d2','#ba7517','#2e844a','#c23934','#0a8aa6'};
            Integer ci = 0;
            for (Crew__c c : crews) {
                CrewEffRow r = new CrewEffRow();
                r.crewName  = c.Name;
                r.color     = colors[Math.mod(ci, colors.size())]; ci++;
                r.stops     = crewStops.containsKey(c.Name) ? crewStops.get(c.Name) : 0;

                Decimal gs = crewGoalSqft.containsKey(c.Name)      ? crewGoalSqft.get(c.Name)      : 0;
                Decimal actSqft = crewActualSqft.containsKey(c.Name) ? crewActualSqft.get(c.Name) : 0;
                // fall back to goal if actual not populated yet
                if (actSqft == 0 && gs > 0) actSqft = gs;
                r.goalHours   = (gs / 500).setScale(1);
                r.actualHours = (actSqft / 500).setScale(1);
                r.variance    = (r.actualHours - r.goalHours).setScale(1);
                r.varLabel    = (r.variance > 0 ? '+' : '') + r.variance;
                r.varCss      = r.variance > 0 ? 'chip chip-amber' : 'chip chip-green';

                Integer fjCnt = crewFj.containsKey(c.Name) ? crewFj.get(c.Name) : 0;
                r.fjPct = r.stops > 0
                          ? ((fjCnt * 100.0) / r.stops).setScale(1) : 0;
                Decimal qiS = crewQiSum.containsKey(c.Name) ? crewQiSum.get(c.Name) : 0;
                r.qiScore = r.stops > 0 ? (qiS / r.stops).setScale(1) : 0;
                rows.add(r);
            }
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getCrewEfficiencyMtd', null, e.getMessage());
        }
        return rows;
    }

    // ─────────────────────────────────────────────
    // DRAFT REVIEW DATA (3PM draft)
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static DraftData getDraftReviewData() {
        DraftData dd = new DraftData();
        dd.cleared  = new List<DraftCrewRow>();
        dd.blocked  = new List<DraftCrewRow>();
        dd.draftTime = '3:00 PM';
        try {
            Date today = Date.today();
            // Get all crews with locked WOs today
            Map<String, List<Work_Order__c>> crewWoMap = new Map<String, List<Work_Order__c>>();
            for (Work_Order__c wo : [
                SELECT Crew__c, Sod_Sqft__c, Route_Distance_Miles__c,
                       Severe_Weather_Hold__c, Status__c, FM_Assignment__r.Name
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true AND Scheduled_Date__c = :today
                  AND Crew__c != null LIMIT 200
            ]) {
                String cName = wo.Crew__c;
                if (!crewWoMap.containsKey(cName)) crewWoMap.put(cName, new List<Work_Order__c>());
                crewWoMap.get(cName).add(wo);
            }

            // Check for OT-risk crew names
            Date weekStart = today.toStartOfWeek().addDays(1);
            Date weekEnd   = weekStart.addDays(4);
            Set<String> otRiskCrews = new Set<String>();
            for (AggregateResult ar : [
                SELECT Crew__c crName, SUM(Sod_Sqft__c) sqft
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c >= :weekStart AND Scheduled_Date__c <= :weekEnd
                  AND Crew__c != null GROUP BY Crew__c
            ]) {
                Decimal sqft = ar.get('sqft') != null ? (Decimal)ar.get('sqft') : 0;
                if ((sqft / 500) > 40) otRiskCrews.add((String)ar.get('crName'));
            }

            for (String cName : crewWoMap.keySet()) {
                List<Work_Order__c> cWos = crewWoMap.get(cName);
                DraftCrewRow r = new DraftCrewRow();
                r.crewName    = cName;
                r.foremanName = cWos[0].FM_Assignment__r != null ? cWos[0].FM_Assignment__r.Name : '—';
                r.stops       = cWos.size();
                Decimal totSqft = 0; Decimal totMi = 0; Boolean wxHold = false;
                for (Work_Order__c w : cWos) {
                    if (w.Sod_Sqft__c != null) totSqft += w.Sod_Sqft__c;
                    if (w.Route_Distance_Miles__c != null) totMi += w.Route_Distance_Miles__c;
                    if (w.Severe_Weather_Hold__c) wxHold = true;
                }
                r.goalHours     = (totSqft / 500).setScale(1);
                r.routeMiles    = totMi.setScale(1);
                Boolean otBlock = otRiskCrews.contains(cName);
                r.otStatus  = otBlock ? 'OT risk' : 'None';
                r.otCss     = otBlock ? 'chip chip-amber' : 'chip chip-green';
                r.weatherStatus = wxHold ? 'Hold' : 'Clear';
                r.weatherCss   = wxHold ? 'chip chip-red' : 'chip chip-green';
                r.cleared      = !otBlock && !wxHold;
                r.blockReason  = otBlock ? 'OT risk — resolve in Overtime tab'
                               : wxHold  ? 'Severe weather hold active'
                               : '';
                r.chipCss = r.cleared ? 'chip chip-green' : 'chip chip-amber';
                if (r.cleared) dd.cleared.add(r); else dd.blocked.add(r);
            }
            dd.hasBlocked   = !dd.blocked.isEmpty();
            dd.clearedCount = dd.cleared.size();
            dd.blockedCount = dd.blocked.size();
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'getDraftReviewData', null, e.getMessage());
        }
        return dd;
    }

    // ─────────────────────────────────────────────
    // DECISION RULES (governance reference table)
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<DecisionRule> getDecisionRules() {
        List<DecisionRule> rules = new List<DecisionRule>();
        Object[][] data = new Object[][]{
            new Object[]{'Traffic +≤15 min',           'Update Travel_Minutes__c. RTN recalc.',           'No',      'No',       ''},
            new Object[]{'Traffic — RTN past 5:30 PM', 'Alert scheduling. Status → Needs Review.',        'Yes',     'After',    'warn-row'},
            new Object[]{'Road closure',               'SF Maps alternate route applied.',                 'Yes',     'After',    'warn-row'},
            new Object[]{'Weather Watch',              'Dashboard flag. Stops proceed.',                   'No',      'Yes — note',''},
            new Object[]{'Weather Warning',            'Stops → Needs Review.',                            'Yes',     'If hold',  'warn-row'},
            new Object[]{'Severe weather / tornado',   'Auto-hold all territory stops. COO override only.','COO only','Do not depart','alert-row'},
            new Object[]{'Schedule Issue alert',       'Flag stops. Auto-draft notification email.',       'Yes',     'After',    'warn-row'},
            new Object[]{'Standing water on lot',      'WO → Site Not Ready. Task created.',               'Yes',     'FM on site','warn-row'},
            new Object[]{'OT risk at 3PM draft',       'Block from auto-release. Crew blocked.',           'Yes',     'After',    'warn-row'},
            new Object[]{'60-mile cap exceeded',       'Block auto-publish. Alert scheduling.',            'Yes',     'After',    'warn-row'},
            new Object[]{'Stop drag/drop (SF Maps)',   'SF Maps recalculates segment order.',              'No',      'Yes',      ''},
            new Object[]{'Re-optimize one-click',      'SF Maps finds optimal stop sequence.',             'Yes',     'After',    ''},
            new Object[]{'Rippling PTO sync',          'Mark resource unavailable. Reassign stops.',       'Yes',     'No',       'ok-row'},
            new Object[]{'Inventory backorder',        'WO → Pending (Pull Ticket blocked).',              'Yes',     'No',       'ok-row'},
            new Object[]{'Site not ready — builder',   'WO stays in backlog. Alert CSM.',                  'Yes',     'No',       ''}
        };
        for (Object[] d : data) {
            DecisionRule r = new DecisionRule();
            r.condition       = (String)d[0];
            r.systemAction    = (String)d[1];
            r.requiresHuman   = (String)d[2];
            r.foremanNotified = (String)d[3];
            r.rowCss          = (String)d[4];
            rules.add(r);
        }
        return rules;
    }

    // ─────────────────────────────────────────────
    // ACTION: RELEASE SCHEDULE (approve cleared crews)
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void releaseSchedule(Date schedDate) {
        if (schedDate == null) schedDate = Date.today();
        try {
            List<Work_Order__c> toRelease = [
                SELECT Id, Crew__c, Severe_Weather_Hold__c
                FROM Work_Order__c
                WHERE Schedule_Locked__c = true
                  AND Scheduled_Date__c = :schedDate
                  AND Severe_Weather_Hold__c = false
                LIMIT 200
            ];
            // Mark as officially released for 4PM — set Sub_Status if needed
            // For now, this is a no-op placeholder; business logic to add as needed
            // update toRelease; // Would update a Released_At__c field if it exists
        } catch (Exception e) {
            ErrorLogService.log('SchedulingController', 'releaseSchedule', null, e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // HELPER — count Mon–Fri business days in range
    // ─────────────────────────────────────────────
    private static Integer countWorkDays(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || endDate < startDate) return 0;
        Integer count = 0;
        Date d = startDate;
        while (d <= endDate) {
            Integer dow = Math.mod(Date.newInstance(1900, 1, 7).daysBetween(d), 7);
            // dow: 0=Sun,1=Mon,...,5=Sat,6=Sun (shifted)
            // Use dayOfWeek: 1=Sun…7=Sat in Apex Date
            Integer dayNum = d.toStartOfWeek().daysBetween(d); // 0=Sun,1=Mon,…,6=Sat
            if (dayNum >= 1 && dayNum <= 5) count++;
            d = d.addDays(1);
        }
        return count;
    }

    // ─────────────────────────────────────────────
    // HELPER
    // ─────────────────────────────────────────────
    private static ProposalRow buildProposalRow(Work_Order__c wo) {
        ProposalRow r = new ProposalRow();
        r.id                = wo.Id;
        r.name              = wo.Name;
        r.url               = '/' + wo.Id;
        r.zone              = wo.Zone__c != null
                              ? 'Zone ' + String.valueOf(wo.Zone__c.intValue())
                              : 'Unzoned';
        r.proposedCrewName  = wo.Proposed_Crew__r != null ? wo.Proposed_Crew__r.Name : '—';
        r.proposedCrewId    = wo.Proposed_Crew__c;
        r.proposedDate      = wo.Proposed_Schedule_Date__c;
        r.proposedDateDisplay = wo.Proposed_Schedule_Date__c != null
                              ? wo.Proposed_Schedule_Date__c.format() : '—';
        r.routeStop         = wo.Route_Stop_Number__c != null ? (Integer)wo.Route_Stop_Number__c : null;
        r.routeDistanceMiles = wo.Route_Distance_Miles__c;
        r.bucket            = wo.Pipeline_Bucket__c;
        r.proposalStatus    = wo.Schedule_Proposal_Status__c;
        r.proposalCreatedAt = wo.Schedule_Proposal_Created_At__c;
        r.daysUntilStart    = wo.Days_Until_Start__c;
        r.isGateOpen        = wo.Pipeline_Bucket__c == 'Clear to Schedule';
        r.gateLabel         = r.isGateOpen ? 'Approve' : 'Gate Closed';
        r.chipCss           = wo.Schedule_Proposal_Status__c == 'Pending Review'
                              ? 'chip chip-amber'
                              : wo.Schedule_Proposal_Status__c == 'Manager Approved'
                              ? 'chip chip-green'
                              : 'chip chip-gray';
        return r;
    }
}