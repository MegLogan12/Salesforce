public with sharing class McLovinEmployeeAgentController {

    @AuraEnabled
    public static Id startDraft(String sourceType, String intakeText) {
        return McLovinEmployeeIntakeService.startDraft(sourceType, intakeText);
    }

    @AuraEnabled
    public static McLovinEmployeeIntakeService.AnalysisResult analyzeRequest(Id requestId, String sourceType, String intakeText) {
        return McLovinEmployeeIntakeService.analyze(requestId, sourceType, intakeText);
    }

    @AuraEnabled
    public static McLovinEmployeeIntakeService.SaveResult saveRequest(Id requestId, String overridesJson, Boolean confirmed) {
        return McLovinEmployeeIntakeService.save(requestId, overridesJson, confirmed);
    }
}