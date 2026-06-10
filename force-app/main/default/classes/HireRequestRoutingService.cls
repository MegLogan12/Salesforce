/**
 * HireRequestRoutingService
 *
 * Routes Hire_Request__c records through the approval chain:
 * - Below VP threshold (configurable, default $75K): single-step VP approval
 * - At/above VP threshold: two-step VP → COO approval
 *
 * Called from Hire_Request__c trigger on insert/update of Status to Submitted.
 * Spec reference: Section 7.13, Section 21.
 */
public with sharing class HireRequestRoutingService {

    // VP authority threshold for single-step vs two-step approval
    // Stored as Custom Setting; falls back to spec default
    private static final Decimal DEFAULT_VP_THRESHOLD = 75000;

    public class RoutingResult {
        public Boolean requiresCOOApproval;
        public Decimal totalAnnualCost;
        public Id assignedApproverId;
        public String routingReason;
    }

    /**
     * Determine routing for a hire request based on cost.
     */
    public static RoutingResult route(Hire_Request__c req) {
        RoutingResult r = new RoutingResult();
        // Total_Annual_Cost__c is a formula; falls back to manual compute for in-memory records
        if (req.Total_Annual_Cost__c != null) {
            r.totalAnnualCost = req.Total_Annual_Cost__c;
        } else if (req.Quantity__c != null && req.Annual_Cost_Per_Person__c != null) {
            r.totalAnnualCost = req.Quantity__c * req.Annual_Cost_Per_Person__c;
        } else {
            r.totalAnnualCost = 0;
        }
        Decimal threshold = getVPThreshold();
        r.requiresCOOApproval = r.totalAnnualCost >= threshold;
        r.routingReason = r.requiresCOOApproval
            ? 'Cost ' + r.totalAnnualCost + ' >= VP threshold ' + threshold + ': two-step approval'
            : 'Cost ' + r.totalAnnualCost + ' < VP threshold ' + threshold + ': single-step VP approval';
        return r;
    }

    /**
     * Bulk route: invoked from trigger.
     * Sets Status to Under VP Review.
     */
    public static void routeBulk(List<Hire_Request__c> reqs) {
        if (reqs == null || reqs.isEmpty()) return;
        for (Hire_Request__c req : reqs) {
            RoutingResult r = route(req);
            req.Status__c = 'Under VP Review';
        }
    }

    /**
     * Decide what happens after VP approval.
     */
    public static void onVPApproved(List<Hire_Request__c> reqs) {
        if (reqs == null || reqs.isEmpty()) return;
        for (Hire_Request__c req : reqs) {
            RoutingResult r = route(req);
            if (r.requiresCOOApproval) {
                req.Status__c = 'Under COO Review';
            } else {
                req.Status__c = 'Approved';
            }
        }
    }

    /**
     * Get the VP threshold from Custom Setting or fall back to default.
     */
    @TestVisible
    private static Decimal getVPThreshold() {
        // In production, read from a Custom Setting
        // For now, return default
        return DEFAULT_VP_THRESHOLD;
    }

    /**
     * Compute approval velocity: average days from submit to final decision.
     */
    public static Decimal computeApprovalVelocity(Date sinceDate) {
        if (sinceDate == null) sinceDate = Date.today().addDays(-30);
        List<Hire_Request__c> reqs = [
            SELECT CreatedDate, Decision_Date__c
            FROM Hire_Request__c
            WHERE CreatedDate >= :sinceDate
            AND Decision_Date__c != null
            LIMIT 1000
        ];
        if (reqs.isEmpty()) return 0;
        Decimal totalDays = 0;
        for (Hire_Request__c r : reqs) {
            totalDays += r.Decision_Date__c.daysBetween(r.CreatedDate.date());
        }
        return totalDays.abs() / reqs.size();
    }
}