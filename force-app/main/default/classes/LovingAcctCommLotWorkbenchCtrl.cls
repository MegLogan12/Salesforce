public with sharing class LovingAcctCommLotWorkbenchCtrl {
    @AuraEnabled(cacheable=true)
    public static LovingAcctCommLotWorkbenchSvc.WorkbenchData getWorkbenchData(String filtersJson) {
        return LovingAcctCommLotWorkbenchSvc.getWorkbenchData(filtersJson);
    }

    @AuraEnabled(cacheable=true)
    public static LovingAcctCommLotWorkbenchSvc.WorkbenchData searchHierarchy(String searchTerm) {
        return LovingAcctCommLotWorkbenchSvc.searchHierarchy(searchTerm);
    }

    @AuraEnabled(cacheable=true)
    public static LovingAcctCommLotWorkbenchSvc.SummaryDTO getParentSummary(Id parentAccountId) {
        return LovingAcctCommLotWorkbenchSvc.getParentSummary(parentAccountId);
    }

    @AuraEnabled(cacheable=true)
    public static LovingAcctCommLotWorkbenchSvc.SummaryDTO getDivisionSummary(Id divisionAccountId) {
        return LovingAcctCommLotWorkbenchSvc.getDivisionSummary(divisionAccountId);
    }

    @AuraEnabled(cacheable=true)
    public static LovingAcctCommLotWorkbenchSvc.SummaryDTO getCommunitySummary(Id communityId) {
        return LovingAcctCommLotWorkbenchSvc.getCommunitySummary(communityId);
    }

    @AuraEnabled(cacheable=true)
    public static LovingAcctCommLotWorkbenchSvc.SummaryDTO getLotSummary(Id lotId) {
        return LovingAcctCommLotWorkbenchSvc.getLotSummary(lotId);
    }

    @AuraEnabled(cacheable=true)
    public static LovingAcctCommLotWorkbenchSvc.PackageSummaryDTO getPackageMatchSummary(Id contextId) {
        return LovingAcctCommLotWorkbenchSvc.getPackageMatchSummary(contextId);
    }
}