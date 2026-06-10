/**
 * LovingCSConsoleControllerTest
 * Negative paths first, per the CS Console build prompt §9:
 * approve before verify fails, approve over mismatch fails, verify without file fails,
 * case close under QI lock fails, send before quote approval fails, escalate writes no
 * recipient, non-admin writes blocked.
 *
 * Fixture DML runs as LovingTestContext.minimalAdmin() — the org's account-insert
 * workaround profile, which is also exempt from PO_Required_Fields. Records are still
 * shaped to satisfy the live validation rules that have no profile exemption
 * (PO_Mismatch_Needs_Notes, PO_NFI_Needs_Reason, PO_Approve_Needs_Validation,
 * CM_Required_On_Customer_Care, Warranty_Requires_Parent_WO).
 */
@IsTest(SeeAllData=false)
private class LovingCSConsoleControllerTest {

    /** The minimal-admin fixture user with the CS Console permission set assigned. */
    private static User csUser() {
        User u = LovingTestContext.minimalAdmin();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            if ([SELECT COUNT() FROM PermissionSetAssignment
                 WHERE AssigneeId = :u.Id AND PermissionSet.Name = 'LOVING_CS_Console'] == 0) {
                PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'LOVING_CS_Console' LIMIT 1];
                insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
            }
        }
        return u;
    }

    private static Builder_PO__c makePo(String status) {
        Account div = new Account(Name = 'CS Test Division ' + status);
        insert div;
        Builder_PO__c p = new Builder_PO__c(
            PO_Number__c = 'PO-TEST-' + status.replaceAll('\\s', '') + '-' + System.now().getTime(),
            Division_Account__c = div.Id,
            PO_Amount__c = 9000,
            Status__c = status,
            PO_Received_Date__c = Date.today(),
            NFI_Count__c = 0
        );
        if (status == 'Mismatch Review') {
            p.Mismatch_Type__c = 'Price Variance';
            p.Mismatch_Notes__c = 'Sod priced under package on 1,910 sf.';
        }
        if (status == 'NFI') {
            p.NFI_Reason__c = 'Missing install date and plat page.';
            p.NFI_Count__c = 1;
        }
        if (status == 'Verified') {
            // PO_Validated__c is a formula over the price/qty checks; satisfy the
            // org gate (PO_Approve_Needs_Validation) by passing both checks.
            p.Price_Check_Result__c = 'Pass';
            p.Qty_Check_Result__c = 'Pass';
        }
        insert p;
        return p;
    }

    private static void attachFile(Id recordId) {
        ContentVersion cv = new ContentVersion(
            Title = 'PO file', PathOnClient = 'po.pdf',
            VersionData = Blob.valueOf('po body'));
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId, LinkedEntityId = recordId, ShareType = 'V');
    }

    @IsTest
    static void bundle_loadsForCsUser() {
        User u = csUser();
        System.runAs(u) {
            makePo('Pending CS Review');
            makePo('Mismatch Review');
            makePo('NFI');

            Account div = new Account(Name = 'CS Bundle Division');
            insert div;
            Community__c comm = new Community__c(
                Name = 'Bundle Community', Builder_Account__c = div.Id,
                Zone__c = '2', BMG_Package_Code__c = 'TST-01',
                Active__c = true, Community_Status__c = 'Active');
            Community__c blocked = new Community__c(
                Name = 'Bundle Blocked Zone', Builder_Account__c = div.Id,
                Zone__c = '1', Active__c = true, Community_Status__c = 'Active');
            insert new List<Community__c>{ comm, blocked };

            Contact cm = new Contact(LastName = 'Bundle CM');
            insert cm;
            Work_Order__c pi = new Work_Order__c(
                Work_Order_Type__c = 'Production Install', Status__c = 'In Progress',
                Community__c = comm.Id, Field_Manager__c = u.Id, QI_Score__c = 9.1);
            insert pi;
            Work_Order__c warr = new Work_Order__c(
                Work_Order_Type__c = 'Warranty', Status__c = 'Scheduled',
                Community__c = comm.Id, Parent_Work_Order__c = pi.Id);
            Work_Order__c fj = new Work_Order__c(
                Work_Order_Type__c = 'Finish Job', Status__c = 'Ready to Schedule',
                Community__c = comm.Id, Parent_Work_Order__c = pi.Id,
                FJ_Reason_Code__c = 'Missed Punch');
            Work_Order__c cc = new Work_Order__c(
                Work_Order_Type__c = 'Customer Care', Status__c = 'New',
                Community__c = comm.Id, Construction_Manager__c = cm.Id,
                Trigger_Source__c = 'QI Inspection', QI_Score__c = 8.0,
                Notes__c = 'QI failed at 8.0\nFM corrects Thursday');
            insert new List<Work_Order__c>{ warr, fj, cc };

            insert new Takeoff__c(
                Status__c = 'Submitted', Community__c = comm.Id,
                Submitted_Date__c = Datetime.now().addDays(-2));
            insert new Takeoff__c(
                Status__c = 'Approved', Community__c = comm.Id,
                Submitted_Date__c = Datetime.now().addDays(-3),
                Approved_Date__c = Datetime.now().addDays(-1));
            insert new Item_Catalog__c(
                Name = 'Bermuda sod (test)', Unit_Price__c = 0.62,
                Standard_Cost__c = 0.38, Active__c = true);
            insert new Invoice__c(
                Builder__c = 'DR Horton', Status__c = 'Pending Send',
                LOVING_Work_Order__c = pi.Id, Community__c = comm.Id);
            insert new Quote__c(Status__c = 'Draft', Community__c = comm.Id);

            Test.startTest();
            LovingCSConsoleController.Bundle b = LovingCSConsoleController.getConsoleData();
            Test.stopTest();
            System.assertEquals(true, b.canEdit, 'CS user can edit');
            System.assert(!b.pos.isEmpty(), 'POs load');
            System.assert(!b.wos.isEmpty(), 'WOs load');
            System.assert(!b.warranty.isEmpty(), 'Warranty queue loads');
            System.assert(!b.fjs.isEmpty(), 'FJ queue loads');
            System.assert(!b.cases.isEmpty(), 'Cases load');
            System.assert(b.cases[0].qiLocked, 'QI lock computed');
            System.assert(!b.takeoffs.isEmpty(), 'Takeoffs load');
            System.assert(!b.invoices.isEmpty(), 'Invoices load');
            System.assert(b.invoices[0].cloudscapeHeld, 'BR step 22 hold computed');
            System.assert(!b.communities.isEmpty(), 'Communities load');
            System.assert(!b.builders.isEmpty(), 'Builders aggregate');
            System.assert(!b.zones.isEmpty(), 'Zones aggregate');
            Boolean sawBlocked = false;
            for (LovingCSConsoleController.ZoneDto z : b.zones) {
                if (z.blocked) {
                    sawBlocked = true;
                    System.assertEquals(null, z.fm, 'G6: no FM name on a blocked zone');
                }
            }
            System.assert(sawBlocked, 'Zone 1 renders blocked (G6)');
            System.assert(!b.catalog.isEmpty(), 'Catalog loads');
            System.assert(!b.quotes.isEmpty(), 'Quotes load');
            System.assert(!b.takeoffTime.isEmpty(), 'Takeoff time report computes');
            System.assert(!b.qiTrend.isEmpty(), 'QI trend report computes');
        }
    }

    @IsTest
    static void quote_rejectFromDraft() {
        User u = csUser();
        System.runAs(u) {
            insert new Quote__c(Status__c = 'Draft');
            Quote__c q = [SELECT Id FROM Quote__c LIMIT 1];
            Test.startTest();
            LovingCSConsoleController.rejectQuote(q.Id);
            Test.stopTest();
            System.assertEquals('Rejected', [SELECT Status__c FROM Quote__c WHERE Id = :q.Id].Status__c);
        }
    }

    @IsTest
    static void verify_blockedWithoutFile_thenPassesWithFile() {
        User u = csUser();
        System.runAs(u) {
            Builder_PO__c p = makePo('Pending CS Review');
            Boolean threw = false;
            try { LovingCSConsoleController.verifyPO(p.Id); }
            catch (AuraHandledException e) {
                threw = true;
                System.assert(e.getMessage().contains('no PO file attached'), e.getMessage());
            }
            System.assertEquals(true, threw, 'Verify without file must fail');

            attachFile(p.Id);
            Test.startTest();
            LovingCSConsoleController.verifyPO(p.Id);
            Test.stopTest();
            System.assertEquals('Verified',
                [SELECT Status__c FROM Builder_PO__c WHERE Id = :p.Id].Status__c);
        }
    }

    @IsTest
    static void approve_blockedBeforeVerifiedAndOverMismatch() {
        User u = csUser();
        System.runAs(u) {
            Builder_PO__c pending = makePo('Pending CS Review');
            Boolean t1 = false;
            try { LovingCSConsoleController.approvePO(pending.Id); }
            catch (AuraHandledException e) { t1 = true; }
            System.assertEquals(true, t1, 'Approve before Verified must fail');

            Builder_PO__c mm = makePo('Mismatch Review');
            Boolean t2 = false;
            try { LovingCSConsoleController.approvePO(mm.Id); }
            catch (AuraHandledException e) {
                t2 = true;
                System.assert(e.getMessage().contains('open mismatch'), e.getMessage());
            }
            System.assertEquals(true, t2, 'Approve over open mismatch must fail');

            Builder_PO__c ok = makePo('Verified');
            Test.startTest();
            LovingCSConsoleController.approvePO(ok.Id);
            Test.stopTest();
            Builder_PO__c after = [SELECT Status__c, CS_Approved__c FROM Builder_PO__c WHERE Id = :ok.Id];
            System.assertEquals('CS Approved', after.Status__c);
            System.assertEquals(true, after.CS_Approved__c, 'CS_Approved__c gates WO creation');
        }
    }

    @IsTest
    static void nfi_incrementsCount() {
        User u = csUser();
        System.runAs(u) {
            Builder_PO__c p = makePo('Pending CS Review');
            Test.startTest();
            LovingCSConsoleController.nfiPO(p.Id, 'Missing plat page');
            Test.stopTest();
            Builder_PO__c after = [SELECT Status__c, NFI_Count__c, NFI_Reason__c FROM Builder_PO__c WHERE Id = :p.Id];
            System.assertEquals('NFI', after.Status__c);
            System.assertEquals(1, after.NFI_Count__c);
            System.assertEquals('Missing plat page', after.NFI_Reason__c);
        }
    }

    @IsTest
    static void escalate_writesTaskWithNoRecipient() {
        User u = csUser();
        System.runAs(u) {
            Builder_PO__c p = makePo('Mismatch Review');
            Test.startTest();
            LovingCSConsoleController.escalatePO(p.Id, 'BMG comparison attached');
            Test.stopTest();
            Task t = [SELECT Subject, Description, OwnerId FROM Task
                      WHERE Subject LIKE 'Escalation:%' ORDER BY CreatedDate DESC LIMIT 1];
            System.assert(t.Subject.startsWith('Escalation:'));
            System.assert(t.Description.contains('no recipient'), 'Recipient-neutral by contract');
            System.assertEquals(u.Id, t.OwnerId, 'Stays with the escalating CSM, no addressee');
        }
    }

    @IsTest
    static void quote_saveApproveSend_sendBlockedBeforeApproval() {
        User u = csUser();
        System.runAs(u) {
            Builder_PO__c p = makePo('Mismatch Review');
            String payload = JSON.serialize(new Map<String, Object>{
                'fromPoId' => p.Id,
                'lotText' => 'Lot 134 - test',
                'lines' => new List<Map<String, Object>>{
                    new Map<String, Object>{ 'name' => 'Bermuda sod', 'qty' => 90, 'price' => 0.62, 'cost' => 0.38 }
                }
            });
            Test.startTest();
            String quoteName = LovingCSConsoleController.saveQuote(payload);
            Test.stopTest();
            System.assertNotEquals(null, quoteName);

            Quote__c q = [SELECT Id, Status__c FROM Quote__c WHERE Builder_PO__c = :p.Id LIMIT 1];
            System.assertEquals('Draft', q.Status__c, 'New quote awaits approval as Draft');
            System.assertEquals(1, [SELECT COUNT() FROM Quote_Line_Item__c WHERE Quote__c = :q.Id]);

            // Mismatch resolved: PO returns to Verified with the resolution stamped.
            Builder_PO__c after = [SELECT Status__c, Mismatch_Notes__c FROM Builder_PO__c WHERE Id = :p.Id];
            System.assertEquals('Verified', after.Status__c);
            System.assert(after.Mismatch_Notes__c.contains('Resolved via'));

            Boolean sendBlocked = false;
            try { LovingCSConsoleController.sendQuote(q.Id); }
            catch (AuraHandledException e) {
                sendBlocked = true;
                System.assert(e.getMessage().contains('needs approval'), e.getMessage());
            }
            System.assertEquals(true, sendBlocked, 'Send before approval must fail');

            LovingCSConsoleController.approveQuote(q.Id);
            Quote__c approved = [SELECT Status__c, Approved_By__c FROM Quote__c WHERE Id = :q.Id];
            System.assertEquals('Draft', approved.Status__c,
                'Org lifecycle is forward-only: CS approval stamps Approved_By__c, not status');
            System.assertNotEquals(null, approved.Approved_By__c);

            LovingCSConsoleController.sendQuote(q.Id);
            System.assertEquals('Sent', [SELECT Status__c FROM Quote__c WHERE Id = :q.Id].Status__c);
        }
    }

    @IsTest
    static void warranty_determinationStamps() {
        User u = csUser();
        System.runAs(u) {
            // Warranty_Requires_Parent_WO has no minimal-admin exemption: link a parent.
            Work_Order__c parent = new Work_Order__c(
                Work_Order_Type__c = 'Production Install', Status__c = 'New');
            insert parent;
            Work_Order__c w = new Work_Order__c(
                Work_Order_Type__c = 'Warranty', Status__c = 'New',
                Parent_Work_Order__c = parent.Id);
            insert w;
            Test.startTest();
            LovingCSConsoleController.warrantyDetermine(w.Id, true, 'Covered, 60-day sod');
            Test.stopTest();
            Work_Order__c after = [SELECT Sub_Status__c, Notes__c FROM Work_Order__c WHERE Id = :w.Id];
            System.assertEquals('Coverage Determined', after.Sub_Status__c);
            System.assert(after.Notes__c.contains('Approved'));
            System.assert(after.Notes__c.contains('BR-032'));

            Boolean threw = false;
            try { LovingCSConsoleController.warrantyDetermine(parent.Id, false, null); }
            catch (AuraHandledException e) { threw = true; }
            System.assertEquals(true, threw, 'Determination only on Warranty WOs');
        }
    }

    /** Customer Care WO with the Construction Manager the org validation requires. */
    private static Work_Order__c makeCcWo(Decimal qiScore, String triggerSource) {
        Contact cm = new Contact(LastName = 'Test CM');
        insert cm;
        Work_Order__c w = new Work_Order__c(
            Work_Order_Type__c = 'Customer Care', Status__c = 'New',
            Construction_Manager__c = cm.Id,
            Trigger_Source__c = triggerSource, QI_Score__c = qiScore);
        insert w;
        return w;
    }

    @IsTest
    static void case_closeBlockedUnderQiLock_unlocksAtNine() {
        User u = csUser();
        System.runAs(u) {
            Work_Order__c w = makeCcWo(8.5, 'QI Inspection');

            LovingCSConsoleController.caseAddNote(w.Id, 'FM corrects Thursday AM');
            LovingCSConsoleController.caseResolve(w.Id);

            Boolean lockHeld = false;
            try { LovingCSConsoleController.caseClose(w.Id); }
            catch (AuraHandledException e) {
                lockHeld = true;
                System.assert(e.getMessage().contains('9 or above'), e.getMessage());
            }
            System.assertEquals(true, lockHeld, 'Close blocked while QI is below the floor of 9');

            // Re-inspection result posts from the field.
            w.QI_Score__c = 9.2;
            update w;
            Test.startTest();
            LovingCSConsoleController.caseClose(w.Id);
            Test.stopTest();
            System.assertEquals('Closed', [SELECT Status__c FROM Work_Order__c WHERE Id = :w.Id].Status__c);
        }
    }

    @IsTest
    static void case_resolveFirstThenClose() {
        User u = csUser();
        System.runAs(u) {
            Work_Order__c w = makeCcWo(null, null);
            Boolean threw = false;
            try { LovingCSConsoleController.caseClose(w.Id); }
            catch (AuraHandledException e) {
                threw = true;
                System.assert(e.getMessage().contains('Resolve first'), e.getMessage());
            }
            System.assertEquals(true, threw, 'Resolve must precede Close');
        }
    }

    @IsTest
    static void creates_poCaseCommunityBuilder() {
        User u = csUser();
        System.runAs(u) {
            Id divId = LovingCSConsoleController.onboardBuilder('Toll Brothers Charlotte (test)');
            System.assertNotEquals(null, divId);

            Id commId = LovingCSConsoleController.createCommunity(JSON.serialize(new Map<String, Object>{
                'name' => 'Catawba Crossing Test', 'builderAccountId' => divId,
                'territory' => 'Charlotte', 'bmg' => 'TST-CLT-01', 'aqua' => false }));
            Community__c c = [SELECT Assigned_FM__c, BMG_Package_Code__c FROM Community__c WHERE Id = :commId];
            System.assertEquals(null, c.Assigned_FM__c, 'G6: FM never defaulted on creation');
            System.assertEquals('TST-CLT-01', c.BMG_Package_Code__c);

            // Case validation requires a CM: stamp one on the community first.
            Contact cm = new Contact(LastName = 'Comm CM');
            insert cm;
            update new Community__c(Id = commId, CM_Contact__c = cm.Id);

            Test.startTest();
            Id poId = LovingCSConsoleController.createPO(JSON.serialize(new Map<String, Object>{
                'poNumber' => 'PO-TEST-NEW', 'amount' => 8500,
                'installDate' => String.valueOf(Date.today().addDays(40)), 'communityId' => commId }));
            Test.stopTest();
            Builder_PO__c p = [SELECT Status__c, Division_Account__c FROM Builder_PO__c WHERE Id = :poId];
            System.assertEquals('Pending CS Review', p.Status__c);
            System.assertEquals(divId, p.Division_Account__c);

            Id caseId = LovingCSConsoleController.createCase(JSON.serialize(new Map<String, Object>{
                'subject' => 'Drainage swale dispute', 'communityId' => commId,
                'lotText' => 'Lot 96', 'origin' => 'Builder email', 'note' => 'Site walk requested' }));
            Work_Order__c cc = [SELECT Work_Order_Type__c, Status__c, Construction_Manager__c
                FROM Work_Order__c WHERE Id = :caseId];
            System.assertEquals('Customer Care', cc.Work_Order_Type__c);
            System.assertEquals('New', cc.Status__c);
            System.assertEquals(cm.Id, cc.Construction_Manager__c, 'CM pulled from the community');
        }
    }

    @IsTest
    static void email_logsTask() {
        User u = csUser();
        System.runAs(u) {
            Builder_PO__c p = makePo('NFI');
            Test.startTest();
            LovingCSConsoleController.sendEmailMsg(JSON.serialize(new Map<String, Object>{
                'toAddress' => 'builder@example.com', 'subject' => 'PO returned',
                'body' => 'We need the plat page.', 'recordId' => p.Id }));
            Test.stopTest();
            System.assertEquals(1, [SELECT COUNT() FROM Task WHERE Subject LIKE 'Email:%']);
        }
    }

    @IsTest
    static void nonAdmin_writesBlocked() {
        // A user without the LOVING_CS_Console permission set: every write throws
        // before any SOQL or DML runs.
        User plain;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            String uniq = 'cspln' + System.now().getTime();
            plain = new User(
                Alias = 'cspln', Email = uniq + '@loving.test',
                Username = uniq + '@loving.test.example', LastName = 'Tester',
                ProfileId = p.Id, TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
            insert plain;
        }
        System.runAs(plain) {
            Test.startTest();
            Integer blocked = 0;
            try { LovingCSConsoleController.verifyPO(null); } catch (AuraHandledException e) { blocked++; }
            try { LovingCSConsoleController.approvePO(null); } catch (AuraHandledException e) { blocked++; }
            try { LovingCSConsoleController.nfiPO(null, 'x'); } catch (AuraHandledException e) { blocked++; }
            try { LovingCSConsoleController.saveQuote('{}'); } catch (AuraHandledException e) { blocked++; }
            try { LovingCSConsoleController.caseClose(null); } catch (AuraHandledException e) { blocked++; }
            Test.stopTest();
            System.assertEquals(5, blocked, 'Every write is permission-gated');
        }
    }

    @IsTest
    static void errorLog_writes() {
        Test.startTest();
        LovingCSConsoleController.logError('unitTest', null,
            new IllegalArgumentException('synthetic'));
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Error_Log__c WHERE Method_Name__c = 'unitTest']);
    }
}
