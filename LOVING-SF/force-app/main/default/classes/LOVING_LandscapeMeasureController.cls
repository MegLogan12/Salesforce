public with sharing class LOVING_LandscapeMeasureController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWorkOrderData(Id workOrderId) {
        WorkOrder wo = [
            SELECT Id,
                   AccountId,
                   Account.BillingStreet,
                   Account.BillingCity,
                   Account.BillingState,
                   Account.BillingPostalCode,
                   Account.BillingLatitude,
                   Account.BillingLongitude,
                   Takeoff_Sod_Sqft__c,
                   Takeoff_Bed_Sqft__c,
                   Takeoff_Linear_Ft__c,
                   Takeoff_Shrubs_1G__c,
                   Takeoff_Shrubs_3G__c,
                   Takeoff_Shrubs_7G__c,
                   Takeoff_Trees_15G__c,
                   Takeoff_Trees_30G__c,
                   Takeoff_Trees_45G__c,
                   Takeoff_Lighting_Units__c,
                   Takeoff_Slope_Pct__c,
                   Takeoff_Grading_Notes__c,
                   Takeoff_Map_Data__c,
                   Takeoff_Complete__c,
                   Takeoff_Date__c
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        String streetAddress = wo.Account?.BillingStreet;

        return new Map<String, Object>{
            'id'             => wo.Id,
            'streetAddress'  => streetAddress,
            'city'           => wo.Account?.BillingCity,
            'state'          => wo.Account?.BillingState,
            'zip'            => wo.Account?.BillingPostalCode,
            'lat'            => wo.Account?.BillingLatitude,
            'lng'            => wo.Account?.BillingLongitude,
            'sodSqft'        => wo.Takeoff_Sod_Sqft__c,
            'bedSqft'        => wo.Takeoff_Bed_Sqft__c,
            'linearFt'       => wo.Takeoff_Linear_Ft__c,
            'shrubs1G'       => wo.Takeoff_Shrubs_1G__c,
            'shrubs3G'       => wo.Takeoff_Shrubs_3G__c,
            'shrubs7G'       => wo.Takeoff_Shrubs_7G__c,
            'trees15G'       => wo.Takeoff_Trees_15G__c,
            'trees30G'       => wo.Takeoff_Trees_30G__c,
            'trees45G'       => wo.Takeoff_Trees_45G__c,
            'lights'         => wo.Takeoff_Lighting_Units__c,
            'slopePct'       => wo.Takeoff_Slope_Pct__c,
            'gradingNotes'   => wo.Takeoff_Grading_Notes__c,
            'mapData'        => wo.Takeoff_Map_Data__c,
            'takeoffComplete' => wo.Takeoff_Complete__c
        };
    }

    @AuraEnabled
    public static void saveTakeoffMeasurements(Id workOrderId, String measureDataJson) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(measureDataJson);

        WorkOrder wo = new WorkOrder(Id = workOrderId);

        if (data.containsKey('sodSqft') && data.get('sodSqft') != null) {
            wo.Takeoff_Sod_Sqft__c = toDecimal(data.get('sodSqft'));
        }
        if (data.containsKey('bedSqft') && data.get('bedSqft') != null) {
            wo.Takeoff_Bed_Sqft__c = toDecimal(data.get('bedSqft'));
        }
        if (data.containsKey('linearFt') && data.get('linearFt') != null) {
            wo.Takeoff_Linear_Ft__c = toDecimal(data.get('linearFt'));
        }
        if (data.containsKey('shrubs1G') && data.get('shrubs1G') != null) {
            wo.Takeoff_Shrubs_1G__c = toDecimal(data.get('shrubs1G'));
        }
        if (data.containsKey('shrubs3G') && data.get('shrubs3G') != null) {
            wo.Takeoff_Shrubs_3G__c = toDecimal(data.get('shrubs3G'));
        }
        if (data.containsKey('shrubs7G') && data.get('shrubs7G') != null) {
            wo.Takeoff_Shrubs_7G__c = toDecimal(data.get('shrubs7G'));
        }
        if (data.containsKey('trees15G') && data.get('trees15G') != null) {
            wo.Takeoff_Trees_15G__c = toDecimal(data.get('trees15G'));
        }
        if (data.containsKey('trees30G') && data.get('trees30G') != null) {
            wo.Takeoff_Trees_30G__c = toDecimal(data.get('trees30G'));
        }
        if (data.containsKey('trees45G') && data.get('trees45G') != null) {
            wo.Takeoff_Trees_45G__c = toDecimal(data.get('trees45G'));
        }
        if (data.containsKey('lights') && data.get('lights') != null) {
            wo.Takeoff_Lighting_Units__c = toDecimal(data.get('lights'));
        }
        if (data.containsKey('slopePct') && data.get('slopePct') != null) {
            wo.Takeoff_Slope_Pct__c = toDecimal(data.get('slopePct'));
        }
        if (data.containsKey('gradingNotes')) {
            wo.Takeoff_Grading_Notes__c = (String) data.get('gradingNotes');
        }
        if (data.containsKey('geoJson')) {
            wo.Takeoff_Map_Data__c = (String) data.get('geoJson');
        }

        wo.Takeoff_Complete__c = true;
        wo.Takeoff_Date__c     = Date.today();

        update wo;
    }

    private static Decimal toDecimal(Object val) {
        if (val == null) return null;
        return Decimal.valueOf(String.valueOf(val));
    }
}
