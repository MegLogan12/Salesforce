/**
 * @description Queueable processor for field usage discovery in batches of <= 25 fields.
 */
public with sharing class FieldUsageDiscoveryQueueable implements Queueable, Database.AllowsCallouts {
    private List<FieldUsageDiscoveryService.FieldInput> inputs;
    private FieldUsageDiscoveryService.DiscoveryOptions options;
    private Integer batchIndex;
    private String runId;
    private Boolean emailResults;

    public FieldUsageDiscoveryQueueable(
        List<FieldUsageDiscoveryService.FieldInput> inputs,
        FieldUsageDiscoveryService.DiscoveryOptions options,
        Integer batchIndex,
        String runId,
        Boolean emailResults
    ) {
        this.inputs = inputs == null ? new List<FieldUsageDiscoveryService.FieldInput>() : inputs;
        this.options = options == null ? new FieldUsageDiscoveryService.DiscoveryOptions() : options;
        this.batchIndex = batchIndex == null ? 1 : batchIndex;
        this.runId = String.isBlank(runId) ? String.valueOf(DateTime.now().getTime()) : runId;
        this.emailResults = emailResults == null ? false : emailResults;
    }

    public void execute(QueueableContext context) {
        List<FieldUsageDiscoveryService.FieldResult> results =
            FieldUsageDiscoveryService.analyze(inputs, options);

        String jsonBody = JSON.serializePretty(results);
        String csvBody = FieldUsageDiscoveryService.toCsv(results);

        List<ContentVersion> versions = new List<ContentVersion>();
        ContentVersion jsonCv = buildContentVersion('json', jsonBody);
        ContentVersion csvCv = buildContentVersion('csv', csvBody);
        if (jsonCv != null) {
            versions.add(jsonCv);
        }
        if (csvCv != null) {
            versions.add(csvCv);
        }
        if (!versions.isEmpty()) {
            Database.insert(versions, AccessLevel.USER_MODE);
        }

        if (emailResults) {
            sendEmail(versions);
        }
    }

    private ContentVersion buildContentVersion(String ext, String body) {
        if (!Schema.sObjectType.ContentVersion.isCreateable()) {
            return null;
        }
        ContentVersion cv = new ContentVersion();
        cv.Title = 'FieldUsageDiscovery_' + runId + '_batch' + String.valueOf(batchIndex) + '.' + ext;
        cv.PathOnClient = cv.Title;
        cv.VersionData = Blob.valueOf(body == null ? '' : body);
        return cv;
    }

    private void sendEmail(List<ContentVersion> versions) {
        if (versions == null || versions.isEmpty()) {
            return;
        }
        List<String> lines = new List<String>();
        lines.add('Field Usage Discovery results ready for run ' + runId + ', batch ' + batchIndex + '.');
        for (ContentVersion cv : versions) {
            lines.add('File: ' + cv.Title);
        }
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(UserInfo.getUserId());
        email.setSubject('Field Usage Discovery Results - ' + runId + ' batch ' + batchIndex);
        email.setPlainTextBody(String.join(lines, '\n'));
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }

    /**
     * @description Enqueue batches of 25 and return the run id.
     * @param inputs Field inputs.
     * @param options Options.
     * @param emailResults Email flag.
     * @return Run id.
     */
    public static String enqueueBatches(
        List<FieldUsageDiscoveryService.FieldInput> inputs,
        FieldUsageDiscoveryService.DiscoveryOptions options,
        Boolean emailResults
    ) {
        String runId = String.valueOf(DateTime.now().getTime());
        if (inputs == null || inputs.isEmpty()) {
            return runId;
        }
        Integer batchIndex = 1;
        List<FieldUsageDiscoveryService.FieldInput> buffer = new List<FieldUsageDiscoveryService.FieldInput>();
        for (FieldUsageDiscoveryService.FieldInput input : inputs) {
            buffer.add(input);
            if (buffer.size() == 25) {
                System.enqueueJob(new FieldUsageDiscoveryQueueable(buffer, options, batchIndex, runId, emailResults));
                batchIndex++;
                buffer = new List<FieldUsageDiscoveryService.FieldInput>();
            }
        }
        if (!buffer.isEmpty()) {
            System.enqueueJob(new FieldUsageDiscoveryQueueable(buffer, options, batchIndex, runId, emailResults));
        }
        return runId;
    }
}
