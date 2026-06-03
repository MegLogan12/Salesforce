@IsTest(SeeAllData=false)
private class CrewAssignControllerTest {

    private static Crew__c makeCrew(String name, Boolean active, Boolean available,
                                    String division, String truck) {
        Crew__c c = new Crew__c(
            Name                        = name,
            Active__c                   = active,
            Available_For_Scheduling__c = available,
            Division__c                 = division,
            Truck_Number__c             = truck
        );
        insert c;
        return c;
    }

    @IsTest
    static void unassignedCrews_returnsIsAssignedFalse() {
        Crew__c c = makeCrew('Test Crew A', true, true, 'North', null);

        Test.startTest();
        List<CrewAssignController.CrewRow> rows = CrewAssignController.getTomorrowsCrews(null);
        Test.stopTest();

        // Find our inserted crew in the results
        CrewAssignController.CrewRow found = null;
        for (CrewAssignController.CrewRow r : rows) {
            if (r.crewId == c.Id) {
                found = r;
                break;
            }
        }
        System.assertNotEquals(null, found, 'Crew should appear in results');
        System.assertEquals(false, found.isAssigned, 'Crew with no truck should be unassigned');
        System.assertEquals(null, found.truckNumber, 'Truck number should be null');
    }

    @IsTest
    static void assignRig_setsFields() {
        Crew__c c = makeCrew('Test Crew B', true, true, 'South', null);

        Test.startTest();
        CrewAssignController.assignRig(c.Id, 'TRK-42', 'Ford F-250');
        Test.stopTest();

        Crew__c updated = [SELECT Truck_Number__c, Vehicle__c FROM Crew__c WHERE Id = :c.Id];
        System.assertEquals('TRK-42',    updated.Truck_Number__c, 'Truck number not updated');
        System.assertEquals('Ford F-250', updated.Vehicle__c,      'Vehicle not updated');
    }

    @IsTest
    static void getTomorrowsCrews_divisionFilter_excludesOtherDivisions() {
        Crew__c northCrew = makeCrew('North Crew', true, true, 'North', null);
        Crew__c southCrew = makeCrew('South Crew', true, true, 'South', null);

        Test.startTest();
        List<CrewAssignController.CrewRow> rows = CrewAssignController.getTomorrowsCrews('North');
        Test.stopTest();

        Set<Id> ids = new Set<Id>();
        for (CrewAssignController.CrewRow r : rows) {
            ids.add(r.crewId);
        }
        System.assert(ids.contains(northCrew.Id),  'North crew should be included');
        System.assert(!ids.contains(southCrew.Id), 'South crew should be excluded by division filter');
    }
}
