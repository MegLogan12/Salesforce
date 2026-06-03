/**
 * MismatchNfiController
 * Returns the queue of Builder_PO__c records held by validation due to
 * price mismatches (Price_Check_Result__c != 'Pass') or NFI issues
 * (NFI_Count__c > 0), along with summary counts.
 *
 * Screen 19 — Mismatch & NFI Review
 */
public with sharing class MismatchNfiController {

    // ─── Inner classes ───────────────────────────────────────────────────────

    public class PoRow {
        @AuraEnabled public Id      poId;
        @AuraEnabled public String  poName;
        @AuraEnabled public String  builderName;
        @AuraEnabled public String  communityName;
        @AuraEnabled public String  mismatchType;   // "Price" | "Qty" | "Both"
        @AuraEnabled public String  detail;
        @AuraEnabled public Decimal poAmount;
        @AuraEnabled public Decimal priceBookTotal;
        @AuraEnabled public Decimal nfiCount;
        @AuraEnabled public String  nfiReason;
        @AuraEnabled public String  status;
        @AuraEnabled public DateTime createdDate;
    }

    public class MismatchView {
        @AuraEnabled public Integer     totalOpen;
        @AuraEnabled public Integer     priceCount;
        @AuraEnabled public Integer     qtyCount;
        @AuraEnabled public Integer     bothCount;
        @AuraEnabled public List<PoRow> rows;
    }

    // ─── Public methods ──────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static MismatchView getMismatches() {
        if (!Schema.sObjectType.Builder_PO__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Builder PO records.');
        }

        List<Builder_PO__c> pos = [
            SELECT Id,
                   Name,
                   Builder_Account__c,
                   Builder_Account__r.Name,
                   Community__c,
                   Community__r.Name,
                   Division_Account__c,
                   Division_Account__r.Name,
                   PO_Amount__c,
                   Price_Book_Total__c,
                   Price_Check_Result__c,
                   Qty_Check_Result__c,
                   NFI_Count__c,
                   NFI_Reason__c,
                   Status__c,
                   CreatedDate
            FROM Builder_PO__c
            WHERE Price_Check_Result__c != 'Pass'
               OR NFI_Count__c > 0
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];

        return buildView(pos);
    }

    // ─── Testable helper ─────────────────────────────────────────────────────

    @TestVisible
    private static MismatchView buildView(List<Builder_PO__c> pos) {
        MismatchView view  = new MismatchView();
        view.rows          = new List<PoRow>();
        view.totalOpen     = 0;
        view.priceCount    = 0;
        view.qtyCount      = 0;
        view.bothCount     = 0;

        for (Builder_PO__c po : pos) {
            Boolean priceFail = (po.Price_Check_Result__c != 'Pass');
            Boolean qtyFail   = (po.NFI_Count__c != null && po.NFI_Count__c > 0);

            String mismatchType;
            if (priceFail && qtyFail) {
                mismatchType = 'Both';
                view.bothCount++;
            } else if (priceFail) {
                mismatchType = 'Price';
                view.priceCount++;
            } else {
                mismatchType = 'Qty';
                view.qtyCount++;
            }
            view.totalOpen++;

            PoRow row          = new PoRow();
            row.poId           = po.Id;
            row.poName         = po.Name;
            row.builderName    = po.Builder_Account__r != null ? po.Builder_Account__r.Name : null;
            row.communityName  = po.Community__r      != null ? po.Community__r.Name       : null;
            row.mismatchType   = mismatchType;
            row.poAmount       = po.PO_Amount__c;
            row.priceBookTotal = po.Price_Book_Total__c;
            row.nfiCount       = po.NFI_Count__c;
            row.nfiReason      = po.NFI_Reason__c;
            row.status         = po.Status__c;
            row.createdDate    = po.CreatedDate;

            // Human-readable detail line
            List<String> parts = new List<String>();
            if (priceFail) {
                String priceCheckVal = po.Price_Check_Result__c != null ? po.Price_Check_Result__c : 'Not Set';
                parts.add('Price: ' + priceCheckVal);
            }
            if (qtyFail) {
                Integer nfi = (Integer) po.NFI_Count__c;
                parts.add('NFI: ' + nfi + ' item' + (nfi == 1 ? '' : 's'));
            }
            row.detail = String.join(parts, ' | ');

            view.rows.add(row);
        }

        return view;
    }
}
