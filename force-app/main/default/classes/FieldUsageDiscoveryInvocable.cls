/**
 * @description Invocable entry point for field usage discovery.
 */
public with sharing class FieldUsageDiscoveryInvocable {
    public class Request {
        @InvocableVariable(label='CSV Text')
        public String csvText;
        @InvocableVariable(label='Object API Name')
        public String objectApiName;
        @InvocableVariable(label='Field API Name')
        public String fieldApiName;
        @InvocableVariable(label='Fill Rate')
        public Decimal fillRate;
        @InvocableVariable(label='Total Count')
        public Integer totalCount;
        @InvocableVariable(label='Filled Count')
        public Integer filledCount;
        @InvocableVariable(label='Sample Fill Rate')
        public Boolean sampleFillRate;
        @InvocableVariable(label='Include Dependencies')
        public Boolean includeDependencies;
        @InvocableVariable(label='Include Field Permissions')
        public Boolean includePermissions;
        @InvocableVariable(label='Email Results')
        public Boolean emailResults;
    }

    public class Response {
        @InvocableVariable(label='Run Id')
        public String runId;
    }

    /**
     * @description Enqueue discovery jobs (batches of 25 fields max).
     * @param requests Requests.
     * @return Response with run id.
     */
    @InvocableMethod(label='Run Field Usage Discovery')
    public static List<Response> run(List<Request> requests) {
        List<FieldUsageDiscoveryService.FieldInput> inputs = new List<FieldUsageDiscoveryService.FieldInput>();
        FieldUsageDiscoveryService.DiscoveryOptions options = new FieldUsageDiscoveryService.DiscoveryOptions();
        Boolean emailResults = false;
        if (requests != null && !requests.isEmpty()) {
            Request first = requests[0];
            options.sampleFillRate = first.sampleFillRate == null ? true : first.sampleFillRate;
            options.includeToolingDependencies = first.includeDependencies == null ? true : first.includeDependencies;
            options.includeFieldPermissions = first.includePermissions == null ? true : first.includePermissions;
            emailResults = first.emailResults == null ? false : first.emailResults;
        }
        for (Request req : requests) {
            if (!String.isBlank(req.csvText)) {
                inputs.addAll(parseCsv(req.csvText));
            } else if (!String.isBlank(req.objectApiName) && !String.isBlank(req.fieldApiName)) {
                FieldUsageDiscoveryService.FieldInput input = new FieldUsageDiscoveryService.FieldInput();
                input.objectApiName = req.objectApiName;
                input.fieldApiName = req.fieldApiName;
                input.fillRate = req.fillRate;
                input.totalCount = req.totalCount;
                input.filledCount = req.filledCount;
                inputs.add(input);
            }
        }
        String runId = FieldUsageDiscoveryQueueable.enqueueBatches(inputs, options, emailResults);
        Response resp = new Response();
        resp.runId = runId;
        return new List<Response>{ resp };
    }

    private static List<FieldUsageDiscoveryService.FieldInput> parseCsv(String csvText) {
        List<FieldUsageDiscoveryService.FieldInput> inputs = new List<FieldUsageDiscoveryService.FieldInput>();
        List<String> lines = csvText.split('\n');
        for (Integer i = 0; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) {
                continue;
            }
            if (i == 0 && line.toLowerCase().contains('object') && line.toLowerCase().contains('field')) {
                continue;
            }
            List<String> cols = line.split(',');
            if (cols.size() < 2) {
                continue;
            }
            FieldUsageDiscoveryService.FieldInput input = new FieldUsageDiscoveryService.FieldInput();
            input.objectApiName = cols[0].trim();
            input.fieldApiName = cols[1].trim();
            if (cols.size() > 2) {
                input.fillRate = parseDecimal(cols[2]);
            }
            if (cols.size() > 3) {
                input.totalCount = parseInteger(cols[3]);
            }
            if (cols.size() > 4) {
                input.filledCount = parseInteger(cols[4]);
            }
            inputs.add(input);
        }
        return inputs;
    }

    private static Decimal parseDecimal(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Decimal.valueOf(value.trim());
        } catch (Exception ex) {
            return null;
        }
    }

    private static Integer parseInteger(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Integer.valueOf(value.trim());
        } catch (Exception ex) {
            return null;
        }
    }
}
