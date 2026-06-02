public with sharing class OpportunityQuotePDFController {
    
    private Opportunity opp;
    
    public OpportunityQuotePDFController(ApexPages.StandardController stdController) {
        // Query the Opportunity with all related fields
        Id oppId = stdController.getId();
        this.opp = [
            SELECT Id, Name, Opportunity_Number__c, CloseDate, 
                   Owner.Name, Account.Name, Account.BillingStreet, 
                   Account.BillingCity, Account.BillingState, 
                   Account.BillingPostalCode,
                   Timeline__c, Budget__c, Desired_Backyard_Outcome__c,
                   Selected_Requirements__c, Extra_Enhancements__c,
                   Price_Range_Min__c, Price_Range_Max__c, 
                   Monthly_Estimate__c, Financing_Option__c,
                   (SELECT Contact.Email, Contact.Phone, Contact.Name FROM OpportunityContactRoles 
                    WHERE IsPrimary = true LIMIT 1)
            FROM Opportunity 
            WHERE Id = :oppId
            LIMIT 1
        ];
    }
    
    public String getPrimaryContactEmail() {
        if (!opp.OpportunityContactRoles.isEmpty() && opp.OpportunityContactRoles[0].Contact != null) {
            return opp.OpportunityContactRoles[0].Contact.Email;
        }
        return '';
    }
    
    public String getPrimaryContactPhone() {
        if (!opp.OpportunityContactRoles.isEmpty() && opp.OpportunityContactRoles[0].Contact != null) {
            return opp.OpportunityContactRoles[0].Contact.Phone;
        }
        return '';
    }
    
    public String getFormattedFeatures() {
        if (String.isBlank(opp.Selected_Requirements__c)) {
            return '<p>No features selected</p>';
        }
        
        List<String> features = opp.Selected_Requirements__c.split(';');
        String html = '<ul style="margin-left: 20px;">';
        for (String feature : features) {
            html += '<li>' + feature.trim() + '</li>';
        }
        html += '</ul>';
        return html;
    }
    
    /**
     * Generate PDF and attach to Opportunity
     * Called from custom button or Lightning action
     */
    @AuraEnabled
    public static String generateAndAttachQuotePDF(Id opportunityId) {
        try {
            // Generate the PDF using the Visualforce page (dynamic reference)
            PageReference pdfPage = new PageReference('/apex/OpportunityQuotePDF');
            pdfPage.getParameters().put('id', opportunityId);
            
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }
            
            // Query Opportunity to get the name for the file
            Opportunity opp = [SELECT Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            String fileName = 'Quote_' + opp.Name.replaceAll('[^a-zA-Z0-9]', '_') + '_' + 
                            String.valueOf(Date.today()).replaceAll('[^0-9]', '') + '.pdf';
            
            // Create ContentVersion (this creates the file)
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = opportunityId;
            cv.IsMajorVersion = true;
            insert cv;
            
            // Get the ContentDocumentId
            ContentVersion insertedCV = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                LIMIT 1
            ];
            
            return insertedCV.ContentDocumentId;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error generating PDF: ' + e.getMessage());
        }
    }
}