public with sharing class LovingSchedulingActionService {
    private static final Integer ROW_LIMIT = 50;
    @TestVisible private static Boolean bypassPermissionForTests = false;
    @TestVisible private static Boolean forceSkillMismatchForTests = false;

    public class ActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Boolean blocked;
        @AuraEnabled public String message;
        @AuraEnabled public String recordId;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String gate;
        @AuraEnabled public String technicalDetail;
        @AuraEnabled public List<String> details;
    }

    public class SlotRecommendation {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String serviceAppointmentId;
        @AuraEnabled public String serviceResourceId;
        @AuraEnabled public String serviceResourceName;
        @AuraEnabled public Datetime startDateTime;
        @AuraEnabled public Datetime endDateTime;
        @AuraEnabled public Integer score;
        @AuraEnabled public List<String> reasons;
    }

    public class RouteStopUpdate {
        @AuraEnabled public Id scheduleStopId;
        @AuraEnabled public Decimal stopNumber;
    }

    public static LovingSchedulingOverlayService.ConsoleData getSchedulingOptimizationData() {
        return LovingSchedulingOverlayService.getConsoleData();
    }

    public static SlotRecommendation findBestSlot(Id serviceAppointmentId) {
        SlotRecommendation rec = new SlotRecommendation();
        rec.success = false;
        rec.serviceAppointmentId = String.valueOf(serviceAppointmentId);
        rec.reasons = new List<String>();

        ServiceAppointment sa = loadServiceAppointment(serviceAppointmentId);
        if (sa == null) {
            rec.message = 'Service Appointment was not found.';
            return rec;
        }
        List<String> gates = baseReadinessFailures(sa, false);
        if (!gates.isEmpty()) {
            rec.message = 'Cannot recommend a slot yet: ' + String.join(gates, ' / ');
            rec.reasons.addAll(gates);
            return rec;
        }

        Datetime startTime = sa.SchedStartTime == null ? System.now().addDays(1) : sa.SchedStartTime;
        Datetime endTime = sa.SchedEndTime == null ? startTime.addMinutes(durationMinutes(sa)) : sa.SchedEndTime;
        List<ServiceResource> candidates = candidateResources(sa, startTime, endTime);
        if (candidates.isEmpty()) {
            rec.message = 'No active qualified resource is available for the appointment territory, skills, and time window.';
            rec.reasons.add('No active qualified resource passed territory, skill, and absence gates.');
            return rec;
        }

        ServiceResource chosen = candidates[0];
        rec.success = true;
        rec.serviceResourceId = chosen.Id;
        rec.serviceResourceName = chosen.Name;
        rec.startDateTime = startTime;
        rec.endDateTime = endTime;
        rec.score = 90;
        rec.message = 'Recommended ' + chosen.Name + ' from ' + String.valueOf(startTime) + ' to ' + String.valueOf(endTime) + '. No records were changed.';
        rec.reasons.add('Resource is active.');
        rec.reasons.add('Resource belongs to the Service Appointment territory.');
        rec.reasons.add('Resource satisfies required skills or no skills are required.');
        rec.reasons.add('No ResourceAbsence overlaps the recommended window.');
        return rec;
    }

    public static ActionResult assignResource(Id serviceAppointmentId, Id serviceResourceId, String reason) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule', 'Assign Resource');
            requireReason(reason, 'Assign Resource');
            ServiceAppointment sa = requireAppointment(serviceAppointmentId);
            requireUnlocked(sa, false);
            requireBaseSchedulingGates(sa);
            ServiceResource sr = requireResource(serviceResourceId);
            Datetime startTime = sa.SchedStartTime == null ? System.now().addDays(1) : sa.SchedStartTime;
            Datetime endTime = sa.SchedEndTime == null ? startTime.addMinutes(durationMinutes(sa)) : sa.SchedEndTime;
            validateResourceForAppointment(sa, sr, startTime, endTime);

            List<AssignedResource> existing = [
                SELECT Id, ServiceResourceId
                FROM AssignedResource
                WHERE ServiceAppointmentId = :serviceAppointmentId
                LIMIT 1
            ];
            AssignedResource assignment;
            if (existing.isEmpty()) {
                assignment = new AssignedResource(ServiceAppointmentId = serviceAppointmentId, ServiceResourceId = serviceResourceId);
                insert assignment;
                return success(result, assignment.Id, 'Assigned resource ' + sr.Name + ' to Service Appointment ' + sa.AppointmentNumber + '.');
            }
            assignment = existing[0];
            assignment.ServiceResourceId = serviceResourceId;
            update assignment;
            return success(result, assignment.Id, 'Updated assigned resource to ' + sr.Name + ' for Service Appointment ' + sa.AppointmentNumber + '.');
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Assign Resource failed.');
        }
    }

    public static ActionResult setScheduledTime(Id serviceAppointmentId, Datetime startDateTime, Datetime endDateTime, String reason) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule', 'Set Scheduled Time');
            requireReason(reason, 'Set Scheduled Time');
            if (startDateTime == null || endDateTime == null || endDateTime <= startDateTime) {
                throw new SchedulingException('Validation', 'Scheduled start/end must be populated and end must be after start.');
            }
            ServiceAppointment sa = requireAppointment(serviceAppointmentId);
            requireUnlocked(sa, false);
            requireBaseSchedulingGates(sa);
            sa.SchedStartTime = startDateTime;
            sa.SchedEndTime = endDateTime;
            update sa;
            return success(result, sa.Id, 'Updated scheduled time for Service Appointment ' + sa.AppointmentNumber + '.');
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Set Scheduled Time failed.');
        }
    }

    public static ActionResult lockSchedule(Id serviceAppointmentId, String reason) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule_Release_Approval', 'Lock Schedule');
            requireReason(reason, 'Lock Schedule');
            ServiceAppointment sa = requireAppointment(serviceAppointmentId);
            requireBaseSchedulingGates(sa);
            sa.FSL__Pinned__c = true;
            update sa;
            return success(result, sa.Id, 'Locked schedule for Service Appointment ' + sa.AppointmentNumber + '.');
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Lock Schedule failed.');
        }
    }

    public static ActionResult unlockSchedule(Id serviceAppointmentId, String reason) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule_Release_Approval', 'Unlock Schedule');
            requireReason(reason, 'Unlock Schedule');
            ServiceAppointment sa = requireAppointment(serviceAppointmentId);
            sa.FSL__Pinned__c = false;
            update sa;
            return success(result, sa.Id, 'Unlocked schedule for Service Appointment ' + sa.AppointmentNumber + '.');
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Unlock Schedule failed.');
        }
    }

    public static ActionResult returnToReview(Id serviceAppointmentId, String issueType, String reason) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule', 'Return to Review');
            requireReason(reason, 'Return to Review');
            ServiceAppointment sa = requireAppointment(serviceAppointmentId);
            Schedule_Issue__c issue = createIssue(sa, normalizeIssueType(issueType), reason, 'High');
            if (isPicklistValue('ServiceAppointment', 'Status', 'Pending Takeoff')) {
                try {
                    sa.Status = 'Pending Takeoff';
                    update sa;
                } catch (Exception statusEx) {
                    result.details.add('Schedule Issue was created, but the Service Appointment status was not changed: ' + statusEx.getMessage());
                }
            }
            return addIssueLinkDetail(success(result, issue.Id, 'Returned Service Appointment ' + sa.AppointmentNumber + ' to review with a ' + issue.Issue_Type__c + ' Schedule Issue.'), issue);
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Return to Review failed.');
        }
    }

    public static ActionResult addSchedulingHold(Id serviceAppointmentId, String issueType, String reason) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule', 'Add Hold');
            requireReason(reason, 'Add Hold');
            ServiceAppointment sa = requireAppointment(serviceAppointmentId);
            Schedule_Issue__c issue = createIssue(sa, normalizeIssueType(issueType), reason, 'High');
            return addIssueLinkDetail(success(result, issue.Id, 'Added ' + issue.Issue_Type__c + ' scheduling hold for Service Appointment ' + sa.AppointmentNumber + '.'), issue);
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Add Hold failed.');
        }
    }

    public static ActionResult clearSchedulingHold(Id scheduleIssueId, String resolutionNotes) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule_Release_Approval', 'Clear Hold');
            requireReason(resolutionNotes, 'Clear Hold');
            Schedule_Issue__c issue = [
                SELECT Id, Name, Status__c, Resolution_Notes__c
                FROM Schedule_Issue__c
                WHERE Id = :scheduleIssueId
                LIMIT 1
            ];
            issue.Status__c = 'Resolved';
            issue.Resolution_Notes__c = resolutionNotes;
            update issue;
            return success(result, issue.Id, 'Cleared Schedule Issue ' + issue.Name + '.');
        } catch (QueryException ex) {
            return blocked(result, 'Schedule Issue', 'Schedule Issue was not found.', ex.getMessage());
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Clear Hold failed.');
        }
    }

    public static ActionResult flagSchedulingConflict(Id serviceAppointmentId, String conflictType, String reason) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule', 'Flag Conflict');
            requireReason(reason, 'Flag Conflict');
            ServiceAppointment sa = requireAppointment(serviceAppointmentId);
            Schedule_Issue__c issue = createIssue(sa, normalizeIssueType(conflictType), reason, 'Medium');
            return addIssueLinkDetail(success(result, issue.Id, 'Flagged scheduling conflict for Service Appointment ' + sa.AppointmentNumber + '.'), issue);
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Flag Conflict failed.');
        }
    }

    public static ActionResult applyRouteOrder(List<RouteStopUpdate> scheduleStopUpdates, String reason) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule_Release_Approval', 'Apply Route Order');
            requireReason(reason, 'Apply Route Order');
            if (scheduleStopUpdates == null || scheduleStopUpdates.isEmpty()) {
                throw new SchedulingException('Route Order', 'At least one Schedule Stop update is required.');
            }
            List<Schedule_Stop__c> updates = new List<Schedule_Stop__c>();
            Set<Id> seen = new Set<Id>();
            for (RouteStopUpdate item : scheduleStopUpdates) {
                if (item == null || item.scheduleStopId == null || item.stopNumber == null) {
                    throw new SchedulingException('Route Order', 'Each route update must include Schedule Stop Id and Stop Number.');
                }
                if (seen.contains(item.scheduleStopId)) {
                    throw new SchedulingException('Route Order', 'Duplicate Schedule Stop update detected: ' + item.scheduleStopId);
                }
                seen.add(item.scheduleStopId);
                updates.add(new Schedule_Stop__c(Id = item.scheduleStopId, Stop_Number__c = item.stopNumber));
            }
            update updates;
            result = success(result, updates[0].Id, 'Applied route order to ' + updates.size() + ' Schedule Stop record(s).');
            result.details.add('Reason: ' + reason);
            return result;
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Apply Route Order failed.');
        }
    }

    public static ActionResult releaseToField(Id serviceAppointmentId, String reason) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule_Release_Approval', 'Release to Field');
            requireReason(reason, 'Release to Field');
            ServiceAppointment sa = requireAppointment(serviceAppointmentId);
            requireUnlocked(sa, false);
            requireReleaseGates(sa);
            if (!isPicklistValue('ServiceAppointment', 'Status', 'Dispatched')) {
                throw new SchedulingException('Release Status', 'ServiceAppointment.Status value Dispatched does not exist.');
            }
            sa.Status = 'Dispatched';
            update sa;
            return success(result, sa.Id, 'Released Service Appointment ' + sa.AppointmentNumber + ' to field execution.');
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Release to Field failed.');
        }
    }

    public static ActionResult notifyFieldManager(Id serviceAppointmentId, String message) {
        ActionResult result = startResult();
        try {
            requirePermission('Schedule', 'Notify Field Manager');
            requireReason(message, 'Notify Field Manager');
            ServiceAppointment sa = requireAppointment(serviceAppointmentId);
            Id ownerId = UserInfo.getUserId();
            Id workOrderId = parentWorkOrderId(sa);
            if (workOrderId != null) {
                WorkOrder wo = [SELECT Id, Field_Manager__c FROM WorkOrder WHERE Id = :workOrderId LIMIT 1];
                if (wo.Field_Manager__c != null) {
                    ownerId = wo.Field_Manager__c;
                }
            }
            Task task = new Task(
                WhatId = workOrderId == null ? serviceAppointmentId : workOrderId,
                OwnerId = ownerId,
                Subject = 'Scheduling Console: Field Manager Notification',
                Status = 'Not Started',
                Priority = 'Normal',
                Description = message
            );
            insert task;
            return success(result, task.Id, 'Created Field Manager notification task for Service Appointment ' + sa.AppointmentNumber + '.');
        } catch (SchedulingException ex) {
            return blocked(result, ex.gate, ex.getMessage(), ex.getMessage());
        } catch (Exception ex) {
            return systemError(result, ex, 'Notify Field Manager failed.');
        }
    }

    private static void requireReleaseGates(ServiceAppointment sa) {
        requireBaseSchedulingGates(sa);
        List<Schedule_Issue__c> issues = openIssuesForAppointment(sa);
        if (!issues.isEmpty()) {
            throw new SchedulingException('Open Hold', 'Open Schedule Issue blocks release: ' + issues[0].Issue_Type__c + ' / ' + issues[0].Summary__c);
        }
        Id workOrderId = parentWorkOrderId(sa);
        if (workOrderId != null) {
            WorkOrder wo = [SELECT Id, Takeoff_Completed__c FROM WorkOrder WHERE Id = :workOrderId LIMIT 1];
            if (wo.Takeoff_Completed__c != true) {
                throw new SchedulingException('Takeoff', 'Takeoff must be completed before release to field.');
            }
        }
    }

    private static void requireBaseSchedulingGates(ServiceAppointment sa) {
        List<String> failures = baseReadinessFailures(sa, true);
        if (!failures.isEmpty()) {
            throw new SchedulingException('Readiness', String.join(failures, ' / '));
        }
    }

    private static List<String> baseReadinessFailures(ServiceAppointment sa, Boolean includeLock) {
        List<String> failures = new List<String>();
        if (sa == null) {
            failures.add('Service Appointment is missing.');
            return failures;
        }
        if (includeLock && sa.FSL__Pinned__c == true) {
            failures.add('Schedule is locked. Unlock permission is required before changing it.');
        }
        if (sa.WorkTypeId == null) {
            failures.add('WorkType is missing.');
        }
        if (sa.ServiceTerritoryId == null) {
            failures.add('Service Territory is missing.');
        }
        return failures;
    }

    private static void validateResourceForAppointment(ServiceAppointment sa, ServiceResource sr, Datetime startTime, Datetime endTime) {
        if (sr.IsActive != true) {
            throw new SchedulingException('Resource Active', 'Resource is inactive and cannot be assigned.');
        }
        if (!resourceInTerritory(sr.Id, sa.ServiceTerritoryId, startTime)) {
            throw new SchedulingException('Territory', 'Resource is not assigned to the Service Appointment territory.');
        }
        if (!resourceHasRequiredSkills(sr.Id, sa.WorkTypeId)) {
            throw new SchedulingException('Skills', 'Resource lacks a required skill for this WorkType.');
        }
        if (hasAbsence(sr.Id, startTime, endTime)) {
            throw new SchedulingException('Absence', 'Resource is absent during the selected time window.');
        }
    }

    private static List<ServiceResource> candidateResources(ServiceAppointment sa, Datetime startTime, Datetime endTime) {
        List<ServiceResource> resources = [
            SELECT Id, Name, IsActive
            FROM ServiceResource
            WHERE IsActive = true
            ORDER BY Name
            LIMIT :ROW_LIMIT
        ];
        List<ServiceResource> candidates = new List<ServiceResource>();
        for (ServiceResource sr : resources) {
            try {
                validateResourceForAppointment(sa, sr, startTime, endTime);
                candidates.add(sr);
            } catch (SchedulingException ex) {
                // Candidate failed a gate; keep looking.
            }
        }
        return candidates;
    }

    private static ServiceAppointment requireAppointment(Id serviceAppointmentId) {
        ServiceAppointment sa = loadServiceAppointment(serviceAppointmentId);
        if (sa == null) {
            throw new SchedulingException('Service Appointment', 'Service Appointment was not found.');
        }
        return sa;
    }

    private static ServiceAppointment loadServiceAppointment(Id serviceAppointmentId) {
        if (serviceAppointmentId == null) {
            return null;
        }
        List<ServiceAppointment> rows = [
            SELECT Id, AppointmentNumber, Subject, Status, SchedStartTime, SchedEndTime, Duration,
                   WorkTypeId, ServiceTerritoryId, ParentRecordId, FSL__Pinned__c
            FROM ServiceAppointment
            WHERE Id = :serviceAppointmentId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static ServiceResource requireResource(Id serviceResourceId) {
        if (serviceResourceId == null) {
            throw new SchedulingException('Resource', 'Service Resource is required.');
        }
        List<ServiceResource> rows = [
            SELECT Id, Name, IsActive
            FROM ServiceResource
            WHERE Id = :serviceResourceId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new SchedulingException('Resource', 'Service Resource was not found.');
        }
        return rows[0];
    }

    private static Boolean resourceInTerritory(Id resourceId, Id territoryId, Datetime startTime) {
        if (resourceId == null || territoryId == null) {
            return false;
        }
        List<ServiceTerritoryMember> rows = [
            SELECT Id
            FROM ServiceTerritoryMember
            WHERE ServiceResourceId = :resourceId
            AND ServiceTerritoryId = :territoryId
            AND EffectiveStartDate <= :startTime
            AND (EffectiveEndDate = null OR EffectiveEndDate >= :startTime)
            LIMIT 1
        ];
        return !rows.isEmpty();
    }

    private static Boolean resourceHasRequiredSkills(Id resourceId, Id workTypeId) {
        if (Test.isRunningTest() && forceSkillMismatchForTests) {
            return false;
        }
        if (workTypeId == null) {
            return false;
        }
        List<SkillRequirement> requirements = [
            SELECT SkillId, SkillLevel
            FROM SkillRequirement
            WHERE RelatedRecordId = :workTypeId
        ];
        if (requirements.isEmpty()) {
            return true;
        }
        Map<Id, Decimal> required = new Map<Id, Decimal>();
        for (SkillRequirement req : requirements) {
            required.put(req.SkillId, req.SkillLevel == null ? 0 : req.SkillLevel);
        }
        for (ServiceResourceSkill skill : [
            SELECT SkillId, SkillLevel
            FROM ServiceResourceSkill
            WHERE ServiceResourceId = :resourceId
            AND SkillId IN :required.keySet()
        ]) {
            if (skill.SkillLevel == null || skill.SkillLevel >= required.get(skill.SkillId)) {
                required.remove(skill.SkillId);
            }
        }
        return required.isEmpty();
    }

    private static Boolean hasAbsence(Id resourceId, Datetime startTime, Datetime endTime) {
        if (resourceId == null || startTime == null || endTime == null) {
            return false;
        }
        return [
            SELECT COUNT()
            FROM ResourceAbsence
            WHERE ResourceId = :resourceId
            AND Start < :endTime
            AND End > :startTime
        ] > 0;
    }

    private static List<Schedule_Issue__c> openIssuesForAppointment(ServiceAppointment sa) {
        Id standardWorkOrderId = parentWorkOrderId(sa);
        if (standardWorkOrderId != null) {
            return [
                SELECT Id, Name, Issue_Type__c, Status__c, Summary__c
                FROM Schedule_Issue__c
                WHERE Standard_WorkOrder__c = :standardWorkOrderId
                AND Status__c IN ('Open', 'In Review')
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        }

        return new List<Schedule_Issue__c>();
    }

    private static Schedule_Issue__c createIssue(ServiceAppointment sa, String issueType, String reason, String severity) {
        Schedule_Issue__c issue = new Schedule_Issue__c(
            Issue_Type__c = issueType,
            Status__c = 'Open',
            Severity__c = severity,
            Summary__c = issueType + ' scheduling issue for ' + (String.isBlank(sa.AppointmentNumber) ? String.valueOf(sa.Id) : sa.AppointmentNumber),
            Resolution_Notes__c = reason,
            Owner__c = UserInfo.getUserId()
        );
        Id standardWorkOrderId = parentWorkOrderId(sa);
        if (standardWorkOrderId != null) {
            issue.Standard_WorkOrder__c = standardWorkOrderId;
        }
        // Validation rules: Weather and Traffic require Market__c (ServiceTerritory lookup)
        if (issueType == 'Weather' || issueType == 'Traffic') {
            if (sa.ServiceTerritoryId != null) {
                issue.Market__c = sa.ServiceTerritoryId;
            }
        }
        // Validation rules: High and Critical severity require Field_Manager__c and Required_Action__c.
        // Default FM is Jim Howie; fall back to the running user if not found.
        if (severity == 'High' || severity == 'Critical') {
            List<User> jhUser = [SELECT Id FROM User WHERE Name = 'Jim Howie' AND IsActive = true LIMIT 1];
            issue.Field_Manager__c = jhUser.isEmpty() ? UserInfo.getUserId() : jhUser[0].Id;
            if (String.isBlank(issue.Required_Action__c)) {
                issue.Required_Action__c = 'Other';
            }
        }
        insert issue;
        return issue;
    }

    private static ActionResult addIssueLinkDetail(ActionResult result, Schedule_Issue__c issue) {
        if (issue.Standard_WorkOrder__c == null) {
            result.details.add('No Work Order lookup was populated because the Service Appointment did not reference a standard Work Order.');
        }
        return result;
    }

    private static Id parentWorkOrderId(ServiceAppointment sa) {
        if (sa == null || sa.ParentRecordId == null) {
            return null;
        }
        return sa.ParentRecordId.getSObjectType() == WorkOrder.SObjectType ? sa.ParentRecordId : null;
    }

    private static Integer durationMinutes(ServiceAppointment sa) {
        if (sa != null && sa.Duration != null && sa.Duration > 0) {
            return Integer.valueOf(sa.Duration);
        }
        return 120;
    }

    private static void requireUnlocked(ServiceAppointment sa, Boolean allowLocked) {
        if (!allowLocked && sa.FSL__Pinned__c == true) {
            throw new SchedulingException('Schedule Lock', 'Schedule is locked. A user with release approval permission must unlock it first.');
        }
    }

    private static void requireReason(String reason, String actionName) {
        if (String.isBlank(reason)) {
            throw new SchedulingException('Reason Required', actionName + ' requires a reason.');
        }
    }

    private static void requirePermission(String permissionName, String actionName) {
        if (Test.isRunningTest() && bypassPermissionForTests) {
            return;
        }
        Boolean hasPermission = FeatureManagement.checkPermission(permissionName);
        if (!hasPermission && permissionName == 'Schedule') {
            // FSL orgs can expose this custom permission under the namespaced key.
            hasPermission = FeatureManagement.checkPermission('FSL__Schedule');
        }
        if (!hasPermission) {
            throw new SchedulingException('Permission', 'Missing permission ' + permissionName + ' for ' + actionName + '.');
        }
    }

    private static String normalizeIssueType(String issueType) {
        String value = String.isBlank(issueType) ? 'Other' : issueType;
        if (!isPicklistValue('Schedule_Issue__c', 'Issue_Type__c', value)) {
            return 'Other';
        }
        return value;
    }

    private static Boolean isPicklistValue(String objectApiName, String fieldApiName, String value) {
        if (String.isBlank(value)) {
            return false;
        }
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) {
            return false;
        }
        Schema.SObjectField fieldToken = objectType.getDescribe().fields.getMap().get(fieldApiName);
        if (fieldToken == null) {
            return false;
        }
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == value) {
                return true;
            }
        }
        return false;
    }

    private static ActionResult startResult() {
        ActionResult result = new ActionResult();
        result.success = false;
        result.blocked = false;
        result.details = new List<String>();
        return result;
    }

    private static ActionResult success(ActionResult result, Id recordId, String message) {
        result.success = true;
        result.blocked = false;
        result.recordId = String.valueOf(recordId);
        result.recordUrl = '/' + String.valueOf(recordId);
        result.message = message;
        result.details.add(message);
        return result;
    }

    private static ActionResult blocked(ActionResult result, String gate, String message, String detail) {
        result.success = false;
        result.blocked = true;
        result.gate = gate;
        result.message = message;
        result.technicalDetail = detail;
        result.details.add(message);
        return result;
    }

    private static ActionResult systemError(ActionResult result, Exception ex, String summary) {
        result.success = false;
        result.blocked = false;
        result.message = summary + ' Please try again or contact an admin.';
        result.technicalDetail = ex.getTypeName() + ': ' + ex.getMessage();
        result.details.add(result.technicalDetail);
        return result;
    }

    private class SchedulingException extends Exception {
        public String gate;
        public SchedulingException(String gate, String message) {
            this.gate = gate;
            this.setMessage(message);
        }
    }

    // ─────────────────────────────────────────────────────────
    // RESCHEDULE ISSUE DTO
    // ─────────────────────────────────────────────────────────
    public class RescheduleResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
        @AuraEnabled public String  serviceAppointmentId;
        @AuraEnabled public String  appointmentName;
        @AuraEnabled public String  previousWindow;
        @AuraEnabled public String  newWindow;
        @AuraEnabled public String  customerEmail;
        @AuraEnabled public String  customerName;
        @AuraEnabled public String  technicalDetail;
    }

    // ─────────────────────────────────────────────────────────
    // RESCHEDULE ISSUE
    // Schedule_Issue__c links to ServiceAppointment via
    // Standard_WorkOrder__c → ServiceAppointment.WorkOrderId
    // ─────────────────────────────────────────────────────────
    public static RescheduleResult rescheduleIssue(Id scheduleIssueId, Integer daysToShift, Boolean reoptimize) {
        RescheduleResult res = new RescheduleResult();
        try {
            Schedule_Issue__c issue = [
                SELECT Id, Name, Status__c, Standard_WorkOrder__c, Schedule_Day__c
                FROM   Schedule_Issue__c
                WHERE  Id = :scheduleIssueId
                LIMIT  1
            ];

            // Resolve linked ServiceAppointment through standard WorkOrder
            ServiceAppointment apt = null;
            if (issue.Standard_WorkOrder__c != null) {
                List<ServiceAppointment> apts = [
                    SELECT Id, AppointmentNumber, SchedStartTime, SchedEndTime,
                           Contact.Name, Contact.Email, Account.Name
                    FROM   ServiceAppointment
                    WHERE  ParentRecordId = :issue.Standard_WorkOrder__c
                    ORDER BY CreatedDate DESC
                    LIMIT  1
                ];
                if (!apts.isEmpty()) apt = apts[0];
            }

            res.appointmentName = issue.Name;

            if (apt == null) {
                // No linked SA — mark issue resolved and return guidance
                issue.Status__c = 'Resolved';
                update issue;
                insert new Task(Subject = 'Reschedule flagged via console (no linked SA)',
                    WhatId = scheduleIssueId, ActivityDate = Date.today(), Status = 'Completed',
                    Description = 'No ServiceAppointment found via Standard_WorkOrder__c. Manual rescheduling required in FSL.');
                res.success       = true;
                res.previousWindow = 'N/A';
                res.newWindow     = 'Please reschedule manually in FSL Dispatcher';
                res.customerEmail = '';
                res.customerName  = '';
                res.message       = 'Issue resolved. No linked ServiceAppointment found — please reschedule in FSL Dispatcher.';
                return res;
            }

            res.serviceAppointmentId = String.valueOf(apt.Id);
            res.appointmentName      = apt.AppointmentNumber;
            res.customerName         = apt.Contact != null ? apt.Contact.Name : (apt.Account != null ? apt.Account.Name : 'Customer');
            res.customerEmail        = apt.Contact != null ? apt.Contact.Email : '';
            res.previousWindow       = formatWindow(apt.SchedStartTime, apt.SchedEndTime);

            if (reoptimize == true) {
                apt.Status = 'None';
                update apt;
                insert new Task(Subject = 'Rescheduled via console — sent to FSL re-optimize',
                    WhatId = apt.Id, ActivityDate = Date.today(), Status = 'Completed');
                res.newWindow = 'Re-optimized by FSL Optimizer (pending)';
            } else {
                Integer days = (daysToShift != null && daysToShift > 0) ? daysToShift : 1;
                Datetime newStart = apt.SchedStartTime != null ? apt.SchedStartTime.addDays(days) : Datetime.now().addDays(days);
                Datetime newEnd   = apt.SchedEndTime   != null ? apt.SchedEndTime.addDays(days)   : newStart.addHours(2);
                apt.SchedStartTime = newStart;
                apt.SchedEndTime   = newEnd;
                apt.Status         = 'Scheduled';
                update apt;
                res.newWindow = formatWindow(newStart, newEnd);
                insert new Task(Subject = 'Rescheduled via console — shifted ' + days + ' day(s)',
                    WhatId = apt.Id, ActivityDate = Date.today(), Status = 'Completed',
                    Description = 'Previous: ' + res.previousWindow + ' New: ' + res.newWindow);
            }

            issue.Status__c = 'Resolved';
            update issue;
            res.success = true;
            res.message = 'Appointment rescheduled successfully.';

        } catch (Exception ex) {
            res.success         = false;
            res.message         = 'Reschedule failed: ' + ex.getMessage();
            res.technicalDetail = ex.getTypeName() + ': ' + ex.getMessage();
        }
        return res;
    }

    // ─────────────────────────────────────────────────────────
    // SEND RESCHEDULE NOTIFICATION + ICS calendar invite
    // ─────────────────────────────────────────────────────────
    public static ActionResult sendRescheduleNotification(Id serviceAppointmentId, String emailBodyText) {
        ActionResult result = new ActionResult();
        result.details = new List<String>();
        try {
            ServiceAppointment apt = [
                SELECT Id, AppointmentNumber, SchedStartTime, SchedEndTime,
                       Contact.Email, Contact.Name
                FROM   ServiceAppointment
                WHERE  Id = :serviceAppointmentId
                LIMIT  1
            ];
            String contactEmail = apt.Contact != null ? apt.Contact.Email : null;
            if (String.isBlank(contactEmail)) {
                return blocked(result, 'Email', 'No email address on contact record.', 'Contact.Email is blank.');
            }
            String icsContent = buildIcs(apt);
            Messaging.EmailFileAttachment icsAttach = new Messaging.EmailFileAttachment();
            icsAttach.setFileName('appointment-reschedule.ics');
            icsAttach.setContentType('text/calendar');
            icsAttach.setBody(Blob.valueOf(icsContent));

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ contactEmail });
            mail.setSubject('Your appointment has been rescheduled — ' + apt.AppointmentNumber);
            mail.setPlainTextBody(emailBodyText);
            mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ icsAttach });
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

            // Also notify assigned employees
            List<AssignedResource> assigned = [
                SELECT ServiceResource.RelatedRecordId
                FROM   AssignedResource
                WHERE  ServiceAppointmentId = :serviceAppointmentId
            ];
            if (!assigned.isEmpty()) {
                List<Id> relIds = new List<Id>();
                for (AssignedResource ar : assigned) {
                    if (ar.ServiceResource.RelatedRecordId != null) relIds.add(ar.ServiceResource.RelatedRecordId);
                }
                if (!relIds.isEmpty()) {
                    List<Messaging.SingleEmailMessage> empMails = new List<Messaging.SingleEmailMessage>();
                    for (User u : [SELECT Email FROM User WHERE Id IN :relIds AND Email != null]) {
                        Messaging.SingleEmailMessage em = new Messaging.SingleEmailMessage();
                        em.setToAddresses(new List<String>{ u.Email });
                        em.setSubject('CALENDAR UPDATE: ' + apt.AppointmentNumber + ' rescheduled');
                        em.setPlainTextBody('Your scheduled appointment has been rescheduled. Please update your calendar.\n\n' + emailBodyText);
                        em.setFileAttachments(new List<Messaging.EmailFileAttachment>{ icsAttach });
                        empMails.add(em);
                    }
                    if (!empMails.isEmpty()) Messaging.sendEmail(empMails);
                }
            }
            return success(result, serviceAppointmentId, 'Reschedule notification sent to customer and assigned employees.');
        } catch (Exception ex) {
            return systemError(result, ex, 'Email notification failed.');
        }
    }

    // ─────────────────────────────────────────────────────────
    // UPDATE ISSUE TYPE (inline picklist edit from console)
    // ─────────────────────────────────────────────────────────
    public static ActionResult updateIssueType(Id scheduleIssueId, String newType) {
        ActionResult result = new ActionResult();
        result.details = new List<String>();
        try {
            update new Schedule_Issue__c(Id = scheduleIssueId, Issue_Type__c = newType);
            insert new Task(Subject='Issue type updated to: ' + newType, WhatId=scheduleIssueId, ActivityDate=Date.today(), Status='Completed');
            return success(result, scheduleIssueId, 'Issue type updated to ' + newType + '.');
        } catch (Exception ex) {
            return systemError(result, ex, 'Failed to update issue type.');
        }
    }

    // ─────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────
    private static String formatWindow(Datetime startDt, Datetime endDt) {
        if (startDt == null) return 'TBD';
        String s = startDt.format('EEE, MMM d h:mm a');
        if (endDt != null) s += ' – ' + endDt.format('h:mm a');
        return s;
    }

    private static String buildIcs(ServiceAppointment apt) {
        String dtStart = apt.SchedStartTime != null ? apt.SchedStartTime.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') : '';
        String dtEnd   = apt.SchedEndTime   != null ? apt.SchedEndTime.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'')   : '';
        String nowTs   = Datetime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        return 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//LOVING Group//EN\r\nMETHOD:REQUEST\r\n'
             + 'BEGIN:VEVENT\r\nUID:' + apt.Id + '@loving.salesforce.com\r\n'
             + 'DTSTAMP:' + nowTs + '\r\nDTSTART:' + dtStart + '\r\nDTEND:' + dtEnd + '\r\n'
             + 'SUMMARY:RESCHEDULED – ' + apt.AppointmentNumber + '\r\n'
             + 'DESCRIPTION:Your appointment has been rescheduled. Please update your calendar.\r\n'
             + 'STATUS:CONFIRMED\r\nSEQUENCE:1\r\nEND:VEVENT\r\nEND:VCALENDAR';
    }
}