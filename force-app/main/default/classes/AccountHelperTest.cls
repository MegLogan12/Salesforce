@isTest
private class AccountHelperTest {

    @TestSetup
    static void makeData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 1; i <= 15; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;
    }

    @isTest
    static void getRecentAccounts_returnsUpToRequestedLimit() {
        List<Account> result = AccountHelper.getRecentAccounts(5);
        Assert.areEqual(5, result.size(), 'Should return exactly the requested limit');
    }

    @isTest
    static void getRecentAccounts_nullLimit_defaultsToTen() {
        List<Account> result = AccountHelper.getRecentAccounts(null);
        Assert.areEqual(10, result.size(), 'Null limit should default to 10');
    }

    @isTest
    static void getRecentAccounts_zeroLimit_defaultsToTen() {
        List<Account> result = AccountHelper.getRecentAccounts(0);
        Assert.areEqual(10, result.size(), 'Zero limit should default to 10');
    }

    @isTest
    static void getRecentAccounts_negativeLimit_defaultsToTen() {
        List<Account> result = AccountHelper.getRecentAccounts(-5);
        Assert.areEqual(10, result.size(), 'Negative limit should default to 10');
    }

    @isTest
    static void getRecentAccounts_limitLargerThanRecordCount_returnsAllRecords() {
        List<Account> result = AccountHelper.getRecentAccounts(100);
        Assert.areEqual(15, result.size(), 'Should return all records when limit exceeds total count');
    }

    @isTest
    static void getRecentAccounts_returnsAccountFields() {
        List<Account> result = AccountHelper.getRecentAccounts(1);
        Assert.isNotNull(result[0].Id, 'Id should be populated');
        Assert.isNotNull(result[0].Name, 'Name should be populated');
        Assert.isNotNull(result[0].CreatedDate, 'CreatedDate should be populated');
    }

    @isTest
    static void getRecentAccounts_orderedByCreatedDateDescending() {
        List<Account> result = AccountHelper.getRecentAccounts(15);
        for (Integer i = 0; i < result.size() - 1; i++) {
            Assert.isTrue(
                result[i].CreatedDate >= result[i + 1].CreatedDate,
                'Records should be ordered by CreatedDate descending'
            );
        }
    }
}