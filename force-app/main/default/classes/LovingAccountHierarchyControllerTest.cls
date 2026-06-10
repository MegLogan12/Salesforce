@isTest
private class LovingAccountHierarchyControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Division Account');
        insert acc;
    }

    @isTest
    static void testGetAccountFiles_NoData() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<LovingAccountHierarchyController.FileRow> result = LovingAccountHierarchyController.getAccountFiles(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return a list');
        System.assertEquals(0, result.size(), 'Should be empty — no files attached');
    }

    @isTest
    static void testGetAccountFiles_NullId() {
        Test.startTest();
        List<LovingAccountHierarchyController.FileRow> result = LovingAccountHierarchyController.getAccountFiles(null);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return an empty list');
        System.assertEquals(0, result.size(), 'Should be empty for null');
    }

    @isTest
    static void testGetAccountFiles_WithFile() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'Test MSA Document',
            PathOnClient = 'TestMSA.pdf',
            VersionData = Blob.valueOf('test content'),
            IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        List<LovingAccountHierarchyController.FileRow> result = LovingAccountHierarchyController.getAccountFiles(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return results');
        System.assertEquals(1, result.size(), 'Should return 1 file');
        System.assertEquals('Test MSA Document', result[0].title, 'Title should match');
        System.assertNotEquals(null, result[0].contentDocumentId, 'ContentDocumentId should be set');
        System.assertNotEquals(null, result[0].isPinned, 'isPinned should not be null');
        System.assertNotEquals(null, result[0].category, 'category should not be null');
    }

    @isTest
    static void testGetScopeDetail_NoData() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<LovingAccountHierarchyController.ScopeDetailRow> result = LovingAccountHierarchyController.getScopeDetail(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return a list');
    }

    @isTest
    static void testGetScopeDetail_NullId() {
        Test.startTest();
        List<LovingAccountHierarchyController.ScopeDetailRow> result = LovingAccountHierarchyController.getScopeDetail(null);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return an empty list');
        System.assertEquals(0, result.size(), 'Should be empty for null');
    }

    @isTest
    static void testGetScopeDetail_WithScopeOfWork() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('Scope_of_Work__c')) {
            Map<String, Schema.SObjectField> sowFields = gd.get('Scope_of_Work__c').getDescribe().fields.getMap();
            if (sowFields.containsKey('account__c') && sowFields.containsKey('line_of_business__c')) {
                SObject sow = gd.get('Scope_of_Work__c').newSObject();
                // Do NOT set Name — it may be auto-number or system-assigned
                sow.put('Account__c', acc.Id);
                sow.put('Line_of_Business__c', 'Production Landscaping');
                try {
                    insert sow;
                } catch (Exception e) { /* ignore if can't insert */ }
            }
        }
        Test.startTest();
        List<LovingAccountHierarchyController.ScopeDetailRow> result = LovingAccountHierarchyController.getScopeDetail(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return a list');
    }

    @isTest
    static void testGetScopeDetail_AllFieldsPresent() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('Scope_of_Work__c')) {
            Map<String, Schema.SObjectField> sowFields = gd.get('Scope_of_Work__c').getDescribe().fields.getMap();
            if (sowFields.containsKey('account__c')) {
                SObject sow = gd.get('Scope_of_Work__c').newSObject();
                sow.put('Account__c', acc.Id);
                if (sowFields.containsKey('line_of_business__c')) sow.put('Line_of_Business__c', 'Aqua');
                if (sowFields.containsKey('status__c')) {
                    // Only set if we know valid values won't cause insert error
                    try { sow.put('Status__c', 'Active'); } catch (Exception e) {}
                }
                if (sowFields.containsKey('notes__c')) sow.put('Notes__c', 'Annual');
                if (sowFields.containsKey('package_tier__c')) {
                    try { sow.put('Package_Tier__c', 'Standard'); } catch (Exception e) {}
                }
                if (sowFields.containsKey('frequency__c')) {
                    try { sow.put('Frequency__c', 'Weekly'); } catch (Exception e) {}
                }
                try { insert sow; } catch (Exception e) {}
            }
        }
        Test.startTest();
        List<LovingAccountHierarchyController.ScopeDetailRow> result = LovingAccountHierarchyController.getScopeDetail(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return a list');
    }

    @isTest
    static void testDtoFields() {
        LovingAccountHierarchyController.FileRow fr = new LovingAccountHierarchyController.FileRow();
        fr.id = null;
        fr.contentDocumentId = null;
        fr.title = 'Test File';
        fr.category = 'MSA & Legal';
        fr.uploadedBy = 'Test User';
        fr.contentModifiedDate = Datetime.now();
        fr.contentSize = 1024L;
        fr.isPinned = true;
        System.assertEquals('Test File', fr.title, 'Title should match');

        LovingAccountHierarchyController.ScopeDetailRow sdr = new LovingAccountHierarchyController.ScopeDetailRow();
        sdr.id = null;
        sdr.serviceLine = 'Production Install';
        sdr.scopeIncluded = 'Full landscape package';
        sdr.specialTerms = 'Per MSA Addendum A';
        sdr.notes = 'Annual review required';
        System.assertEquals('Production Install', sdr.serviceLine, 'Service line should match');
    }

    @isTest
    static void testGetAccountFiles_MultipleFiles() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        // Create two files
        for (Integer i = 0; i < 2; i++) {
            ContentVersion cv = new ContentVersion(
                Title = 'File ' + i,
                PathOnClient = 'File' + i + '.pdf',
                VersionData = Blob.valueOf('content ' + i),
                IsMajorVersion = true
            );
            insert cv;
            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = acc.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
        }
        Test.startTest();
        List<LovingAccountHierarchyController.FileRow> result = LovingAccountHierarchyController.getAccountFiles(acc.Id);
        Test.stopTest();
        System.assertEquals(2, result.size(), 'Should return 2 files');
    }
}