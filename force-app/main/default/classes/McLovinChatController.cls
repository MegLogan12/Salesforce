public with sharing class McLovinChatController {

    @AuraEnabled
    public static McLovinChatService.ChatResult sendMessage(String historyJson) {
        List<McLovinChatService.ChatMessage> history =
            (List<McLovinChatService.ChatMessage>) JSON.deserialize(
                historyJson,
                List<McLovinChatService.ChatMessage>.class
            );
        return McLovinChatService.chat(history);
    }
}
