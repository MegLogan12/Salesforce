public with sharing class DispatchMapController {

    public class TruckPin {
        @AuraEnabled public String unitName;
        @AuraEnabled public String driverName;
        @AuraEnabled public String subject;
        @AuraEnabled public String appointmentNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String schedTime;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public Decimal lat;
        @AuraEnabled public Decimal lng;
        @AuraEnabled public Integer sortKey;
    }

    @AuraEnabled(cacheable=true)
    public static List<TruckPin> getTodayDispatch() {
        Datetime startOfDay = Datetime.newInstance(Date.today(), Time.newInstance(0,0,0,0));
        Datetime endOfDay   = Datetime.newInstance(Date.today(), Time.newInstance(23,59,59,0));

        List<AssignedResource> rows = [
            SELECT ServiceAppointmentId,
                   ServiceResource.Name, ServiceResource.ResourceType,
                   ServiceAppointment.Subject,
                   ServiceAppointment.AppointmentNumber,
                   ServiceAppointment.Status,
                   ServiceAppointment.SchedStartTime,
                   ServiceAppointment.Street,
                   ServiceAppointment.City,
                   ServiceAppointment.Latitude,
                   ServiceAppointment.Longitude
            FROM   AssignedResource
            WHERE  ServiceAppointment.SchedStartTime >= :startOfDay
            AND    ServiceAppointment.SchedStartTime <= :endOfDay
            AND    ServiceResource.ResourceType IN ('C','T')
            ORDER BY ServiceAppointment.SchedStartTime, ServiceResource.ResourceType
        ];

        Map<Id, TruckPin> pins = new Map<Id, TruckPin>();
        Integer i = 0;
        for (AssignedResource ar : rows) {
            Id saId = ar.ServiceAppointmentId;
            if (!pins.containsKey(saId)) {
                TruckPin p          = new TruckPin();
                p.subject           = ar.ServiceAppointment.Subject;
                p.appointmentNumber = ar.ServiceAppointment.AppointmentNumber;
                p.status            = ar.ServiceAppointment.Status;
                p.street            = ar.ServiceAppointment.Street;
                p.city              = ar.ServiceAppointment.City;
                p.lat               = ar.ServiceAppointment.Latitude;
                p.lng               = ar.ServiceAppointment.Longitude;
                p.sortKey           = i++;
                if (ar.ServiceAppointment.SchedStartTime != null) {
                    p.schedTime = ar.ServiceAppointment.SchedStartTime
                                    .format('h:mm a', 'America/New_York');
                }
                pins.put(saId, p);
            }
            TruckPin p = pins.get(saId);
            if ('C' == ar.ServiceResource.ResourceType) {
                p.unitName   = ar.ServiceResource.Name;
            } else {
                p.driverName = ar.ServiceResource.Name;
            }
        }

        return pins.values();
    }
}
