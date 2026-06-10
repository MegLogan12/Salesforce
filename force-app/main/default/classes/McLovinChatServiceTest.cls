@IsTest
private class McLovinChatServiceTest {

    private class MockOpenAISuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"role":"assistant","content":"Hello from mcLOVIN!"}}]}');
            return res;
        }
    }

    private class MockOpenAIError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(401);
            res.setBody('{"error":{"message":"Invalid API key"}}');
            return res;
        }
    }

    @IsTest
    static void testChatSuccess() {
        McLovin_Settings__c settings = new McLovin_Settings__c();
        settings.OpenAI_API_Key__c = 'test-key-123';
        insert settings;

        McLovinChatService.ChatMessage msg = new McLovinChatService.ChatMessage();
        msg.role = 'user';
        msg.content = 'What is a work order?';

        Test.setMock(HttpCalloutMock.class, new MockOpenAISuccess());
        Test.startTest();
        McLovinChatService.ChatResult result = McLovinChatService.chat(
            new List<McLovinChatService.ChatMessage>{ msg }
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected success');
        System.assertEquals('Hello from mcLOVIN!', result.reply);
    }

    @IsTest
    static void testChatErrorResponse() {
        McLovin_Settings__c settings = new McLovin_Settings__c();
        settings.OpenAI_API_Key__c = 'bad-key';
        insert settings;

        McLovinChatService.ChatMessage msg = new McLovinChatService.ChatMessage();
        msg.role = 'user';
        msg.content = 'Hello';

        Test.setMock(HttpCalloutMock.class, new MockOpenAIError());
        Test.startTest();
        McLovinChatService.ChatResult result = McLovinChatService.chat(
            new List<McLovinChatService.ChatMessage>{ msg }
        );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('401'));
    }

    @IsTest
    static void testChatNoApiKey() {
        Test.startTest();
        McLovinChatService.ChatResult result = McLovinChatService.chat(
            new List<McLovinChatService.ChatMessage>()
        );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('API key'));
    }

    @IsTest
    static void testControllerSendMessage() {
        McLovin_Settings__c settings = new McLovin_Settings__c();
        settings.OpenAI_API_Key__c = 'test-key-456';
        insert settings;

        String historyJson = '[{"role":"user","content":"How do I create a PO?"}]';
        Test.setMock(HttpCalloutMock.class, new MockOpenAISuccess());
        Test.startTest();
        McLovinChatService.ChatResult result = McLovinChatController.sendMessage(historyJson);
        Test.stopTest();

        System.assertEquals(true, result.success);
    }

    @IsTest
    static void testLargeHistory() {
        McLovin_Settings__c settings = new McLovin_Settings__c();
        settings.OpenAI_API_Key__c = 'test-key-789';
        insert settings;

        List<McLovinChatService.ChatMessage> history = new List<McLovinChatService.ChatMessage>();
        for (Integer i = 0; i < 25; i++) {
            McLovinChatService.ChatMessage m = new McLovinChatService.ChatMessage();
            m.role = Math.mod(i, 2) == 0 ? 'user' : 'assistant';
            m.content = 'Message ' + i;
            history.add(m);
        }

        Test.setMock(HttpCalloutMock.class, new MockOpenAISuccess());
        Test.startTest();
        McLovinChatService.ChatResult result = McLovinChatService.chat(history);
        Test.stopTest();

        System.assertEquals(true, result.success);
    }
}
