public with sharing class ODLVoucherCodeService {
    private static final Integer SUFFIX_LENGTH = 8;
    private static final String CODE_CHARSET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    private static final Integer MAX_GENERATION_PASSES = 25;
    private static final String DEFAULT_PREFIX = 'ODLAUTO';
    private static final String LENNAR_PREFIX = 'LENNAR';

    public static void assignMissingCodes(List<Voucher__c> voucherRows) {
        if (voucherRows == null || voucherRows.isEmpty()) {
            return;
        }

        Set<Id> campaignIds = new Set<Id>();
        Set<Id> builderIds = new Set<Id>();
        Set<String> reservedCodes = new Set<String>();
        Map<String, List<Voucher__c>> rowsByPrefix = new Map<String, List<Voucher__c>>();

        for (Voucher__c row : voucherRows) {
            if (String.isNotBlank(row.Voucher_Code__c)) {
                reservedCodes.add(row.Voucher_Code__c.trim().toUpperCase());
            }
            if (row.Campaign__c != null) {
                campaignIds.add(row.Campaign__c);
            }
            if (row.Builder_Account__c != null) {
                builderIds.add(row.Builder_Account__c);
            }
        }

        Map<Id, Campaign> campaignsById = campaignIds.isEmpty()
            ? new Map<Id, Campaign>()
            : new Map<Id, Campaign>([
                SELECT Id, Name, Builder_Account__c
                FROM Campaign
                WHERE Id IN :campaignIds
            ]);

        for (Campaign campaignRow : campaignsById.values()) {
            if (campaignRow.Builder_Account__c != null) {
                builderIds.add(campaignRow.Builder_Account__c);
            }
        }

        Map<Id, Account> buildersById = builderIds.isEmpty()
            ? new Map<Id, Account>()
            : new Map<Id, Account>([
                SELECT Id, Name
                FROM Account
                WHERE Id IN :builderIds
            ]);

        for (Voucher__c row : voucherRows) {
            if (String.isNotBlank(row.Voucher_Code__c)) {
                continue;
            }

            Campaign campaignRow = row.Campaign__c == null ? null : campaignsById.get(row.Campaign__c);
            Account builderRow = row.Builder_Account__c == null
                ? (campaignRow != null && campaignRow.Builder_Account__c != null ? buildersById.get(campaignRow.Builder_Account__c) : null)
                : buildersById.get(row.Builder_Account__c);

            String prefix = resolvePrefix(null, campaignRow == null ? null : campaignRow.Name, builderRow == null ? null : builderRow.Name);
            if (!rowsByPrefix.containsKey(prefix)) {
                rowsByPrefix.put(prefix, new List<Voucher__c>());
            }
            rowsByPrefix.get(prefix).add(row);
        }

        for (String prefix : rowsByPrefix.keySet()) {
            List<Voucher__c> rowsForPrefix = rowsByPrefix.get(prefix);
            List<String> generatedCodes = generateUniqueCodes(prefix, rowsForPrefix.size(), reservedCodes);
            for (Integer index = 0; index < rowsForPrefix.size(); index++) {
                rowsForPrefix[index].Voucher_Code__c = generatedCodes[index];
            }
            reservedCodes.addAll(generatedCodes);
        }
    }

    public static List<String> generateUniqueCodes(String requestedPrefix, Integer count, Set<String> reservedCodes) {
        if (count == null || count <= 0) {
            return new List<String>();
        }

        String prefix = normalizePrefix(requestedPrefix);
        Set<String> reserved = reservedCodes == null ? new Set<String>() : new Set<String>(reservedCodes);
        List<String> output = new List<String>();
        Integer passCount = 0;

        while (output.size() < count && passCount < MAX_GENERATION_PASSES) {
            Integer needed = count - output.size();
            Integer candidateTarget = Math.max(needed * 3, needed + 5);
            Set<String> candidateCodes = new Set<String>();

            while (candidateCodes.size() < candidateTarget) {
                String candidate = prefix + '-' + randomSuffix(SUFFIX_LENGTH);
                if (!reserved.contains(candidate)) {
                    candidateCodes.add(candidate);
                }
            }

            Set<String> existingCodes = new Set<String>();
            for (Voucher__c existingVoucher : [
                SELECT Voucher_Code__c
                FROM Voucher__c
                WHERE Voucher_Code__c IN :candidateCodes
            ]) {
                existingCodes.add(existingVoucher.Voucher_Code__c);
            }

            for (String candidate : candidateCodes) {
                if (existingCodes.contains(candidate) || reserved.contains(candidate)) {
                    continue;
                }
                output.add(candidate);
                reserved.add(candidate);
                if (output.size() == count) {
                    break;
                }
            }
            passCount++;
        }

        if (output.size() != count) {
            throw new AuraHandledException('Unable to generate a unique voucher code batch. Try again.');
        }
        return output;
    }

    public static String resolvePrefix(String explicitPrefix, String campaignName, String builderName) {
        if (String.isNotBlank(explicitPrefix)) {
            return normalizePrefix(explicitPrefix);
        }

        String campaignText = normalizeForMatch(campaignName);
        String builderText = normalizeForMatch(builderName);
        if (campaignText.contains('LENNAR') || builderText.contains('LENNAR')) {
            return LENNAR_PREFIX;
        }
        return DEFAULT_PREFIX;
    }

    private static String normalizeForMatch(String value) {
        return String.isBlank(value) ? '' : value.trim().toUpperCase();
    }

    private static String normalizePrefix(String value) {
        String raw = String.isBlank(value) ? DEFAULT_PREFIX : value.trim().toUpperCase();
        String normalized = raw.replaceAll('[^A-Z0-9]', '');
        if (String.isBlank(normalized)) {
            normalized = DEFAULT_PREFIX;
        }
        return normalized.length() > 12 ? normalized.substring(0, 12) : normalized;
    }

    private static String randomSuffix(Integer lengthValue) {
        String suffix = '';
        Integer charsetSize = CODE_CHARSET.length();
        while (suffix.length() < lengthValue) {
            Integer index = Math.mod(Crypto.getRandomInteger(), charsetSize);
            if (index < 0) {
                index += charsetSize;
            }
            suffix += CODE_CHARSET.substring(index, index + 1);
        }
        return suffix;
    }
}