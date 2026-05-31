/**
 * AquaRouteService
 * Route optimization request and shop-stop management for Aqua technicians.
 * Called from AquaConsoleController @AuraEnabled wrapper methods.
 */
public without sharing class AquaRouteService {

    /**
     * Submit a route re-optimization request.
     * Creates a Route_Optimization_Result__c record with Status = 'Pending'
     * and a Task for the FM to review results.
     */
    public static void reoptimize() {
        Schedule_Day__c today = getTodayScheduleDay();

        Route_Optimization_Result__c ror = new Route_Optimization_Result__c(
            Optimization_Run_DateTime__c = System.now(),
            Status__c                    = 'Proposed',
            Recommendation__c            = 'Re-optimization requested by console user at ' + System.now().format()
        );
        if (today != null) ror.Schedule_Day__c = today.Id;
        insert ror;

        Task t = new Task(
            Subject     = 'Aqua Route Re-Optimization Requested',
            Description = 'A route re-optimization was requested from the Aqua Console. Review results once complete.',
            Status      = 'Not Started',
            Priority    = 'Normal'
        );
        insert t;
    }

    /**
     * Add a shop stop to today's schedule for a given tech.
     * Creates a Schedule_Stop__c record with Stop_Type__c = 'Shop'.
     *
     * @param techId  Employee__c Id of the tech
     * @param notes   Optional note for the stop
     */
    public static void addShopStop(Id techId, String notes) {
        if (techId == null) throw new AuraHandledException('Tech ID is required.');

        Schedule_Day__c today = getTodayScheduleDay();

        // Get current highest stop number for this tech today
        Integer nextSeq = 1;
        List<AggregateResult> maxSeq = [
            SELECT MAX(Stop_Number__c) maxNum
            FROM Schedule_Stop__c
            WHERE Employee__c = :techId
            AND Schedule_Day__r.Schedule_Date__c = :Date.today()
        ];
        if (!maxSeq.isEmpty() && maxSeq[0].get('maxNum') != null) {
            nextSeq = ((Decimal) maxSeq[0].get('maxNum')).intValue() + 1;
        }

        Schedule_Stop__c stop = new Schedule_Stop__c(
            Employee__c   = techId,
            Stop_Type__c  = 'Shop',
            Stop_Number__c = nextSeq,
            Route_Status__c = 'Proposed',
            Notes__c      = String.isNotBlank(notes) ? notes : 'Shop stop added via Aqua Console'
        );
        if (today != null) stop.Schedule_Day__c = today.Id;
        insert stop;
    }

    private static Schedule_Day__c getTodayScheduleDay() {
        List<Schedule_Day__c> days = [
            SELECT Id FROM Schedule_Day__c
            WHERE Schedule_Date__c = :Date.today()
            LIMIT 1
        ];
        if (!days.isEmpty()) return days[0];
        // Create a stub Schedule_Day__c so MasterDetail insert doesn't fail
        Schedule_Day__c newDay = new Schedule_Day__c(
            Schedule_Date__c = Date.today(),
            Status__c        = 'Proposed'
        );
        insert newDay;
        return newDay;
    }
}