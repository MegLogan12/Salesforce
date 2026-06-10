public with sharing class AccountHelper {
    public static List<Account> getRecentAccounts(Integer limitSize) {
        Integer safeLimit = limitSize == null || limitSize <= 0 ? 10 : limitSize;

        return [
            SELECT Id, Name, CreatedDate
            FROM Account
            ORDER BY CreatedDate DESC
            LIMIT :safeLimit
        ];
    }
}