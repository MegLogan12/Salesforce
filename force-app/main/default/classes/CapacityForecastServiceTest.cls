@IsTest
private class CapacityForecastServiceTest {

    @IsTest
    static void getCurrentSnapshotReturnsAllServiceLines() {
        Test.startTest();
        CapacityForecastService.ForecastSnapshot snap = CapacityForecastService.getCurrentSnapshot();
        Test.stopTest();
        System.assertNotEquals(null, snap);
        System.assertEquals(4, snap.serviceLines.size());
        System.assertNotEquals(null, snap.asOfDate);
    }

    @IsTest
    static void getCurrentSnapshotComputesUtilization() {
        Test.startTest();
        CapacityForecastService.ForecastSnapshot snap = CapacityForecastService.getCurrentSnapshot();
        Test.stopTest();
        for (CapacityForecastService.ServiceLineCapacity sl : snap.serviceLines) {
            System.assertNotEquals(null, sl.utilizationPct);
            System.assertNotEquals(null, sl.status);
        }
    }

    @IsTest
    static void calculateROIReturnsResult() {
        Test.startTest();
        CapacityForecastService.HireROIResult r =
            CapacityForecastService.calculateROI(40, 95, 80, 70000, 1);
        Test.stopTest();
        System.assertNotEquals(null, r);
        System.assert(r.y1RevenueCapacity > 0);
        System.assert(r.totalAnnualCost == 70000);
    }

    @IsTest
    static void calculateROIHandlesNulls() {
        Test.startTest();
        CapacityForecastService.HireROIResult r =
            CapacityForecastService.calculateROI(null, null, null, null, null);
        Test.stopTest();
        System.assertNotEquals(null, r);
        System.assertEquals(70000, r.totalAnnualCost);
    }

    @IsTest
    static void calculateROIMultipleQuantity() {
        Test.startTest();
        CapacityForecastService.HireROIResult r =
            CapacityForecastService.calculateROI(40, 95, 80, 70000, 4);
        Test.stopTest();
        System.assertEquals(280000, r.totalAnnualCost);
    }

    @IsTest
    static void computeStatusReturnsCorrectColor() {
        System.assertEquals('green', CapacityForecastService.computeStatus(50));
        System.assertEquals('amber', CapacityForecastService.computeStatus(100));
        System.assertEquals('red', CapacityForecastService.computeStatus(110));
        System.assertEquals('gray', CapacityForecastService.computeStatus(0));
        System.assertEquals('gray', CapacityForecastService.computeStatus(null));
    }

    @IsTest
    static void hireROIInputDefaults() {
        CapacityForecastService.HireROIInput i = new CapacityForecastService.HireROIInput();
        System.assertEquals(40, i.hoursPerWeekPerTech);
        System.assertEquals(95, i.revenuePerHour);
        System.assertEquals(80, i.utilizationPct);
        System.assertEquals(70000, i.annualCostPerPerson);
        System.assertEquals(1, i.quantity);
        System.assertEquals(5, i.rampWeeks);
    }
}