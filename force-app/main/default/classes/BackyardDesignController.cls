/**
 * BackyardDesignController
 * 
 * Apex controller for the startMyDesignForm LWC
 * Handles Lead creation, conversion, Opportunity creation/updates, and file uploads
 */
public without sharing class BackyardDesignController {
  
  /**
   * Gets the designated owner User Id (Megan)
   * Falls back to running user if not found
   * @return Id - The User Id for record ownership
   */
  private static Id getDesignatedOwnerId() {
    // List<User> users = [SELECT Id FROM User WHERE Name LIKE '%Megan%' AND Email LIKE '%megan.logan@thelovingcompanies.com%' AND IsActive = true LIMIT 1];
    if (System.Label.DESIGNATED_OWNER_USER_NAME != null) {
      return System.Label.DESIGNATED_OWNER_USER_NAME;
    }
    return UserInfo.getUserId();
  }
  
  /**
   * Creates a new Lead record from form data
   * @param leadData Map containing First/Last Name, Email, Phone, Street, City, State, PostalCode
   * @return String - The ID of the created Lead
   */
  @AuraEnabled
  public static String createLead(Map<String, String> leadData) {
    try {
      String email = leadData.get('Email');
      String leadSourceValue = String.isNotBlank(leadData.get('LeadSource')) ? leadData.get('LeadSource') : 'Web - Design Form';
      List<Lead> existingLeads = [SELECT Id, IsConverted, ConvertedAccountId, ConvertedContactId, FirstName, LastName, Company, Phone, Street, City, State, PostalCode, LeadSource, OwnerId, SMS_Consent__c FROM Lead WHERE Email = :email ORDER BY CreatedDate DESC LIMIT 1];
      if (!existingLeads.isEmpty()) {
        Lead existingLead = existingLeads[0];
        // Always update all fields on the lead
        existingLead.FirstName = leadData.get('FirstName');
        existingLead.LastName = leadData.get('LastName');
        existingLead.Company = leadData.get('FirstName') + ' ' + leadData.get('LastName');
        existingLead.Phone = leadData.get('Phone');
        existingLead.Street = leadData.get('Street');
        existingLead.City = leadData.get('City');
        existingLead.State = leadData.get('State');
        existingLead.PostalCode = leadData.get('PostalCode');
        existingLead.LeadSource = leadSourceValue;
        existingLead.OwnerId = getDesignatedOwnerId();
        existingLead.SMS_Consent__c = leadData.get('SMSConsent') == 'true';
        existingLead.Lead_Type__c = 'Homeowner';
        existingLead.Community_Name__c = 'Homeowner Web Form';
        update existingLead;
        // If converted, update Account and Contact as well
        if (existingLead.IsConverted) {
          if (existingLead.ConvertedAccountId != null) {
            Account acc = [SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, Phone, ODL_Household_Display_Name__c FROM Account WHERE Id = :existingLead.ConvertedAccountId LIMIT 1];
            acc.Name = leadData.get('FirstName') + ' ' + leadData.get('LastName');
            acc.BillingStreet = leadData.get('Street');
            acc.BillingCity = leadData.get('City');
            acc.BillingState = leadData.get('State');
            acc.BillingPostalCode = leadData.get('PostalCode');
            acc.Phone = leadData.get('Phone');
            ODLHouseholdService.applyHouseholdFields(acc, leadData.get('LastName'));
            update acc;
          }
          if (existingLead.ConvertedContactId != null) {
            Contact con = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, SMS_Consent__c FROM Contact WHERE Id = :existingLead.ConvertedContactId LIMIT 1];
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
        return existingLead.Id;
      }
      // No existing lead, create new
      Lead newLead = new Lead(
        FirstName = leadData.get('FirstName'),
        LastName = leadData.get('LastName'),
        Company = leadData.get('FirstName') + ' ' + leadData.get('LastName'),
        Email = leadData.get('Email'),
        Phone = leadData.get('Phone'),
        Street = leadData.get('Street'),
        City = leadData.get('City'),
        State = leadData.get('State'),
        PostalCode = leadData.get('PostalCode'),
        LeadSource = leadSourceValue,
        OwnerId = getDesignatedOwnerId(),
        SMS_Consent__c = leadData.get('SMSConsent') == 'true',
        Lead_Type__c = 'Homeowner',
        Community_Name__c = 'Homeowner Web Form'
      );
      insert newLead;
      return newLead.Id;
    } catch (Exception e) {
      throw new AuraHandledException('Error creating lead: ' + e.getMessage());
    }
  }

  /**
   * Updates an existing Lead record with new data
   * @param leadId The ID of the Lead to update
   * @param leadData Map containing First/Last Name, Email, Phone, Street, City, State, PostalCode
   * @return String - The ID of the updated Lead
   */
  @AuraEnabled
  public static String updateLead(String leadId, Map<String, String> leadData) {
    // Check if Lead exists and is not converted
    List<Lead> leads = [SELECT Id, IsConverted FROM Lead WHERE Id = :leadId LIMIT 1];
    
    if (leads.isEmpty()) {
      throw new AuraHandledException('Lead not found with ID: ' + leadId);
    }
    
    Lead existingLead = leads[0];
    
    if (existingLead.IsConverted) {
      // Lead is already converted, can't update - just return the ID
      return existingLead.Id;
    }
    
    try {
      existingLead.FirstName = leadData.get('FirstName');
      existingLead.LastName = leadData.get('LastName');
      existingLead.Company = leadData.get('FirstName') + ' ' + leadData.get('LastName');
      existingLead.Email = leadData.get('Email');
      existingLead.Phone = leadData.get('Phone');
      existingLead.Street = leadData.get('Street');
      existingLead.City = leadData.get('City');
      existingLead.State = leadData.get('State');
      existingLead.PostalCode = leadData.get('PostalCode');
      existingLead.SMS_Consent__c = leadData.get('SMSConsent') == 'true';
      existingLead.Lead_Type__c = 'Homeowner';
      existingLead.Community_Name__c = 'Homeowner Web Form';
      
      update existingLead;
      return existingLead.Id;
    } catch (Exception e) {
      throw new AuraHandledException('Error updating lead: ' + e.getMessage());
    }
  }

  /**
   * Converts a Lead to an Account/Contact and creates an Opportunity
   * @param leadId The ID of the Lead to convert
   * @param opportunityData Map containing timeline, budget, description
   * @return String - The ID of the created Opportunity
   */
  @AuraEnabled
  public static String convertLeadAndCreateOpportunity(
    String leadId,
    Map<String, String> opportunityData
  ) {
    try {

      // Fetch Lead details including conversion status and related Account/Contact
      Lead leadRecord = [SELECT Id, FirstName, LastName, Email, Phone, Street, City, State, PostalCode, LeadSource, IsConverted, ConvertedAccountId, ConvertedContactId, SMS_Consent__c FROM Lead WHERE Id = :leadId LIMIT 1];

      String accountId;
      String contactId;
      String firstName = leadRecord.FirstName;
      String lastName = leadRecord.LastName;
      String phone = leadRecord.Phone;
      String street = leadRecord.Street;
      String city = leadRecord.City;
      String state = leadRecord.State;
      String postalCode = leadRecord.PostalCode;
      String smsConsent = String.valueOf(leadRecord.get('SMS_Consent__c'));

      if (leadRecord.IsConverted) {
        accountId = leadRecord.ConvertedAccountId;
        contactId = leadRecord.ConvertedContactId;
        if (accountId != null) {
          Account acc = [SELECT Id, IsPersonAccount, FirstName, LastName, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, Phone, ODL_Household_Display_Name__c FROM Account WHERE Id = :accountId LIMIT 1];
          if (acc.IsPersonAccount) {
            acc.FirstName = firstName;
            acc.LastName = lastName;
          } else {
            acc.Name = firstName + ' ' + lastName;
          }
          acc.BillingStreet = street;
          acc.BillingCity = city;
          acc.BillingState = state;
          acc.BillingPostalCode = postalCode;
          acc.Phone = phone;
          ODLHouseholdService.applyHouseholdFields(acc, lastName);
          update acc;
        }
        if (contactId != null) {
          Contact con = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, SMS_Consent__c FROM Contact WHERE Id = :contactId LIMIT 1];
          con.FirstName = firstName;
          con.LastName = lastName;
          con.Email = leadRecord.Email;
          con.Phone = phone;
          con.MailingStreet = street;
          con.MailingCity = city;
          con.MailingState = state;
          con.MailingPostalCode = postalCode;
          con.SMS_Consent__c = (smsConsent == 'true');
          update con;
        }
      } else {
        // Convert Lead
        Database.LeadConvertResult lcr = convertLead(leadRecord);
        if (!lcr.isSuccess()) {
          throw new AuraHandledException('Lead conversion failed');
        }
        accountId = lcr.getAccountId();
        contactId = lcr.getContactId();
        // Also update Account and Contact with latest info after conversion
        if (accountId != null) {
          Account acc = [SELECT Id, IsPersonAccount, FirstName, LastName, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, Phone, ODL_Household_Display_Name__c FROM Account WHERE Id = :accountId LIMIT 1];
          if (acc.IsPersonAccount) {
            acc.FirstName = firstName;
            acc.LastName = lastName;
          } else {
            acc.Name = firstName + ' ' + lastName;
          }
          acc.BillingStreet = street;
          acc.BillingCity = city;
          acc.BillingState = state;
          acc.BillingPostalCode = postalCode;
          acc.Phone = phone;
          ODLHouseholdService.applyHouseholdFields(acc, lastName);
          update acc;
        }
        if (contactId != null) {
          Contact con = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode, SMS_Consent__c FROM Contact WHERE Id = :contactId LIMIT 1];
          con.FirstName = firstName;
          con.LastName = lastName;
          con.Email = leadRecord.Email;
          con.Phone = phone;
          con.MailingStreet = street;
          con.MailingCity = city;
          con.MailingState = state;
          con.MailingPostalCode = postalCode;
          con.SMS_Consent__c = (smsConsent == 'true');
          update con;
        }
      }

      // Create Opportunity with Contact linked and updated name
      Id ownerId = getDesignatedOwnerId();
      Opportunity newOpp = new Opportunity(
        Name = firstName + ' ' + lastName + ' - Backyard Design',
        AccountId = accountId,
        ContactId = contactId,
        RecordTypeId = ODLHouseholdService.getUmbOpportunityRecordTypeId(),
        StageName = 'Quote Requested',
        CloseDate = System.today().addDays(30),
        LeadSource = leadRecord.LeadSource,
        Type = 'UMB',
        OwnerId = ownerId,
        Description = 'Timeline: ' + opportunityData.get('timeline') + ' | Budget: ' + opportunityData.get('budget') + ' | ' + opportunityData.get('description'),
        Timeline__c = opportunityData.get('timeline'),
        Budget__c = opportunityData.get('budget'),
        Desired_Backyard_Outcome__c = opportunityData.get('description')
      );
      insert newOpp;

      // Apply coupon code if provided
      String couponCode = opportunityData.get('couponCode');
      if (String.isNotBlank(couponCode)) {
        applyCouponToOpportunity(newOpp.Id, couponCode);
      }

      // Create Tasks for Designer
      createDesignerTasks(newOpp.Id);

      return newOpp.Id;
    } catch (Exception e) {
      throw new AuraHandledException('Error in lead conversion: ' + e.getMessage());
    }
  }
  
  /**
   * Calculates a date by adding business days (excluding weekends)
   * @param startDate The start date
   * @param businessDaysToAdd Number of business days to add
   * @return Date - The calculated date
   */
  private static Date addBusinessDays(Date startDate, Integer businessDaysToAdd) {
    Date currentDate = startDate;
    Integer daysAdded = 0;
    
    while (daysAdded < businessDaysToAdd) {
      currentDate = currentDate.addDays(1);
      
      // Get day of week (1=Sunday, 2=Monday, ..., 7=Saturday)
      DateTime dt = DateTime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));
      Integer dayOfWeek = Integer.valueOf(dt.format('u'));
      
      // Skip weekends (1=Sunday, 7=Saturday)
      if (dayOfWeek != 1 && dayOfWeek != 7) {
        daysAdded++;
      }
    }
    
    return currentDate;
  }

  /**
   * Creates Tasks for Designer role
   * @param opportunityId The ID of the Opportunity
   */
  private static void createDesignerTasks(String opportunityId) {
    List<Task> tasksToCreate = new List<Task>();
    Id ownerId = getDesignatedOwnerId();
    
    // Task 1: Create Design - Virtual (Due in 2 business days)
    Task createDesignTask = new Task(
      Subject = 'Create Design - Virtual',
      WhatId = opportunityId,
      OwnerId = ownerId,
      Status = 'Not Started',
      Priority = 'Normal',
      ActivityDate = addBusinessDays(System.today(), 2)
    );
    tasksToCreate.add(createDesignTask);
    
    // Task 2: Upload Design into Salesforce in the Opportunity
    Task uploadDesignTask = new Task(
      Subject = 'Upload Design into Salesforce in the Opportunity - Virtual',
      WhatId = opportunityId,
      OwnerId = ownerId,
      Status = 'Not Started',
      Priority = 'Normal',
      ActivityDate = addBusinessDays(System.today(), 2)
    );
    tasksToCreate.add(uploadDesignTask);
    
    // Task 3: Create Quote
    Task createQuoteTask = new Task(
      Subject = 'Create Quote',
      WhatId = opportunityId,
      OwnerId = ownerId,
      Status = 'Not Started',
      Priority = 'Normal',
      ActivityDate = addBusinessDays(System.today(), 12)
    );
    tasksToCreate.add(createQuoteTask);
    
    // Task 4: Schedule virtual 10-minute consult
    Task scheduleConsultTask = new Task(
      Subject = 'Schedule Virtual 10-minute Consult',
      WhatId = opportunityId,
      OwnerId = ownerId,
      Status = 'Not Started',
      Priority = 'Normal',
      ActivityDate = System.today().addDays(3)
    );
    tasksToCreate.add(scheduleConsultTask);
    
    insert tasksToCreate;
  }

  /**
   * Converts a Lead record to Account/Contact
   * @param lead The Lead record to convert
   * @return Database.LeadConvertResult - Result of the conversion
   */
  private static Database.LeadConvertResult convertLead(Lead lead) {
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(lead.Id);
    
    // Don't create automatic Opportunity - we create our own
    lc.setDoNotCreateOpportunity(true);
    
    // Query for a valid converted Lead status
    LeadStatus convertedStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
    lc.setConvertedStatus(convertedStatus.MasterLabel);

    // A homeowner is a person, not a business. Create a Person Account and convert into it.
    // Company is cleared first (it is not required here, only Lead Source is) so the
    // conversion into a Person Account is allowed. Falls back to the standard
    // business-account conversion if Person Accounts are unavailable for the running user.
    try {
      Schema.RecordTypeInfo paInfo =
        Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount');
      if (paInfo != null && paInfo.isAvailable()) {
        if (lead.Company != null) {
          update new Lead(Id = lead.Id, Company = null);
        }
        Account personAcct = new Account(
          RecordTypeId = paInfo.getRecordTypeId(),
          FirstName = lead.FirstName,
          LastName = (String.isBlank(lead.LastName) ? 'Homeowner' : lead.LastName),
          PersonEmail = lead.Email
        );
        insert personAcct;
        lc.setAccountId(personAcct.Id);
      }
    } catch (Exception pae) {
      System.debug(LoggingLevel.WARN,
        'Person Account path unavailable, using standard conversion: ' + pae.getMessage());
    }

    Database.LeadConvertResult lcr = Database.convertLead(lc);
    return lcr;
  }

  /**
   * Updates an existing Opportunity with form data (when going back/forth in form)
   * @param opportunityId The ID of the Opportunity to update
   * @param opportunityData Map containing timeline, budget, description
   * @return String - The ID of the updated Opportunity
   */
  @AuraEnabled
  public static String updateOpportunity(
    String opportunityId,
    Map<String, String> opportunityData
  ) {
    try {
      List<Opportunity> opps = [SELECT Id, Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
      
      if (opps.isEmpty()) {
        throw new AuraHandledException('Opportunity not found with ID: ' + opportunityId);
      }
      
      Opportunity opp = opps[0];
      
      opp.Description = 'Timeline: ' + opportunityData.get('timeline') + ' | Budget: ' + opportunityData.get('budget') + ' | ' + opportunityData.get('description');
      opp.Timeline__c = opportunityData.get('timeline');
      opp.Budget__c = opportunityData.get('budget');
      opp.Desired_Backyard_Outcome__c = opportunityData.get('description');
      
      // Apply coupon code if provided
      String couponCode = opportunityData.get('couponCode');
      if (String.isNotBlank(couponCode)) {
        applyCouponToOpportunity(opp.Id, couponCode);
      }

      update opp;
      
      return opp.Id;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException('Error updating opportunity: ' + e.getMessage());
    }
  }

  /**
   * Marks the Opportunity as form submitted
   * @param opportunityId The ID of the Opportunity
   */
  @AuraEnabled
  public static void markFormSubmitted(String opportunityId) {
    try {
      Opportunity opp = new Opportunity(
        Id = opportunityId,
        Form_Submitted__c = true
      );
      update opp;
    } catch (Exception e) {
      throw new AuraHandledException('Error marking form submitted: ' + e.getMessage());
    }
  }

  /**
   * Updates an Opportunity with selected features and estimates
   * @param opportunityId The ID of the Opportunity
   * @param featureData Map containing selectedFeatures, estimateTotal, monthlyEstimate, additionalDetails
   */
  @AuraEnabled
  public static void updateOpportunityWithFeatures(
    String opportunityId,
    Map<String, Object> featureData
  ) {
    try {
      Opportunity opp = new Opportunity(Id = opportunityId);
      
      // Append selected features to Description
      String description = 'Features: ' + featureData.get('selectedFeatures') + ' | Estimated Budget: $' + 
        featureData.get('estimateTotal');
      
      if (String.isNotBlank((String)featureData.get('additionalDetails'))) {
        description += ' | Additional Details: ' + featureData.get('additionalDetails');
        opp.Extra_Enhancements__c = (String)featureData.get('additionalDetails');
      }
      
      opp.Description = description;
      
      // Map selected features to multi-select picklist
      Object selectedFeaturesObj = featureData.get('selectedFeaturesList');
      if (selectedFeaturesObj != null) {
        List<String> selectedFeatures = new List<String>();
        List<Object> featuresObjList = (List<Object>)selectedFeaturesObj;
        for (Object feature : featuresObjList) {
          selectedFeatures.add((String)feature);
        }
        if (!selectedFeatures.isEmpty()) {
          opp.Selected_Requirements__c = String.join(selectedFeatures, ';');
        }
      }
      
      // Map price estimates - remove commas and convert to Decimal
      String estimateTotalStr = ((String)featureData.get('estimateTotal')).replaceAll(',', '');
      String monthlyEstimateStr = ((String)featureData.get('monthlyEstimate')).replaceAll(',', '');
      
      // Use estimateTotal for both min and max fields (single price now)
      opp.Price_Range_Min__c = Decimal.valueOf(estimateTotalStr);
      opp.Price_Range_Max__c = Decimal.valueOf(estimateTotalStr);
      opp.Amount = Decimal.valueOf(estimateTotalStr);
      opp.Monthly_Estimate__c = Decimal.valueOf(monthlyEstimateStr);
      
      update opp;
    } catch (Exception e) {
      throw new AuraHandledException('Error updating opportunity features: ' + e.getMessage());
    }
  }

  /**
   * Uploads a backyard photo and attaches it to an Opportunity as a Content Document
   * @param opportunityId The ID of the Opportunity
   * @param fileName The name of the file
   * @param base64Data The Base64 encoded file data
   * @return String - The ID of the created ContentDocument
   */
  @AuraEnabled
  public static String uploadBackyardPhoto(String opportunityId, String fileName, String base64Data) {
    try {
      // Decode Base64 data
      Blob fileBody = EncodingUtil.base64Decode(base64Data);
      
      // Create ContentVersion and link directly to Opportunity using FirstPublishLocationId
      // This avoids ContentDocumentLink permission issues in Experience Cloud
      ContentVersion cv = new ContentVersion(
        Title = 'Photo of Backyard - ' + fileName,
        PathOnClient = fileName,
        VersionData = fileBody,
        IsMajorVersion = true,
        FirstPublishLocationId = opportunityId
      );
      
      insert cv;

      // Get the ContentDocumentId
      cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

      // Flagship flow: with the backyard photo now on the Opportunity, auto-generate the
      // three design renderings (Retreat / Entertainer / Signature) from it.
      if (opportunityId != null && String.valueOf(opportunityId).startsWith('006')) {
        try { UMBDesignGenerationService.requestDesignGeneration((Id) opportunityId); }
        catch (Exception genEx) { System.debug(LoggingLevel.WARN, 'Design auto-generation enqueue skipped: ' + genEx.getMessage()); }
      }

      return cv.ContentDocumentId;
    } catch (Exception e) {
      throw new AuraHandledException('Error uploading photo: ' + e.getMessage());
    }
  }

  // ───────────────────────────────────────────────
  //  Validate Coupon Code (Lennar Voucher)
  //  Returns the Coupon_Code__c record Id if valid, null otherwise
  // ─────────────────────────────────────────────
  @AuraEnabled
  public static String validateCouponCode(String code) {
    if (String.isBlank(code)) {
      return null;
    }
    List<Coupon_Code__c> coupons = [
      SELECT Id, Code__c, Is_Active__c, Related_To__c
      FROM Coupon_Code__c
      WHERE Code__c = :code
        AND Is_Active__c = true
        AND Related_To__c = 'Lennar'
      LIMIT 1
    ];
    return coupons.isEmpty() ? null : coupons[0].Id;
  }

  // ─────────────────────────────────────────────
  //  Apply Coupon to Opportunity
  //  Links the coupon to the Opportunity and deactivates it
  // ─────────────────────────────────────────────
  private static void applyCouponToOpportunity(Id oppId, String couponCode) {
    if (String.isBlank(couponCode)) return;
    List<Coupon_Code__c> coupons = [
      SELECT Id FROM Coupon_Code__c
      WHERE Code__c = :couponCode
      LIMIT 1
    ];
    if (!coupons.isEmpty()) {
      // Link coupon to Opportunity
      Opportunity opp = new Opportunity(Id = oppId, Coupon_Code__c = coupons[0].Id);
      update opp;
      // Mark coupon as inactive
      coupons[0].Is_Active__c = false;
      update coupons[0];
    }
  }
}