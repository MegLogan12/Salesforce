@IsTest
private class ODLLeadOppAttribBackfillTest {
    @IsTest
    static void repairsConvertedLeadOpportunityAttributionByContactSourceAndDate() {
        Campaign campaignRow = new Campaign(
            Name = 'ODL Backfill Campaign',
            Type = 'Website Direct',
            Status = 'In Progress',
            IsActive = true
        );
        insert campaignRow;

        Lead leadRow = new Lead(
            FirstName = 'Blake',
            LastName = 'Backfill',
            Company = 'Blake Backfill',
            Email = 'blake.backfill@example.com',
            Phone = '555-300-1000',
            Street = '414 Attribution Way',
            City = 'Charlotte',
            State = 'NC',
            PostalCode = '28202',
            LeadSource = 'Web - Design Form',
            Lead_Type__c = 'Homeowner',
            Community_Name__c = 'Homeowner Web Form'
        );
        insert leadRow;
        insert new CampaignMember(CampaignId = campaignRow.Id, LeadId = leadRow.Id, Status = 'Sent');

        Database.LeadConvert convertRequest = new Database.LeadConvert();
        convertRequest.setLeadId(leadRow.Id);
        convertRequest.setDoNotCreateOpportunity(true);
        convertRequest.setConvertedStatus('Qualified');
        Database.LeadConvertResult convertResult = Database.convertLead(convertRequest);
        System.assertEquals(true, convertResult.isSuccess());

        Lead convertedLead = [
            SELECT Id, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId
            FROM Lead
            WHERE Id = :leadRow.Id
        ];
        System.assertEquals(null, convertedLead.ConvertedOpportunityId);

        Opportunity orphanedOpp = new Opportunity(
            Name = 'Blake Backfill - Backyard Design',
            AccountId = convertedLead.ConvertedAccountId,
            ContactId = convertedLead.ConvertedContactId,
            StageName = 'Quote Requested',
            CloseDate = Date.today().addDays(30),
            LeadSource = 'Web - Design Form',
            Type = 'UpgradeMyBackyard'
        );
        insert orphanedOpp;

        Test.startTest();
        Database.executeBatch(new ODLLeadOpportunityAttributionBackfill(), 50);
        Test.stopTest();

        Opportunity repairedOpp = [
            SELECT Source_Lead__c, CampaignId
            FROM Opportunity
            WHERE Id = :orphanedOpp.Id
        ];
        System.assertEquals(leadRow.Id, repairedOpp.Source_Lead__c);
        System.assertEquals(campaignRow.Id, repairedOpp.CampaignId);
    }
}