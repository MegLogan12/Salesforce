public with sharing class LovingTakeoffGateController {

    public class KpiDTO {
        @AuraEnabled public Integer totalTakeoffs;
        @AuraEnabled public Integer returned;
        @AuraEnabled public Integer matched;
        @AuraEnabled public Integer submitted;
    }

    public class TakeoffDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String poId;
        @AuraEnabled public String poName;
        @AuraEnabled public String poStatus;
        @AuraEnabled public String communityName;
        @AuraEnabled public String lotName;
        @AuraEnabled public String divisionName;
        @AuraEnabled public String packageCode;
        @AuraEnabled public String takeoffStatusOnPO;
        @AuraEnabled public Boolean csApproved;
        @AuraEnabled public String exceptionReason;
        @AuraEnabled public String approvedByName;
        @AuraEnabled public String approvedDate;
        @AuraEnabled public String fmName;
        @AuraEnabled public String notes;
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public Integer nfiCount;
        @AuraEnabled public String nfiReason;
        @AuraEnabled public Boolean checklistComplete;
        @AuraEnabled public Boolean eight11Confirmed;
        @AuraEnabled public Boolean canApprove;
        @AuraEnabled public Boolean canCreateWo;
        @AuraEnabled public List<LineItemDTO> lineItems;
        @AuraEnabled public List<GateStepDTO> gates;
    }

    public class LineItemDTO {
        @AuraEnabled public String lineName;
        @AuraEnabled public String poQty;
        @AuraEnabled public String measuredQty;
        @AuraEnabled public String unit;
        @AuraEnabled public String decision;
    }

    public class GateStepDTO {
        @AuraEnabled public Integer stepNum;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public String state;
    }

    public class ActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static KpiDTO getKpiSummary() {
        KpiDTO kpi = new KpiDTO();
        kpi.totalTakeoffs = [SELECT COUNT() FROM Takeoff__c];
        kpi.returned = [SELECT COUNT() FROM Takeoff__c WHERE Status__c = 'Returned'];
        kpi.matched = [SELECT COUNT() FROM Takeoff__c WHERE Status__c = 'Approved'];
        kpi.submitted = [SELECT COUNT() FROM Takeoff__c WHERE Status__c = 'Submitted'];
        return kpi;
    }

    @AuraEnabled(cacheable=true)
    public static TakeoffDTO getTakeoffRecord(String takeoffId) {
        if (String.isBlank(takeoffId)) return null;

        List<Takeoff__c> records = [
            SELECT Id, Name, Status__c, Notes__c, NFI_Count__c, NFI_Reason__c,
                   Photo_Count__c, Checklist_Complete__c, Eight11_Confirmed__c,
                   Sod_Sqft__c, Sod_Measured_Sqft__c,
                   Plants_Count__c, Trees_Count__c,
                   Mulch_Measured_CY__c, Irrigation_Zones__c,
                   Approved_Date__c, Approved_By__c, Approved_By__r.Name,
                   Submitted_Date__c,
                   FM_Assignment__c, FM_Assignment__r.Name,
                   Community__c, Community__r.Name,
                   Lot__c, Lot__r.Name,
                   Purchase_Order__c, Purchase_Order__r.Name, Purchase_Order__r.Status__c,
                   Purchase_Order__r.Takeoff_Status__c,
                   Purchase_Order__r.Approval_Process_Completed__c,
                   Purchase_Order__r.Exception_Reason__c,
                   Purchase_Order__r.BMG_Package_Code__c,
                   Purchase_Order__r.Division_Name__c,
                   Purchase_Order__r.PO_Amount__c,
                   Purchase_Order__r.Work_Order__c
            FROM Takeoff__c
            WHERE Id = :takeoffId
            LIMIT 1
        ];

        if (records.isEmpty()) return null;
        Takeoff__c t = records[0];

        TakeoffDTO dto = new TakeoffDTO();
        dto.id = t.Id;
        dto.name = t.Name;
        dto.status = t.Status__c;
        dto.notes = t.Notes__c;
        dto.photoCount = t.Photo_Count__c != null ? Integer.valueOf(t.Photo_Count__c) : 0;
        dto.nfiCount = t.NFI_Count__c != null ? Integer.valueOf(t.NFI_Count__c) : 0;
        dto.nfiReason = t.NFI_Reason__c;
        dto.checklistComplete = t.Checklist_Complete__c == true;
        dto.eight11Confirmed = t.Eight11_Confirmed__c == true;
        dto.approvedByName = t.Approved_By__c != null ? t.Approved_By__r.Name : null;
        dto.approvedDate = t.Approved_Date__c != null ? String.valueOf(t.Approved_Date__c) : null;
        dto.fmName = t.FM_Assignment__c != null ? t.FM_Assignment__r.Name : null;
        dto.communityName = t.Community__c != null ? t.Community__r.Name : null;
        dto.lotName = t.Lot__c != null ? t.Lot__r.Name : null;

        if (t.Purchase_Order__c != null) {
            dto.poId = t.Purchase_Order__c;
            dto.poName = t.Purchase_Order__r.Name;
            dto.poStatus = t.Purchase_Order__r.Status__c;
            dto.packageCode = t.Purchase_Order__r.BMG_Package_Code__c;
            dto.divisionName = t.Purchase_Order__r.Division_Name__c;
            dto.takeoffStatusOnPO = t.Purchase_Order__r.Takeoff_Status__c;
            dto.csApproved = t.Purchase_Order__r.Approval_Process_Completed__c == true;
            dto.exceptionReason = t.Purchase_Order__r.Exception_Reason__c;
        } else {
            dto.csApproved = false;
        }

        dto.lineItems = buildLineItems(t);
        dto.gates = buildGates(t, dto);

        dto.canApprove = dto.checklistComplete
            && dto.photoCount > 0
            && dto.eight11Confirmed
            && t.Status__c != 'Approved'
            && dto.exceptionReason == null;

        dto.canCreateWo = t.Status__c == 'Approved'
            && dto.csApproved == true
            && t.Purchase_Order__c != null
            && t.Purchase_Order__r.Work_Order__c != null;

        return dto;
    }

    @AuraEnabled
    public static ActionResult approveTakeoff(String takeoffId) {
        ActionResult result = new ActionResult();
        try {
            Takeoff__c check = [
                SELECT Id, Status__c, Checklist_Complete__c, Photo_Count__c,
                       Eight11_Confirmed__c, Purchase_Order__c,
                       Purchase_Order__r.Exception_Reason__c,
                       Purchase_Order__r.Work_Order__c
                FROM Takeoff__c WHERE Id = :takeoffId LIMIT 1
            ];
            if (check.Status__c == 'Approved') {
                result.success = false;
                result.message = 'Takeoff is already approved.';
                return result;
            }
            if (check.Checklist_Complete__c != true) {
                result.success = false;
                result.message = 'Cannot approve: checklist is not complete.';
                return result;
            }
            if (check.Photo_Count__c == null || check.Photo_Count__c < 1) {
                result.success = false;
                result.message = 'Cannot approve: at least one photo is required.';
                return result;
            }
            if (check.Eight11_Confirmed__c != true) {
                result.success = false;
                result.message = 'Cannot approve: 811 utility locate has not been confirmed.';
                return result;
            }
            if (check.Purchase_Order__r.Exception_Reason__c != null) {
                result.success = false;
                result.message = 'Cannot approve: Purchase Order has an unresolved exception. Resolve the PO exception first.';
                return result;
            }
            update new Takeoff__c(
                Id = takeoffId,
                Status__c = 'Approved',
                Approved_Date__c = Datetime.now(),
                Approved_By__c = UserInfo.getUserId()
            );
            if (check.Purchase_Order__c != null) {
                update new Purchase_Order__c(
                    Id = check.Purchase_Order__c,
                    Status__c = 'Takeoff Complete',
                    Takeoff_Status__c = 'Approved',
                    Pipeline_Stage__c = PurchaseOrderTimingService.STAGE_TAKEOFF_COMPLETE,
                    Pipeline_Bucket__c = 'Clear for Schedule'
                );
            }

            Integer createdScopeRows = 0;
            if (check.Purchase_Order__c != null && check.Purchase_Order__r.Work_Order__c != null) {
                createdScopeRows = LovingPoBackboneService.materializeApprovedWorkScope(takeoffId);
            }

            result.success = true;
            result.message = createdScopeRows > 0
                ? 'Takeoff approved. Standard WorkOrder scope generated and the Builder PO is ready for WorkOrder handoff.'
                : 'Takeoff approved. Builder PO is ready for WorkOrder handoff.';
        } catch (Exception e) {
            result.success = false;
            result.message = e.getMessage();
        }
        return result;
    }

    @AuraEnabled
    public static ActionResult returnTakeoff(String takeoffId, String nfiReason) {
        ActionResult result = new ActionResult();
        if (String.isBlank(nfiReason)) {
            result.success = false;
            result.message = 'NFI reason is required before returning a Takeoff.';
            return result;
        }
        try {
            Takeoff__c t = [
                SELECT Id, NFI_Count__c, Purchase_Order__c
                FROM Takeoff__c WHERE Id = :takeoffId LIMIT 1
            ];
            Integer currentCount = t.NFI_Count__c != null ? Integer.valueOf(t.NFI_Count__c) : 0;
            update new Takeoff__c(
                Id = takeoffId,
                Status__c = 'Returned',
                NFI_Reason__c = nfiReason,
                NFI_Count__c = currentCount + 1
            );
            if (t.Purchase_Order__c != null) {
                update new Purchase_Order__c(
                    Id = t.Purchase_Order__c,
                    Takeoff_Status__c = 'In Progress'
                );
            }
            result.success = true;
            result.message = 'Takeoff returned for corrections. NFI count incremented.';
        } catch (Exception e) {
            result.success = false;
            result.message = e.getMessage();
        }
        return result;
    }

    private static List<LineItemDTO> buildLineItems(Takeoff__c t) {
        List<LineItemDTO> lines = new List<LineItemDTO>();

        List<Takeoff_Line__c> persistedLines = [
            SELECT Id, Item_Name__c, Item_Description__c, PO_Quantity__c, PO_Qty__c,
                   Measured_Quantity__c, Measured_Qty__c, Verified_Quantity__c, Verified_Qty__c,
                   Unit__c, Determination__c
            FROM Takeoff_Line__c
            WHERE Takeoff__c = :t.Id
            ORDER BY CreatedDate ASC
        ];
        if (!persistedLines.isEmpty()) {
            for (Takeoff_Line__c row : persistedLines) {
                LineItemDTO li = new LineItemDTO();
                li.lineName = firstNonBlank(new List<String>{ row.Item_Name__c, row.Item_Description__c, 'Line Item' });
                li.poQty = decimalToText(coalesceDecimal(row.PO_Quantity__c, row.PO_Qty__c));
                li.measuredQty = decimalToText(coalesceDecimal(row.Verified_Quantity__c, row.Verified_Qty__c, row.Measured_Quantity__c, row.Measured_Qty__c));
                li.unit = String.isNotBlank(row.Unit__c) ? row.Unit__c : '--';
                li.decision = String.isNotBlank(row.Determination__c)
                    ? row.Determination__c
                    : compareQty(coalesceDecimal(row.Verified_Quantity__c, row.Verified_Qty__c, row.Measured_Quantity__c, row.Measured_Qty__c),
                                 coalesceDecimal(row.PO_Quantity__c, row.PO_Qty__c));
                lines.add(li);
            }
            return lines;
        }

        if (t.Sod_Measured_Sqft__c != null || t.Sod_Sqft__c != null) {
            LineItemDTO li = new LineItemDTO();
            li.lineName = 'Sod';
            li.measuredQty = t.Sod_Measured_Sqft__c != null
                ? String.valueOf(Integer.valueOf(t.Sod_Measured_Sqft__c)) : '--';
            li.poQty = t.Sod_Sqft__c != null
                ? String.valueOf(Integer.valueOf(t.Sod_Sqft__c)) : '--';
            li.unit = 'sf';
            li.decision = compareQty(t.Sod_Measured_Sqft__c, t.Sod_Sqft__c);
            lines.add(li);
        }

        if (t.Plants_Count__c != null) {
            LineItemDTO li = new LineItemDTO();
            li.lineName = 'Plants';
            li.measuredQty = String.valueOf(Integer.valueOf(t.Plants_Count__c));
            li.poQty = '--';
            li.unit = 'ea';
            li.decision = 'Review';
            lines.add(li);
        }

        if (t.Trees_Count__c != null) {
            LineItemDTO li = new LineItemDTO();
            li.lineName = 'Trees';
            li.measuredQty = String.valueOf(Integer.valueOf(t.Trees_Count__c));
            li.poQty = '--';
            li.unit = 'ea';
            li.decision = 'Review';
            lines.add(li);
        }

        if (t.Mulch_Measured_CY__c != null) {
            LineItemDTO li = new LineItemDTO();
            li.lineName = 'Mulch';
            li.measuredQty = String.valueOf(t.Mulch_Measured_CY__c);
            li.poQty = '--';
            li.unit = 'cy';
            li.decision = 'Review';
            lines.add(li);
        }

        if (t.Irrigation_Zones__c != null) {
            LineItemDTO li = new LineItemDTO();
            li.lineName = 'Irrigation Zones';
            li.measuredQty = String.valueOf(Integer.valueOf(t.Irrigation_Zones__c));
            li.poQty = '--';
            li.unit = 'zones';
            li.decision = 'Review';
            lines.add(li);
        }

        return lines;
    }

    private static Decimal coalesceDecimal(Decimal firstVal, Decimal secondVal) {
        return firstVal != null ? firstVal : secondVal;
    }

    private static Decimal coalesceDecimal(Decimal firstVal, Decimal secondVal, Decimal thirdVal, Decimal fourthVal) {
        if (firstVal != null) return firstVal;
        if (secondVal != null) return secondVal;
        if (thirdVal != null) return thirdVal;
        return fourthVal;
    }

    private static String decimalToText(Decimal value) {
        return value == null ? '--' : String.valueOf(value.stripTrailingZeros());
    }

    private static String firstNonBlank(List<String> values) {
        for (String value : values) {
            if (String.isNotBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String compareQty(Decimal measured, Decimal po) {
        if (measured == null) return 'Missing';
        if (po == null) return 'Review';
        Decimal diff = Math.abs(measured - po);
        Decimal pct = po > 0 ? (diff / po) * 100 : 0;
        return pct <= 5 ? 'Match' : 'Mismatch';
    }

    private static List<GateStepDTO> buildGates(Takeoff__c t, TakeoffDTO dto) {
        List<GateStepDTO> gates = new List<GateStepDTO>();
        Boolean priorDone = true;

        Boolean gate1Done = t.Purchase_Order__c != null && t.Lot__c != null;
        gates.add(makeGate(1, 'PO matched to lot',
            'Division, Community, Lot, and requested date confirmed.',
            gate1Done ? 'done' : 'active'));
        priorDone = gate1Done;

        Boolean gate2Done = String.isNotBlank(dto.packageCode);
        gates.add(makeGate(2, 'Package selected',
            'Standard / corner / custom package confirmed.',
            gate2Done ? 'done' : (priorDone ? 'active' : 'pending')));
        priorDone = priorDone && gate2Done;

        Boolean gate3Done = String.isBlank(dto.exceptionReason);
        gates.add(makeGate(3, 'BMG prices matched',
            'All billable scope has approved pricing. Exception reason is blank.',
            gate3Done ? 'done' : (priorDone ? 'active' : 'pending')));
        priorDone = priorDone && gate3Done;

        Boolean gate4Done = t.Status__c == 'Approved';
        gates.add(makeGate(4, 'Takeoff approved',
            'Checklist complete, photos attached, CS reviewed and approved.',
            gate4Done ? 'done' : (priorDone ? 'active' : 'pending')));
        priorDone = priorDone && gate4Done;

        Boolean gate5Done = dto.canCreateWo == true;
        gates.add(makeGate(5, 'Work Order creation',
            'Standard Work Order scope can be generated from this approved Takeoff.',
            gate5Done ? 'done' : (priorDone ? 'active' : 'pending')));

        return gates;
    }

    private static GateStepDTO makeGate(Integer num, String title, String gateDesc, String state) {
        GateStepDTO g = new GateStepDTO();
        g.stepNum = num;
        g.title = title;
        g.description = gateDesc;
        g.state = state;
        return g;
    }
}