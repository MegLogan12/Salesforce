/**
 * LovingWorkOrderLineItemService
 *
 * Builds LineItemDTO records from Takeoff_Line__c records associated with a
 * Work Order via its Takeoff__c lookup.
 *
 * Field availability notes (as of current data model):
 *   - Takeoff_Line__c.Product__c         — NOT YET CREATED; uses Item_Description__c
 *   - Takeoff_Line__c.Category__c         — NOT YET CREATED; uses Determination__c
 *   - Revenue quote source for work-order quantities — NOT YET CONNECTED here
 *   - WLR_Time_Rule__c                    — NOT YET CREATED; goalMinutes/goalHours = null
 *
 * @group Work Order Page
 */
public with sharing class LovingWorkOrderLineItemService {

    /** Default pricing source when no external quote exists. */
    private static final String DEFAULT_PRICING_SOURCE = 'Takeoff';

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Build line item DTOs for the work order identified by workOrderId.
     *
     * Resolution chain: Work_Order__c → Takeoff__c → Takeoff_Line__c
     *
     * @param workOrderId  Id of the Work_Order__c record.
     * @return             Ordered list of LineItemDTO; empty when no takeoff exists.
     */
    public static List<WorkOrderPageDTO.LineItemDTO> buildLineItems(Id workOrderId) {
        // Step 1: fetch the work order to obtain the Takeoff__c lookup
        Work_Order__c wo = [
            SELECT Id, Takeoff__c
            FROM   Work_Order__c
            WHERE  Id = :workOrderId
            LIMIT  1
        ];

        if (wo.Takeoff__c == null) {
            return new List<WorkOrderPageDTO.LineItemDTO>();
        }

        Id takeoffId = wo.Takeoff__c;

        // Step 2: query all takeoff lines, ordered by Sort_Order__c
        List<Takeoff_Line__c> lines = [
            SELECT Id,
                   Item_Description__c,
                   Determination__c,
                   PO_Quantity__c,
                   Measured_Quantity__c,
                   Verified_Quantity__c,
                   Unit__c,
                   Unit_Price__c,
                   Substitution_Notes__c,
                   Material_Substitution__c
            FROM   Takeoff_Line__c
            WHERE  Takeoff__c = :takeoffId
            ORDER BY Sort_Order__c NULLS LAST
        ];

        // Step 3: map each Takeoff_Line__c to a LineItemDTO
        List<WorkOrderPageDTO.LineItemDTO> dtos = new List<WorkOrderPageDTO.LineItemDTO>();
        for (Takeoff_Line__c line : lines) {
            dtos.add(toLineItemDTO(line));
        }
        return dtos;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Map a single Takeoff_Line__c record to a LineItemDTO.
     */
    private static WorkOrderPageDTO.LineItemDTO toLineItemDTO(Takeoff_Line__c line) {
        WorkOrderPageDTO.LineItemDTO dto = new WorkOrderPageDTO.LineItemDTO();

        dto.id                   = line.Id;
        // Product__c not yet created — use Item_Description__c
        dto.productName          = line.Item_Description__c;
        // Category__c not yet created — use Determination__c
        dto.category             = line.Determination__c;

        dto.poQuantity           = line.PO_Quantity__c;
        dto.measuredQuantity     = line.Measured_Quantity__c;
        dto.verifiedQuantity     = line.Verified_Quantity__c;
        // Revenue quote quantity is not yet connected into this DTO
        dto.quotedQuantity       = null;

        dto.unitOfMeasure        = line.Unit__c;

        // WLR_Time_Rule__c not yet created — labor goals deferred
        dto.goalMinutes          = null;
        dto.goalHours            = null;

        dto.unitPrice            = line.Unit_Price__c;
        dto.extendedPrice        = computeExtendedPrice(line);

        // Revenue quote pricing is not yet connected; pricing still comes from takeoff
        dto.pricingSource        = DEFAULT_PRICING_SOURCE;

        dto.materialVerified     = false;
        dto.substitutionRequired = (line.Material_Substitution__c == true);
        dto.substitutionNotes    = line.Substitution_Notes__c;

        // Derive line status from Determination__c when available
        dto.lineStatus           = line.Determination__c;

        return dto;
    }

    /**
     * Compute extended price = unit price × best available quantity.
     * Priority: Verified_Quantity__c → Measured_Quantity__c → PO_Quantity__c
     * Returns null when unit price or all quantities are null.
     */
    private static Decimal computeExtendedPrice(Takeoff_Line__c line) {
        if (line.Unit_Price__c == null) {
            return null;
        }
        Decimal qty = line.Verified_Quantity__c != null
            ? line.Verified_Quantity__c
            : (line.Measured_Quantity__c != null
                ? line.Measured_Quantity__c
                : line.PO_Quantity__c);

        if (qty == null) {
            return null;
        }
        return line.Unit_Price__c * qty;
    }
}