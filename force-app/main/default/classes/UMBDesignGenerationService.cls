/**
 * UMBDesignGenerationService
 * Generates the three Retreat / Entertainer / Signature renderings for an
 * Opportunity using Google Gemini (free tier) and the customer's backyard photo.
 *
 * Flow: backyard photo (File on Opportunity) + tier prompt -> Gemini image edit
 *       -> save rendering as a File on the Opportunity
 *       -> upsert a UMB_Design_Option__c record with the image URL.
 *
 * No hardcoded prices or images. If no photo exists, the option records are still
 * created (cards show the "photo needed" state) so nothing is fabricated.
 */
public with sharing class UMBDesignGenerationService {

    private static final String GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta/models/';
    private static final String DEFAULT_MODEL = 'gemini-2.5-flash-image';

    // Tier -> design instruction. The prompt describes what to add to the customer's
    // actual backyard photo. Prices/features are entered by the team, not invented here.
    private static final Map<String, String> TIER_PROMPTS = new Map<String, String>{
        'Retreat' =>
            'Photorealistically edit this backyard photo. Keep the existing house, fence, and trees exactly. ' +
            'Add a clean paver patio, foundation plantings, and fresh sod borders. Tasteful and simple.',
        'Entertainer' =>
            'Photorealistically edit this backyard photo. Keep the existing house, fence, and trees exactly. ' +
            'Add a larger paver patio, a stone seat wall, a gas fire pit with seating, and layered seasonal plantings.',
        'Signature' =>
            'Photorealistically edit this backyard photo. Keep the existing house, fence, and trees exactly. ' +
            'Add a premium paver patio, a built-in grill island, a cedar pergola with string lights, ' +
            'landscape lighting, and designer plantings. Full outdoor living transformation.'
    };

    private static final Map<String, Integer> TIER_ORDER = new Map<String, Integer>{
        'Retreat' => 1, 'Entertainer' => 2, 'Signature' => 3
    };

    // ── Entry points ────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void requestDesignGeneration(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('No opportunity provided.');
        }
        System.enqueueJob(new GenerateDesignsJob(opportunityId));
    }

    @InvocableMethod(label='Generate UMB Designs' description='Generates Retreat/Entertainer/Signature renderings for an Opportunity.')
    public static void generateFromFlow(List<Id> opportunityIds) {
        for (Id oppId : opportunityIds) {
            System.enqueueJob(new GenerateDesignsJob(oppId));
        }
    }

    // ── Async worker (callouts run here) ─────────────────────────────────────────

    public class GenerateDesignsJob implements Queueable, Database.AllowsCallouts {
        private Id opportunityId;
        public GenerateDesignsJob(Id opportunityId) { this.opportunityId = opportunityId; }

        public void execute(QueueableContext ctx) {
            // Queries are fine before callouts; DML is NOT. So: all callouts first, then all DML.
            String base64Photo = getLatestBackyardPhoto(opportunityId);
            Boolean isConcept = String.isBlank(base64Photo);
            String wishes = getDesiredOutcome(opportunityId);

            // Phase 1 — callouts only, no DML.
            Map<String, String> tierToImage = new Map<String, String>();
            for (String tier : TIER_PROMPTS.keySet()) {
                try {
                    tierToImage.put(tier, callGemini(buildPrompt(tier, isConcept, wishes), base64Photo));
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Gemini callout failed for ' + tier + ': ' + e.getMessage());
                    tierToImage.put(tier, null);
                }
            }

            // Phase 2 — DML only (save files + upsert option records). No more callouts.
            for (String tier : TIER_PROMPTS.keySet()) {
                try {
                    String img = tierToImage.get(tier);
                    String imageUrl = (String.isNotBlank(img)) ? saveRendering(opportunityId, tier, img) : null;
                    upsertOption(opportunityId, tier, imageUrl, isConcept);
                } catch (Exception e) {
                    logError('Saving design option failed for tier ' + tier, e, opportunityId);
                }
            }
        }
    }

    // Builds the Gemini prompt. With a photo: edit their actual yard. Without a photo:
    // generate a representative concept from what the homeowner said they want.
    @TestVisible
    private static String buildPrompt(String tier, Boolean isConcept, String wishes) {
        String tierPrompt = TIER_PROMPTS.get(tier);
        if (!isConcept) {
            return tierPrompt;
        }
        String wishLine = String.isNotBlank(wishes)
            ? ' The homeowner described what they want as: "' + wishes + '".'
            : '';
        return 'Generate a photorealistic concept image of a typical suburban backyard for the ' +
               tier + ' package.' + wishLine + ' ' + tierPrompt;
    }

    @TestVisible
    private static String getDesiredOutcome(Id opportunityId) {
        if (!Schema.sObjectType.Opportunity.fields.getMap().containsKey('desired_backyard_outcome__c')) {
            return null;
        }
        List<Opportunity> opps = [SELECT Desired_Backyard_Outcome__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        return opps.isEmpty() ? null : opps[0].Desired_Backyard_Outcome__c;
    }

    // ── Read the customer's backyard photo (most recent image File) ──────────────

    public static String getLatestBackyardPhoto(Id opportunityId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
            ORDER BY SystemModstamp DESC
        ];
        if (links.isEmpty()) return null;
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

        List<ContentVersion> versions = [
            SELECT VersionData, FileType
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND IsLatest = true
            AND FileType IN ('JPG','JPEG','PNG','HEIC')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (versions.isEmpty()) return null;
        return EncodingUtil.base64Encode(versions[0].VersionData);
    }

    // ── Gemini callout ───────────────────────────────────────────────────────────

    // Reads the key/model from the Gemini Setting custom metadata record. Key never lives in code.
    @TestVisible
    private static Gemini_Setting__mdt getConfig() {
        Gemini_Setting__mdt cfg = Gemini_Setting__mdt.getInstance('Default');
        if (cfg == null) {
            List<Gemini_Setting__mdt> all = [SELECT Api_Key__c, Model__c FROM Gemini_Setting__mdt LIMIT 1];
            if (!all.isEmpty()) cfg = all[0];
        }
        return cfg;
    }

    public static String callGemini(String prompt, String base64Photo) {
        Gemini_Setting__mdt cfg = getConfig();
        String apiKey = (cfg != null) ? cfg.Api_Key__c : null;
        String model = (cfg != null && String.isNotBlank(cfg.Model__c)) ? cfg.Model__c : DEFAULT_MODEL;
        if (String.isBlank(apiKey)) {
            System.debug(LoggingLevel.ERROR, 'Gemini API key not configured in Gemini Setting (Default).');
            return null;
        }
        return invokeGemini(model, apiKey, prompt, base64Photo);
    }

    @TestVisible
    private static String invokeGemini(String model, String apiKey, String prompt, String base64Photo) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(GEMINI_BASE + model + ':generateContent?key=' + apiKey);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

        List<Object> parts = new List<Object>{ new Map<String, Object>{ 'text' => prompt } };
        if (String.isNotBlank(base64Photo)) {
            parts.add(new Map<String, Object>{
                'inline_data' => new Map<String, Object>{
                    'mime_type' => 'image/jpeg',
                    'data' => base64Photo
                }
            });
        }
        Map<String, Object> body = new Map<String, Object>{
            'contents' => new List<Object>{ new Map<String, Object>{ 'parts' => parts } }
        };
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            System.debug(LoggingLevel.ERROR, 'Gemini HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            return null;
        }
        return extractImage(res.getBody());
    }

    @TestVisible
    private static String extractImage(String responseBody) {
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> candidates = (List<Object>) root.get('candidates');
            if (candidates == null || candidates.isEmpty()) return null;
            Map<String, Object> content = (Map<String, Object>) ((Map<String, Object>) candidates[0]).get('content');
            if (content == null) return null;
            List<Object> parts = (List<Object>) content.get('parts');
            if (parts == null) return null;
            for (Object p : parts) {
                Map<String, Object> part = (Map<String, Object>) p;
                Map<String, Object> inline = (Map<String, Object>) part.get('inlineData');
                if (inline == null) inline = (Map<String, Object>) part.get('inline_data');
                if (inline != null && inline.get('data') != null) {
                    return (String) inline.get('data');
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Gemini response parse failed: ' + e.getMessage());
        }
        return null;
    }

    // ── Save rendering as a File and return a displayable URL ────────────────────

    public static String saveRendering(Id opportunityId, String tier, String base64Image) {
        ContentVersion cv = new ContentVersion(
            Title = 'UMB ' + tier + ' Rendering',
            PathOnClient = 'UMB_' + tier + '_Rendering.png',
            VersionData = EncodingUtil.base64Decode(base64Image),
            FirstPublishLocationId = opportunityId
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Prefer a public distribution URL (works in the customer portal). Fall back to the
        // internal file download URL if Content Deliveries are not enabled.
        try {
            ContentDistribution cd = new ContentDistribution(
                Name = 'UMB ' + tier + ' Rendering',
                ContentVersionId = cv.Id,
                PreferencesAllowViewInBrowser = true,
                PreferencesLinkLatestVersion = true,
                PreferencesNotifyOnVisit = false,
                PreferencesPasswordRequired = false,
                PreferencesAllowOriginalDownload = true
            );
            insert cd;
            cd = [SELECT DistributionPublicUrl FROM ContentDistribution WHERE Id = :cd.Id];
            if (String.isNotBlank(cd.DistributionPublicUrl)) return cd.DistributionPublicUrl;
        } catch (Exception e) {
            // Content Deliveries not enabled — use the internal file URL.
        }
        return '/sfc/servlet.shepherd/version/download/' + cv.Id;
    }

    // ── Upsert the design option record ──────────────────────────────────────────

    @TestVisible
    private static void upsertOption(Id opportunityId, String tier, String imageUrl, Boolean isConcept) {
        List<UMB_Design_Option__c> existing = [
            SELECT Id, Rendered_Image_URL__c
            FROM UMB_Design_Option__c
            WHERE Opportunity__c = :opportunityId AND Tier__c = :tier
            LIMIT 1
        ];
        UMB_Design_Option__c opt = existing.isEmpty()
            ? new UMB_Design_Option__c(Opportunity__c = opportunityId, Tier__c = tier, Name = tier)
            : existing[0];
        opt.Sort_Order__c = TIER_ORDER.get(tier);
        opt.Is_Concept__c = isConcept;
        if (String.isNotBlank(imageUrl)) {
            opt.Rendered_Image_URL__c = imageUrl;
        }
        upsert opt;
    }

    // ── Error logging (never throws) ─────────────────────────────────────────────

    private static void logError(String message, Exception e, Id relatedId) {
        String detail = message + (e != null ? ' :: ' + e.getMessage() : '');
        System.debug(LoggingLevel.ERROR, detail);
        try {
            Error_Log__c log = new Error_Log__c();
            if (Schema.sObjectType.Error_Log__c.fields.getMap().containsKey('message__c')) {
                log.put('Message__c', detail.left(255));
            }
            insert log;
        } catch (Exception ignored) {
            // Error_Log__c shape varies; never let logging break generation.
        }
    }
}