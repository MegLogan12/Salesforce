/**
 * ConsultationController
 * 
 * Apex controller for the scheduleAVisitForm LWC
 * Handles Lead creation, conversion, Opportunity creation with consultation date management
 */
public without sharing class ConsultationController {
  
  /**
   * Gets the designated owner User Id (Megan)
   * Falls back to running user if not found
   * @return Id - The User Id for record ownership
   */
  private static Id getDesignatedOwnerId() {
    //List<User> users = [SELECT Id FROM User WHERE Name LIKE '%Megan%' AND Email LIKE '%megan.logan@thelovingcompanies.com%' AND IsActive = true LIMIT 1];
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
      String leadSourceValue = String.isNotBlank(leadData.get('LeadSource')) ? leadData.get('LeadSource') : 'Web - Consultation Form';
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
    List<Lead> leads = [SELECT Id, IsConverted, SMS_Consent__c FROM Lead WHERE Id = :leadId LIMIT 1];
    
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
   * Converts a Lead to an Account/Contact and creates an Opportunity with consultation dates
   * @param leadId The ID of the Lead to convert
   * @param opportunityData Map containing timeline, budget, desiredOutcome, and consultation dates array
   * @return String - The ID of the created Opportunity
   */
  @AuraEnabled
  public static String convertLeadAndCreateOpportunity(
    String leadId,
    Map<String, Object> opportunityData
  ) {
    try {
      // Fetch Lead details including LeadSource, conversion status, and related Account/Contact
      Lead leadRecord = [SELECT Id, FirstName, LastName, Email, Phone, Street, City, State, PostalCode, LeadSource, IsConverted, ConvertedAccountId, ConvertedContactId, SMS_Consent__c
                        FROM Lead WHERE Id = :leadId LIMIT 1];

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
        // Use existing Account/Contact and update them with latest info
        accountId = leadRecord.ConvertedAccountId;
        contactId = leadRecord.ConvertedContactId;
        if (accountId != null) {
          Account acc = [SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, Phone, ODL_Household_Display_Name__c FROM Account WHERE Id = :accountId LIMIT 1];
          acc.Name = firstName + ' ' + lastName;
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
          Account acc = [SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, Phone, ODL_Household_Display_Name__c FROM Account WHERE Id = :accountId LIMIT 1];
          acc.Name = firstName + ' ' + lastName;
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
        Name = firstName + ' ' + lastName + ' - Consultation',
        AccountId = accountId,
        ContactId = contactId,
        RecordTypeId = ODLHouseholdService.getUmbOpportunityRecordTypeId(),
        StageName = 'Quote Requested',
        CloseDate = System.today().addDays(14),
        LeadSource = leadRecord.LeadSource,
        Type = 'UMB',
        OwnerId = ownerId,
        Description = 'Timeline: ' + opportunityData.get('timeline') + ' | Budget: ' + opportunityData.get('budget') + ' | ' + opportunityData.get('desiredOutcome'),
        Timeline__c = (String)opportunityData.get('timeline'),
        Budget__c = (String)opportunityData.get('budget'),
        Desired_Backyard_Outcome__c = (String)opportunityData.get('desiredOutcome')
      );
      insert newOpp;

      // Apply coupon code if provided
      String couponCode = (String)opportunityData.get('couponCode');
      if (String.isNotBlank(couponCode)) {
        applyCouponToOpportunity(newOpp.Id, couponCode);
      }

      // Create Task for Designer
      createConsultationTask(newOpp.Id);

      // Handle consultation dates if provided
      List<Object> consultationDates = (List<Object>)opportunityData.get('consultationDates');
      if (consultationDates != null && !consultationDates.isEmpty()) {
        saveConsultationDates(newOpp.Id, consultationDates);
      }

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
  private static void createConsultationTask(String opportunityId) {
    List<Task> tasksToCreate = new List<Task>();
    Id ownerId = getDesignatedOwnerId();
    
    // Task 1: Create Design - Onsite (Due in 5 business days)
    Task createDesignTask = new Task(
      Subject = 'Create Design - Onsite',
      WhatId = opportunityId,
      OwnerId = ownerId,
      Status = 'Not Started',
      Priority = 'Normal',
      ActivityDate = addBusinessDays(System.today(), 5)
    );
    tasksToCreate.add(createDesignTask);
    
    // Task 2: Upload Design into Salesforce in the Opportunity
    Task uploadDesignTask = new Task(
      Subject = 'Upload Design into Salesforce in the Opportunity - Onsite',
      WhatId = opportunityId,
      OwnerId = ownerId,
      Status = 'Not Started',
      Priority = 'Normal',
      ActivityDate = addBusinessDays(System.today(), 5)
    );
    tasksToCreate.add(uploadDesignTask);
    
    // Task 3: Schedule 60-minute on-site consult
    Task scheduleConsultTask = new Task(
      Subject = 'Schedule 60-Minutes On-Site Consult',
      WhatId = opportunityId,
      OwnerId = ownerId,
      Status = 'Not Started',
      Priority = 'Normal',
      ActivityDate = addBusinessDays(System.today(), 2)
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
    
    Database.LeadConvertResult lcr = Database.convertLead(lc);
    return lcr;
  }

  /**
   * Saves consultation dates to Opportunity fields
   * Maps up to 3 consultation date/time slots to Consultation_Date_1__c, Consultation_Date_2__c, Consultation_Date_3__c
   * Accepts UTC ISO datetime strings from the form (converted from browser's local time)
   * @param opportunityId The ID of the Opportunity
   * @param consultationDates List of consultation date/time objects with 'utcDateTime' (ISO 8601 UTC string)
   */
  private static void saveConsultationDates(String opportunityId, List<Object> consultationDates) {
    try {
      Opportunity opp = new Opportunity(Id = opportunityId);
      
      System.debug('Saving consultation dates for Opportunity: ' + opportunityId);
      System.debug('Number of consultation dates received: ' + consultationDates.size());
      
      // Map consultation dates to the three date-time fields
      for (Integer i = 0; i < consultationDates.size() && i < 3; i++) {
        // Use JSON serialize/deserialize to properly convert the map type
        Object slotObj = consultationDates.get(i);
        System.debug('Processing slot ' + i + ': ' + slotObj);
        
        // Convert to JSON string then back to proper Map type
        String slotJson = JSON.serialize(slotObj);
        Map<String, Object> slot = (Map<String, Object>)JSON.deserializeUntyped(slotJson);
        
        String utcDateTimeStr = (String)slot.get('utcDateTime');
        System.debug('UTC DateTime string: ' + utcDateTimeStr);
        
        // If utcDateTime is not present, try to construct it from date and time fields
        if (String.isBlank(utcDateTimeStr)) {
          String dateStr = (String)slot.get('date');
          String timeStr = (String)slot.get('time');
          System.debug('Date string: ' + dateStr + ', Time string: ' + timeStr);
          
          if (String.isNotBlank(dateStr) && String.isNotBlank(timeStr)) {
            // Construct ISO datetime string: YYYY-MM-DDTHH:mm:ssZ
            utcDateTimeStr = dateStr + 'T' + timeStr + ':00Z';
            System.debug('Constructed UTC DateTime string: ' + utcDateTimeStr);
          }
        }
        
        if (String.isNotBlank(utcDateTimeStr)) {
          // Parse ISO 8601 UTC string: 2026-02-02T18:30:00.000Z or 2026-02-02T18:30:00Z
          // Remove the 'Z' suffix and milliseconds, replace 'T' with space
          // Format needed for DateTime.valueOfGmt: 'yyyy-MM-dd HH:mm:ss'
          String cleanedDateTime = utcDateTimeStr
            .replace('T', ' ')
            .replace('Z', '')
            .substringBefore('.');
          
          System.debug('Cleaned DateTime for parsing: ' + cleanedDateTime);
          
          // valueOfGmt interprets the string as GMT/UTC time
          DateTime consultationDateTime = DateTime.valueOfGmt(cleanedDateTime);
          
          System.debug('Created DateTime (stored as GMT): ' + consultationDateTime);
          System.debug('DateTime will display in EST as: ' + consultationDateTime.format('yyyy-MM-dd hh:mm a z', 'America/New_York'));
          
          if (i == 0) {
            opp.Consultation_Date_1__c = consultationDateTime;
          } else if (i == 1) {
            opp.Consultation_Date_2__c = consultationDateTime;
          } else if (i == 2) {
            opp.Consultation_Date_3__c = consultationDateTime;
          }
        }
      }
      
      update opp;
      System.debug('Opportunity updated successfully with consultation dates');
    } catch (Exception e) {
      // Log error but don't fail the main process
      System.debug('Error saving consultation dates: ' + e.getMessage());
      System.debug('Stack trace: ' + e.getStackTraceString());
    }
  }

  /**
   * Updates an existing Opportunity with form data (when going back/forth in form)
   * @param opportunityId The ID of the Opportunity to update
   * @param opportunityData Map containing timeline, budget, desiredOutcome, and consultation dates array
   * @return String - The ID of the updated Opportunity
   */
  @AuraEnabled
  public static String updateOpportunity(
    String opportunityId,
    Map<String, Object> opportunityData
  ) {
    try {
      List<Opportunity> opps = [SELECT Id, Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
      
      if (opps.isEmpty()) {
        throw new AuraHandledException('Opportunity not found with ID: ' + opportunityId);
      }
      
      Opportunity opp = opps[0];
      
      opp.Description = 'Timeline: ' + opportunityData.get('timeline') + ' | Budget: ' + opportunityData.get('budget') + ' | ' + opportunityData.get('desiredOutcome');
      opp.Timeline__c = (String)opportunityData.get('timeline');
      opp.Budget__c = (String)opportunityData.get('budget');
      opp.Desired_Backyard_Outcome__c = (String)opportunityData.get('desiredOutcome');
      
      // Apply coupon code if provided
      String couponCode = (String)opportunityData.get('couponCode');
      if (String.isNotBlank(couponCode)) {
        applyCouponToOpportunity(opp.Id, couponCode);
      }

      update opp;
      
      // Handle consultation dates if provided
      List<Object> consultationDates = (List<Object>)opportunityData.get('consultationDates');
      if (consultationDates != null && !consultationDates.isEmpty()) {
        saveConsultationDates(opportunityId, consultationDates);
      }
      
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