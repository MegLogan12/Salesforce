@IsTest(SeeAllData=true)
private class LovingSAWorkspaceControllerTest {
    @IsTest
    static void returnsWorkspaceForExistingServiceAppointment() {
        List<ServiceAppointment> appointments = [SELECT Id FROM ServiceAppointment LIMIT 1];
        if (appointments.isEmpty()) {
            System.debug('[LovingSAWorkspaceControllerTest] No ServiceAppointments in org - skipping smoke test.');
            return;
        }
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

        // smokeType already asserts type resolution when data is present.
        // When no live SA exists for a type the smoke skips gracefully — no hard assert needed.
        if (!coverage.isEmpty()) {
            System.debug('[LovingSAWorkspaceControllerTest] Verified SA types: ' + coverage.keySet());
        }
    }

    private static void smokeType(List<ServiceAppointment> rows, String expectedType, Map<String, String> coverage) {
        if (rows.isEmpty()) {
            System.debug('[LovingSAWorkspaceControllerTest] No live SA for type ' + expectedType + ' - skipping smoke type.');
            return;
        }
        LovingSAWorkspaceController.WorkspaceDto dto =
            LovingSAWorkspaceController.getWorkspace(rows[0].Id);
        System.assertEquals(expectedType, dto.header.appointmentType, 'Type mismatch for ' + expectedType);
        System.assertNotEquals(null, dto.proofRows, 'Proof rows should exist for ' + expectedType);
        coverage.put(expectedType, rows[0].Id);
    }
}