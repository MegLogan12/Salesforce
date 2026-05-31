trigger VoucherTrigger on Voucher__c (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ODLVoucherCodeService.assignMissingCodes(Trigger.new);
    }
}