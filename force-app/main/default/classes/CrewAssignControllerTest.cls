@IsTest(SeeAllData=false)
private class CrewAssignControllerTest {

    // Crew__c.Division__c is a restricted picklist — omit it (field is nullable).
    // Tests verify the core get/assign behavior without division filtering.

    private static Crew__c makeCrew(String name, Boolean active, Boolean available, String truck) {
        Crew__c c = new Crew__c(
            Name                        = name,
            Active__c                   = active,
            Available_For_Scheduling__c = available,
            Truck_Number__c             = truck
        );
        insert c;
        return c;
    }

    @IsTest
    static void unassignedCrew_returnsIsAssignedFalse() {
        Crew__c c = makeCrew('Test Crew A', true, true, null);

        Test.startTest();
        List<CrewAssignController.CrewRow> rows = CrewAssignController.getTomorrowsCrews(null);
        Test.stopTest();

        CrewAssignController.CrewRow found = null;
        for (CrewAssignController.CrewRow r : rows) {
            if (r.crewId == c.Id) { found = r; break; }
        }
        System.assertNotEquals(null, found, 'Crew should appear in results');
        System.assertEquals(false, found.isAssigned, 'Crew with no truck should be unassigned');
        System.assertEquals(null, found.truckNumber, 'Truck number should be null');
    }

    @IsTest
    static void assignRig_setsFields() {
        Crew__c c = makeCrew('Test Crew B', true, true, null);

        Test.startTest();
        CrewAssignController.assignRig(c.Id, 'TRK-42', 'Ford F-250');
        Test.stopTest();

        Crew__c updated = [SELECT Truck_Number__c, Vehicle__c FROM Crew__c WHERE Id = :c.Id];
        System.assertEquals('TRK-42',     updated.Truck_Number__c, 'Truck number not updated');
        System.assertEquals('Ford F-250', updated.Vehicle__c,       'Vehicle not updated');
    }

    @IsTest
    static void assignedCrew_returnsIsAssignedTrue() {
        Crew__c c = makeCrew('Test Crew C', true, true, 'TRK-99');

        Test.startTest();
        List<CrewAssignController.CrewRow> rows = CrewAssignController.getTomorrowsCrews(null);
        Test.stopTest();

        CrewAssignController.CrewRow found = null;
        for (CrewAssignController.CrewRow r : rows) {
            if (r.crewId == c.Id) { found = r; break; }
        }
        System.assertNotEquals(null, found, 'Crew should appear in results');
        System.assertEquals(true,    found.isAssigned,   'Crew with truck should be assigned');
        System.assertEquals('TRK-99', found.truckNumber, 'Truck number should match');
    }
}
