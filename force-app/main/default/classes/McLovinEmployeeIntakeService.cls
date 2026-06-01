public with sharing class McLovinEmployeeIntakeService {

    public class RecordCandidate implements Comparable {
        @AuraEnabled public String recordId;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String label;
        @AuraEnabled public Integer score;
        @AuraEnabled public String reason;

        public Integer compareTo(Object otherObj) {
            RecordCandidate otherCandidate = (RecordCandidate) otherObj;
            Integer left = score == null ? 0 : score;
            Integer right = otherCandidate == null || otherCandidate.score == null ? 0 : otherCandidate.score;
            if (left == right) return 0;
            return left > right ? -1 : 1;
        }
    }

    public class MissingField {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String reason;
        @AuraEnabled public String value;
    }

    public class AnalysisResult {
        @AuraEnabled public Id requestId;
        @AuraEnabled public String status;
        @AuraEnabled public String sourceType;
        @AuraEnabled public String classification;
        @AuraEnabled public String suggestedPrimaryObject;
        @AuraEnabled public String suggestedAction;
        @AuraEnabled public String suggestedRecordName;
        @AuraEnabled public Map<String, Object> extractedData;
        @AuraEnabled public List<RecordCandidate> candidates;
        @AuraEnabled public List<MissingField> missingFields;
        @AuraEnabled public Integer linkedFileCount;
        @AuraEnabled public String combinedPreview;
    }

    public class SaveResult {
        @AuraEnabled public Id requestId;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String status;
        @AuraEnabled public Id primaryRecordId;
        @AuraEnabled public String primaryObjectApiName;
        @AuraEnabled public String primaryRecordName;
        @AuraEnabled public List<Id> relatedRecordIds;
        @AuraEnabled public String message;
    }

    private class ScopeItemMatch {
        String catalogId;
        String catalogName;
        String category;
        Integer score;
    }

    private static final List<String> INTERNAL_DIVISION_PREFIXES = new List<String>{
        'the loving group',
        'materials & services - tlg',
        'tlg turf'
    };

    private static Map<String, Id> queueCache = new Map<String, Id>();
    private static Id customerSuccessCaseRtId;

    public static Id startDraft(String sourceType, String intakeText) {
        mcLOVIN_Intake_Request__c draft = new mcLOVIN_Intake_Request__c(
            Source_Type__c = String.isBlank(sourceType) ? 'Text' : sourceType,
            Intake_Text__c = intakeText,
            Status__c = 'Draft',
            Requested_By__c = UserInfo.getUserId()
        );
        insert draft;
        return draft.Id;
    }

    public static AnalysisResult analyze(Id requestId, String sourceType, String intakeText) {
        mcLOVIN_Intake_Request__c req = getOrCreateRequest(requestId, sourceType, intakeText);
        req.Source_Type__c = String.isBlank(sourceType) ? req.Source_Type__c : sourceType;
        req.Intake_Text__c = intakeText;

        List<ContentVersion> versions = getLinkedVersions(req.Id);
        String combinedText = buildCombinedText(intakeText, versions);
        Map<String, Object> extracted = extractData(combinedText, req.Source_Type__c);
        String classification = (String) extracted.get('classification');
        List<RecordCandidate> candidates = findCandidates(extracted, classification);

        Map<String, Object> matchSummary = new Map<String, Object>{
            'matchedAccountId' => findFirstCandidateId(candidates, 'Account'),
            'matchedContactId' => findFirstCandidateId(candidates, 'Contact'),
            'matchedLeadId' => findFirstCandidateId(candidates, 'Lead'),
            'matchedOpportunityId' => findFirstCandidateId(candidates, 'Opportunity'),
            'matchedCaseId' => findFirstCandidateId(candidates, 'Case')
        };

        String primaryObject = determinePrimaryObject(classification);
        String suggestedAction = determineSuggestedAction(primaryObject, matchSummary);
        String suggestedName = determineSuggestedRecordName(extracted, classification);
        List<MissingField> missingFields = determineMissingFields(primaryObject, classification, extracted, suggestedAction);

        req.Classification__c = classification;
        req.Suggested_Primary_Object__c = primaryObject;
        req.Suggested_Action__c = suggestedAction;
        req.Suggested_Record_Name__c = suggestedName;
        req.Extracted_JSON__c = JSON.serialize(extracted);
        req.Match_JSON__c = JSON.serialize(new Map<String, Object>{
            'summary' => matchSummary,
            'candidates' => candidates
        });
        req.Missing_Fields_JSON__c = JSON.serialize(missingFields);
        req.Status__c = missingFields.isEmpty() ? 'Ready To Save' : 'Needs Review';
        update req;

        AnalysisResult result = new AnalysisResult();
        result.requestId = req.Id;
        result.status = req.Status__c;
        result.sourceType = req.Source_Type__c;
        result.classification = classification;
        result.suggestedPrimaryObject = primaryObject;
        result.suggestedAction = suggestedAction;
        result.suggestedRecordName = suggestedName;
        result.extractedData = extracted;
        result.candidates = candidates;
        result.missingFields = missingFields;
        result.linkedFileCount = versions.size();
        result.combinedPreview = truncate(combinedText, 5000);
        return result;
    }

    public static SaveResult save(Id requestId, String overridesJson, Boolean confirmed) {
        if (confirmed != true) {
            throw new AuraHandledException('Save requires explicit confirmation.');
        }

        mcLOVIN_Intake_Request__c req = [
            SELECT Id, Source_Type__c, Status__c, Classification__c, Suggested_Primary_Object__c,
                   Suggested_Action__c, Suggested_Record_Name__c, Extracted_JSON__c,
                   Match_JSON__c, Missing_Fields_JSON__c
            FROM mcLOVIN_Intake_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];

        Map<String, Object> extracted = stringToMap(req.Extracted_JSON__c);
        Map<String, Object> overrides = stringToMap(overridesJson);
        Map<String, Object> matchJson = stringToMap(req.Match_JSON__c);
        Map<String, Object> matchSummary = matchJson.containsKey('summary')
            ? (Map<String, Object>) matchJson.get('summary')
            : new Map<String, Object>();

        mergeMaps(extracted, overrides);

        Id accountId;
        Id contactId;
        Id primaryRecordId;
        String primaryObject = String.isBlank(req.Suggested_Primary_Object__c)
            ? determinePrimaryObject(req.Classification__c)
            : req.Suggested_Primary_Object__c;
        if ('Builder Scope'.equals(req.Classification__c)) {
            primaryObject = 'Account';
        }
        String primaryRecordName;
        List<Id> relatedRecordIds = new List<Id>();

        if (primaryObject == 'Lead') {
            Lead leadRecord = buildLead(extracted, req.Classification__c);
            insert leadRecord;
            primaryRecordId = leadRecord.Id;
            primaryRecordName = leadRecord.FirstName + ' ' + leadRecord.LastName;
        } else {
            accountId = resolveOrCreateAccount(extracted, req.Classification__c, req.Suggested_Action__c, matchSummary);
            if (accountId != null) {
                relatedRecordIds.add(accountId);
            }
            contactId = resolveOrCreateContact(extracted, accountId, matchSummary);
            if (contactId != null) {
                relatedRecordIds.add(contactId);
            }

            if (primaryObject == 'Account') {
                primaryRecordId = accountId;
                primaryRecordName = [
                    SELECT Name
                    FROM Account
                    WHERE Id = :accountId
                    LIMIT 1
                ].Name;
            } else if (primaryObject == 'Case') {
                Case caseRecord = buildCase(extracted, accountId, contactId);
                insert caseRecord;
                primaryRecordId = caseRecord.Id;
                primaryRecordName = caseRecord.Subject;
            } else {
                Opportunity opp = buildOpportunity(extracted, accountId, contactId, req.Classification__c);
                insert opp;
                primaryRecordId = opp.Id;
                primaryRecordName = opp.Name;
                relatedRecordIds.add(opp.Id);
            }
        }

        Integer createdScopeItemCount = 0;
        Id workOrderId = castId(extracted.get('workOrderId'));
        if (workOrderId != null) {
            createdScopeItemCount = createWorkOrderLineItems(workOrderId, extracted, relatedRecordIds);
        }

        linkUploadedFiles(req.Id, primaryRecordId);

        req.Created_Record_Id__c = primaryRecordId;
        req.Status__c = 'Saved';
        update req;

        SaveResult result = new SaveResult();
        result.requestId = req.Id;
        result.success = true;
        result.status = 'Saved';
        result.primaryRecordId = primaryRecordId;
        result.primaryObjectApiName = primaryObject;
        result.primaryRecordName = primaryRecordName;
        result.relatedRecordIds = relatedRecordIds;
        result.message = buildSaveMessage(createdScopeItemCount, workOrderId, extracted);
        return result;
    }

    private static mcLOVIN_Intake_Request__c getOrCreateRequest(Id requestId, String sourceType, String intakeText) {
        if (requestId != null) {
            return [
                SELECT Id, Source_Type__c, Intake_Text__c, Status__c
                FROM mcLOVIN_Intake_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
        }
        Id newId = startDraft(sourceType, intakeText);
        return [
            SELECT Id, Source_Type__c, Intake_Text__c, Status__c
            FROM mcLOVIN_Intake_Request__c
            WHERE Id = :newId
            LIMIT 1
        ];
    }

    private static List<ContentVersion> getLinkedVersions(Id requestId) {
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :requestId
        ]) {
            docIds.add(link.ContentDocumentId);
        }
        if (docIds.isEmpty()) {
            return new List<ContentVersion>();
        }
        return [
            SELECT Id, ContentDocumentId, Title, FileType, FileExtension, PathOnClient, ContentSize, TextPreview, VersionData
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId IN :docIds
            ORDER BY LastModifiedDate DESC
        ];
    }

    private static String buildCombinedText(String intakeText, List<ContentVersion> versions) {
        List<String> chunks = new List<String>();
        if (String.isNotBlank(intakeText)) {
            chunks.add(intakeText);
        }
        for (ContentVersion version : versions) {
            String extractedText = extractVersionText(version);
            if (String.isNotBlank(extractedText)) {
                chunks.add(extractedText);
            }
        }
        return String.join(chunks, '\n\n');
    }

    private static String extractVersionText(ContentVersion version) {
        if (version == null) return null;
        List<String> parts = new List<String>();
        String label = 'FILE: ' + version.Title + ' (' + version.FileType + ')';
        if (String.isNotBlank(version.PathOnClient)) {
            label += ' [' + version.PathOnClient + ']';
        }
        if (version.ContentSize != null) {
            label += ' ' + String.valueOf(version.ContentSize) + ' bytes';
        }
        parts.add(label);

        if (String.isNotBlank(version.TextPreview)) {
            parts.add(version.TextPreview);
            return String.join(parts, '\n');
        }

        if (isPlainTextFile(version.FileExtension) && version.VersionData != null) {
            try {
                parts.add(truncate(version.VersionData.toString(), 12000));
                return String.join(parts, '\n');
            } catch (Exception ignored) {
            }
        }

        parts.add('[Inline text extraction was limited for this attachment. CSV, TSV, TXT, XML, and JSON files are handled better than binary office files here. Paste exported text if you need full row-level review.]');
        return String.join(parts, '\n');
    }

    private static Boolean isPlainTextFile(String extension) {
        if (String.isBlank(extension)) return false;
        String lower = extension.toLowerCase();
        return lower == 'csv' || lower == 'tsv' || lower == 'txt' || lower == 'log' || lower == 'json' || lower == 'xml' || lower == 'html' || lower == 'htm';
    }

    private static Map<String, Object> extractData(String combinedText, String sourceType) {
        Map<String, Object> data = new Map<String, Object>();
        String normalized = combinedText == null ? '' : combinedText;
        String lower = normalized.toLowerCase();
        String division = matchGroup(normalized, '(?im)(?:Division)\\s*[:\\-]\\s*([^\\n]+)');
        String customer = matchGroup(normalized, '(?im)(?:Customer|Builder Customer)\\s*[:\\-]\\s*([^\\n]+)');
        data.put('sourceType', sourceType);
        data.put('combinedText', truncate(normalized, 12000));

        String email = matchGroup(normalized, '(?i)([A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,})');
        String phone = matchGroup(normalized, '(?i)(\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4})');
        String address = matchGroup(normalized, '(?im)(\\d{2,6}\\s+[A-Za-z0-9 .#-]+(?:Street|St|Road|Rd|Lane|Ln|Drive|Dr|Court|Ct|Way|Boulevard|Blvd|Avenue|Ave)\\b[^\\n]*)');
        String cityStateZip = matchGroup(normalized, '(?im)([A-Za-z .-]+,\\s*[A-Z]{2}\\s+\\d{5}(?:-\\d{4})?)');
        String lot = matchGroup(normalized, '(?i)Lot\\s*(?:#|No\\.?|Number)?\\s*([A-Za-z0-9-]+)');
        String community = matchGroup(normalized, '(?i)(?:Community|Subdivision)\\s*[:\\-]\\s*([^\\n]+)');
        String umbNumber = matchGroup(normalized, '(?i)\\bUMB\\s*[:#-]?\\s*([A-Za-z0-9-]+)');
        String voucher = matchGroup(normalized, '(?i)(?:Voucher|Coupon)\\s*[:#-]?\\s*([A-Za-z0-9-]+)');
        String purchaseOrderNumber = matchGroup(normalized, '(?im)^(?:PO|P\\.O\\.|Purchase Order)[ \\t]*(?:Number|No\\.?|#)?[ \\t]*[:#-]?[ \\t]*([^\\n]+)');
        String routingLane = matchGroup(normalized, '(?im)(?:Routing Lane)\\s*[:\\-]\\s*([^\\n]+)');
        String caseType = matchGroup(normalized, '(?im)(?:Case Type)\\s*[:\\-]\\s*([^\\n]+)');
        String requestType = matchGroup(normalized, '(?im)(?:Request Type)\\s*[:\\-]\\s*([^\\n]+)');
        String company = extractCompany(normalized);
        String jobDescription = extractJobDescription(normalized);
        if (String.isBlank(company) && String.isNotBlank(customer)) {
            company = customer;
        }
        if (String.isBlank(community)) {
            community = deriveCommunityName(company);
        }
        String normalizedBuilderAccountName = normalizeBuilderAccountName(company);
        String firstName = null;
        String lastName = null;

        if (String.isNotBlank(email) && email.contains('@')) {
            List<String> emailParts = email.substringBefore('@').replace('_', '.').split('\\.');
            if (emailParts.size() >= 2) {
                firstName = capitalizeWord(emailParts[0]);
                lastName = capitalizeWord(emailParts[emailParts.size() - 1]);
            }
        }

        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            String contactLine = matchGroup(normalized, '(?im)(?:Contact|From|Prepared By|Requested By)\\s*[:\\-]\\s*([A-Z][A-Za-z-]+)\\s+([A-Z][A-Za-z-]+)');
            if (String.isNotBlank(contactLine)) {
                List<String> parts = contactLine.split('\\s+');
                if (parts.size() >= 2) {
                    firstName = parts[0];
                    lastName = parts[1];
                }
            }
        }

        Boolean explicitVoucher = lower.contains('voucher') || lower.contains('coupon');
        Boolean explicitUmb = Pattern.compile('(?i)\\bumb\\b').matcher(normalized).find();
        Boolean serviceSignals =
            lower.contains('warranty') ||
            lower.contains('service issue') ||
            lower.contains('repair') ||
            lower.contains('customer care') ||
            lower.contains('reschedule') ||
            lower.contains('scheduling') ||
            lower.contains('aqua repair') ||
            String.isNotBlank(routingLane) ||
            String.isNotBlank(caseType) ||
            String.isNotBlank(requestType);
        Boolean builderSignals =
            lower.contains('scope of work') ||
            lower.contains('builder services') ||
            lower.contains('community') ||
            lower.contains('lot ') ||
            String.isNotBlank(community) ||
            String.isNotBlank(normalizedBuilderAccountName) ||
            isInternalDivisionName(division);

        String classification = 'General Intake';
        if (serviceSignals) {
            classification = 'Service Case';
        } else if ('Spreadsheet'.equalsIgnoreCase(sourceType) || looksLikeSpreadsheet(normalized)) {
            classification = 'Spreadsheet Batch';
        } else if (builderSignals) {
            classification = 'Builder Scope';
        } else if (explicitVoucher) {
            classification = 'Lennar Voucher';
        } else if (explicitUmb) {
            classification = 'UMB Intake';
        } else if (String.isNotBlank(address) || String.isNotBlank(cityStateZip)) {
            classification = 'Homeowner Intake';
        }

        data.put('classification', classification);
        data.put('email', email);
        data.put('phone', phone);
        data.put('streetAddress', address);
        data.put('cityStateZip', cityStateZip);
        data.put('divisionName', cleanExtractedValue(division));
        data.put('customerName', cleanExtractedValue(customer));
        data.put('companyName', company);
        data.put('normalizedBuilderAccountName', normalizedBuilderAccountName);
        data.put('firstName', firstName);
        data.put('lastName', lastName);
        data.put('lotNumber', lot);
        data.put('communityName', community);
        data.put('umbNumber', umbNumber);
        data.put('voucherCode', voucher);
        data.put('purchaseOrderNumber', purchaseOrderNumber);
        data.put('routingLane', cleanExtractedValue(routingLane));
        data.put('caseType', cleanExtractedValue(caseType));
        data.put('requestType', cleanExtractedValue(requestType));
        data.put('jobDescription', jobDescription);
        data.put('opportunityName', buildOpportunityName(company, firstName, lastName, classification));
        data.put('householdName', buildHouseholdName(lastName, address, cityStateZip));
        data.put('parsedScopeItems', parseScopeItems(normalized, jobDescription));

        if ('Spreadsheet Batch'.equals(classification)) {
            data.put('batchRowCount', estimateRowCount(normalized));
        }

        return data;
    }

    private static List<RecordCandidate> findCandidates(Map<String, Object> extracted, String classification) {
        List<RecordCandidate> candidates = new List<RecordCandidate>();
        String companyName = stringValue(extracted.get('companyName'));
        String normalizedBuilderAccountName = stringValue(extracted.get('normalizedBuilderAccountName'));
        String customerName = stringValue(extracted.get('customerName'));
        String communityName = stringValue(extracted.get('communityName'));
        String email = stringValue(extracted.get('email'));
        String phone = normalizePhone(stringValue(extracted.get('phone')));
        String address = stringValue(extracted.get('streetAddress'));
        String firstName = stringValue(extracted.get('firstName'));
        String lastName = stringValue(extracted.get('lastName'));

        if (String.isNotBlank(communityName) && isBuilderClassification(classification)) {
            for (Community__c communityRecord : [
                SELECT Id, Name, Builder_Account__c, Builder_Account__r.Name
                FROM Community__c
                WHERE Name = :communityName
                AND Builder_Account__c != null
                ORDER BY LastModifiedDate DESC
                LIMIT 3
            ]) {
                candidates.add(candidate(
                    communityRecord.Builder_Account__c,
                    'Account',
                    communityRecord.Builder_Account__r.Name,
                    100,
                    'Exact community to builder account match'
                ));
            }
        }

        List<String> accountNamesToSearch = new List<String>();
        if (String.isNotBlank(normalizedBuilderAccountName)) accountNamesToSearch.add(normalizedBuilderAccountName);
        if (String.isNotBlank(customerName) && !accountNamesToSearch.contains(customerName)) accountNamesToSearch.add(customerName);
        if (String.isNotBlank(companyName) && !accountNamesToSearch.contains(companyName)) accountNamesToSearch.add(companyName);

        for (String accountSearchName : accountNamesToSearch) {
            if (String.isBlank(accountSearchName) || isInternalDivisionName(accountSearchName)) continue;
            List<Account> foundAccounts;
            if (isBuilderClassification(classification)) {
                foundAccounts = [
                    SELECT Id, Name, RecordType.DeveloperName, BillingStreet
                    FROM Account
                    WHERE RecordType.DeveloperName IN ('Builder_Market', 'Builder_Parent')
                    AND Name LIKE :('%' + accountSearchName + '%')
                    ORDER BY LastModifiedDate DESC
                    LIMIT 5
                ];
            } else {
                foundAccounts = [
                    SELECT Id, Name, RecordType.DeveloperName, BillingStreet
                    FROM Account
                    WHERE Name LIKE :('%' + accountSearchName + '%')
                    ORDER BY LastModifiedDate DESC
                    LIMIT 5
                ];
            }

            for (Account acc : foundAccounts) {
                if (isInternalDivisionName(acc.Name)) continue;
                Integer score = 70;
                if (equalsIgnoreCase(acc.Name, accountSearchName)) score = 95;
                else if (equalsIgnoreCase(acc.Name, normalizedBuilderAccountName)) score = 98;
                candidates.add(candidate(acc.Id, 'Account', acc.Name, score, 'Similar account name'));
            }
        }

        if (String.isNotBlank(companyName) && !isInternalDivisionName(companyName)) {
            for (Account acc : [
                SELECT Id, Name, RecordType.DeveloperName, BillingStreet
                FROM Account
                WHERE Name LIKE :('%' + companyName + '%')
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ]) {
                if (isInternalDivisionName(acc.Name)) continue;
                Integer score = 70;
                if (equalsIgnoreCase(acc.Name, companyName)) score = 95;
                candidates.add(candidate(acc.Id, 'Account', acc.Name, score, 'Similar account name'));
            }
        }

        if (String.isNotBlank(email)) {
            for (Contact con : [
                SELECT Id, FirstName, LastName, Email, Account.Name
                FROM Contact
                WHERE Email = :email
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ]) {
                candidates.add(candidate(con.Id, 'Contact', con.FirstName + ' ' + con.LastName, 98, 'Exact email match'));
            }
            for (Lead leadRec : [
                SELECT Id, FirstName, LastName, Company, Email
                FROM Lead
                WHERE Email = :email
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ]) {
                candidates.add(candidate(leadRec.Id, 'Lead', leadRec.FirstName + ' ' + leadRec.LastName, 96, 'Exact lead email match'));
            }
        }

        if (String.isNotBlank(address)) {
            for (Account accByAddress : [
                SELECT Id, Name, BillingStreet
                FROM Account
                WHERE BillingStreet LIKE :('%' + address.substring(0, Math.min(20, address.length())) + '%')
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ]) {
                candidates.add(candidate(accByAddress.Id, 'Account', accByAddress.Name, 82, 'Address similarity'));
            }
        }

        if (String.isNotBlank(firstName) && String.isNotBlank(lastName)) {
            for (Contact namedCon : [
                SELECT Id, FirstName, LastName, Account.Name
                FROM Contact
                WHERE FirstName = :firstName AND LastName = :lastName
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ]) {
                candidates.add(candidate(namedCon.Id, 'Contact', namedCon.FirstName + ' ' + namedCon.LastName, 78, 'Name similarity'));
            }
        }

        if ('Service Case'.equals(classification) && String.isNotBlank(email)) {
            for (Case c : [
                SELECT Id, Subject
                FROM Case
                WHERE Contact.Email = :email
                ORDER BY LastModifiedDate DESC
                LIMIT 5
            ]) {
                candidates.add(candidate(c.Id, 'Case', c.Subject, 75, 'Prior case for contact'));
            }
        }

        candidates.sort();
        return deDupeCandidates(candidates);
    }

    private static String determinePrimaryObject(String classification) {
        if ('Service Case'.equals(classification)) return 'Case';
        if ('Builder Scope'.equals(classification)) return 'Account';
        if ('Spreadsheet Batch'.equals(classification)) return 'Account';
        if ('Homeowner Intake'.equals(classification)) return 'Opportunity';
        if ('Lennar Voucher'.equals(classification)) return 'Opportunity';
        if ('UMB Intake'.equals(classification)) return 'Opportunity';
        return 'Lead';
    }

    private static String determineSuggestedAction(String primaryObject, Map<String, Object> matchSummary) {
        if (matchSummary.get('matchedAccountId') != null || matchSummary.get('matchedLeadId') != null || matchSummary.get('matchedCaseId') != null) {
            return 'Use Existing And Add New ' + primaryObject;
        }
        return 'Create New ' + primaryObject;
    }

    private static String determineSuggestedRecordName(Map<String, Object> extracted, String classification) {
        if ('Service Case'.equals(classification)) {
            return stringValue(extracted.get('companyName')) + ' Service Request';
        }
        if ('Homeowner Intake'.equals(classification)) {
            return stringValue(extracted.get('householdName'));
        }
        return String.isNotBlank(stringValue(extracted.get('companyName')))
            ? stringValue(extracted.get('companyName'))
            : stringValue(extracted.get('opportunityName'));
    }

    private static List<MissingField> determineMissingFields(String primaryObject, String classification, Map<String, Object> extracted, String suggestedAction) {
        List<MissingField> fields = new List<MissingField>();
        if ('Lead'.equals(primaryObject)) {
            addIfBlank(fields, 'lastName', 'Last Name', 'Lead creation requires a last name.', extracted);
            addIfBlank(fields, 'companyName', 'Company or Household Name', 'Lead creation requires a company/household value.', extracted);
        } else {
            if ('Homeowner Intake'.equals(classification)) {
                if (String.isBlank(stringValue(extracted.get('householdName')))) {
                    fields.add(missing('householdName', 'Household Name', 'Need a household name to create the homeowner account.'));
                }
                addIfBlank(fields, 'streetAddress', 'Street Address', 'Need the homeowner property address so the household lands on the right property path.', extracted);
            } else {
                addIfBlank(fields, 'companyName', 'Account Name', 'Need an account name before save.', extracted);
            }
            if (isBuilderClassification(classification) || 'Spreadsheet Batch'.equals(classification)) {
                addIfBlank(fields, 'communityName', 'Community', 'Need the community so mcLOVIN can tie this to the right builder path.', extracted);
                addIfBlank(fields, 'lotNumber', 'Lot Number', 'Need the lot number to keep the intake tied to the right property chain.', extracted);
            }
            if ('Builder Scope'.equals(classification)) {
                addIfBlank(fields, 'purchaseOrderNumber', 'PO Number', 'Need the PO number if this upload is a purchase order or builder scope package.', extracted);
            }
            if ('Lennar Voucher'.equals(classification)) {
                addIfBlank(fields, 'voucherCode', 'Voucher Code', 'Need the voucher code before routing this intake into the Lennar voucher path.', extracted);
            }
            if ('UMB Intake'.equals(classification)) {
                addIfBlank(fields, 'umbNumber', 'UMB Number', 'Need the UMB number before routing this intake into the UMB path.', extracted);
            }
            if ('Case'.equals(primaryObject)) {
                addIfBlank(fields, 'caseSubject', 'Case Subject', 'Need a case subject before save.', extracted);
                addIfBlank(fields, 'routingLane', 'Routing Lane', 'Need the routing lane so mcLOVIN can send the case to the right queue or team.', extracted);
            } else if ('Account'.equals(primaryObject)) {
                // Account-only intake does not need an opportunity name.
            } else {
                addIfBlank(fields, 'opportunityName', 'Opportunity Name', 'Need an opportunity name before save.', extracted);
            }
            if (!parsedScopeItemsFromExtracted(extracted).isEmpty() && String.isBlank(stringValue(extracted.get('workOrderId')))) {
                fields.add(missing('workOrderId', 'Existing Work Order Id', 'Optional but smart: add a Work Order Id if these parsed scope lines should become real Work Order line items.'));
            }
        }
        return fields;
    }

    private static Id resolveOrCreateAccount(Map<String, Object> extracted, String classification, String suggestedAction, Map<String, Object> matchSummary) {
        Id matchedAccountId = castId(matchSummary.get('matchedAccountId'));
        if (matchedAccountId != null && String.valueOf(suggestedAction).startsWith('Use Existing')) {
            return matchedAccountId;
        }
        if ('Service Case'.equals(classification) && matchedAccountId == null) {
            return null;
        }

        Account accountRecord = new Account();
        String accountName;
        if ('Homeowner Intake'.equals(classification)) {
            accountRecord.RecordTypeId = RecordTypeHelper.getAccountRT('Home_Owner');
            accountName = String.isNotBlank(stringValue(extracted.get('householdName')))
                ? stringValue(extracted.get('householdName'))
                : 'New Household';
            accountRecord.Type = 'Home Owner';
        } else if ('Builder Scope'.equals(classification) || 'UMB Intake'.equals(classification) || 'Lennar Voucher'.equals(classification)) {
            accountRecord.RecordTypeId = RecordTypeHelper.getAccountRT('Builder_Parent');
            accountName = String.isNotBlank(stringValue(extracted.get('normalizedBuilderAccountName')))
                ? stringValue(extracted.get('normalizedBuilderAccountName'))
                : String.isNotBlank(stringValue(extracted.get('customerName')))
                    ? stringValue(extracted.get('customerName'))
                    : stringValue(extracted.get('companyName'));
            accountRecord.Type = 'Builder Parent';
        } else {
            accountRecord.RecordTypeId = RecordTypeHelper.getAccountRT('Business_Account');
            accountName = String.isNotBlank(stringValue(extracted.get('companyName')))
                ? stringValue(extracted.get('companyName'))
                : 'New Business Account';
            accountRecord.Type = 'Business Account';
        }

        accountRecord.Name = accountName;
        if (String.isNotBlank(stringValue(extracted.get('streetAddress')))) {
            accountRecord.BillingStreet = stringValue(extracted.get('streetAddress'));
        }
        applyCityStateZip(accountRecord, stringValue(extracted.get('cityStateZip')));
        if (String.isNotBlank(stringValue(extracted.get('phone')))) {
            accountRecord.Phone = stringValue(extracted.get('phone'));
        }
        insert accountRecord;
        return accountRecord.Id;
    }

    private static Id resolveOrCreateContact(Map<String, Object> extracted, Id accountId, Map<String, Object> matchSummary) {
        Id matchedContactId = castId(matchSummary.get('matchedContactId'));
        if (matchedContactId != null) {
            return matchedContactId;
        }
        String firstName = stringValue(extracted.get('firstName'));
        String lastName = stringValue(extracted.get('lastName'));
        String email = stringValue(extracted.get('email'));
        String phone = stringValue(extracted.get('phone'));
        if (String.isBlank(lastName) && String.isBlank(email) && String.isBlank(phone)) {
            return null;
        }
        Contact con = new Contact(
            AccountId = accountId,
            FirstName = firstName,
            LastName = String.isBlank(lastName) ? 'Unknown' : lastName,
            Email = email,
            Phone = phone
        );
        if (String.isNotBlank(stringValue(extracted.get('streetAddress')))) {
            con.MailingStreet = stringValue(extracted.get('streetAddress'));
        }
        applyCityStateZip(con, stringValue(extracted.get('cityStateZip')));
        insert con;
        return con.Id;
    }

    private static Lead buildLead(Map<String, Object> extracted, String classification) {
        String firstName = stringValue(extracted.get('firstName'));
        String lastName = stringValue(extracted.get('lastName'));
        String companyName = stringValue(extracted.get('companyName'));
        if ('Homeowner Intake'.equals(classification) && String.isBlank(companyName)) {
            companyName = stringValue(extracted.get('householdName'));
        }
        Lead leadRecord = new Lead(
            FirstName = firstName,
            LastName = String.isBlank(lastName) ? 'Unknown' : lastName,
            Company = String.isBlank(companyName) ? 'mcLOVIN Intake' : companyName,
            Email = stringValue(extracted.get('email')),
            Phone = stringValue(extracted.get('phone')),
            Status = 'New'
        );
        if ('Homeowner Intake'.equals(classification)) {
            leadRecord.Lead_Type__c = 'Homeowner';
        }
        if (String.isNotBlank(stringValue(extracted.get('streetAddress')))) {
            leadRecord.Street = stringValue(extracted.get('streetAddress'));
        }
        applyCityStateZip(leadRecord, stringValue(extracted.get('cityStateZip')));
        return leadRecord;
    }

    private static Opportunity buildOpportunity(Map<String, Object> extracted, Id accountId, Id contactId, String classification) {
        Opportunity opp = new Opportunity(
            AccountId = accountId,
            ContactId = contactId,
            Name = String.isBlank(stringValue(extracted.get('opportunityName')))
                ? (String.isBlank(stringValue(extracted.get('companyName'))) ? 'mcLOVIN Intake Opportunity' : stringValue(extracted.get('companyName')) + ' - Intake')
                : stringValue(extracted.get('opportunityName')),
            StageName = 'Quote Requested',
            CloseDate = Date.today().addDays(30),
            Description = buildDescription(extracted)
        );
        if ('UMB Intake'.equals(classification)) {
            Id umbRt = RecordTypeHelper.getOpportunityRT('UMB');
            if (umbRt != null) opp.RecordTypeId = umbRt;
        }
        return opp;
    }

    private static Case buildCase(Map<String, Object> extracted, Id accountId, Id contactId) {
        Case c = new Case(
            AccountId = accountId,
            ContactId = contactId,
            Origin = 'Web',
            Subject = String.isBlank(stringValue(extracted.get('caseSubject')))
                ? defaultCaseSubject(extracted)
                : stringValue(extracted.get('caseSubject')),
            Description = buildDescription(extracted)
        );
        Id caseRtId = getCustomerSuccessCaseRtId();
        if (caseRtId != null) {
            c.RecordTypeId = caseRtId;
        }
        Id queueId = resolveCaseQueueId(stringValue(extracted.get('routingLane')), stringValue(extracted.get('caseType')), stringValue(extracted.get('requestType')), c.Subject);
        if (queueId != null) {
            c.OwnerId = queueId;
        }
        return c;
    }

    private static String defaultCaseSubject(Map<String, Object> extracted) {
        String routingLane = stringValue(extracted.get('routingLane'));
        String caseType = stringValue(extracted.get('caseType'));
        String requestType = stringValue(extracted.get('requestType'));
        if (String.isNotBlank(caseType)) {
            return 'mcLOVIN ' + caseType + ' Request';
        }
        if (String.isNotBlank(requestType)) {
            return 'mcLOVIN ' + requestType + ' Request';
        }
        if (String.isNotBlank(routingLane)) {
            return 'mcLOVIN ' + routingLane + ' Request';
        }
        return 'mcLOVIN Service Request';
    }

    private static Id resolveCaseQueueId(String routingLane, String caseType, String requestType, String subject) {
        String joined = String.join(new List<String>{
            routingLane == null ? '' : routingLane,
            caseType == null ? '' : caseType,
            requestType == null ? '' : requestType,
            subject == null ? '' : subject
        }, ' ').toLowerCase();

        if (joined.contains('warranty')) {
            return getQueueId('Warranty');
        }
        if (joined.contains('scheduling') || joined.contains('reschedule')) {
            return getQueueId('Scheduling_Queue');
        }
        if (joined.contains('closeout') || joined.contains('customer care')) {
            return getQueueId('Customer_Care_Closeout');
        }
        return null;
    }

    private static Id getQueueId(String developerName) {
        if (String.isBlank(developerName)) return null;
        if (!queueCache.containsKey(developerName)) {
            List<Group> groups = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName = :developerName
                LIMIT 1
            ];
            queueCache.put(developerName, groups.isEmpty() ? null : groups[0].Id);
        }
        return queueCache.get(developerName);
    }

    private static Id getCustomerSuccessCaseRtId() {
        if (customerSuccessCaseRtId == null) {
            RecordTypeInfo rti = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Customer_Success');
            customerSuccessCaseRtId = (rti != null && rti.isAvailable()) ? rti.getRecordTypeId() : null;
        }
        return customerSuccessCaseRtId;
    }

    private static void linkUploadedFiles(Id requestId, Id targetRecordId) {
        if (requestId == null || targetRecordId == null) return;
        for (ContentDocumentLink existing : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :requestId
        ]) {
            List<ContentDocumentLink> dupes = [
                SELECT Id FROM ContentDocumentLink
                WHERE LinkedEntityId = :targetRecordId
                AND ContentDocumentId = :existing.ContentDocumentId
                LIMIT 1
            ];
            if (dupes.isEmpty()) {
                insert new ContentDocumentLink(
                    LinkedEntityId = targetRecordId,
                    ContentDocumentId = existing.ContentDocumentId,
                    ShareType = 'V'
                );
            }
        }
    }

    private static String extractCompany(String text) {
        List<String> lines = text == null ? new List<String>() : text.split('\\n');
        for (String rawLine : lines) {
            String line = rawLine == null ? '' : rawLine.trim();
            if (String.isBlank(line)) continue;
            if (line.toLowerCase().startsWith('scope of work')) continue;
            line = line.replaceFirst('(?i)^(Customer|Builder|Account|Company|Division)\\s*[:\\-]\\s*', '');
            if (isInternalDivisionName(line)) continue;
            if (line.contains('LLC') || line.contains('Inc') || line.contains('Homes') || line.contains('Builder') || line.contains('Construction') || line.contains('Company')) {
                return truncate(line, 255);
            }
        }
        String labeled = matchGroup(text, '(?im)(?:Company|Builder|Account)\\s*[:\\-]\\s*([^\\n]+)');
        return String.isNotBlank(labeled) ? truncate(labeled.trim(), 255) : null;
    }

    private static Boolean looksLikeSpreadsheet(String text) {
        if (String.isBlank(text)) return false;
        Integer rowCount = estimateRowCount(text);
        String lower = text.toLowerCase();
        Boolean hasTabularMarkers =
            text.contains('\t') ||
            (lower.contains('division') && lower.contains('customer') && lower.contains('community')) ||
            (lower.contains('wo type') && lower.contains('job category'));
        return rowCount >= 5 && hasTabularMarkers;
    }

    private static Integer estimateRowCount(String text) {
        if (String.isBlank(text)) return 0;
        List<String> rows = text.split('\\n');
        Integer count = 0;
        for (String row : rows) {
            if (String.isNotBlank(row)) count++;
        }
        return count;
    }

    private static List<Map<String, Object>> parseScopeItems(String combinedText, String explicitJobDescription) {
        String source = String.isNotBlank(explicitJobDescription) ? explicitJobDescription : combinedText;
        List<Map<String, Object>> items = new List<Map<String, Object>>();
        Set<String> seen = new Set<String>();
        for (String fragment : splitScopeFragments(source)) {
            if (!looksLikeScopeLine(fragment)) continue;
            String cleaned = cleanScopeLine(fragment);
            if (String.isBlank(cleaned)) continue;
            String dedupeKey = cleaned.toLowerCase();
            if (seen.contains(dedupeKey)) continue;
            seen.add(dedupeKey);

            Decimal quantity = extractQuantity(cleaned);
            String unit = extractUnit(cleaned);
            String subject = removeQuantityPrefix(cleaned);
            ScopeItemMatch match = matchItemCatalog(subject);

            Map<String, Object> item = new Map<String, Object>();
            item.put('rawLine', cleaned);
            item.put('subject', truncate(subject, 255));
            item.put('quantity', quantity);
            item.put('unitOfMeasure', unit);
            item.put('itemCatalogId', match == null ? null : match.catalogId);
            item.put('itemCatalogName', match == null ? null : match.catalogName);
            item.put('itemCatalogCategory', match == null ? null : match.category);
            item.put('matchScore', match == null ? 0 : match.score);
            items.add(item);
        }
        return items;
    }

    private static List<String> splitScopeFragments(String source) {
        List<String> items = new List<String>();
        if (String.isBlank(source)) return items;
        for (String line : source.split('\\n')) {
            if (String.isBlank(line)) continue;
            List<String> parts = line.split('\\s*[;|•]+\\s*');
            for (String part : parts) {
                if (String.isNotBlank(part)) {
                    items.add(part.trim());
                }
            }
        }
        return items;
    }

    private static Boolean looksLikeScopeLine(String line) {
        if (String.isBlank(line)) return false;
        String lower = line.trim().toLowerCase();
        if (lower.length() < 6) return false;
        List<String> excludedPrefixes = new List<String>{
            'division', 'customer', 'builder customer', 'community', 'lot', 'voucher',
            'coupon', 'contact', 'from', 'prepared by', 'requested by', 'address',
            'city', 'state', 'email', 'phone', 'wo type', 'job category', 'umb'
        };
        for (String prefix : excludedPrefixes) {
            if (lower.startsWith(prefix + ':') || lower.startsWith(prefix + ' ')) return false;
        }
        if (lower.contains('@')) return false;
        if (Pattern.compile('(?i)^[A-Z][a-z]+,\\s*[A-Z]{2}\\s+\\d{5}(?:-\\d{4})?$').matcher(line.trim()).find()) return false;
        if (Pattern.compile('(?i)^\\d{2,6}\\s+[A-Za-z0-9 .#-]+(?:street|st|road|rd|lane|ln|drive|dr|court|ct|way|boulevard|blvd|avenue|ave)\\b').matcher(line.trim()).find()) return false;
        if (lower == 'scope of work' || lower == 'job description' || lower == 'description') return false;
        if (Pattern.compile('(?i)\\b(install|remove|repair|replace|add|provide|build|grade|stone|mulch|sod|irrigation|drain|plant|countertop|grill|lighting|paver|concrete|wall|firepit|patio)\\b').matcher(lower).find()) {
            return true;
        }
        return Pattern.compile('(?i)^\\s*\\d+(?:\\.\\d+)?\\s*(?:x|ea|each|tons?|ton|sq\\s*ft|sf|ft|hrs?|hours?|bags?|loads?|units?|pieces?)\\b').matcher(line).find();
    }

    private static String cleanScopeLine(String line) {
        if (String.isBlank(line)) return null;
        String cleaned = line.trim();
        cleaned = cleaned.replaceFirst('^[\\-\\*\\u2022\\s]+', '');
        cleaned = cleaned.replaceAll('\\s+', ' ').trim();
        return truncate(cleaned, 255);
    }

    private static Decimal extractQuantity(String line) {
        if (String.isBlank(line)) return null;
        Matcher matcher = Pattern.compile('^\\s*(\\d+(?:\\.\\d+)?)\\b').matcher(line);
        if (matcher.find()) {
            try {
                return Decimal.valueOf(matcher.group(1));
            } catch (Exception ignored) {
            }
        }
        return null;
    }

    private static String extractUnit(String line) {
        if (String.isBlank(line)) return null;
        Matcher matcher = Pattern.compile('(?i)^\\s*\\d+(?:\\.\\d+)?\\s*(x|ea|each|tons?|ton|sq\\s*ft|sf|ft|hrs?|hours?|bags?|loads?|units?|pieces?)\\b').matcher(line);
        if (matcher.find()) {
            return truncate(matcher.group(1).toLowerCase(), 40);
        }
        return null;
    }

    private static String removeQuantityPrefix(String line) {
        if (String.isBlank(line)) return null;
        String value = line.replaceFirst('^\\s*\\d+(?:\\.\\d+)?\\s*(?:x|ea|each|tons?|ton|sq\\s*ft|sf|ft|hrs?|hours?|bags?|loads?|units?|pieces?)?\\s*', '');
        return truncate(value.trim(), 255);
    }

    private static ScopeItemMatch matchItemCatalog(String line) {
        if (String.isBlank(line)) return null;
        List<String> tokens = significantTokens(line);
        if (tokens.isEmpty()) return null;
        String likeTerm = '%' + tokens[0] + '%';
        List<Item_Catalog__c> candidates = [
            SELECT Id, Name, Category__c, Description__c, Active__c
            FROM Item_Catalog__c
            WHERE Active__c = true
            AND Name LIKE :likeTerm
            ORDER BY LastModifiedDate DESC
            LIMIT 25
        ];

        ScopeItemMatch best;
        for (Item_Catalog__c candidate : candidates) {
            Integer score = tokenOverlapScore(tokens, candidate.Name + ' ' + candidate.Description__c);
            if (score < 2) continue;
            if (best == null || score > best.score) {
                best = new ScopeItemMatch();
                best.catalogId = candidate.Id;
                best.catalogName = candidate.Name;
                best.category = candidate.Category__c;
                best.score = score;
            }
        }
        return best;
    }

    private static Integer tokenOverlapScore(List<String> tokens, String haystack) {
        if (tokens.isEmpty() || String.isBlank(haystack)) return 0;
        Integer score = 0;
        String lowerHaystack = haystack.toLowerCase();
        for (String token : tokens) {
            if (lowerHaystack.contains(token)) score++;
        }
        return score;
    }

    private static List<String> significantTokens(String line) {
        List<String> tokens = new List<String>();
        if (String.isBlank(line)) return tokens;
        Set<String> ignored = new Set<String>{ 'the', 'and', 'for', 'with', 'job', 'scope', 'work', 'install', 'remove', 'replace', 'repair', 'add', 'provide' };
        for (String token : line.toLowerCase().replaceAll('[^a-z0-9 ]', ' ').split('\\s+')) {
            if (String.isBlank(token) || token.length() < 3 || ignored.contains(token)) continue;
            tokens.add(token);
        }
        return tokens;
    }

    private static String extractJobDescription(String text) {
        if (String.isBlank(text)) return null;
        String labeled = extractLabeledBlock(text, new List<String>{ 'Job Description', 'Scope of Work', 'Scope', 'Description' });
        return String.isBlank(labeled) ? null : truncate(labeled, 4000);
    }

    private static String extractLabeledBlock(String text, List<String> labels) {
        if (String.isBlank(text) || labels == null || labels.isEmpty()) return null;
        List<String> lines = text.split('\\n');
        Boolean capture = false;
        List<String> captured = new List<String>();
        for (String rawLine : lines) {
            String line = rawLine == null ? '' : rawLine.trim();
            if (String.isBlank(line)) {
                if (capture && !captured.isEmpty()) break;
                continue;
            }
            if (!capture) {
                for (String label : labels) {
                    if (line.toLowerCase().startsWith(label.toLowerCase())) {
                        capture = true;
                        String remainder = line.substring(label.length()).replaceFirst('^\\s*[:\\-]?\\s*', '');
                        if (String.isNotBlank(remainder)) captured.add(remainder);
                        break;
                    }
                }
            } else {
                if (Pattern.compile('(?i)^(Division|Customer|Builder Customer|Community|Lot|Voucher|Coupon|Contact|From|Prepared By|Requested By|Address|City|State|Email|Phone|WO Type|Job Category|UMB)\\s*[:\\-]').matcher(line).find()) {
                    break;
                }
                captured.add(line);
            }
        }
        return captured.isEmpty() ? null : String.join(captured, '\n');
    }

    private static String buildOpportunityName(String company, String firstName, String lastName, String classification) {
        if ('Homeowner Intake'.equals(classification)) {
            return String.isNotBlank(lastName)
                ? lastName + ' Household - Intake'
                : 'Homeowner Intake';
        }
        if (String.isNotBlank(company)) return company + ' - Intake';
        if (String.isNotBlank(firstName) || String.isNotBlank(lastName)) {
            String fullName = ((firstName == null ? '' : firstName + ' ') + (lastName == null ? '' : lastName)).trim();
            return fullName + ' - Intake';
        }
        return 'mcLOVIN Intake Opportunity';
    }

    private static String buildHouseholdName(String lastName, String address, String cityStateZip) {
        if (String.isNotBlank(lastName)) {
            return lastName + ' Household';
        }
        if (String.isNotBlank(address)) {
            return address + ' Household';
        }
        if (String.isNotBlank(cityStateZip)) {
            return cityStateZip + ' Household';
        }
        return null;
    }

    private static String buildDescription(Map<String, Object> extracted) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(stringValue(extracted.get('jobDescription')))) {
            parts.add('Job Description:\n' + truncate(stringValue(extracted.get('jobDescription')), 2500));
        }
        if (String.isNotBlank(stringValue(extracted.get('combinedText')))) {
            parts.add(truncate(stringValue(extracted.get('combinedText')), 2500));
        }
        if (String.isNotBlank(stringValue(extracted.get('voucherCode')))) {
            parts.add('Voucher: ' + stringValue(extracted.get('voucherCode')));
        }
        if (String.isNotBlank(stringValue(extracted.get('umbNumber')))) {
            parts.add('UMB: ' + stringValue(extracted.get('umbNumber')));
        }
        if (String.isNotBlank(stringValue(extracted.get('purchaseOrderNumber')))) {
            parts.add('PO: ' + stringValue(extracted.get('purchaseOrderNumber')));
        }
        if (String.isNotBlank(stringValue(extracted.get('routingLane')))) {
            parts.add('Routing Lane: ' + stringValue(extracted.get('routingLane')));
        }
        return String.join(parts, '\n\n');
    }

    private static String buildSaveMessage(Integer createdScopeItemCount, Id workOrderId, Map<String, Object> extracted) {
        if (createdScopeItemCount > 0) {
            return 'mcLOVIN\' created and linked the record set successfully, including ' + createdScopeItemCount + ' Work Order line item(s).';
        }
        if (workOrderId != null) {
            return 'mcLOVIN\' created and linked the record set successfully. No Work Order line items were created from the parsed scope.';
        }
        if (!parsedScopeItemsFromExtracted(extracted).isEmpty()) {
            return 'mcLOVIN\' created and linked the record set successfully. Parsed scope items are ready; provide a Work Order Id to create line items.';
        }
        return 'mcLOVIN\' created and linked the record set successfully.';
    }

    private static Integer createWorkOrderLineItems(Id workOrderId, Map<String, Object> extracted, List<Id> relatedRecordIds) {
        if (workOrderId == null) return 0;
        WorkOrder workOrderRecord = [
            SELECT Id
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        List<Map<String, Object>> parsedItems = parsedScopeItemsFromExtracted(extracted);
        if (parsedItems.isEmpty()) return 0;

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.WorkOrderLineItem.fields.getMap();
        List<WorkOrderLineItem> toInsert = new List<WorkOrderLineItem>();
        for (Map<String, Object> item : parsedItems) {
            String subject = stringValue(item.get('subject'));
            if (String.isBlank(subject)) continue;

            WorkOrderLineItem line = new WorkOrderLineItem();
            line.WorkOrderId = workOrderRecord.Id;
            line.Subject = truncate(subject, 255);

            String description = stringValue(item.get('rawLine'));
            if (String.isNotBlank(description)) {
                line.Description = truncate(description, 32000);
            }

            if (fieldMap.containsKey('Item_Catalog__c')) {
                Id catalogId = castId(item.get('itemCatalogId'));
                if (catalogId != null) {
                    line.put('Item_Catalog__c', catalogId);
                }
            }

            if (fieldMap.containsKey('Catalog_Item__c')) {
                String catalogName = stringValue(item.get('itemCatalogName'));
                Schema.DisplayType displayType = fieldMap.get('Catalog_Item__c').getDescribe().getType();
                if (String.isNotBlank(catalogName) && displayType == Schema.DisplayType.String) {
                    line.put('Catalog_Item__c', truncate(catalogName, 255));
                }
            }

            toInsert.add(line);
        }

        if (toInsert.isEmpty()) return 0;
        insert toInsert;
        for (WorkOrderLineItem created : toInsert) {
            relatedRecordIds.add(created.Id);
        }
        return toInsert.size();
    }

    private static List<Map<String, Object>> parsedScopeItemsFromExtracted(Map<String, Object> extracted) {
        List<Map<String, Object>> items = new List<Map<String, Object>>();
        if (extracted == null || !extracted.containsKey('parsedScopeItems')) return items;
        Object rawItems = extracted.get('parsedScopeItems');
        try {
            for (Object raw : (List<Object>) rawItems) {
                items.add((Map<String, Object>) raw);
            }
        } catch (Exception ignored) {
            return new List<Map<String, Object>>();
        }
        return items;
    }

    private static void applyCityStateZip(SObject sob, String cityStateZip) {
        if (String.isBlank(cityStateZip)) return;
        List<String> split = cityStateZip.split(',');
        if (split.size() < 2) return;
        String city = split[0].trim();
        String stateZip = split[1].trim();
        List<String> stateZipParts = stateZip.split('\\s+');
        String state = stateZipParts.isEmpty() ? null : stateZipParts[0];
        String postal = stateZipParts.size() > 1 ? stateZipParts[1] : null;

        Map<String, Object> values = new Map<String, Object>();
        if (sob.getSObjectType() == Account.SObjectType) {
            values.put('BillingCity', city);
            values.put('BillingState', state);
            values.put('BillingPostalCode', postal);
        } else if (sob.getSObjectType() == Contact.SObjectType) {
            values.put('MailingCity', city);
            values.put('MailingState', state);
            values.put('MailingPostalCode', postal);
        } else if (sob.getSObjectType() == Lead.SObjectType) {
            values.put('City', city);
            values.put('State', state);
            values.put('PostalCode', postal);
        }
        for (String fieldName : values.keySet()) {
            sob.put(fieldName, values.get(fieldName));
        }
    }

    private static void addIfBlank(List<MissingField> fields, String apiName, String label, String reason, Map<String, Object> extracted) {
        if (String.isBlank(stringValue(extracted.get(apiName)))) {
            fields.add(missing(apiName, label, reason));
        }
    }

    private static MissingField missing(String apiName, String label, String reason) {
        MissingField f = new MissingField();
        f.apiName = apiName;
        f.label = label;
        f.reason = reason;
        f.value = null;
        return f;
    }

    private static RecordCandidate candidate(Id recordId, String objectApiName, String label, Integer score, String reason) {
        RecordCandidate c = new RecordCandidate();
        c.recordId = (String) recordId;
        c.objectApiName = objectApiName;
        c.label = label;
        c.score = score;
        c.reason = reason;
        return c;
    }

    private static String findFirstCandidateId(List<RecordCandidate> candidates, String objectApiName) {
        for (RecordCandidate candidate : candidates) {
            if (candidate.objectApiName == objectApiName) return candidate.recordId;
        }
        return null;
    }

    private static List<RecordCandidate> deDupeCandidates(List<RecordCandidate> raw) {
        Map<String, RecordCandidate> deduped = new Map<String, RecordCandidate>();
        for (RecordCandidate candidate : raw) {
            if (candidate == null || String.isBlank(candidate.recordId)) continue;
            if (!deduped.containsKey(candidate.recordId) || deduped.get(candidate.recordId).score < candidate.score) {
                deduped.put(candidate.recordId, candidate);
            }
        }
        List<RecordCandidate> result = new List<RecordCandidate>();
        result.addAll(deduped.values());
        result.sort();
        return result;
    }

    private static String matchGroup(String text, String regex) {
        if (String.isBlank(text)) return null;
        Matcher matcher = Pattern.compile(regex).matcher(text);
        if (matcher.find()) {
            return matcher.group(1);
        }
        return null;
    }

    private static void mergeMaps(Map<String, Object> baseMap, Map<String, Object> overrides) {
        if (overrides == null) return;
        for (String key : overrides.keySet()) {
            Object value = overrides.get(key);
            if (value != null && String.isNotBlank(String.valueOf(value))) {
                baseMap.put(key, value);
            }
        }
    }

    private static Map<String, Object> stringToMap(String jsonString) {
        if (String.isBlank(jsonString)) return new Map<String, Object>();
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        } catch (Exception ignored) {
            return new Map<String, Object>();
        }
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value).trim();
    }

    private static Decimal decimalValue(Object value) {
        String stringified = stringValue(value);
        if (String.isBlank(stringified)) return null;
        try {
            return Decimal.valueOf(stringified);
        } catch (Exception ignored) {
            return null;
        }
    }

    private static Id castId(Object value) {
        String val = stringValue(value);
        return String.isBlank(val) ? null : (Id) val;
    }

    private static String normalizePhone(String phone) {
        return phone == null ? null : phone.replaceAll('[^0-9]', '');
    }

    private static String truncate(String value, Integer maxLength) {
        if (value == null || value.length() <= maxLength) return value;
        return value.substring(0, maxLength);
    }

    private static String capitalizeWord(String value) {
        if (String.isBlank(value)) return value;
        return value.substring(0, 1).toUpperCase() + value.substring(1).toLowerCase();
    }

    private static Boolean equalsIgnoreCase(String left, String right) {
        return left != null && right != null && left.toLowerCase() == right.toLowerCase();
    }

    private static String cleanExtractedValue(String value) {
        return String.isBlank(value) ? null : truncate(value.trim(), 255);
    }

    private static Boolean isInternalDivisionName(String value) {
        if (String.isBlank(value)) return false;
        String lower = value.trim().toLowerCase();
        for (String prefix : INTERNAL_DIVISION_PREFIXES) {
            if (lower.startsWith(prefix)) return true;
        }
        return false;
    }

    private static Boolean isBuilderClassification(String classification) {
        return classification == 'Builder Scope' || classification == 'Spreadsheet Batch' || classification == 'UMB Intake' || classification == 'Lennar Voucher';
    }

    private static String deriveCommunityName(String companyName) {
        if (String.isBlank(companyName) || !companyName.contains(' - ')) return null;
        return truncate(companyName.substringAfterLast(' - ').trim(), 255);
    }

    private static String normalizeBuilderAccountName(String rawCompanyName) {
        if (String.isBlank(rawCompanyName) || isInternalDivisionName(rawCompanyName)) return null;
        String value = rawCompanyName.trim();
        if (value.contains(' - ')) {
            value = value.substringBeforeLast(' - ').trim();
        }
        Matcher drHorton = Pattern.compile('(?i)^(DR\\s*Horton)\\s+Homes\\s+(Asheville|Charlotte|Columbia|Greenville|Triad)\\b').matcher(value);
        if (drHorton.find()) {
            return drHorton.group(1).replaceAll('\\s+', ' ').trim() + ' – ' + capitalizeWord(drHorton.group(2));
        }
        Matcher lennar = Pattern.compile('(?i)^(Lennar\\s+Homes)\\s+(Asheville|Charlotte|Columbia|Greenville|Triad)\\b').matcher(value);
        if (lennar.find()) {
            return lennar.group(1).replaceAll('\\s+', ' ').trim() + ' – ' + capitalizeWord(lennar.group(2));
        }
        return truncate(value, 255);
    }

}