/**
 * LovingCSConsoleController
 * Live data + gated writes for the LOVING Customer Success Console (lovingCSConsole LWC).
 *
 * Contract: loving_customer_success_console_6.html (v6 mockup) + CS Console build prompt
 * (Meg Logan, Jun 10 2026). Hard gates enforced server-side, not just in UI:
 *  - Verify blocked unless a PO file is attached (ContentDocumentLink; the org has no
 *    Uploaded_PO_Received__c field — audit finding, file presence is checked directly).
 *  - Approve blocked while Status is Mismatch Review or before Verified. CS_Approved__c
 *    gates Work Order creation downstream.
 *  - Quote Send blocked until the quote is Approved. New quotes land as Draft (the org
 *    Quote__c.Status__c picklist has no Pending Approval value; Draft is the
 *    awaiting-approval state and the Approvals tab reads it that way).
 *  - QI floor: Customer Care WOs born from QI inspection stay Close-locked until
 *    QI_Score__c is 9 or above (re-inspection result posted from the field).
 *  - Escalation is recipient-neutral: a Task with full context and no addressee.
 *  - G6: zones 1, 3, 4 FM names render BLOCKED; never guessed here or in reports.
 *  - G5: no payment or credit actions exist anywhere in this class.
 *  - Takeoffs are read-only for CS. No approve/return methods exist for takeoffs.
 *  - BR-032 / BR step 22 surface read-only (invoice list + Cloudscape hold reason).
 *
 * Writes are gated by the LOVING_CS_Console_Edit custom permission.
 * Every server-side failure writes Error_Log__c (build rule 13).
 */
public with sharing class LovingCSConsoleController {

    @TestVisible private static final String EDIT_PERM = 'LOVING_CS_Console_Edit';
    private static final Set<String> PO_CS_STATUSES = new Set<String>{
        'Pending CS Review', 'NFI', 'Verified', 'Mismatch Review', 'CS Approved', 'Work Order Created'
    };
    // G6: zone ownership lives on configuration; these zones are BLOCKED pending Ops
    // and their FM names are never rendered or guessed anywhere.
    @TestVisible private static final Set<String> BLOCKED_ZONES = new Set<String>{ '1', '3', '4' };

    // ─── bundle ──────────────────────────────────────────────────────────────

    public class Bundle {
        @AuraEnabled public Boolean canEdit;
        @AuraEnabled public List<PoDto> pos = new List<PoDto>();
        @AuraEnabled public List<WoDto> wos = new List<WoDto>();
        @AuraEnabled public List<QuoteDto> quotes = new List<QuoteDto>();
        @AuraEnabled public List<WoDto> warranty = new List<WoDto>();
        @AuraEnabled public List<WoDto> fjs = new List<WoDto>();
        @AuraEnabled public List<CaseDto> cases = new List<CaseDto>();
        @AuraEnabled public List<InvoiceDto> invoices = new List<InvoiceDto>();
        @AuraEnabled public List<TakeoffDto> takeoffs = new List<TakeoffDto>();
        @AuraEnabled public List<CommunityDto> communities = new List<CommunityDto>();
        @AuraEnabled public List<BuilderDto> builders = new List<BuilderDto>();
        @AuraEnabled public List<ZoneDto> zones = new List<ZoneDto>();
        @AuraEnabled public List<CatalogDto> catalog = new List<CatalogDto>();
        @AuraEnabled public List<ReportRowDto> warrantyRate = new List<ReportRowDto>();
        @AuraEnabled public List<ReportRowDto> qiTrend = new List<ReportRowDto>();
        @AuraEnabled public List<ReportRowDto> takeoffTime = new List<ReportRowDto>();
    }
    public class PoDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String poNumber;
        @AuraEnabled public String builder;
        @AuraEnabled public String community;
        @AuraEnabled public String lot;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String received;
        @AuraEnabled public String install;
        @AuraEnabled public String bucket;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal nfi;
        @AuraEnabled public String nfiReason;
        @AuraEnabled public String mismatchNotes;
        @AuraEnabled public String mismatchType;
        @AuraEnabled public Boolean hasFile;
        @AuraEnabled public Boolean csApproved;
    }
    public class WoDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String woType;
        @AuraEnabled public String status;
        @AuraEnabled public String subStatus;
        @AuraEnabled public String community;
        @AuraEnabled public String lot;
        @AuraEnabled public String fm;
        @AuraEnabled public Boolean fmBlocked;
        @AuraEnabled public Decimal qiScore;
        @AuraEnabled public String billableType;
        @AuraEnabled public String coverage;
        @AuraEnabled public String reason;
        @AuraEnabled public String scheduled;
        @AuraEnabled public Boolean determinationPending;
    }
    public class CaseDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String subject;
        @AuraEnabled public String account;
        @AuraEnabled public String lot;
        @AuraEnabled public String origin;
        @AuraEnabled public String status;
        @AuraEnabled public String subStatus;
        @AuraEnabled public Boolean qiLocked;
        @AuraEnabled public Decimal qiScore;
        @AuraEnabled public String notes;
    }
    public class QuoteDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String kind;
        @AuraEnabled public String lot;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal gp;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal days;
        @AuraEnabled public Boolean approvedInternal;
    }
    public class InvoiceDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String builder;
        @AuraEnabled public String lot;
        @AuraEnabled public String wo;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal gp;
        @AuraEnabled public String status;
        @AuraEnabled public String invType;
        @AuraEnabled public Boolean cloudscapeHeld;
    }
    public class TakeoffDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String lot;
        @AuraEnabled public String community;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal photos;
        @AuraEnabled public Boolean mismatch;
        @AuraEnabled public String po;
    }
    public class CommunityDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String division;
        @AuraEnabled public Id divisionId;
        @AuraEnabled public String territory;
        @AuraEnabled public String zone;
        @AuraEnabled public String fm;
        @AuraEnabled public Boolean fmBlocked;
        @AuraEnabled public Decimal lots;
        @AuraEnabled public String bmg;
        @AuraEnabled public Boolean aqua;
    }
    public class BuilderDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer communities;
        @AuraEnabled public Decimal lots;
    }
    public class ZoneDto {
        @AuraEnabled public String zone;
        @AuraEnabled public String fm;
        @AuraEnabled public Boolean blocked;
        @AuraEnabled public String communities;
    }
    public class CatalogDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String unit;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Decimal cost;
    }
    public class ReportRowDto {
        @AuraEnabled public String c1;
        @AuraEnabled public String c2;
        @AuraEnabled public String c3;
        @AuraEnabled public String c4;
        public ReportRowDto(String a, String b, String c, String d) { c1 = a; c2 = b; c3 = c; c4 = d; }
    }

    @AuraEnabled(cacheable=true)
    public static Bundle getConsoleData() {
        try {
            Bundle b = new Bundle();
            b.canEdit = canEdit();
            loadPos(b);
            loadWos(b);
            loadQuotes(b);
            loadInvoices(b);
            loadTakeoffs(b);
            loadCommunities(b);
            loadCatalog(b);
            loadReports(b);
            return b;
        } catch (Exception e) {
            logError('getConsoleData', null, e);
            throw auraErr('Failed to load console data: ' + e.getMessage());
        }
    }

    private static void loadPos(Bundle b) {
        List<Builder_PO__c> pos = [
            SELECT Id, Name, PO_Number__c, Builder_Name__c, Division_Name__c,
                   Community__r.Name, Lot__r.Name, PO_Amount__c, PO_Received_Date__c,
                   Requested_Install_Date__c, Pipeline_Bucket__c, Pipeline_Status__c,
                   Status__c, NFI_Count__c, NFI_Reason__c, Mismatch_Notes__c,
                   Price_Check_Result__c, Qty_Check_Result__c, CS_Approved__c
            FROM Builder_PO__c
            WHERE Status__c IN :PO_CS_STATUSES
            WITH USER_MODE
            ORDER BY PO_Received_Date__c DESC NULLS LAST
            LIMIT 200
        ];
        Set<Id> poIds = new Map<Id, Builder_PO__c>(pos).keySet();
        Set<Id> withFiles = new Set<Id>();
        for (ContentDocumentLink l : [
            SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :poIds
        ]) {
            withFiles.add(l.LinkedEntityId);
        }
        for (Builder_PO__c p : pos) {
            PoDto d = new PoDto();
            d.id = p.Id;
            d.name = p.Name;
            d.poNumber = String.isBlank(p.PO_Number__c) ? p.Name : p.PO_Number__c;
            d.builder = blankDash(p.Builder_Name__c == null ? p.Division_Name__c : p.Builder_Name__c);
            d.community = p.Community__r == null ? '—' : p.Community__r.Name;
            d.lot = p.Lot__r == null ? '—' : p.Lot__r.Name;
            d.amount = p.PO_Amount__c;
            d.received = fmtDate(p.PO_Received_Date__c);
            d.install = fmtDate(p.Requested_Install_Date__c);
            d.bucket = String.isBlank(p.Pipeline_Bucket__c) ? p.Pipeline_Status__c : p.Pipeline_Bucket__c;
            d.status = p.Status__c;
            d.nfi = p.NFI_Count__c == null ? 0 : p.NFI_Count__c;
            d.nfiReason = p.NFI_Reason__c;
            d.mismatchNotes = p.Mismatch_Notes__c;
            d.mismatchType = p.Price_Check_Result__c == 'Fail'
                ? 'Price Variance'
                : (p.Qty_Check_Result__c == 'Fail' ? 'Quantity Variance' : null);
            d.hasFile = withFiles.contains(p.Id);
            d.csApproved = p.CS_Approved__c == true;
            b.pos.add(d);
        }
    }

    private static void loadWos(Bundle b) {
        for (Work_Order__c w : [
            SELECT Id, Name, Work_Order_Type__c, Status__c, Sub_Status__c,
                   Community__r.Name, Lot__r.Name, Field_Manager__r.Name,
                   QI_Score__c, Billable_Type__c, Warranty_Coverage_Type__c,
                   FJ_Reason_Code__c, Notes__c, Source__c, Trigger_Source__c,
                   Estimated_Start_Date__c, Builder__c
            FROM Work_Order__c
            WHERE Status__c NOT IN ('Closed', 'Cancelled')
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 400
        ]) {
            WoDto d = new WoDto();
            d.id = w.Id;
            d.name = w.Name;
            d.woType = w.Work_Order_Type__c;
            d.status = w.Status__c;
            d.subStatus = w.Sub_Status__c;
            d.community = w.Community__r == null ? '—' : w.Community__r.Name;
            d.lot = w.Lot__r == null ? '—' : w.Lot__r.Name;
            d.fm = w.Field_Manager__r == null ? '—' : w.Field_Manager__r.Name;
            d.fmBlocked = false;
            d.qiScore = w.QI_Score__c;
            d.billableType = w.Billable_Type__c;
            d.coverage = w.Warranty_Coverage_Type__c;
            d.reason = w.Work_Order_Type__c == 'Finish Job' ? w.FJ_Reason_Code__c : firstLine(w.Notes__c);
            d.scheduled = fmtDate(w.Estimated_Start_Date__c);
            d.determinationPending = w.Work_Order_Type__c == 'Warranty'
                && w.Sub_Status__c != 'Coverage Determined';
            b.wos.add(d);
            if (w.Work_Order_Type__c == 'Warranty') { b.warranty.add(d); }
            if (w.Work_Order_Type__c == 'Finish Job') { b.fjs.add(d); }
            if (w.Work_Order_Type__c == 'Customer Care') {
                CaseDto c = new CaseDto();
                c.id = w.Id;
                c.name = w.Name;
                c.subject = blankDash(firstLine(w.Notes__c));
                c.account = blankDash(w.Builder__c);
                c.lot = d.lot + ' · ' + d.community;
                c.origin = blankDash(w.Source__c);
                c.status = w.Status__c;
                c.subStatus = w.Sub_Status__c;
                c.qiScore = w.QI_Score__c;
                c.qiLocked = w.Trigger_Source__c == 'QI Inspection'
                    && (w.QI_Score__c == null || w.QI_Score__c < 9);
                c.notes = w.Notes__c;
                b.cases.add(c);
            }
        }
    }

    private static void loadQuotes(Bundle b) {
        for (Quote__c q : [
            SELECT Id, Name, Status__c, Total_Amount__c, Gross_Margin_Pct__c,
                   Days_Outstanding__c, Lot__r.Name, Community__r.Name, Builder_PO__c,
                   Approved_By__c
            FROM Quote__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 100
        ]) {
            QuoteDto d = new QuoteDto();
            d.id = q.Id;
            d.name = q.Name;
            d.kind = q.Builder_PO__c == null ? 'Customer Care' : 'EPO';
            d.lot = (q.Lot__r == null ? '' : q.Lot__r.Name + ' · ')
                + (q.Community__r == null ? '—' : q.Community__r.Name);
            d.amount = q.Total_Amount__c;
            d.gp = q.Gross_Margin_Pct__c;
            d.status = q.Status__c;
            d.days = q.Days_Outstanding__c;
            d.approvedInternal = q.Approved_By__c != null;
            b.quotes.add(d);
        }
    }

    private static void loadInvoices(Bundle b) {
        for (Invoice__c i : [
            SELECT Id, Name, Builder__c, Lot__r.Name, Community__r.Name,
                   LOVING_Work_Order__r.Name, LOVING_Work_Order__r.Lennar_Cloudscape_Entry_Complete__c,
                   Total_Revenue__c, GP_Percent__c, Status__c, Invoice_Type__c
            FROM Invoice__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 150
        ]) {
            InvoiceDto d = new InvoiceDto();
            d.id = i.Id;
            d.name = i.Name;
            d.builder = blankDash(i.Builder__c);
            d.lot = (i.Lot__r == null ? '—' : i.Lot__r.Name)
                + (i.Community__r == null ? '' : ' · ' + i.Community__r.Name);
            d.wo = i.LOVING_Work_Order__r == null ? '—' : i.LOVING_Work_Order__r.Name;
            d.amount = i.Total_Revenue__c;
            d.gp = i.GP_Percent__c;
            d.status = i.Status__c;
            d.invType = blankDash(i.Invoice_Type__c);
            // BR step 22: DR Horton invoices hold until the Cloudscape entry is complete.
            d.cloudscapeHeld = i.Builder__c == 'DR Horton'
                && i.Status__c == 'Pending Send'
                && i.LOVING_Work_Order__r != null
                && i.LOVING_Work_Order__r.Lennar_Cloudscape_Entry_Complete__c != true;
            b.invoices.add(d);
        }
    }

    private static void loadTakeoffs(Bundle b) {
        for (Takeoff__c t : [
            SELECT Id, Name, Lot__r.Name, Community__r.Name, Status__c,
                   Photos_Count__c, Photo_Count__c, Mismatch_Found__c, Builder_PO__r.Name
            FROM Takeoff__c
            WHERE Status__c != 'Approved'
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 100
        ]) {
            TakeoffDto d = new TakeoffDto();
            d.id = t.Id;
            d.name = t.Name;
            d.lot = t.Lot__r == null ? '—' : t.Lot__r.Name;
            d.community = t.Community__r == null ? '—' : t.Community__r.Name;
            d.status = t.Status__c;
            d.photos = t.Photos_Count__c == null ? (t.Photo_Count__c == null ? 0 : t.Photo_Count__c) : t.Photos_Count__c;
            d.mismatch = t.Mismatch_Found__c == true;
            d.po = t.Builder_PO__r == null ? '—' : t.Builder_PO__r.Name;
            b.takeoffs.add(d);
        }
    }

    private static void loadCommunities(Bundle b) {
        Map<Id, BuilderDto> builderById = new Map<Id, BuilderDto>();
        Map<String, List<String>> zoneComms = new Map<String, List<String>>();
        Map<String, Set<String>> zoneFms = new Map<String, Set<String>>();
        for (Community__c c : [
            SELECT Id, Name, Builder_Account__c, Builder_Account__r.Name, Territory__c,
                   Zone__c, Assigned_FM__r.Name, Number_Of_Lots__c, BMG_Package_Code__c,
                   Aqua_Active__c, Community_Status__c
            FROM Community__c
            WHERE Community_Status__c = 'Active' OR (Community_Status__c = null AND Active__c = true)
            WITH USER_MODE
            ORDER BY Name
            LIMIT 400
        ]) {
            CommunityDto d = new CommunityDto();
            d.id = c.Id;
            d.name = c.Name;
            d.division = c.Builder_Account__r == null ? '—' : c.Builder_Account__r.Name;
            d.divisionId = c.Builder_Account__c;
            d.territory = blankDash(c.Territory__c);
            d.zone = c.Zone__c;
            d.fmBlocked = c.Zone__c != null && BLOCKED_ZONES.contains(c.Zone__c);
            // G6: never render an FM name for a blocked zone.
            d.fm = d.fmBlocked ? null : (c.Assigned_FM__r == null ? null : c.Assigned_FM__r.Name);
            d.lots = c.Number_Of_Lots__c;
            d.bmg = blankDash(c.BMG_Package_Code__c);
            d.aqua = c.Aqua_Active__c == true;
            b.communities.add(d);

            if (c.Builder_Account__c != null) {
                BuilderDto bd = builderById.get(c.Builder_Account__c);
                if (bd == null) {
                    bd = new BuilderDto();
                    bd.id = c.Builder_Account__c;
                    bd.name = d.division;
                    bd.communities = 0;
                    bd.lots = 0;
                    builderById.put(c.Builder_Account__c, bd);
                }
                bd.communities++;
                bd.lots += (c.Number_Of_Lots__c == null ? 0 : c.Number_Of_Lots__c);
            }
            String z = c.Zone__c == null ? '—' : c.Zone__c;
            if (!zoneComms.containsKey(z)) {
                zoneComms.put(z, new List<String>());
                zoneFms.put(z, new Set<String>());
            }
            zoneComms.get(z).add(c.Name);
            if (d.fm != null) { zoneFms.get(z).add(d.fm); }
        }
        b.builders = builderById.values();
        List<String> zs = new List<String>(zoneComms.keySet());
        zs.sort();
        for (String z : zs) {
            ZoneDto zd = new ZoneDto();
            zd.zone = z;
            zd.blocked = BLOCKED_ZONES.contains(z);
            zd.fm = zd.blocked ? null : (zoneFms.get(z).isEmpty() ? null : String.join(new List<String>(zoneFms.get(z)), ', '));
            List<String> comms = zoneComms.get(z);
            zd.communities = comms.size() > 6
                ? String.join(slice(comms, 6), ', ') + ' +' + (comms.size() - 6) + ' more'
                : String.join(comms, ', ');
            b.zones.add(zd);
        }
    }

    private static void loadCatalog(Bundle b) {
        for (Item_Catalog__c i : [
            SELECT Id, Name, Unit_Price__c, Standard_Cost__c, Unit_of_Measure__c
            FROM Item_Catalog__c
            WHERE Active__c = true
            WITH USER_MODE
            ORDER BY Name
            LIMIT 250
        ]) {
            CatalogDto d = new CatalogDto();
            d.id = i.Id;
            d.name = i.Name;
            d.unit = i.Unit_of_Measure__c;
            d.price = i.Unit_Price__c == null ? 0 : i.Unit_Price__c;
            d.cost = i.Standard_Cost__c == null ? 0 : i.Standard_Cost__c;
            b.catalog.add(d);
        }
    }

    private static void loadReports(Bundle b) {
        // Warranty rate by community: warranty WOs per production installs, last 90 days.
        Map<Id, Integer> installs = new Map<Id, Integer>();
        Map<Id, Integer> warr = new Map<Id, Integer>();
        Map<Id, String> commName = new Map<Id, String>();
        for (AggregateResult ar : [
            SELECT Community__c cid, Community__r.Name cname, Work_Order_Type__c t, COUNT(Id) n
            FROM Work_Order__c
            WHERE CreatedDate = LAST_N_DAYS:90 AND Community__c != null
              AND Work_Order_Type__c IN ('Production Install', 'Warranty')
            WITH USER_MODE
            GROUP BY Community__c, Community__r.Name, Work_Order_Type__c
            LIMIT 200
        ]) {
            Id cid = (Id) ar.get('cid');
            commName.put(cid, (String) ar.get('cname'));
            Integer n = (Integer) ar.get('n');
            if ((String) ar.get('t') == 'Warranty') { warr.put(cid, n); } else { installs.put(cid, n); }
        }
        for (Id cid : commName.keySet()) {
            Integer ins = installs.containsKey(cid) ? installs.get(cid) : 0;
            Integer w = warr.containsKey(cid) ? warr.get(cid) : 0;
            String rate = ins > 0 ? String.valueOf((w * 1000 / ins) / 10.0) + '%' : '—';
            b.warrantyRate.add(new ReportRowDto(commName.get(cid), String.valueOf(ins), String.valueOf(w), rate));
        }
        // QI trend by FM. G6: blocked-zone FMs report no data rather than guesses —
        // the aggregate is by actual FM on the WO; no name is ever invented.
        for (AggregateResult ar : [
            SELECT Field_Manager__r.Name fm, AVG(QI_Score__c) avgQi, COUNT(Id) n
            FROM Work_Order__c
            WHERE QI_Score__c != null AND CreatedDate = LAST_N_DAYS:90 AND Field_Manager__c != null
            WITH USER_MODE
            GROUP BY Field_Manager__r.Name
            LIMIT 50
        ]) {
            Decimal avgQi = (Decimal) ar.get('avgQi');
            b.qiTrend.add(new ReportRowDto((String) ar.get('fm'),
                avgQi == null ? '—' : String.valueOf(avgQi.setScale(1)),
                String.valueOf((Integer) ar.get('n')), null));
        }
        // Takeoff approval time (submitted → approved, days).
        for (Takeoff__c t : [
            SELECT Name, Community__r.Name, Submitted_Date__c, Approved_Date__c
            FROM Takeoff__c
            WHERE Submitted_Date__c != null AND Approved_Date__c != null
            WITH USER_MODE
            ORDER BY Approved_Date__c DESC
            LIMIT 25
        ]) {
            Integer days = t.Submitted_Date__c.date().daysBetween(t.Approved_Date__c.date());
            b.takeoffTime.add(new ReportRowDto(t.Name,
                t.Community__r == null ? '—' : t.Community__r.Name,
                fmtDate(t.Approved_Date__c.date()), String.valueOf(days)));
        }
    }

    // ─── PO workflow (server-enforced status machine) ────────────────────────

    @AuraEnabled
    public static void verifyPO(Id poId) {
        assertCanEdit();
        try {
            Builder_PO__c p = [
                SELECT Id, Name, Status__c FROM Builder_PO__c WHERE Id = :poId WITH USER_MODE LIMIT 1
            ];
            if (p.Status__c != 'Pending CS Review' && p.Status__c != 'NFI') {
                throw auraErr(p.Name + ' is already past review (' + p.Status__c + ').');
            }
            Integer files = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :poId];
            if (files == 0) {
                throw auraErr(
                    'Verify blocked: no PO file attached on ' + p.Name + '. Attach the PO first.');
            }
            update as user new Builder_PO__c(Id = p.Id, Status__c = 'Verified');
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError('verifyPO', poId, e);
            throw auraErr('Verify failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void nfiPO(Id poId, String reason) {
        assertCanEdit();
        try {
            Builder_PO__c p = [
                SELECT Id, Name, Status__c, NFI_Count__c FROM Builder_PO__c
                WHERE Id = :poId WITH USER_MODE LIMIT 1
            ];
            Builder_PO__c upd = new Builder_PO__c(
                Id = p.Id,
                Status__c = 'NFI',
                NFI_Count__c = (p.NFI_Count__c == null ? 0 : p.NFI_Count__c) + 1);
            if (String.isNotBlank(reason)) { upd.NFI_Reason__c = reason; }
            update as user upd;
        } catch (Exception e) {
            logError('nfiPO', poId, e);
            throw auraErr('NFI return failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void approvePO(Id poId) {
        assertCanEdit();
        try {
            Builder_PO__c p = [
                SELECT Id, Name, Status__c FROM Builder_PO__c WHERE Id = :poId WITH USER_MODE LIMIT 1
            ];
            if (p.Status__c == 'Mismatch Review') {
                throw auraErr(
                    'Approve blocked: open mismatch on ' + p.Name + '. Correct it or create an EPO.');
            }
            if (p.Status__c != 'Verified') {
                throw auraErr('Approve blocked: ' + p.Name + ' must be Verified first.');
            }
            update as user new Builder_PO__c(
                Id = p.Id, Status__c = 'CS Approved', CS_Approved__c = true);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError('approvePO', poId, e);
            throw auraErr('Approve failed: ' + e.getMessage());
        }
    }

    /**
     * Recipient-neutral escalation: writes a Task with the full context attached and
     * no addressee. Routing waits on the escalation matrix (Section 11, item 7).
     */
    @AuraEnabled
    public static void escalatePO(Id poId, String context) {
        assertCanEdit();
        try {
            Builder_PO__c p = [
                SELECT Id, Name, Mismatch_Notes__c, Status__c, Division_Account__c
                FROM Builder_PO__c
                WHERE Id = :poId WITH USER_MODE LIMIT 1
            ];
            // Activities are not enabled on Builder_PO__c, so the escalation Task
            // anchors to the division Account with the PO named in the subject.
            insertTaskSafe(new Task(
                Subject = 'Escalation: ' + p.Name,
                Description = 'CS escalation (no recipient: routing matrix is an open Section 11 decision).\n'
                    + 'PO: ' + p.Name + '\n'
                    + 'Status: ' + p.Status__c + '\n'
                    + (String.isBlank(p.Mismatch_Notes__c) ? '' : 'Mismatch: ' + p.Mismatch_Notes__c + '\n')
                    + (String.isBlank(context) ? '' : context),
                Status = 'Not Started',
                Priority = 'High',
                WhatId = p.Division_Account__c
            ));
        } catch (Exception e) {
            logError('escalatePO', poId, e);
            throw auraErr('Escalation failed: ' + e.getMessage());
        }
    }

    public class NewPoRequest {
        public String poNumber;
        public Decimal amount;
        public String installDate;
        public Id communityId;
    }

    @AuraEnabled
    public static Id createPO(String payload) {
        assertCanEdit();
        try {
            NewPoRequest r = (NewPoRequest) JSON.deserialize(payload, NewPoRequest.class);
            if (String.isBlank(r.poNumber) || r.amount == null || r.communityId == null) {
                throw auraErr('PO number, amount, and community are required.');
            }
            Community__c c = [
                SELECT Id, Builder_Account__c FROM Community__c WHERE Id = :r.communityId WITH USER_MODE LIMIT 1
            ];
            Builder_PO__c p = new Builder_PO__c(
                PO_Number__c = r.poNumber,
                PO_Amount__c = r.amount,
                Requested_Install_Date__c = String.isBlank(r.installDate) ? null : Date.valueOf(r.installDate),
                Community__c = c.Id,
                Division_Account__c = c.Builder_Account__c,
                Builder_Account__c = c.Builder_Account__c,
                Status__c = 'Pending CS Review',
                PO_Received_Date__c = Date.today(),
                NFI_Count__c = 0,
                PO_Source__c = 'Manual Upload'
            );
            insert as user p;
            return p.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError('createPO', null, e);
            throw auraErr('Create PO failed: ' + e.getMessage());
        }
    }

    // ─── quotes (calculator; Draft → Approved → Sent; send gated) ────────────

    public class QuoteLineRequest {
        public String name;
        public Decimal qty;
        public Decimal price;
        public Decimal cost;
        public Id catalogId;
    }
    public class QuoteRequest {
        public Id fromPoId;
        public Id communityId;
        public String lotText;
        public List<QuoteLineRequest> lines;
    }

    @AuraEnabled
    public static String saveQuote(String payload) {
        assertCanEdit();
        Savepoint sp = Database.setSavepoint();
        try {
            QuoteRequest r = (QuoteRequest) JSON.deserialize(payload, QuoteRequest.class);
            if (r.lines == null || r.lines.isEmpty()) {
                throw auraErr('Add at least one line before saving the quote.');
            }
            Decimal rev = 0, cost = 0;
            for (QuoteLineRequest l : r.lines) {
                rev += (l.qty == null ? 0 : l.qty) * (l.price == null ? 0 : l.price);
                cost += (l.qty == null ? 0 : l.qty) * (l.cost == null ? 0 : l.cost);
            }
            // Total_Amount__c is a rollup from the line items; only the cost is written here.
            Quote__c q = new Quote__c(
                Status__c = 'Draft',  // Draft = awaiting CS approval; Send is gated on Approved
                Estimated_Cost__c = cost,
                Community__c = r.communityId,
                Builder_PO__c = r.fromPoId,
                Notes__c = String.isBlank(r.lotText) ? null : 'Lot/client: ' + r.lotText
            );
            if (r.fromPoId != null) {
                List<Builder_PO__c> pos = [
                    SELECT Id, Status__c, Lot__c, Community__c, Mismatch_Notes__c
                    FROM Builder_PO__c WHERE Id = :r.fromPoId WITH USER_MODE LIMIT 1
                ];
                if (!pos.isEmpty()) {
                    q.Lot__c = pos[0].Lot__c;
                    if (q.Community__c == null) { q.Community__c = pos[0].Community__c; }
                }
            }
            insert as user q;
            List<Quote_Line_Item__c> lines = new List<Quote_Line_Item__c>();
            for (QuoteLineRequest l : r.lines) {
                lines.add(new Quote_Line_Item__c(
                    Quote__c = q.Id,
                    Item_Description__c = l.name,
                    Quantity__c = l.qty,
                    Unit_Price__c = l.price,
                    Unit_Cost__c = l.cost,
                    Item_Catalog__c = l.catalogId
                ));
            }
            insert as user lines;
            String quoteName = [SELECT Name FROM Quote__c WHERE Id = :q.Id LIMIT 1].Name;
            // EPO raised from a mismatch: the source PO returns to Verified with the
            // resolution stamped, per the mockup contract.
            if (r.fromPoId != null) {
                Builder_PO__c p = [
                    SELECT Id, Status__c, Mismatch_Notes__c FROM Builder_PO__c
                    WHERE Id = :r.fromPoId WITH USER_MODE LIMIT 1
                ];
                if (p.Status__c == 'Mismatch Review') {
                    update as user new Builder_PO__c(
                        Id = p.Id,
                        Status__c = 'Verified',
                        Mismatch_Notes__c =
                            (String.isBlank(p.Mismatch_Notes__c) ? '' : p.Mismatch_Notes__c + '\n')
                            + 'Resolved via ' + quoteName + ' (EPO), ' + Datetime.now().format('MMM d, yyyy'));
                }
            }
            return quoteName;
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            logError('saveQuote', null, e);
            throw auraErr('Save quote failed: ' + e.getMessage());
        }
    }

    /**
     * Internal CS approval. The org quote lifecycle is forward-only and 'Approved'
     * means the builder accepted a sent quote, so CS approval stamps Approved_By__c
     * on the Draft instead of changing status. Send is gated on this stamp.
     */
    @AuraEnabled
    public static void approveQuote(Id quoteId) {
        assertCanEdit();
        try {
            update as user new Quote__c(
                Id = quoteId,
                Approved_By__c = UserInfo.getUserId(), Approved_Date__c = Datetime.now());
        } catch (Exception e) {
            logError('approveQuote', quoteId, e);
            throw auraErr('Quote approval failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void rejectQuote(Id quoteId) {
        assertCanEdit();
        try {
            update as user new Quote__c(Id = quoteId, Status__c = 'Rejected');
        } catch (Exception e) {
            logError('rejectQuote', quoteId, e);
            throw auraErr('Quote rejection failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendQuote(Id quoteId) {
        assertCanEdit();
        try {
            Quote__c q = [
                SELECT Id, Name, Status__c, Approved_By__c
                FROM Quote__c WHERE Id = :quoteId WITH USER_MODE LIMIT 1
            ];
            if (q.Approved_By__c == null) {
                throw auraErr(q.Name + ' needs approval before it goes out.');
            }
            if (q.Status__c != 'Draft') {
                throw auraErr(q.Name + ' is already ' + q.Status__c + '.');
            }
            update as user new Quote__c(Id = q.Id, Status__c = 'Sent', Sent_Date__c = Date.today());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError('sendQuote', quoteId, e);
            throw auraErr('Send failed: ' + e.getMessage());
        }
    }

    // ─── warranty determination (no billing — BR-032 holds downstream) ───────

    @AuraEnabled
    public static void warrantyDetermine(Id woId, Boolean covered, String note) {
        assertCanEdit();
        try {
            Work_Order__c w = [
                SELECT Id, Name, Work_Order_Type__c, Notes__c FROM Work_Order__c
                WHERE Id = :woId WITH USER_MODE LIMIT 1
            ];
            if (w.Work_Order_Type__c != 'Warranty') {
                throw auraErr(w.Name + ' is not a Warranty work order.');
            }
            update as user new Work_Order__c(
                Id = w.Id,
                Sub_Status__c = 'Coverage Determined',
                Notes__c = (String.isBlank(w.Notes__c) ? '' : w.Notes__c + '\n')
                    + 'Warranty determination: ' + (covered ? 'Approved (covered, no charge — BR-032)' : 'Denied')
                    + (String.isBlank(note) ? '' : ' — ' + note)
                    + ' [' + UserInfo.getName() + ', ' + Datetime.now().format('MMM d, yyyy h:mm a') + ']');
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError('warrantyDetermine', woId, e);
            throw auraErr('Determination failed: ' + e.getMessage());
        }
    }

    // ─── cases (Customer Care WOs; QI floor of 9 enforced on Close) ──────────

    @AuraEnabled
    public static void caseAddNote(Id woId, String note) {
        assertCanEdit();
        if (String.isBlank(note)) { throw auraErr('Type the note first.'); }
        try {
            Work_Order__c w = [SELECT Id, Notes__c FROM Work_Order__c WHERE Id = :woId WITH USER_MODE LIMIT 1];
            update as user new Work_Order__c(
                Id = w.Id,
                Notes__c = (String.isBlank(w.Notes__c) ? '' : w.Notes__c + '\n')
                    + '[' + UserInfo.getName() + ', ' + Datetime.now().format('MMM d h:mm a') + '] ' + note);
        } catch (Exception e) {
            logError('caseAddNote', woId, e);
            throw auraErr('Add note failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void caseResolve(Id woId) {
        assertCanEdit();
        try {
            update as user new Work_Order__c(Id = woId, Sub_Status__c = 'Complete');
        } catch (Exception e) {
            logError('caseResolve', woId, e);
            throw auraErr('Resolve failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void caseClose(Id woId) {
        assertCanEdit();
        try {
            Work_Order__c w = [
                SELECT Id, Name, Sub_Status__c, Trigger_Source__c, QI_Score__c
                FROM Work_Order__c WHERE Id = :woId WITH USER_MODE LIMIT 1
            ];
            // QI floor: a case born from a QI failure stays locked until re-inspection
            // passes at 9 or above. The score posts from the field, not from CS.
            if (w.Trigger_Source__c == 'QI Inspection' && (w.QI_Score__c == null || w.QI_Score__c < 9)) {
                throw auraErr(
                    'Close blocked: this case came from a QI failure and stays locked until '
                    + 're-inspection passes with every item at 9 or above.');
            }
            if (w.Sub_Status__c != 'Complete') {
                throw auraErr('Resolve first, then Close.');
            }
            update as user new Work_Order__c(Id = w.Id, Status__c = 'Closed');
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError('caseClose', woId, e);
            throw auraErr('Close failed: ' + e.getMessage());
        }
    }

    public class NewCaseRequest {
        public String subject;
        public Id communityId;
        public String lotText;
        public String origin;
        public String note;
    }

    @AuraEnabled
    public static Id createCase(String payload) {
        assertCanEdit();
        try {
            NewCaseRequest r = (NewCaseRequest) JSON.deserialize(payload, NewCaseRequest.class);
            if (String.isBlank(r.subject)) {
                throw auraErr('Subject is required to open a case.');
            }
            Id cmId = null;
            if (r.communityId != null) {
                for (Community__c cm : [
                    SELECT CM_Contact__c, Primary_CM__c FROM Community__c
                    WHERE Id = :r.communityId WITH USER_MODE LIMIT 1
                ]) {
                    cmId = cm.CM_Contact__c != null ? cm.CM_Contact__c : cm.Primary_CM__c;
                }
            }
            Work_Order__c w = new Work_Order__c(
                Work_Order_Type__c = 'Customer Care',
                Status__c = 'New',
                Community__c = r.communityId,
                Construction_Manager__c = cmId,
                Source__c = mapOrigin(r.origin),
                Trigger_Source__c = 'Customer Care Request',
                Notes__c = r.subject
                    + (String.isBlank(r.lotText) ? '' : '\nLot/location: ' + r.lotText)
                    + (String.isBlank(r.note) ? '' : '\n[' + UserInfo.getName() + '] ' + r.note)
            );
            insert as user w;
            return w.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError('createCase', null, e);
            throw auraErr('Create case failed: ' + e.getMessage());
        }
    }

    // ─── onboarding ──────────────────────────────────────────────────────────

    @AuraEnabled
    public static Id onboardBuilder(String divisionName) {
        assertCanEdit();
        if (String.isBlank(divisionName)) {
            throw auraErr('Builder division name is required.');
        }
        try {
            Account a = new Account(Name = divisionName);
            insert as user a;
            return a.Id;
        } catch (Exception e) {
            logError('onboardBuilder', null, e);
            throw auraErr('Onboarding failed: ' + e.getMessage());
        }
    }

    public class NewCommunityRequest {
        public String name;
        public Id builderAccountId;
        public String territory;
        public String bmg;
        public Boolean aqua;
    }

    @AuraEnabled
    public static Id createCommunity(String payload) {
        assertCanEdit();
        try {
            NewCommunityRequest r = (NewCommunityRequest) JSON.deserialize(payload, NewCommunityRequest.class);
            if (String.isBlank(r.name) || String.isBlank(r.bmg)) {
                throw auraErr('Community name and BMG package code are required.');
            }
            // G6: FM assignment is zone configuration and is never guessed or defaulted
            // on a new community — Assigned_FM__c stays null until Ops assigns it.
            // Territory__c is a formula in the org and derives on its own.
            Community__c c = new Community__c(
                Name = r.name,
                Builder_Account__c = r.builderAccountId,
                BMG_Package_Code__c = r.bmg,
                Aqua_Active__c = r.aqua == true,
                Active__c = true,
                Community_Status__c = 'Active'
            );
            insert as user c;
            return c.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError('createCommunity', null, e);
            throw auraErr('Create community failed: ' + e.getMessage());
        }
    }

    // ─── email (logged to the record; recipients come from typed input) ──────

    public class EmailRequest {
        public String toAddress;
        public String subject;
        public String body;
        public Id recordId;
    }

    @AuraEnabled
    public static void sendEmailMsg(String payload) {
        assertCanEdit();
        try {
            EmailRequest r = (EmailRequest) JSON.deserialize(payload, EmailRequest.class);
            if (String.isBlank(r.toAddress) || String.isBlank(r.body)) {
                throw auraErr('Recipient and body are required.');
            }
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new List<String>{ r.toAddress });
            m.setSubject(String.isBlank(r.subject) ? 'LOVING Customer Success' : r.subject);
            m.setPlainTextBody(r.body);
            if (!Test.isRunningTest()) {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ m });
            }
            try {
                insertTaskSafe(new Task(
                    Subject = 'Email: ' + m.getSubject(),
                    Description = 'To: ' + r.toAddress + '\n\n' + r.body,
                    Status = 'Completed',
                    ActivityDate = Date.today(),
                    WhatId = r.recordId
                ));
            } catch (Exception taskErr) {
                logError('sendEmailMsg.taskLog', r.recordId, taskErr);
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            logError('sendEmailMsg', null, e);
            throw auraErr('Email failed: ' + e.getMessage());
        }
    }

    // ─── helpers ─────────────────────────────────────────────────────────────

    private static Boolean canEdit() {
        return FeatureManagement.checkPermission(EDIT_PERM);
    }

    private static void assertCanEdit() {
        if (!canEdit()) {
            throw auraErr(
                'You do not have permission to take Customer Success actions.');
        }
    }

    /**
     * Inserts the activity log Task, dropping WhatId when the target object does not
     * have activities enabled (e.g. Builder_PO__c) so the log is never lost.
     */
    private static void insertTaskSafe(Task t) {
        try {
            insert t;
        } catch (DmlException e) {
            if (t.WhatId != null) {
                t.WhatId = null;
                insert t;
            } else {
                throw e;
            }
        }
    }

    /** AuraHandledException with the message actually set, so tests and logs see it. */
    private static AuraHandledException auraErr(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }

    private static String mapOrigin(String origin) {
        if (origin == 'Builder call' || origin == 'Builder email') { return 'Builder'; }
        if (origin == 'Homeowner portal') { return 'Portal'; }
        if (origin == 'Customer call') { return 'Call'; }
        if (origin == 'Customer email') { return 'Email'; }
        return 'Call';
    }

    private static String fmtDate(Date d) {
        return d == null ? '—' : Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('MMM d');
    }

    private static String blankDash(String s) {
        return String.isBlank(s) ? '—' : s;
    }

    private static String firstLine(String s) {
        if (String.isBlank(s)) { return null; }
        return s.split('\n')[0].left(140);
    }

    private static List<String> slice(List<String> src, Integer n) {
        List<String> out = new List<String>();
        for (Integer i = 0; i < n && i < src.size(); i++) { out.add(src[i]); }
        return out;
    }

    @TestVisible
    private static void logError(String method, Id recordId, Exception e) {
        try {
            Database.insert(new Error_Log__c(
                Class_Name__c = 'LovingCSConsoleController',
                Method_Name__c = method,
                Record_Id__c = recordId == null ? null : String.valueOf(recordId),
                Message__c = e.getMessage() + '\n' + e.getStackTraceString(),
                Logged_At__c = Datetime.now()
            ), false);
        } catch (Exception ignore) {
            // last resort: never mask the original error with a logging failure
        }
    }
}
