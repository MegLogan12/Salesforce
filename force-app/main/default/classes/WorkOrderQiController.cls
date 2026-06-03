public with sharing class WorkOrderQiController {

    public class QiPayload {
        @AuraEnabled public Quality_Inspection__c inspection;
        @AuraEnabled public List<QI_Line__c>      lines;
    }

    // Returns the QI header + lines for a given WorkOrder.
    // Returns null inspection + empty lines when no QI record exists yet.
    @AuraEnabled(cacheable=true)
    public static QiPayload getQiInspection(Id workOrderId) {
        QiPayload p = new QiPayload();
        p.inspection = null;
        p.lines      = new List<QI_Line__c>();
        if (workOrderId == null) return p;

        List<Quality_Inspection__c> qis = [
            SELECT Id, Name, Result__c, Score_Pct__c, Avg_Score__c,
                   Total_Lines__c, Failed_Lines__c, Passed_Lines__c,
                   Inspected_By__c, Inspected_Date__c, Submitted__c
            FROM Quality_Inspection__c
            WHERE Work_Order__c = :workOrderId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (qis.isEmpty()) return p;

        p.inspection = qis[0];
        p.lines = [
            SELECT Id, Name, Item__c, Category__c, Score__c, Result__c, Note__c, Photo_Attached__c
            FROM QI_Line__c
            WHERE Quality_Inspection__c = :qis[0].Id
            ORDER BY Category__c, Item__c
        ];
        return p;
    }

    // Saves scores and notes for a list of QI_Line__c records supplied as JSON.
    // The trigger (QILineTrigger) automatically derives Result__c from Score__c.
    // After save, the Quality_Inspection__c.Result__c formula refreshes automatically.
    @AuraEnabled
    public static void saveLines(String lineData) {
        List<Object> raw = (List<Object>) JSON.deserializeUntyped(lineData);
        List<QI_Line__c> toUpdate = new List<QI_Line__c>();
        for (Object o : raw) {
            Map<String, Object> m = (Map<String, Object>) o;
            QI_Line__c line = new QI_Line__c(Id = (Id) m.get('Id'));
            if (m.get('Score__c') != null) {
                line.Score__c = Decimal.valueOf(String.valueOf(m.get('Score__c')));
            }
            if (m.containsKey('Note__c')) {
                line.Note__c = (String) m.get('Note__c');
            }
            toUpdate.add(line);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }
}
