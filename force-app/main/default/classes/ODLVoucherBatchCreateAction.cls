public with sharing class ODLVoucherBatchCreateAction {
    public class Request {
        @InvocableVariable(required=true)
        public Integer quantity;

        @InvocableVariable(required=true)
        public Id campaignId;

        @InvocableVariable
        public Id builderAccountId;

        @InvocableVariable
        public String codePrefix;

        @InvocableVariable
        public String voucherStatus;

        @InvocableVariable
        public Date expirationDate;

        @InvocableVariable
        public Decimal voucherFaceValue;
    }

    public class Result {
        @InvocableVariable
        public Integer createdCount;

        @InvocableVariable
        public String createdCodes;

        @InvocableVariable
        public Id firstVoucherId;

        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label='Create ODL Voucher Batch' description='Creates a batch of duplicate-safe vouchers with auto-generated codes.')
    public static List<Result> createVouchers(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null) {
            return results;
        }

        for (Request requestRow : requests) {
            results.add(createVoucherBatch(requestRow));
        }
        return results;
    }

    private static Result createVoucherBatch(Request requestRow) {
        if (requestRow == null) {
            throw new AuraHandledException('Voucher request is required.');
        }
        if (requestRow.campaignId == null) {
            throw new AuraHandledException('Campaign is required.');
        }
        Integer requestedQuantity = requestRow.quantity == null ? 0 : requestRow.quantity;
        if (requestedQuantity <= 0 || requestedQuantity > 200) {
            throw new AuraHandledException('Quantity must be between 1 and 200.');
        }

        Campaign campaignRow = [
            SELECT Id, Name, Builder_Account__c, Builder_Account__r.Name
            FROM Campaign
            WHERE Id = :requestRow.campaignId
            LIMIT 1
        ];

        Id builderAccountId = requestRow.builderAccountId != null ? requestRow.builderAccountId : campaignRow.Builder_Account__c;
        String builderName = campaignRow.Builder_Account__r == null ? null : campaignRow.Builder_Account__r.Name;
        String prefix = ODLVoucherCodeService.resolvePrefix(requestRow.codePrefix, campaignRow.Name, builderName);

        if (builderAccountId == null) {
            throw new AuraHandledException('Builder Account is required for Lennar vouchers.');
        }

        String voucherType = 'Standard Grilling Island';
        String voucherStatus = String.isBlank(requestRow.voucherStatus)
            ? 'Active'
            : requestRow.voucherStatus;

        Decimal voucherFaceValue = requestRow.voucherFaceValue;

        List<String> generatedCodes = ODLVoucherCodeService.generateUniqueCodes(prefix, requestedQuantity, new Set<String>());
        List<Voucher__c> vouchersToInsert = new List<Voucher__c>();
        for (String generatedCode : generatedCodes) {
            Voucher__c voucherRow = new Voucher__c();
            voucherRow.Voucher_Code__c = generatedCode;
            voucherRow.Campaign__c = campaignRow.Id;
            voucherRow.Builder_Account__c = builderAccountId;
            voucherRow.Voucher_Type__c = voucherType;
            voucherRow.Status__c = voucherStatus;
            voucherRow.Expiration_Date__c = requestRow.expirationDate;
            voucherRow.Voucher_Face_Value__c = voucherFaceValue;
            voucherRow.Builder_Invoice_Status__c = 'Pending';
            vouchersToInsert.add(voucherRow);
        }

        insert vouchersToInsert;

        Result resultRow = new Result();
        resultRow.createdCount = vouchersToInsert.size();
        resultRow.firstVoucherId = vouchersToInsert.isEmpty() ? null : vouchersToInsert[0].Id;
        resultRow.createdCodes = String.join(generatedCodes, '\n');
        resultRow.message = 'Created ' + vouchersToInsert.size() + ' vouchers for ' + campaignRow.Name + '.';
        return resultRow;
    }
}