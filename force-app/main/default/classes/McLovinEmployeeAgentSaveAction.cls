global with sharing class McLovinEmployeeAgentSaveAction {

    global class SaveInput {
        @InvocableVariable(label='Intake Request Id' required=true)
        public Id requestId;
        @InvocableVariable(label='Overrides JSON')
        public String overridesJson;
        @InvocableVariable(label='Confirmed' required=true)
        public Boolean confirmed;
    }

    global class SaveOutput {
        @InvocableVariable(label='Request Id')
        public Id requestId;
        @InvocableVariable(label='Primary Record Id')
        public Id primaryRecordId;
        @InvocableVariable(label='Primary Object')
        public String primaryObjectApiName;
        @InvocableVariable(label='Primary Record Name')
        public String primaryRecordName;
        @InvocableVariable(label='Status')
        public String status;
        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(label='mcLOVIN Save Intake' description='Creates the recommended Salesforce record set after required fields are filled and the user confirms save.')
    global static List<SaveOutput> save(List<SaveInput> inputs) {
        List<SaveOutput> outputs = new List<SaveOutput>();
        for (SaveInput input : inputs) {
            McLovinEmployeeIntakeService.SaveResult saveResult = McLovinEmployeeIntakeService.save(input.requestId, input.overridesJson, input.confirmed);
            SaveOutput output = new SaveOutput();
            output.requestId = saveResult.requestId;
            output.primaryRecordId = saveResult.primaryRecordId;
            output.primaryObjectApiName = saveResult.primaryObjectApiName;
            output.primaryRecordName = saveResult.primaryRecordName;
            output.status = saveResult.status;
            output.message = saveResult.message;
            outputs.add(output);
        }
        return outputs;
    }
}