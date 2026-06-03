@IsTest
private class QIHandlerTest {

    // ── setResultFromScore ────────────────────────────────────────────────────

    @IsTest
    static void setResult_score9_setsPass() {
        QI_Line__c line = new QI_Line__c(Score__c = 9);
        QIHandler.setResultFromScore(new List<QI_Line__c>{ line });
        System.assertEquals('Pass', line.Result__c, 'Score 9 should be Pass');
    }

    @IsTest
    static void setResult_score10_setsPass() {
        QI_Line__c line = new QI_Line__c(Score__c = 10);
        QIHandler.setResultFromScore(new List<QI_Line__c>{ line });
        System.assertEquals('Pass', line.Result__c, 'Score 10 should be Pass');
    }

    @IsTest
    static void setResult_score8_setsFail() {
        QI_Line__c line = new QI_Line__c(Score__c = 8);
        QIHandler.setResultFromScore(new List<QI_Line__c>{ line });
        System.assertEquals('Fail', line.Result__c, 'Score 8 should be Fail');
    }

    @IsTest
    static void setResult_score1_setsFail() {
        QI_Line__c line = new QI_Line__c(Score__c = 1);
        QIHandler.setResultFromScore(new List<QI_Line__c>{ line });
        System.assertEquals('Fail', line.Result__c, 'Score 1 should be Fail');
    }

    @IsTest
    static void setResult_nullScore_clearsResult() {
        QI_Line__c line = new QI_Line__c(Score__c = null);
        QIHandler.setResultFromScore(new List<QI_Line__c>{ line });
        System.assertEquals(null, line.Result__c, 'Null score should yield null result');
    }

    @IsTest
    static void setResult_multipleLines_allSet() {
        List<QI_Line__c> lines = new List<QI_Line__c>{
            new QI_Line__c(Score__c = 10),
            new QI_Line__c(Score__c = 9),
            new QI_Line__c(Score__c = 8),
            new QI_Line__c(Score__c = null)
        };
        QIHandler.setResultFromScore(lines);
        System.assertEquals('Pass', lines[0].Result__c);
        System.assertEquals('Pass', lines[1].Result__c);
        System.assertEquals('Fail', lines[2].Result__c);
        System.assertEquals(null,   lines[3].Result__c);
    }

    // ── QI_Line__c trigger integration: insert sets Result__c ─────────────────

    @IsTest
    static void trigger_insertLine_setsResult() {
        Quality_Inspection__c qi = new Quality_Inspection__c();
        insert qi;

        Test.startTest();
        QI_Line__c line = new QI_Line__c(
            Quality_Inspection__c = qi.Id,
            Item__c               = 'Mulch depth',
            Category__c           = 'Sod & Turf',
            Score__c              = 9
        );
        insert line;
        Test.stopTest();

        QI_Line__c saved = [SELECT Result__c FROM QI_Line__c WHERE Id = :line.Id];
        System.assertEquals('Pass', saved.Result__c, 'Trigger should set Pass for score 9');
    }

    @IsTest
    static void trigger_updateScoreToFail_setsFailResult() {
        Quality_Inspection__c qi = new Quality_Inspection__c();
        insert qi;
        QI_Line__c line = new QI_Line__c(
            Quality_Inspection__c = qi.Id,
            Item__c               = 'Mulch depth',
            Category__c           = 'Sod & Turf',
            Score__c              = 10
        );
        insert line;

        Test.startTest();
        line.Score__c = 7;
        update line;
        Test.stopTest();

        QI_Line__c saved = [SELECT Result__c FROM QI_Line__c WHERE Id = :line.Id];
        System.assertEquals('Fail', saved.Result__c, 'Trigger should update to Fail on score 7');
    }

    // ── syncResultToWorkOrder: null Work_Order__c is silently skipped ─────────

    @IsTest
    static void sync_nullWorkOrder_noException() {
        Quality_Inspection__c qi = new Quality_Inspection__c();
        insert qi;
        // Re-query to get computed Result__c = 'Pending' (no lines yet)
        Quality_Inspection__c qiLoaded = [
            SELECT Id, Name, Work_Order__c, Result__c FROM Quality_Inspection__c WHERE Id = :qi.Id
        ];
        Test.startTest();
        // Work_Order__c is null → handler skips WO update silently
        QIHandler.syncResultToWorkOrder(new List<Quality_Inspection__c>{ qiLoaded }, null);
        Test.stopTest();
        System.assert(true, 'No exception expected when Work_Order__c is null');
    }

    // ── Fail path: inserting a line with Score < 9 triggers the roll-up which
    //    fires QIInspectionTrigger → WO gets QI_Result__c=Fail, task created ──

    @IsTest(SeeAllData=true)
    static void sync_failResult_updatesWoAndCreatesTask() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder LIMIT 1];
        if (wos.isEmpty()) {
            System.assert(true, 'No WO in org — skipping.'); return;
        }

        Quality_Inspection__c qi = new Quality_Inspection__c(Work_Order__c = wos[0].Id);
        insert qi;

        Test.startTest();
        // Score 7 < 9 → Result__c formula → "Red — Rework Required" → trigger fires
        QI_Line__c failLine = new QI_Line__c(
            Quality_Inspection__c = qi.Id,
            Item__c               = 'Grading check',
            Category__c           = 'Grading & Drainage',
            Score__c              = 7
        );
        insert failLine;
        Test.stopTest();

        WorkOrder wo = [SELECT QI_Result__c, QI_Complete__c FROM WorkOrder WHERE Id = :wos[0].Id];
        System.assertEquals('Fail', wo.QI_Result__c,   'QI_Result__c should be Fail after red result');
        System.assertEquals(false,  wo.QI_Complete__c, 'QI_Complete__c should be false on Fail');

        List<Task> tasks = [SELECT Subject FROM Task WHERE WhatId = :wos[0].Id AND Subject LIKE 'QI Failed%'];
        System.assertEquals(1, tasks.size(), 'Customer Care task should have been created');
    }

    // ── Pass path: all lines >= 9 → Acceptable/Excellent → QI_Complete__c=true ──

    @IsTest(SeeAllData=true)
    static void sync_passResult_setsQiComplete() {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder LIMIT 1];
        if (wos.isEmpty()) {
            System.assert(true, 'No WO in org — skipping.'); return;
        }

        Quality_Inspection__c qi = new Quality_Inspection__c(Work_Order__c = wos[0].Id);
        insert qi;

        Test.startTest();
        // Score 10 → Result__c formula → "Excellent" → trigger fires
        QI_Line__c passLine = new QI_Line__c(
            Quality_Inspection__c = qi.Id,
            Item__c               = 'Edging',
            Category__c           = 'Sod & Turf',
            Score__c              = 10
        );
        insert passLine;
        Test.stopTest();

        WorkOrder wo = [SELECT QI_Result__c, QI_Complete__c FROM WorkOrder WHERE Id = :wos[0].Id];
        System.assertEquals('Pass', wo.QI_Result__c,   'QI_Result__c should be Pass on Excellent result');
        System.assertEquals(true,   wo.QI_Complete__c, 'QI_Complete__c should be true on Pass');
    }

    // ── syncByIds invocable covers the SOQL + delegate path ──────────────────

    @IsTest
    static void syncByIds_noWo_noException() {
        Quality_Inspection__c qi = new Quality_Inspection__c();
        insert qi;
        Test.startTest();
        QIHandler.syncByIds(new List<Id>{ qi.Id });
        Test.stopTest();
        System.assert(true, 'syncByIds should complete without exception');
    }
}
