global with sharing class McLovinEmployeeAgentActions {

    global class AnalyzeInput {
        @InvocableVariable(label='Intake Request Id')
        public Id requestId;
        @InvocableVariable(label='Source Type' required=true)
        public String sourceType;
        @InvocableVariable(label='Intake Text')
        public String intakeText;
    }

    global class AnalyzeOutput {
        @InvocableVariable(label='Request Id')
        public Id requestId;
        @InvocableVariable(label='Status')
        public String status;
        @InvocableVariable(label='Classification')
        public String classification;
        @InvocableVariable(label='Suggested Primary Object')
        public String suggestedPrimaryObject;
        @InvocableVariable(label='Suggested Action')
        public String suggestedAction;
        @InvocableVariable(label='Suggested Record Name')
        public String suggestedRecordName;
        @InvocableVariable(label='Missing Fields JSON')
        public String missingFieldsJson;
        @InvocableVariable(label='Extracted Data JSON')
        public String extractedDataJson;
    }

    @InvocableMethod(label='mcLOVIN Analyze Intake' description='Analyzes uploaded text or document context and proposes the Salesforce records to create or update.')
    global static List<AnalyzeOutput> analyze(List<AnalyzeInput> inputs) {
        List<AnalyzeOutput> outputs = new List<AnalyzeOutput>();
        for (AnalyzeInput input : inputs) {
            McLovinEmployeeIntakeService.AnalysisResult analysis = McLovinEmployeeIntakeService.analyze(input.requestId, input.sourceType, input.intakeText);
            AnalyzeOutput output = new AnalyzeOutput();
            output.requestId = analysis.requestId;
            output.status = analysis.status;
            output.classification = analysis.classification;
            output.suggestedPrimaryObject = analysis.suggestedPrimaryObject;
            output.suggestedAction = analysis.suggestedAction;
            output.suggestedRecordName = analysis.suggestedRecordName;
            output.missingFieldsJson = JSON.serialize(analysis.missingFields);
            output.extractedDataJson = JSON.serialize(analysis.extractedData);
            outputs.add(output);
        }
        return outputs;
    }
}