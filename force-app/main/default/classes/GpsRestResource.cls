/**
 * GpsRestResource
 * REST endpoint for the crew mobile flow.
 *
 *   POST /services/apexrest/loving/gps/beginDrive
 *     body: { "workOrderId": "0WOxxx", "lat": 35.227, "lng": -80.843 }
 *
 *   POST /services/apexrest/loving/gps/ping
 *     body: { "workOrderId": "0WOxxx", "lat": 35.227, "lng": -80.843 }
 *
 * Mobile app (LWC or native) calls these on the crew's device. The "ping"
 * endpoint is hit every 60–120 seconds while in transit; it auto-transitions
 * the Work Order to 'In Progress' when the device is within
 * Geofence_Radius_M__c of the lot (default 150m).
 */
@RestResource(urlMapping='/loving/gps/*')
global with sharing class GpsRestResource {

    global class GpsRequest {
        public String workOrderId;
        public Decimal lat;
        public Decimal lng;
    }

    global class GpsResponse {
        public Boolean success;
        public String  status;
        public String  message;
        public Id      workOrderId;
        public DateTime arrivedAt;
    }

    @HttpPost
    global static GpsResponse handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        GpsResponse out = new GpsResponse();
        try {
            String action = req.requestURI.substringAfterLast('/');
            String body   = req.requestBody == null ? '' : req.requestBody.toString();
            GpsRequest gr = (GpsRequest) JSON.deserialize(body, GpsRequest.class);
            if (gr == null || String.isBlank(gr.workOrderId)) {
                out.success = false; out.message = 'workOrderId is required';
                res.statusCode = 400; return out;
            }

            WorkOrder wo;
            if (action == 'beginDrive') {
                wo = GpsTransitionService.beginDrive(Id.valueOf(gr.workOrderId), gr.lat, gr.lng);
            } else if (action == 'ping') {
                wo = GpsTransitionService.gpsPing(Id.valueOf(gr.workOrderId), gr.lat, gr.lng);
            } else {
                out.success = false; out.message = 'Unknown action: ' + action;
                res.statusCode = 404; return out;
            }

            out.success      = true;
            out.workOrderId  = wo.Id;
            out.status       = wo.Status__c;
            out.arrivedAt    = wo.Arrived_At__c;
            out.message      = (wo.Arrived_At__c != null && action == 'ping')
                               ? 'Arrived on site — status set to In Progress'
                               : 'OK';
            res.statusCode = 200;
            return out;
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
            res.statusCode = 500;
            ErrorLogService.log('GpsRestResource','handlePost',null,e.getMessage());
            return out;
        }
    }
}