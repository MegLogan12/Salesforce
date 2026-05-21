public with sharing class DispatchMapController {

    public class TruckPin {
        @AuraEnabled public String  unitName;
        @AuraEnabled public String  driverName;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  appointmentNumber;
        @AuraEnabled public String  status;
        @AuraEnabled public String  schedTime;
        @AuraEnabled public String  street;
        @AuraEnabled public String  city;
        @AuraEnabled public Decimal lat;
        @AuraEnabled public Decimal lng;
        @AuraEnabled public Integer sortKey;
        @AuraEnabled public String  truckNumber;
        @AuraEnabled public String  lastSeen;
    }

    @AuraEnabled(cacheable=true)
    public static List<TruckPin> getTodayDispatch() {
        DateTime cutoff = DateTime.now().addHours(-10);
        Date     today  = Date.today();

        // Active crews with a linked vehicle that has GPS data from the last 10 hours
        List<Crew__c> crews = [
            SELECT Id, Name, Truck_Number__c,
                   Foreman__r.Name,
                   Vehicle__r.GPS_Latitude__c,
                   Vehicle__r.GPS_Longitude__c,
                   Vehicle__r.GPS_Status__c,
                   Vehicle__r.GPS_Last_Seen__c
            FROM   Crew__c
            WHERE  Active__c = true
            AND    Vehicle__c != null
            AND    Vehicle__r.GPS_Last_Seen__c >= :cutoff
            AND    Vehicle__r.GPS_Latitude__c  != null
            ORDER BY Truck_Number__c ASC
        ];

        // Collect crew IDs so we can look up today's first work order per crew
        Set<Id> crewIds = new Set<Id>();
        for (Crew__c c : crews) crewIds.add(c.Id);

        // First scheduled work order per crew today (ordered by stop sequence)
        Map<Id, WorkOrder> firstWO = new Map<Id, WorkOrder>();
        for (WorkOrder wo : [
            SELECT Id, WorkOrderNumber, Subject, Street, City, Crew__c
            FROM   WorkOrder
            WHERE  Crew__c IN :crewIds
            AND    Scheduled_Date__c = :today
            ORDER BY Stop_Sequence__c ASC NULLS LAST
            LIMIT  500
        ]) {
            if (!firstWO.containsKey(wo.Crew__c)) firstWO.put(wo.Crew__c, wo);
        }

        List<TruckPin> pins = new List<TruckPin>();
        Integer i = 0;
        for (Crew__c c : crews) {
            TruckPin p    = new TruckPin();
            p.sortKey     = i++;
            p.truckNumber = c.Truck_Number__c;
            p.unitName    = c.Name + (c.Truck_Number__c != null ? ' · T' + c.Truck_Number__c : '');
            p.driverName  = c.Foreman__r != null ? c.Foreman__r.Name : 'Unassigned';
            p.lat         = c.Vehicle__r.GPS_Latitude__c;
            p.lng         = c.Vehicle__r.GPS_Longitude__c;
            p.status      = c.Vehicle__r.GPS_Status__c != null ? c.Vehicle__r.GPS_Status__c : 'Unknown';
            if (c.Vehicle__r.GPS_Last_Seen__c != null) {
                p.lastSeen = c.Vehicle__r.GPS_Last_Seen__c.format('h:mm a', 'America/New_York');
            }

            WorkOrder wo = firstWO.get(c.Id);
            if (wo != null) {
                p.subject           = wo.Subject;
                p.appointmentNumber = wo.WorkOrderNumber;
                p.street            = wo.Street;
                p.city              = wo.City;
            } else {
                p.subject           = 'No jobs scheduled today';
                p.appointmentNumber = (String)c.Id;
            }
            pins.add(p);
        }
        return pins;
    }
}
