/**
 * LeadConversionService
 * Stage 2 — Lead Converted
 *
 * Routes conversion logic based on Lead_Type__c:
 *
 *   Scenario A — Net New Builder:
 *     Creates: Builder Parent Account, Contact.
 *     If Market__c is populated (regional/national builder): also creates Builder Market Account;
 *     Contact is linked to the Market Account.
 *     If Market__c is blank (local builder): no Market Account; Contact linked to Parent Account.
 *     No Opportunity at this stage — Community Opportunities are created
 *     separately when a specific community is activated (Scenario C).
 *
 *   Scenario B — Homeowner:
 *     Native conversion creates Account + Contact + optional Opportunity.
 *     This stamps the Account as Home_Owner record type and sets Type.
 *     If an Opportunity was created, Type is set to UpgradeMyBackyard so the
 *     ODLHomeownerPropertyIdentityOpportunity trigger creates Homeowner_Property__c
 *     for all homeowner LeadSource values (including Google, Social Media, etc.).
 *
 *   Scenario C — Existing Builder, New Community:
 *     Creates: Community Opportunity on the existing Builder Market Account
 *              (or Builder Parent Account for local builders).
 *              Matches or creates Contact.
 *
 * Called from LeadHandler.handleAfter when IsConverted flips to true.
 */
public with sharing class LeadConversionService {

    public static void routeConversion(List<Id> leadIds) {
        List<Lead> leads = [
            SELECT Id, Lead_Type__c, Company, FirstName, LastName, Email, Phone,
                   Community_Name__c, Market__c,
                   Builder_Parent_Account__c, Builder_Market_Account__c,
                   ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId,
                   Estimated_Lot_Count__c, Estimated_Annual_Value__c,
                   Service_Flag_Aqua__c, Service_Flag_Irrigation__c,
                   Service_Flag_Grading__c, Service_Flag_Lawn_Care__c,
                   Service_Flag_Refreshes__c
            FROM Lead
            WHERE Id IN :leadIds
        ];

        for (Lead l : leads) {
            try {
                if (l.Lead_Type__c == 'Net New Builder') {
                    convertScenarioA(l);
                } else if (l.Lead_Type__c == 'Homeowner') {
                    convertScenarioB(l);
                } else if (l.Lead_Type__c == 'Existing Builder New Community') {
                    convertScenarioC(l);
                }
            } catch (Exception e) {
                // Log error — do not re-throw to avoid partial rollback of unrelated records
                ErrorLogService.log('LeadConversionService', 'routeConversion', l.Id, e.getMessage());
            }
        }
    }

    // ─────────────────────────────────────────────
    // SCENARIO A — Net New Builder
    // ─────────────────────────────────────────────
    private static void convertScenarioA(Lead l) {
        // 1. Repurpose the auto-converted Account as the Builder Parent Account.
        //    Native Database.convertLead() creates a plain Account; we update it in-place
        //    to apply the correct Record Type and Type instead of creating a duplicate.
        update new Account(
            Id           = l.ConvertedAccountId,
            Name         = l.Company,
            RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Parent'),
            Type         = 'Builder Parent',
            BillingState = 'NC'
        );

        // 2. Builder Market Account (regional/national builders only)
        //    Local builders operate without a market account — Contact links to Parent.
        Id primaryAccountId = l.ConvertedAccountId;
        if (String.isNotBlank(l.Market__c)) {
            Account marketAcct = new Account(
                Name            = l.Company + ' – ' + l.Market__c,
                RecordTypeId    = RecordTypeHelper.getAccountRT('Builder_Market'),
                ParentId        = l.ConvertedAccountId,
                Type            = 'Builder Market'
            );
            insert marketAcct;
            primaryAccountId = marketAcct.Id;
        }

        // 3. Relink the converted Contact to the correct account.
        //    Native conversion creates a Contact linked to the plain converted Account;
        //    we move it to the Market Account (regional) or Parent Account (local).
        //    This avoids the DUPLICATES_DETECTED error from inserting a second Contact.
        if (l.ConvertedContactId != null) {
            update new Contact(
                Id        = l.ConvertedContactId,
                AccountId = primaryAccountId
            );
        }
    }

    // ─────────────────────────────────────────────
    // SCENARIO B — Homeowner
    // ─────────────────────────────────────────────
    private static void convertScenarioB(Lead l) {
        // Native conversion creates a plain Account. Stamp the correct record type and type.
        update new Account(
            Id           = l.ConvertedAccountId,
            RecordTypeId = RecordTypeHelper.getAccountRT('Home_Owner'),
            Type         = 'Home Owner'
        );

        // Set Opportunity Type to UpgradeMyBackyard so ODLHomeownerPropertyIdentityService
        // classifies it as ODL for all homeowner LeadSource values (Google, Social Media, etc.)
        // that aren't in the ODL_LEAD_SOURCES set. The trigger fires on update and creates
        // or finds the Homeowner_Property__c record.
        if (l.ConvertedOpportunityId != null) {
            update new Opportunity(
                Id   = l.ConvertedOpportunityId,
                Type = 'UpgradeMyBackyard'
            );
        }
    }

    // ─────────────────────────────────────────────
    // SCENARIO C — Existing Builder, New Community
    // ─────────────────────────────────────────────
    private static void convertScenarioC(Lead l) {
        // Resolve the account to attach the Community Opportunity to.
        // Regional/national builders use the Builder Market Account.
        // Local builders (no market) use the Builder Parent Account directly.
        Id targetAccountId = l.Builder_Market_Account__c != null
            ? l.Builder_Market_Account__c
            : l.Builder_Parent_Account__c;

        if (targetAccountId == null) {
            throw new ConversionException(
                'Scenario C requires either Builder Market Account or Builder Parent Account to be set on the Lead.'
            );
        }

        // Match or create Contact
        Id contactId = matchOrCreateContact(l, targetAccountId);

        // Community Opportunity on the resolved account
        Opportunity communityOpp = new Opportunity(
            Name                    = l.Community_Name__c,
            AccountId               = targetAccountId,
            StageName               = 'Community Activated',
            CloseDate               = Date.today().addDays(365),
            Amount                  = l.Estimated_Annual_Value__c,
            Market__c               = l.Market__c,
            Estimated_Lot_Count__c  = l.Estimated_Lot_Count__c,
            Service_Flag_Aqua__c    = l.Service_Flag_Aqua__c,
            Service_Flag_Irrigation__c = l.Service_Flag_Irrigation__c,
            Service_Flag_Grading__c    = l.Service_Flag_Grading__c,
            Service_Flag_Lawn_Care__c  = l.Service_Flag_Lawn_Care__c,
            Service_Flag_Refreshes__c  = l.Service_Flag_Refreshes__c
        );
        insert communityOpp;
    }

    private static Id matchOrCreateContact(Lead l, Id accountId) {
        List<Contact> existing = [
            SELECT Id FROM Contact
            WHERE Email = :l.Email
            AND AccountId = :accountId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        Contact con = new Contact(
            FirstName = l.FirstName,
            LastName  = l.LastName,
            Email     = l.Email,
            Phone     = l.Phone,
            AccountId = accountId
        );
        insert con;
        return con.Id;
    }

    public class ConversionException extends Exception {}
}