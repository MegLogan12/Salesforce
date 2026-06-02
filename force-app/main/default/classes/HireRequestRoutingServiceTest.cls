@IsTest
private class HireRequestRoutingServiceTest {

    @IsTest
    static void belowThresholdRoutesToVPOnly() {
        Hire_Request__c req = new Hire_Request__c(
            Service_Line__c = 'Landscape',
            Role_Type__c = 'Technician',
            Quantity__c = 1,
            Annual_Cost_Per_Person__c = 50000
        );
        HireRequestRoutingService.RoutingResult r = HireRequestRoutingService.route(req);
        System.assertEquals(false, r.requiresCOOApproval);
        System.assertEquals(50000, r.totalAnnualCost);
    }

    @IsTest
    static void aboveThresholdRequiresCOO() {
        Hire_Request__c req = new Hire_Request__c(
            Service_Line__c = 'Landscape',
            Role_Type__c = 'Technician',
            Quantity__c = 2,
            Annual_Cost_Per_Person__c = 50000
        );
        // Total = 100000 > 75000 threshold
        HireRequestRoutingService.RoutingResult r = HireRequestRoutingService.route(req);
        System.assertEquals(true, r.requiresCOOApproval);
        System.assertEquals(100000, r.totalAnnualCost);
    }

    @IsTest
    static void atExactThresholdRequiresCOO() {
        Hire_Request__c req = new Hire_Request__c(
            Quantity__c = 1,
            Annual_Cost_Per_Person__c = 75000
        );
        HireRequestRoutingService.RoutingResult r = HireRequestRoutingService.route(req);
        System.assertEquals(true, r.requiresCOOApproval);
    }

    @IsTest
    static void nullValuesProduceZeroCost() {
        Hire_Request__c req = new Hire_Request__c();
        HireRequestRoutingService.RoutingResult r = HireRequestRoutingService.route(req);
        System.assertEquals(0, r.totalAnnualCost);
        System.assertEquals(false, r.requiresCOOApproval);
    }

    @IsTest
    static void routeBulkSetsStatusToUnderVPReview() {
        List<Hire_Request__c> reqs = new List<Hire_Request__c>{
            new Hire_Request__c(
                Service_Line__c = 'Landscape',
                Role_Type__c = 'Technician',
                Quantity__c = 1,
                Annual_Cost_Per_Person__c = 60000
            )
        };
        HireRequestRoutingService.routeBulk(reqs);
        System.assertEquals('Under VP Review', reqs[0].Status__c);
    }

    @IsTest
    static void onVPApprovedBelowThresholdSetsApproved() {
        Hire_Request__c req = new Hire_Request__c(
            Service_Line__c = 'Landscape',
            Role_Type__c = 'Technician',
            Quantity__c = 1,
            Annual_Cost_Per_Person__c = 50000,
            Status__c = 'Under VP Review'
        );
        HireRequestRoutingService.onVPApproved(new List<Hire_Request__c>{ req });
        System.assertEquals('Approved', req.Status__c);
    }

    @IsTest
    static void onVPApprovedAboveThresholdRoutesToCOO() {
        Hire_Request__c req = new Hire_Request__c(
            Service_Line__c = 'Landscape',
            Role_Type__c = 'Technician',
            Quantity__c = 2,
            Annual_Cost_Per_Person__c = 60000,
            Status__c = 'Under VP Review'
        );
        HireRequestRoutingService.onVPApproved(new List<Hire_Request__c>{ req });
        System.assertEquals('Under COO Review', req.Status__c);
    }

    @IsTest
    static void onVPApprovedHandlesNull() {
        HireRequestRoutingService.onVPApproved(null);
        HireRequestRoutingService.onVPApproved(new List<Hire_Request__c>());
        System.assert(true, 'Did not throw');
    }

    @IsTest
    static void thresholdReturnsDefault() {
        Decimal threshold = HireRequestRoutingService.getVPThreshold();
        System.assertEquals(75000, threshold);
    }

    @IsTest
    static void routeBulkHandlesNull() {
        HireRequestRoutingService.routeBulk(null);
        HireRequestRoutingService.routeBulk(new List<Hire_Request__c>());
        System.assert(true, 'Did not throw');
    }

    @IsTest
    static void approvalVelocityWithNoData() {
        Decimal v = HireRequestRoutingService.computeApprovalVelocity(Date.today().addDays(-30));
        System.assertEquals(0, v);
    }

    @IsTest
    static void approvalVelocityWithNullDate() {
        Decimal v = HireRequestRoutingService.computeApprovalVelocity(null);
        System.assertEquals(0, v);
    }
}