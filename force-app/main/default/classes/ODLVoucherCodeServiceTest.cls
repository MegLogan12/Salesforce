@IsTest
private class ODLVoucherCodeServiceTest {
    @IsTest
    static void generatesRequestedBatchWithLennarPrefix() {
        List<String> codes = ODLVoucherCodeService.generateUniqueCodes('lennar', 5, new Set<String>{ 'LENNAR-ABCDEFGH' });
        System.assertEquals(5, codes.size());

        Set<String> seen = new Set<String>();
        for (String codeValue : codes) {
            System.assert(codeValue.startsWith('LENNAR-'));
            System.assertEquals(15, codeValue.length());
            System.assert(!seen.contains(codeValue), 'Codes should be unique inside the generated batch.');
            seen.add(codeValue);
        }
    }

    @IsTest
    static void assignsMissingCodesBeforeInsert() {
        Account builder = new Account(Name = 'Lennar Homes');
        insert builder;

        Campaign campaignRow = new Campaign(
            Name = 'Lennar Voucher',
            Status = 'In Progress',
            Type = 'Website Direct',
            IsActive = true,
            Builder_Account__c = builder.Id
        );
        insert campaignRow;

        Voucher__c voucherOne = new Voucher__c(
            Campaign__c = campaignRow.Id,
            Builder_Account__c = builder.Id,
            Status__c = 'Active',
            Voucher_Type__c = 'Standard Grilling Island'
        );
        Voucher__c voucherTwo = new Voucher__c(
            Campaign__c = campaignRow.Id,
            Builder_Account__c = builder.Id,
            Status__c = 'Active',
            Voucher_Type__c = 'Standard Grilling Island'
        );

        Test.startTest();
        insert new List<Voucher__c>{ voucherOne, voucherTwo };
        Test.stopTest();

        List<Voucher__c> insertedRows = [
            SELECT Voucher_Code__c
            FROM Voucher__c
            WHERE Id IN :new List<Id>{ voucherOne.Id, voucherTwo.Id }
        ];
        System.assertEquals(2, insertedRows.size());
        System.assertNotEquals(insertedRows[0].Voucher_Code__c, insertedRows[1].Voucher_Code__c);
        for (Voucher__c row : insertedRows) {
            System.assert(row.Voucher_Code__c.startsWith('LENNAR-'));
            System.assertEquals(15, row.Voucher_Code__c.length());
        }
    }
}