public with sharing class McLovinChatService {

    private static final String OPENAI_ENDPOINT = 'https://api.openai.com/v1/chat/completions';
    private static final String MODEL            = 'gpt-4o';
    private static final Integer MAX_TOKENS      = 1200;
    private static final Integer MAX_HISTORY     = 20;

    private static final String SYSTEM_PROMPT =
        'You are mcLOVIN, the internal AI assistant for The LOVING Companies. ' +
        'LOVING is a family of outdoor living brands doing landscaping, pools, turf, ' +
        'irrigation, and related work across multiple divisions in the Carolinas and surrounding areas.\n\n' +

        'Your job is to help employees get things done. Answer questions, explain processes, ' +
        'translate Salesforce fields and data into plain English, recommend what to do next, ' +
        'and help with intake requests.\n\n' +

        'TONE RULES (non-negotiable, always follow these):\n' +
        '- Write the way a smart, friendly coworker talks. Conversational, direct, and warm.\n' +
        '- Never use em-dashes (the long dash character). Not once. Use a comma, ' +
        'a period, or just rewrite the sentence.\n' +
        '- Skip bullet points unless the person specifically asks for a list.\n' +
        '- No corporate buzzwords. No jargon without an immediate plain-English explanation.\n' +
        '- Keep sentences short. Get to the point.\n' +
        '- When explaining something technical, lead with what it means for the person ' +
        'in their day-to-day work, then get into the mechanics.\n' +
        '- Be confident and give real answers. Do not hedge everything with disclaimers.\n' +
        '- If you do not know something specific to LOVING\'s current setup, say so ' +
        'simply, then give the most useful general guidance you can.\n\n' +

        'ABOUT LOVING AND ITS SALESFORCE SETUP:\n' +
        'Key roles: Field Manager (FM), Customer Success Manager (CSM), Account Partner (AP), ' +
        'Dispatcher, VP of Operations, COO.\n' +
        'Core objects: Work Orders, Communities (neighborhoods or developments), ' +
        'Lots (individual job sites), Builder Accounts (the builder/developer client at division ' +
        'level), Service Appointments, Work Order Line Items.\n' +
        'Builder Account is the division-level account for a builder. It rolls up to a Parent ' +
        'Account. Communities belong to builders. Lots belong to communities.\n' +
        'Gates (G3, G5, G6, G9) are escalation checkpoints requiring COO or leadership decisions. ' +
        'G5 is the accounting system choice gate.\n' +
        'Main tools: Field Services Console, Scheduling Console, Dispatch Map, ' +
        'Invoice Accounting Console, COO Command Center, Measuring Cup Console.\n' +
        'Intake types handled: Builder Scope, Homeowner Intake, Service Case, PO Upload, ' +
        'Spreadsheet Batch, and New Account creation.';

    public class ChatMessage {
        @AuraEnabled public String role;
        @AuraEnabled public String content;
    }

    public class ChatResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String reply;
        @AuraEnabled public String errorMessage;
    }

    public static ChatResult chat(List<ChatMessage> history) {
        ChatResult result = new ChatResult();
        try {
            String apiKey = getApiKey();
            if (String.isBlank(apiKey)) {
                result.success = false;
                result.errorMessage = 'OpenAI API key is not configured yet. ' +
                    'Go to Setup > Custom Settings > McLovin Settings > Manage ' +
                    'and set the org default API key.';
                return result;
            }

            List<Map<String, String>> messages = new List<Map<String, String>>();

            Map<String, String> sysMsg = new Map<String, String>();
            sysMsg.put('role', 'system');
            sysMsg.put('content', SYSTEM_PROMPT);
            messages.add(sysMsg);

            Integer start = history.size() > MAX_HISTORY
                ? history.size() - MAX_HISTORY
                : 0;
            for (Integer i = start; i < history.size(); i++) {
                ChatMessage m = history[i];
                Map<String, String> entry = new Map<String, String>();
                entry.put('role',    m.role);
                entry.put('content', m.content);
                messages.add(entry);
            }

            Map<String, Object> body = new Map<String, Object>{
                'model'      => MODEL,
                'messages'   => messages,
                'max_tokens' => MAX_TOKENS
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(OPENAI_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + apiKey);
            req.setHeader('Content-Type',  'application/json');
            req.setBody(JSON.serialize(body));
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> parsed  = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> choices        = (List<Object>) parsed.get('choices');
                Map<String, Object> first   = (Map<String, Object>) choices[0];
                Map<String, Object> message = (Map<String, Object>) first.get('message');
                result.success = true;
                result.reply   = (String) message.get('content');
            } else {
                result.success      = false;
                result.errorMessage = 'OpenAI returned ' + res.getStatusCode() + '. ' + res.getBody();
            }

        } catch (Exception e) {
            result.success      = false;
            result.errorMessage = e.getMessage();
        }
        return result;
    }

    private static String getApiKey() {
        McLovin_Settings__c cfg = McLovin_Settings__c.getOrgDefaults();
        return cfg != null ? cfg.OpenAI_API_Key__c : null;
    }
}
