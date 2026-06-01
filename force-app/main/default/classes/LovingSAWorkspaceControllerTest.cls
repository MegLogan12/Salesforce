@IsTest(SeeAllData=true)
private class LovingSAWorkspaceControllerTest {
    @IsTest
    static void returnsWorkspaceForExistingServiceAppointment() {
        List<ServiceAppointment> appointments = [SELECT Id FROM ServiceAppointment LIMIT 1];
        System.assert(!appointments.isEmpty(), 'Expected at least one ServiceAppointment in the org for workspace smoke coverage.');
        LovingSAWorkspaceController.WorkspaceDto dto =
            LovingSAWorkspaceController.getWorkspace(appointments[0].Id);
        System.assertNotEquals(null, dto);
        System.assertNotEquals(null, dto.header);
        System.assertNotEquals(null, dto.kpis);
        System.assertNotEquals(null, dto.header.appointmentType);
    }

    @IsTest
    static void resolvesLiveTypePatterns() {
        Map<String, String> coverage = new Map<String, String>();
        smokeType(
            [SELECT Id FROM ServiceAppointment WHERE WorkType.Name = 'Production Install' AND ParentRecordId != null LIMIT 1],
            'Production Install',
            coverage
        );
        smokeType(
            [SELECT Id FROM ServiceAppointment WHERE WorkType.Name = 'Field Manager Takeoff' AND ParentRecordId != null LIMIT 1],
            'Takeoff',
            coverage
        );
        smokeType(
            [SELECT Id FROM ServiceAppointment WHERE WorkType.Name = 'Aqua Check' AND ParentRecordId != null LIMIT 1],
            'Aqua Check',
            coverage
        );
        smokeType(
            [SELECT Id FROM ServiceAppointment WHERE WorkType.Name = 'Aqua Pickup' AND ParentRecordId != null LIMIT 1],
            'Aqua Pickup',
            coverage
        );
        smokeType(
            [SELECT Id FROM ServiceAppointment WHERE Subject LIKE 'Site Readiness%' AND ParentRecordId != null LIMIT 1],
            'Site Readiness',
            coverage
        );
        smokeType(
            [SELECT Id FROM ServiceAppointment WHERE Subject LIKE 'FM Review%' AND ParentRecordId != null LIMIT 1],
            'FM Review',
            coverage
        );
        smokeType(
            [SELECT Id FROM ServiceAppointment WHERE WorkType.Name = 'Site Visit' AND ParentRecordId != null LIMIT 1],
            'Site Visit',
            coverage
        );
        smokeType(
            [SELECT Id FROM ServiceAppointment
             WHERE ParentRecordId IN (
                 SELECT Id FROM WorkOrder
                 WHERE Work_Order_Type__c = 'Customer Success'
             )
             AND WorkTypeId = null
             LIMIT 1],
            'Customer Success',
            coverage
        );

        System.assert(coverage.containsKey('Production Install'), 'Production Install sample should resolve.');
        System.assert(coverage.containsKey('Takeoff'), 'Takeoff sample should resolve.');
        System.assert(coverage.containsKey('Aqua Check'), 'Aqua Check sample should resolve.');
        System.assert(coverage.containsKey('Aqua Pickup'), 'Aqua Pickup sample should resolve.');
        System.assert(coverage.containsKey('Site Readiness'), 'Site Readiness sample should resolve.');
        System.assert(coverage.containsKey('FM Review'), 'FM Review sample should resolve.');
        System.assert(coverage.containsKey('Site Visit'), 'Site Visit sample should resolve.');
        System.assert(coverage.containsKey('Customer Success'), 'Customer Success sample should resolve.');
    }

    private static void smokeType(List<ServiceAppointment> rows, String expectedType, Map<String, String> coverage) {
        System.assert(!rows.isEmpty(), 'Expected a live ServiceAppointment example for ' + expectedType + '.');
        LovingSAWorkspaceController.WorkspaceDto dto =
            LovingSAWorkspaceController.getWorkspace(rows[0].Id);
        System.assertEquals(expectedType, dto.header.appointmentType, 'Type mismatch for ' + expectedType);
        System.assertNotEquals(null, dto.proofRows, 'Proof rows should exist for ' + expectedType);
        coverage.put(expectedType, rows[0].Id);
    }
}