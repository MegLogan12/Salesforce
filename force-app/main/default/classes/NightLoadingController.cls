/**
 * NightLoadingController
 * Backend for Screen 25 — Night Loading Queue.
 * Returns Loading_Ticket__c records for today and tomorrow, grouped for
 * display.  Provides a write method to mark a ticket as Loaded.
 */
public with sharing class NightLoadingController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class TruckRow {
        @AuraEnabled public Id      ticketId;
        @AuraEnabled public String  ticketName;
        @AuraEnabled public String  truckNumber;
        @AuraEnabled public String  crewName;
        @AuraEnabled public String  fmAssignment;
        @AuraEnabled public Date    scheduledDate;
        @AuraEnabled public String  status;
        @AuraEnabled public Boolean isLoaded;
        @AuraEnabled public Integer plantsExpected;
        @AuraEnabled public Decimal sodExpected;
    }

    public class NightLoadingView {
        @AuraEnabled public Integer       totalTrucks;
        @AuraEnabled public Integer       loadedCount;
        @AuraEnabled public Integer       pendingCount;
        @AuraEnabled public List<TruckRow> trucks;
    }

    // ─── Public API ──────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static NightLoadingView getLoadingQueue() {
        if (!Schema.sObjectType.Loading_Ticket__c.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to Loading Ticket records.'
            );
        }
        List<Loading_Ticket__c> tickets = [
            SELECT Id, Name, Truck_Number__c,
                   Crew__c,
                   FM_Assignment__c, FM_Assignment__r.Name,
                   Scheduled_Date__c, Status__c,
                   Plants_Expected__c, Sod_Sqft_Expected__c
            FROM   Loading_Ticket__c
            WHERE  Scheduled_Date__c >= :Date.today()
            AND    Scheduled_Date__c <= :Date.today().addDays(1)
            ORDER BY Truck_Number__c
        ];
        return buildView(tickets);
    }

    @AuraEnabled
    public static void markLoaded(Id ticketId) {
        if (!Schema.sObjectType.Loading_Ticket__c.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to Loading Ticket records.'
            );
        }
        if (!Schema.sObjectType.Loading_Ticket__c.isUpdateable()) {
            throw new AuraHandledException(
                'Insufficient permission to update Loading Ticket records.'
            );
        }
        update new Loading_Ticket__c(Id = ticketId, Status__c = 'Loaded');
    }

    // ─── Testable builder ────────────────────────────────────────────────────

    @TestVisible
    private static NightLoadingView buildView(List<Loading_Ticket__c> tickets) {
        NightLoadingView view  = new NightLoadingView();
        view.trucks            = new List<TruckRow>();
        Integer loadedCnt      = 0;
        Integer pendingCnt     = 0;

        for (Loading_Ticket__c t : tickets) {
            TruckRow row        = new TruckRow();
            row.ticketId        = t.Id;
            row.ticketName      = t.Name;
            row.truckNumber     = t.Truck_Number__c != null ? String.valueOf(t.Truck_Number__c.intValue()) : null;
            row.crewName        = String.isNotBlank(t.Crew__c) ? t.Crew__c : null;
            row.fmAssignment    = t.FM_Assignment__r != null ? t.FM_Assignment__r.Name : null;
            row.scheduledDate   = t.Scheduled_Date__c;
            row.status          = t.Status__c;
            row.isLoaded        = (t.Status__c == 'Loaded' || t.Status__c == 'Submitted');
            row.plantsExpected  = t.Plants_Expected__c != null
                ? Integer.valueOf(t.Plants_Expected__c)
                : 0;
            row.sodExpected     = t.Sod_Sqft_Expected__c != null
                ? t.Sod_Sqft_Expected__c
                : 0;

            if (row.isLoaded) {
                loadedCnt++;
            } else {
                pendingCnt++;
            }
            view.trucks.add(row);
        }

        view.totalTrucks  = view.trucks.size();
        view.loadedCount  = loadedCnt;
        view.pendingCount = pendingCnt;
        return view;
    }
}
