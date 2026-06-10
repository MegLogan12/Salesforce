/**
 * HomeownerNurtureScheduler — nightly job that auto-moves ghosted Opportunities.
 *
 * Rules:
 *   30 days no Task logged from any active stage → StageName = Nurturing (Lead) or Nurture stage
 *   90 days in Nurturing with no Task → StageName = Closed Lost, Loss_Reason__c = Unresponsive
 *
 * Schedule: run nightly at 1 AM via System.schedule (run once from Anonymous Apex):
 *   System.schedule('Homeowner Nurture Nightly', '0 0 1 * * ?', new HomeownerNurtureScheduler());
 */
global with sharing class HomeownerNurtureScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        nurtureStalePipeline();
        closeLongNurture();
    }

    // Move active Opps with no activity in 30 days into Nurture stage
    private void nurtureStalePipeline() {
        Date cutoff = Date.today().addDays(-30);
        Set<String> activeStagesToNurture = new Set<String>{
            'Prospecting','Consultation Scheduled','Design In Progress',
            'Proposal Presented','Contract Sent'
        };

        // Find Opps where no Task has been logged in 30 days
        List<AggregateResult> recentActivity = [
            SELECT WhatId
            FROM Task
            WHERE WhatId != null
            AND ActivityDate >= :cutoff
            AND What.Type = 'Opportunity'
            GROUP BY WhatId
        ];
        Set<Id> activeOppIds = new Set<Id>();
        for (AggregateResult ar : recentActivity) {
            activeOppIds.add((Id) ar.get('WhatId'));
        }

        List<Opportunity> toNurture = [
            SELECT Id, StageName, RecordTypeId
            FROM Opportunity
            WHERE StageName IN :activeStagesToNurture
            AND IsDeleted = false
            AND Id NOT IN :activeOppIds
            AND CreatedDate < :DateTime.newInstance(cutoff, Time.newInstance(0,0,0,0))
        ];

        for (Opportunity o : toNurture) {
            o.StageName = 'Nurturing';
        }
        if (!toNurture.isEmpty()) {
            Database.update(toNurture, false);
        }
    }

    // Move Opps that have been in Nurturing for 90+ days with no response to Closed Lost
    private void closeLongNurture() {
        Date cutoff90 = Date.today().addDays(-90);

        List<AggregateResult> recentActivity = [
            SELECT WhatId
            FROM Task
            WHERE WhatId != null
            AND ActivityDate >= :cutoff90
            AND What.Type = 'Opportunity'
            GROUP BY WhatId
        ];
        Set<Id> activeOppIds = new Set<Id>();
        for (AggregateResult ar : recentActivity) {
            activeOppIds.add((Id) ar.get('WhatId'));
        }

        List<Opportunity> toLose = [
            SELECT Id, StageName
            FROM Opportunity
            WHERE StageName = 'Nurturing'
            AND IsDeleted = false
            AND Id NOT IN :activeOppIds
        ];

        for (Opportunity o : toLose) {
            o.StageName = 'Closed Lost';
            o.Loss_Reason__c = 'Unresponsive';
        }
        if (!toLose.isEmpty()) {
            Database.update(toLose, false);
        }
    }
}