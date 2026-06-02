public with sharing class ODLHomeownerIntakeService {
    public class TaskTemplate {
        public String subject;
        public Integer dueBusinessDays;
        public Integer dueCalendarDays;

        public TaskTemplate(String subject, Integer dueBusinessDays, Integer dueCalendarDays) {
            this.subject = subject;
            this.dueBusinessDays = dueBusinessDays;
            this.dueCalendarDays = dueCalendarDays;
        }
    }

    private class HouseholdResolution {
        Id existingAccountId;
        Id existingContactId;
        Id sourceAccountIdForHistory;
        String householdName;
        Boolean duplicateFound = false;
        Boolean reuseExistingHousehold = false;
        String decision;
    }

    private static final Set<String> REUSE_DECISIONS = new Set<String>{ 'SAME_HOUSEHOLD', 'SPOUSE_PARTNER' };
    private static final Set<String> NEW_HOUSEHOLD_DECISIONS = new Set<String>{ 'NEW_OWNER', 'NEW_RESIDENT', 'TENANT', 'OVERRIDE' };
    private static final Set<String> BLOCKED_VOUCHER_STATUSES = new Set<String>{ 'Expired', 'Voided', 'Rejected' };
    private static final Set<String> NON_REUSABLE_VOUCHER_STATUSES = new Set<String>{
        'Applied to Quote', 'Contract Signed', 'Deposit Paid', 'Builder Invoice Pending',
        'Builder Invoiced', 'Paid by Builder', 'Redeemed'
    };

    public static String validateVoucherCode(String voucherCode) {
        Voucher__c voucherRow = resolveVoucher(voucherCode, null);
        return voucherRow == null ? null : voucherRow.Id;
    }

    public static void applyVoucherToOpportunity(Id opportunityId, String voucherCode) {
        if (opportunityId == null || String.isBlank(voucherCode)) {
            return;
        }

        Opportunity oppRow = [
            SELECT Id, CampaignId, ContactId, AccountId
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        Voucher__c voucherRow = resolveVoucher(voucherCode, oppRow.Id);
        if (voucherRow == null) {
            throw new AuraHandledException('Voucher not found or not eligible for this homeowner opportunity.');
        }

        voucherRow.Reserved_Opportunity__c = oppRow.Id;
        if (oppRow.ContactId != null) {
            voucherRow.Contact__c = oppRow.ContactId;
        }
        update voucherRow;

        if (oppRow.CampaignId == null && voucherRow.Campaign__c != null) {
            update new Opportunity(
                Id = oppRow.Id,
                CampaignId = voucherRow.Campaign__c
            );
        }

        ensureCampaignMember(voucherRow.Campaign__c, oppRow.ContactId, null);
    }

    public static String createLead(Map<String, String> leadData, String defaultLeadSource, Id ownerId) {
        Lead leadRecord = upsertLead(leadData, defaultLeadSource, ownerId);
        return leadRecord.Id;
    }

    public static String updateLead(String leadId, Map<String, String> leadData) {
        List<Lead> leads = [SELECT Id, IsConverted FROM Lead WHERE Id = :leadId LIMIT 1];
        if (leads.isEmpty()) {
            throw new AuraHandledException('Lead not found with ID: ' + leadId);
        }
        if (leads[0].IsConverted) {
            return leads[0].Id;
        }

        Lead existingLead = leads[0];
        applyLeadFields(existingLead, leadData, null, false);
        validateDuplicateProperty(existingLead.FirstName, existingLead.LastName, existingLead.Email,
            existingLead.Street, existingLead.City, existingLead.State, existingLead.PostalCode, leadData);
        update existingLead;
        return existingLead.Id;
    }

    public static String createUpgradeMyBackyardOpportunity(String leadId, Map<String, Object> opportunityData, Id ownerId) {
        List<TaskTemplate> taskTemplates = new List<TaskTemplate>{
            new TaskTemplate('Create Design - Virtual', 2, null),
            new TaskTemplate('Upload Design into Salesforce in the Opportunity - Virtual', 2, null),
            new TaskTemplate('Create Quote', 12, null),
            new TaskTemplate('Schedule Virtual 10-minute Consult', null, 3)
        };
        return createOpportunityFromLead(leadId, opportunityData, ownerId, 'UpgradeMyBackyard', 'UMB',
            'Backyard Design', 30, taskTemplates, false);
    }

    public static String createDesignBuildOpportunity(String leadId, Map<String, Object> opportunityData, Id ownerId) {
        List<TaskTemplate> taskTemplates = new List<TaskTemplate>{
            new TaskTemplate('Create Design - Onsite', 5, null),
            new TaskTemplate('Upload Design into Salesforce in the Opportunity - Onsite', 5, null),
            new TaskTemplate('Schedule 60-Minutes On-Site Consult', 2, null)
        };
        return createOpportunityFromLead(leadId, opportunityData, ownerId, 'Design Build', 'Design_Build',
            'Consultation', 14, taskTemplates, true);
    }

    public static void saveConsultationDates(String opportunityId, List<Object> consultationDates) {
        try {
            Opportunity opp = new Opportunity(Id = opportunityId);
            for (Integer i = 0; i < consultationDates.size() && i < 3; i++) {
                Object slotObj = consultationDates.get(i);
                String slotJson = JSON.serialize(slotObj);
                Map<String, Object> slot = (Map<String, Object>) JSON.deserializeUntyped(slotJson);

                String utcDateTimeStr = stringValue(slot.get('utcDateTime'));
                if (String.isBlank(utcDateTimeStr)) {
                    String dateStr = stringValue(slot.get('date'));
                    String timeStr = stringValue(slot.get('time'));
                    if (String.isNotBlank(dateStr) && String.isNotBlank(timeStr)) {
                        utcDateTimeStr = dateStr + 'T' + timeStr + ':00Z';
                    }
                }
                if (String.isBlank(utcDateTimeStr)) {
                    continue;
                }

                String cleanedDateTime = utcDateTimeStr.replace('T', ' ').replace('Z', '').substringBefore('.');
                Datetime consultationDateTime = Datetime.valueOfGmt(cleanedDateTime);
                if (i == 0) opp.Consultation_Date_1__c = consultationDateTime;
                if (i == 1) opp.Consultation_Date_2__c = consultationDateTime;
                if (i == 2) opp.Consultation_Date_3__c = consultationDateTime;
            }
            update opp;
        } catch (Exception e) {
            System.debug('Error saving consultation dates: ' + e.getMessage());
        }
    }

    private static Lead upsertLead(Map<String, String> leadData, String defaultLeadSource, Id ownerId) {
        String email = leadData.get('Email');
        String leadSourceValue = String.isNotBlank(leadData.get('LeadSource')) ? leadData.get('LeadSource') : defaultLeadSource;
        List<Lead> existingLeads = [
            SELECT Id, IsConverted, ConvertedAccountId, ConvertedContactId, FirstName, LastName, Company, Phone,
                   Street, City, State, PostalCode, LeadSource, OwnerId, SMS_Consent__c, Email
            FROM Lead
            WHERE Email = :email
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!existingLeads.isEmpty()) {
            Lead existingLead = existingLeads[0];
            applyLeadFields(existingLead, leadData, leadSourceValue, true);
            existingLead.OwnerId = ownerId;
            validateDuplicateProperty(existingLead.FirstName, existingLead.LastName, existingLead.Email,
                existingLead.Street, existingLead.City, existingLead.State, existingLead.PostalCode, leadData);
            update existingLead;
            syncConvertedAccountAndContact(existingLead, leadData);
            return existingLead;
        }

        Lead newLead = new Lead();
        applyLeadFields(newLead, leadData, leadSourceValue, true);
        newLead.OwnerId = ownerId;
        newLead.Lead_Type__c = 'Homeowner';
        newLead.Community_Name__c = 'Homeowner Web Form';
        validateDuplicateProperty(newLead.FirstName, newLead.LastName, newLead.Email,
            newLead.Street, newLead.City, newLead.State, newLead.PostalCode, leadData);
        insert newLead;
        return newLead;
    }

    private static void applyLeadFields(Lead leadRecord, Map<String, String> leadData, String leadSourceValue, Boolean updateLeadSource) {
        String firstName = leadData.get('FirstName');
        String lastName = leadData.get('LastName');
        String street = leadData.get('Street');
        if (String.isBlank(lastName)) {
            throw new AuraHandledException('Last Name is required before creating or updating a homeowner lead.');
        }
        leadRecord.FirstName = firstName;
        leadRecord.LastName = lastName;
        leadRecord.Company = buildHouseholdName(lastName, street, firstName);
        leadRecord.Email = leadData.get('Email');
        leadRecord.Phone = leadData.get('Phone');
        leadRecord.Street = street;
        leadRecord.City = leadData.get('City');
        leadRecord.State = leadData.get('State');
        leadRecord.PostalCode = leadData.get('PostalCode');
        if (updateLeadSource && String.isNotBlank(leadSourceValue)) {
            leadRecord.LeadSource = leadSourceValue;
        }
        leadRecord.SMS_Consent__c = leadData.get('SMSConsent') == 'true';
    }

    private static void syncConvertedAccountAndContact(Lead existingLead, Map<String, String> leadData) {
        if (!existingLead.IsConverted) {
            return;
        }
        if (existingLead.ConvertedAccountId != null) {
            Account acc = [
                SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, Phone, ODL_Household_Display_Name__c
                FROM Account
                WHERE Id = :existingLead.ConvertedAccountId
                LIMIT 1
            ];
            applyHouseholdNaming(acc, leadData.get('LastName'), leadData.get('Street'), leadData.get('FirstName'));
            acc.BillingStreet = leadData.get('Street');
            acc.BillingCity = leadData.get('City');
            acc.BillingState = leadData.get('State');
            acc.BillingPostalCode = leadData.get('PostalCode');
            acc.Phone = leadData.get('Phone');
            update acc;
        }
        if (existingLead.ConvertedContactId != null) {
            Contact con = [
                SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, SMS_Consent__c
                FROM Contact
                WHERE Id = :existingLead.ConvertedContactId
                LIMIT 1
            ];
            con.FirstName = leadData.get('FirstName');
            con.LastName = leadData.get('LastName');
            con.Email = leadData.get('Email');
            con.Phone = leadData.get('Phone');
            con.MailingStreet = leadData.get('Street');
            con.MailingCity = leadData.get('City');
            con.MailingState = leadData.get('State');
            con.MailingPostalCode = leadData.get('PostalCode');
            con.SMS_Consent__c = leadData.get('SMSConsent') == 'true';
            update con;
        }
    }

    private static String createOpportunityFromLead(String leadId, Map<String, Object> opportunityData, Id ownerId,
            String opportunityType, String recordTypeDeveloperName, String opportunityNameSuffix, Integer closeDateDays,
            List<TaskTemplate> taskTemplates, Boolean saveConsultDates) {
        try {
            Lead leadRecord = [
                SELECT Id, FirstName, LastName, Email, Phone, Street, City, State, PostalCode, LeadSource,
                       IsConverted, ConvertedAccountId, ConvertedContactId, SMS_Consent__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            HouseholdResolution resolution = resolveHousehold(leadRecord, opportunityData);
            String opportunityName = firstNonBlank(new List<String>{
                buildHouseholdName(leadRecord.LastName, leadRecord.Street, leadRecord.FirstName),
                'Homeowner Household'
            }) + ' - ' + opportunityNameSuffix;
            Id leadCampaignId = latestLeadCampaignId(leadRecord.Id);
            Database.LeadConvertResult lcr;
            if (!leadRecord.IsConverted) {
                lcr = convertLead(leadRecord, resolution.existingAccountId, resolution.existingContactId, opportunityName);
            }

            Id accountId = leadRecord.IsConverted ? leadRecord.ConvertedAccountId : lcr.getAccountId();
            Id contactId = leadRecord.IsConverted ? leadRecord.ConvertedContactId : lcr.getContactId();
            Account householdAccount = [
                SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, Phone,
                       ODL_Household_Display_Name__c, ODL_Secondary_Contact__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            applyHouseholdNaming(householdAccount, leadRecord.LastName, leadRecord.Street, leadRecord.FirstName);
            householdAccount.BillingStreet = leadRecord.Street;
            householdAccount.BillingCity = leadRecord.City;
            householdAccount.BillingState = leadRecord.State;
            householdAccount.BillingPostalCode = leadRecord.PostalCode;
            householdAccount.Phone = leadRecord.Phone;
            update householdAccount;

            if (contactId != null) {
                Contact con = [
                    SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, SMS_Consent__c
                    FROM Contact
                    WHERE Id = :contactId
                    LIMIT 1
                ];
                con.FirstName = leadRecord.FirstName;
                con.LastName = leadRecord.LastName;
                con.Email = leadRecord.Email;
                con.Phone = leadRecord.Phone;
                con.MailingStreet = leadRecord.Street;
                con.MailingCity = leadRecord.City;
                con.MailingState = leadRecord.State;
                con.MailingPostalCode = leadRecord.PostalCode;
                con.SMS_Consent__c = leadRecord.SMS_Consent__c;
                update con;

                if (resolution.reuseExistingHousehold && resolution.decision == 'SPOUSE_PARTNER' && Schema.SObjectType.Account.fields.getMap().containsKey('ODL_Secondary_Contact__c')) {
                    householdAccount.ODL_Secondary_Contact__c = con.Id;
                    update householdAccount;
                }
            }

            String voucherCode = extractVoucherCode(opportunityData);
            Voucher__c voucherRow = resolveVoucher(voucherCode, null);
            Id campaignId = coalesceId(
                (Id) opportunityData.get('campaignId'),
                coalesceId(voucherRow != null ? voucherRow.Campaign__c : null, leadCampaignId)
            );
            Opportunity newOpp = new Opportunity();
            newOpp.Name = householdAccount.Name + ' - ' + opportunityNameSuffix;
            newOpp.AccountId = accountId;
            newOpp.ContactId = contactId;
            newOpp.StageName = 'Quote Requested';
            newOpp.CloseDate = System.today().addDays(closeDateDays);
            newOpp.LeadSource = leadRecord.LeadSource;
            newOpp.OwnerId = ownerId;
            newOpp.Description = buildOpportunityDescription(opportunityData);
            newOpp.Timeline__c = normalizeTimeline(stringValue(opportunityData.get('timeline')));
            newOpp.Budget__c = normalizeBudget(stringValue(opportunityData.get('budget')));
            newOpp.Desired_Backyard_Outcome__c = firstNonBlank(new List<String>{
                stringValue(opportunityData.get('desiredOutcome')),
                stringValue(opportunityData.get('description'))
            });
            newOpp.Type = opportunityType;
            newOpp.RecordTypeId = recordTypeId('Opportunity', recordTypeDeveloperName);
            newOpp.CampaignId = campaignId;
            newOpp.Source_Lead__c = leadRecord.Id;
            insert newOpp;

            createTasks(newOpp.Id, ownerId, taskTemplates);
            if (saveConsultDates) {
                List<Object> consultationDates = (List<Object>) opportunityData.get('consultationDates');
                if (consultationDates != null && !consultationDates.isEmpty()) {
                    saveConsultationDates(newOpp.Id, consultationDates);
                }
            }

            syncVoucherAndCampaign(leadRecord.Id, contactId, newOpp, voucherRow);
            ensurePropertyAndReview(newOpp.Id, accountId, contactId, householdAccount, voucherRow, resolution);
            return newOpp.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error in lead conversion: ' + e.getMessage());
        }
    }

    private static void validateDuplicateProperty(String firstName, String lastName, String email, String street, String city, String state, String postalCode, Map<String, String> input) {
        HouseholdResolution resolution = resolveHousehold(firstName, lastName, email, street, city, state, postalCode, toObjectMap(input));
        if (resolution.duplicateFound && !resolution.reuseExistingHousehold && String.isBlank(resolution.decision)) {
            throw new AuraHandledException('A homeowner household already exists at this property address. Choose SAME_HOUSEHOLD, SPOUSE_PARTNER, NEW_OWNER, NEW_RESIDENT, TENANT, or OVERRIDE with a reason before continuing.');
        }
    }

    private static HouseholdResolution resolveHousehold(Lead leadRecord, Map<String, Object> input) {
        return resolveHousehold(leadRecord.FirstName, leadRecord.LastName, leadRecord.Email, leadRecord.Street,
            leadRecord.City, leadRecord.State, leadRecord.PostalCode, input);
    }

    private static HouseholdResolution resolveHousehold(String firstName, String lastName, String email, String street,
            String city, String state, String postalCode, Map<String, Object> input) {
        HouseholdResolution resolution = new HouseholdResolution();
        resolution.householdName = buildHouseholdName(lastName, street, firstName);
        if (String.isBlank(street) || String.isBlank(city) || String.isBlank(state) || String.isBlank(postalCode)) {
            return resolution;
        }

        List<Account> matchingAccounts = [
            SELECT Id, Name, PersonEmail, BillingStreet, BillingCity, BillingState, BillingPostalCode, PersonContactId
            FROM Account
            WHERE BillingStreet = :street
              AND BillingCity = :city
              AND BillingState = :state
              AND BillingPostalCode = :postalCode
            ORDER BY LastModifiedDate DESC
            LIMIT 20
        ];
        if (matchingAccounts.isEmpty()) {
            return resolution;
        }

        resolution.duplicateFound = true;
        String decision = normalizeDecision(stringValue(input.get('householdDecision')));
        String overrideReason = stringValue(input.get('householdOverrideReason'));
        Id selectedAccountId = coalesceId((Id) input.get('existingAccountId'), matchingAccounts[0].Id);

        for (Account candidate : matchingAccounts) {
            if (String.isNotBlank(email) && sameIgnoreCase(email, candidate.PersonEmail)) {
                resolution.existingAccountId = candidate.Id;
                resolution.existingContactId = candidate.PersonContactId;
                resolution.reuseExistingHousehold = true;
                resolution.decision = 'SAME_HOUSEHOLD';
                return resolution;
            }
        }

        if (String.isNotBlank(email)) {
            Set<Id> matchingAccountIds = new Set<Id>();
            for (Account candidate : matchingAccounts) {
                matchingAccountIds.add(candidate.Id);
            }
            List<Contact> matchingContacts = [
                SELECT Id, AccountId
                FROM Contact
                WHERE AccountId IN :matchingAccountIds
                  AND Email = :email
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (!matchingContacts.isEmpty()) {
                Contact matchingContact = matchingContacts[0];
                resolution.existingAccountId = matchingContact.AccountId;
                resolution.existingContactId = matchingContact.Id;
                resolution.reuseExistingHousehold = true;
                resolution.decision = 'SAME_HOUSEHOLD';
                return resolution;
            }
        }

        if (String.isBlank(decision)) {
            return resolution;
        }
        resolution.decision = decision;
        if (decision == 'OVERRIDE' && String.isBlank(overrideReason)) {
            throw new AuraHandledException('A household override reason is required when bypassing an address duplicate warning.');
        }
        if (REUSE_DECISIONS.contains(decision)) {
            resolution.reuseExistingHousehold = true;
            resolution.existingAccountId = selectedAccountId;
            for (Account candidate : matchingAccounts) {
                if (candidate.Id == selectedAccountId) {
                    resolution.existingContactId = candidate.PersonContactId;
                    break;
                }
            }
        } else if (NEW_HOUSEHOLD_DECISIONS.contains(decision)) {
            resolution.sourceAccountIdForHistory = selectedAccountId;
        } else if (!NEW_HOUSEHOLD_DECISIONS.contains(decision)) {
            throw new AuraHandledException('Unsupported household decision. Use SAME_HOUSEHOLD, SPOUSE_PARTNER, NEW_OWNER, NEW_RESIDENT, TENANT, or OVERRIDE.');
        }
        return resolution;
    }

    private static Database.LeadConvertResult convertLead(Lead leadRecord, Id accountId, Id contactId, String opportunityName) {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadRecord.Id);
        lc.setDoNotCreateOpportunity(true);
        if (accountId != null) {
            lc.setAccountId(accountId);
        }
        if (contactId != null) {
            lc.setContactId(contactId);
        }
        LeadStatus convertedStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        lc.setConvertedStatus(convertedStatus.MasterLabel);
        return Database.convertLead(lc);
    }

    private static Id latestLeadCampaignId(Id leadId) {
        if (leadId == null || !Schema.sObjectType.CampaignMember.isAccessible()) {
            return null;
        }
        List<CampaignMember> members = [
            SELECT CampaignId
            FROM CampaignMember
            WHERE LeadId = :leadId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return members.isEmpty() ? null : members[0].CampaignId;
    }

    private static void syncVoucherAndCampaign(Id leadId, Id contactId, Opportunity opp, Voucher__c voucherRow) {
        if (voucherRow != null) {
            voucherRow.Homeowner_Lead__c = leadId;
            voucherRow.Contact__c = contactId;
            voucherRow.Reserved_Opportunity__c = opp.Id;
            update voucherRow;
            ensureCampaignMember(voucherRow.Campaign__c, contactId, leadId);
            if (opp.CampaignId == null && voucherRow.Campaign__c != null) {
                update new Opportunity(Id = opp.Id, CampaignId = voucherRow.Campaign__c);
            }
        }
    }

    private static Voucher__c resolveVoucher(String voucherCode, Id opportunityId) {
        if (String.isBlank(voucherCode) || !Schema.getGlobalDescribe().containsKey('Voucher__c')) {
            return null;
        }
        List<Voucher__c> vouchers = [
            SELECT Id, Voucher_Code__c, Status__c, Expiration_Date__c, Campaign__c, Builder_Account__c, Contact__c,
                   Homeowner_Lead__c, Reserved_Opportunity__c, Redeemed_Quote__c, Minimum_Project_Value__c
            FROM Voucher__c
            WHERE Voucher_Code__c = :voucherCode
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (vouchers.isEmpty()) {
            return null;
        }
        Voucher__c voucherRow = vouchers[0];
        if (BLOCKED_VOUCHER_STATUSES.contains(voucherRow.Status__c)) {
            throw new AuraHandledException('This voucher cannot be used because it is ' + voucherRow.Status__c + '.');
        }
        if (voucherRow.Expiration_Date__c != null && voucherRow.Expiration_Date__c < Date.today()) {
            throw new AuraHandledException('This voucher has expired and cannot be reserved.');
        }
        if (NON_REUSABLE_VOUCHER_STATUSES.contains(voucherRow.Status__c) || voucherRow.Redeemed_Quote__c != null) {
            throw new AuraHandledException('This voucher has already been used and cannot be reused.');
        }
        if (voucherRow.Reserved_Opportunity__c != null && voucherRow.Reserved_Opportunity__c != opportunityId) {
            throw new AuraHandledException('This voucher is already reserved on another opportunity.');
        }
        return voucherRow;
    }

    private static String extractVoucherCode(Map<String, Object> opportunityData) {
        return firstNonBlank(new List<String>{
            stringValue(opportunityData.get('voucherCode')),
            stringValue(opportunityData.get('couponCode'))
        });
    }

    private static void ensureCampaignMember(Id campaignId, Id contactId, Id leadId) {
        if (campaignId == null || (contactId == null && leadId == null)) {
            return;
        }
        List<CampaignMember> existingMembers = [
            SELECT Id
            FROM CampaignMember
            WHERE CampaignId = :campaignId
              AND (ContactId = :contactId OR LeadId = :leadId)
            LIMIT 1
        ];
        if (!existingMembers.isEmpty()) {
            return;
        }
        String defaultStatus = 'Sent';
        List<CampaignMemberStatus> statuses = [
            SELECT Label
            FROM CampaignMemberStatus
            WHERE CampaignId = :campaignId AND IsDefault = true
            LIMIT 1
        ];
        if (!statuses.isEmpty()) {
            defaultStatus = statuses[0].Label;
        }
        CampaignMember member = new CampaignMember(CampaignId = campaignId, Status = defaultStatus);
        if (contactId != null) {
            member.ContactId = contactId;
        } else {
            member.LeadId = leadId;
        }
        insert member;
    }

    private static void ensurePropertyAndReview(Id opportunityId, Id accountId, Id contactId, Account householdAccount, Voucher__c voucherRow, HouseholdResolution resolution) {
        List<Homeowner_Property__c> existingForOpportunity = [
            SELECT Id, Name, Community__c, Lot__c, Homeowner_Account__c, Contact__c
            FROM Homeowner_Property__c
            WHERE Opportunity__c = :opportunityId
            LIMIT 1
        ];
        Homeowner_Property__c propertyRow;
        if (!existingForOpportunity.isEmpty()) {
            propertyRow = existingForOpportunity[0];
            propertyRow.Homeowner_Account__c = accountId;
            if (Schema.SObjectType.Homeowner_Property__c.fields.getMap().containsKey('Contact__c')) {
                propertyRow.put('Contact__c', contactId);
            }
            update propertyRow;
        } else {
            String propertyName = firstNonBlank(new List<String>{ householdAccount.BillingStreet, householdAccount.Name });
            propertyRow = new Homeowner_Property__c(
                Name = propertyName,
                Homeowner_Account__c = accountId,
                Opportunity__c = opportunityId
            );
            if (Schema.SObjectType.Homeowner_Property__c.fields.getMap().containsKey('Contact__c')) {
                propertyRow.put('Contact__c', contactId);
            }

            if (resolution != null && resolution.sourceAccountIdForHistory != null) {
                List<Homeowner_Property__c> historicalRows = [
                    SELECT Id, Community__c, Lot__c, Name
                    FROM Homeowner_Property__c
                    WHERE Homeowner_Account__c = :resolution.sourceAccountIdForHistory
                    ORDER BY LastModifiedDate DESC
                    LIMIT 1
                ];
                if (!historicalRows.isEmpty()) {
                    Homeowner_Property__c historicalRow = historicalRows[0];
                    propertyRow.Community__c = historicalRow.Community__c;
                    propertyRow.Lot__c = historicalRow.Lot__c;
                    if (String.isBlank(propertyName)) {
                        propertyRow.Name = historicalRow.Name;
                    }
                }
            }

            insert propertyRow;
        }

        if (voucherRow != null && Schema.SObjectType.Voucher__c.fields.getMap().containsKey('Homeowner_Property__c')) {
            update new Voucher__c(
                Id = voucherRow.Id,
                Homeowner_Property__c = propertyRow.Id
            );
        }

        insert new Design_Review__c(
            Opportunity__c = opportunityId,
            Status__c = 'Draft'
        );
    }

    private static void createTasks(String opportunityId, Id ownerId, List<TaskTemplate> templates) {
        List<Task> tasksToCreate = new List<Task>();
        for (TaskTemplate template : templates) {
            Date dueDate = template.dueBusinessDays != null
                ? addBusinessDays(System.today(), template.dueBusinessDays)
                : System.today().addDays(template.dueCalendarDays);
            tasksToCreate.add(new Task(
                Subject = template.subject,
                WhatId = opportunityId,
                OwnerId = ownerId,
                Status = 'Not Started',
                Priority = 'Normal',
                ActivityDate = dueDate
            ));
        }
        if (!tasksToCreate.isEmpty()) {
            insert tasksToCreate;
        }
    }

    private static Date addBusinessDays(Date startDate, Integer businessDaysToAdd) {
        Date currentDate = startDate;
        Integer daysAdded = 0;
        while (daysAdded < businessDaysToAdd) {
            currentDate = currentDate.addDays(1);
            DateTime dt = DateTime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));
            Integer dayOfWeek = Integer.valueOf(dt.format('u'));
            if (dayOfWeek != 1 && dayOfWeek != 7) {
                daysAdded++;
            }
        }
        return currentDate;
    }

    private static void applyHouseholdNaming(Account acc, String lastName, String street, String firstName) {
        String householdName = buildHouseholdName(lastName, street, firstName);
        acc.Name = householdName;
        if (Schema.SObjectType.Account.fields.getMap().containsKey('ODL_Household_Display_Name__c')) {
            acc.put('ODL_Household_Display_Name__c', householdName);
        }
    }

    private static String buildHouseholdName(String lastName, String street, String firstName) {
        String cleanLast = String.isNotBlank(lastName) ? lastName.trim() : null;
        String cleanStreet = String.isNotBlank(street) ? street.trim() : null;
        if (String.isNotBlank(cleanLast) && String.isNotBlank(cleanStreet)) {
            return cleanLast + ' - ' + cleanStreet;
        }
        return firstNonBlank(new List<String>{ cleanLast, firstName, 'Homeowner Household' });
    }

    private static Id recordTypeId(String sobjectType, String developerName) {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :sobjectType AND DeveloperName = :developerName AND IsActive = true
            LIMIT 1
        ];
        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }

    private static String buildOpportunityDescription(Map<String, Object> opportunityData) {
        return 'Timeline: ' + stringValue(opportunityData.get('timeline'))
            + ' | Budget: ' + stringValue(opportunityData.get('budget'))
            + ' | ' + firstNonBlank(new List<String>{
                stringValue(opportunityData.get('desiredOutcome')),
                stringValue(opportunityData.get('description'))
            });
    }

    private static String normalizeBudget(String rawBudget) {
        if (String.isBlank(rawBudget)) {
            return null;
        }
        String trimmed = rawBudget.trim();
        Set<String> validValues = new Set<String>{
            'Under $5,000',
            '$5,000-$10,000',
            '$10,000-$20,000',
            '$20,000+',
            'Not sure yet'
        };
        if (validValues.contains(trimmed)) {
            return trimmed;
        }
        String lowered = trimmed.toLowerCase();
        if (lowered.contains('not sure') || lowered.contains('unknown') || lowered.contains('explor')) {
            return 'Not sure yet';
        }
        String digitsOnly = trimmed.replaceAll('[^0-9]', '');
        if (String.isBlank(digitsOnly)) {
            return null;
        }
        Decimal amount = Decimal.valueOf(digitsOnly);
        if (amount < 5000) {
            return 'Under $5,000';
        }
        if (amount <= 10000) {
            return '$5,000-$10,000';
        }
        if (amount <= 20000) {
            return '$10,000-$20,000';
        }
        return '$20,000+';
    }

    private static String normalizeTimeline(String rawTimeline) {
        if (String.isBlank(rawTimeline)) {
            return null;
        }
        String trimmed = rawTimeline.trim();
        Set<String> validValues = new Set<String>{
            'ASAP (0-2 months)',
            '2-4 months',
            '4-6 months',
            '6+ months',
            'Just exploring'
        };
        if (validValues.contains(trimmed)) {
            return trimmed;
        }
        String lowered = trimmed.toLowerCase();
        if (lowered.contains('explor')) {
            return 'Just exploring';
        }
        String digitsOnly = trimmed.replaceAll('[^0-9]', '');
        if (String.isBlank(digitsOnly)) {
            return null;
        }
        Integer amount = Integer.valueOf(digitsOnly);
        if (lowered.contains('day')) {
            if (amount <= 60) {
                return 'ASAP (0-2 months)';
            }
            if (amount <= 120) {
                return '2-4 months';
            }
            if (amount <= 180) {
                return '4-6 months';
            }
            return '6+ months';
        }
        if (lowered.contains('month')) {
            if (amount <= 2) {
                return 'ASAP (0-2 months)';
            }
            if (amount <= 4) {
                return '2-4 months';
            }
            if (amount <= 6) {
                return '4-6 months';
            }
            return '6+ months';
        }
        return null;
    }

    private static Map<String, Object> toObjectMap(Map<String, String> input) {
        Map<String, Object> out = new Map<String, Object>();
        if (input == null) {
            return out;
        }
        for (String key : input.keySet()) {
            out.put(key, input.get(key));
        }
        return out;
    }

    private static String normalizeDecision(String decision) {
        if (String.isBlank(decision)) {
            return null;
        }
        return decision.trim().toUpperCase().replace(' ', '_').replace('-', '_').replace('/', '_');
    }

    private static Boolean sameIgnoreCase(String left, String right) {
        return String.isNotBlank(left) && String.isNotBlank(right) && left.trim().toLowerCase() == right.trim().toLowerCase();
    }

    private static String stringValue(Object raw) {
        return raw == null ? null : String.valueOf(raw);
    }

    private static Id coalesceId(Id left, Id right) {
        return left != null ? left : right;
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (String.isNotBlank(value)) {
                return value;
            }
        }
        return null;
    }
}