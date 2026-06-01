import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import SOD_BASIS         from '@salesforce/schema/Account.Sod_Billing_Basis__c';
import TREE_BASIS        from '@salesforce/schema/Account.Tree_Billing_Basis__c';
import SOD_TYPE_NOTES    from '@salesforce/schema/Account.Sod_Type_Notes__c';
import MODEL_DISC_PCT    from '@salesforce/schema/Account.Model_Home_Discount_Pct__c';
import MODEL_DISC_NOTES  from '@salesforce/schema/Account.Model_Home_Discount_Notes__c';
import PRICE_ADJ_PROC    from '@salesforce/schema/Account.Price_Adjustment_Process__c';
import PRICE_ADJ_DAYS    from '@salesforce/schema/Account.Price_Adjustment_Notice_Days__c';
import PAYMENT_METHOD    from '@salesforce/schema/Account.Payment_Method__c';
import PAY_SCHED_115     from '@salesforce/schema/Account.Payment_Schedule_1_15__c';
import PAY_SCHED_16E     from '@salesforce/schema/Account.Payment_Schedule_16_End__c';
import INV_DEADLINE      from '@salesforce/schema/Account.Invoice_Deadline_Days__c';
import INV_METHOD_PRI    from '@salesforce/schema/Account.Invoice_Method_Primary__c';
import INV_METHOD_NON    from '@salesforce/schema/Account.Invoice_Method_Non_Portal__c';
import NON_PORTAL_REQ    from '@salesforce/schema/Account.Non_Portal_Invoice_Requirements__c';
import BUILDER_PORTAL    from '@salesforce/schema/Account.Builder_Portal_Link__c';
import VENDOR_PORTAL     from '@salesforce/schema/Account.Vendor_Portal__c';
import AP_EMAIL          from '@salesforce/schema/Account.AP_Invoicing_Email__c';
import BACK_CHARGE_FEE   from '@salesforce/schema/Account.Back_Charge_Admin_Fee_Pct__c';
import LIEN_WAIVER       from '@salesforce/schema/Account.Lien_Waiver_Required__c';
import CONTRACT_DATE     from '@salesforce/schema/Account.Contractor_Agreement_Signed_Date__c';
import EXHIBIT_A         from '@salesforce/schema/Account.Exhibit_A_Signed__c';
import EXHIBIT_B         from '@salesforce/schema/Account.Exhibit_B_Signed__c';
import EXHIBIT_C         from '@salesforce/schema/Account.Exhibit_C_Signed__c';
import EXHIBIT_D         from '@salesforce/schema/Account.Exhibit_D_Signed__c';
import ADDL_INSURED      from '@salesforce/schema/Account.Additional_Insured_Required__c';
import AUTO_LIAB         from '@salesforce/schema/Account.Auto_Liability_Limit__c';
import CGL_OCC           from '@salesforce/schema/Account.CGL_Per_Occurrence__c';
import CGL_AGG           from '@salesforce/schema/Account.CGL_Aggregate__c';
import UMBRELLA          from '@salesforce/schema/Account.Umbrella_Limit__c';
import WORKERS_COMP      from '@salesforce/schema/Account.Workers_Comp_Limit__c';
import CERTS_ON_FILE     from '@salesforce/schema/Account.Certs_On_File__c';
import W9_ON_FILE        from '@salesforce/schema/Account.W9_On_File__c';
import LOVING_LICENSE    from '@salesforce/schema/Account.LOVING_License_Number__c';
import RENEWAL_CERT      from '@salesforce/schema/Account.Renewal_Cert_Lead_Days__c';
import WAIVER_SUBRO      from '@salesforce/schema/Account.Waiver_Of_Subrogation_Required__c';

const FIELDS = [
    SOD_BASIS, TREE_BASIS, SOD_TYPE_NOTES,
    MODEL_DISC_PCT, MODEL_DISC_NOTES,
    PRICE_ADJ_PROC, PRICE_ADJ_DAYS,
    PAYMENT_METHOD, PAY_SCHED_115, PAY_SCHED_16E,
    INV_DEADLINE, INV_METHOD_PRI, INV_METHOD_NON, NON_PORTAL_REQ,
    BUILDER_PORTAL, VENDOR_PORTAL, AP_EMAIL,
    BACK_CHARGE_FEE, LIEN_WAIVER,
    CONTRACT_DATE, EXHIBIT_A, EXHIBIT_B, EXHIBIT_C, EXHIBIT_D,
    ADDL_INSURED, AUTO_LIAB, CGL_OCC, CGL_AGG, UMBRELLA, WORKERS_COMP,
    CERTS_ON_FILE, W9_ON_FILE, LOVING_LICENSE, RENEWAL_CERT, WAIVER_SUBRO
];

export default class DivisionPricingPanel extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    account;

    get isLoaded() { return !!this.account.data; }
    get hasError() { return !!this.account.error; }

    _val(field)  { return getFieldValue(this.account.data, field); }
    _str(field)  { return this._val(field) || '—'; }
    _bool(field) { const v = this._val(field); return v === true || v === 'true'; }

    get sodBasis()       { return this._str(SOD_BASIS); }
    get treeBasis()      { return this._str(TREE_BASIS); }
    get sodTypeNotes()   { return this._str(SOD_TYPE_NOTES); }

    get modelDiscPct()   {
        const v = this._val(MODEL_DISC_PCT);
        return v != null ? `${v}%` : '—';
    }
    get modelDiscNotes() { return this._str(MODEL_DISC_NOTES); }
    get priceAdjProc()   { return this._str(PRICE_ADJ_PROC); }
    get priceAdjDays()   {
        const v = this._val(PRICE_ADJ_DAYS);
        return v != null ? `${v} days` : '—';
    }

    get paymentMethod()  { return this._str(PAYMENT_METHOD); }
    get paySchedule115() { return this._str(PAY_SCHED_115); }
    get paySchedule16E() { return this._str(PAY_SCHED_16E); }
    get invDeadline()    {
        const v = this._val(INV_DEADLINE);
        return v != null ? `${v} days` : '—';
    }
    get invMethodPri()   { return this._str(INV_METHOD_PRI); }
    get invMethodNon()   { return this._str(INV_METHOD_NON); }
    get nonPortalReq()   { return this._str(NON_PORTAL_REQ); }
    get builderPortal()  { return this._val(BUILDER_PORTAL) || ''; }
    get vendorPortal()   { return this._val(VENDOR_PORTAL)  || ''; }
    get apEmail()        { return this._str(AP_EMAIL); }
    get apEmailHref()    {
        const e = this._val(AP_EMAIL);
        return e ? `mailto:${e}` : null;
    }
    get backChargeFee()  {
        const v = this._val(BACK_CHARGE_FEE);
        return v != null ? `${v}%` : '—';
    }
    get lienWaiver()     { return this._bool(LIEN_WAIVER) ? 'Required' : 'Not required'; }
    get lienChip()       { return this._bool(LIEN_WAIVER) ? 'chip ca' : 'chip cgr'; }

    get contractDate()   { return this._str(CONTRACT_DATE); }
    get exhibitA()       { return this._bool(EXHIBIT_A); }
    get exhibitB()       { return this._bool(EXHIBIT_B); }
    get exhibitC()       { return this._bool(EXHIBIT_C); }
    get exhibitD()       { return this._bool(EXHIBIT_D); }

    get agreements() {
        const chip = (signed) => signed ? 'chip cg' : 'chip cr';
        return [
            { id: 'a', label: 'Exhibit A — Scope of Work',  signed: this.exhibitA, chipClass: chip(this.exhibitA) },
            { id: 'b', label: 'Exhibit B — Payment Terms',  signed: this.exhibitB, chipClass: chip(this.exhibitB) },
            { id: 'c', label: 'Exhibit C — Job Site Rules', signed: this.exhibitC, chipClass: chip(this.exhibitC) },
            { id: 'd', label: 'Exhibit D — Insurance Reqs', signed: this.exhibitD, chipClass: chip(this.exhibitD) }
        ];
    }

    get addlInsured()    { return this._bool(ADDL_INSURED) ? 'Required' : 'Not required'; }
    get addlInsuredChip(){ return this._bool(ADDL_INSURED) ? 'chip ca' : 'chip cgr'; }
    get autoLiab()       { return this._str(AUTO_LIAB); }
    get cglOcc()         { return this._str(CGL_OCC); }
    get cglAgg()         { return this._str(CGL_AGG); }
    get umbrella()       { return this._str(UMBRELLA); }
    get workersComp()    { return this._str(WORKERS_COMP); }
    get certsOnFile()    { return this._bool(CERTS_ON_FILE) ? 'On file ✓' : 'Not on file'; }
    get certsChip()      { return this._bool(CERTS_ON_FILE) ? 'chip cg' : 'chip cr'; }
    get w9OnFile()       { return this._bool(W9_ON_FILE) ? 'On file ✓' : 'Not on file'; }
    get w9Chip()         { return this._bool(W9_ON_FILE) ? 'chip cg' : 'chip cr'; }
    get lovingLicense()  { return this._str(LOVING_LICENSE); }
    get renewalCert()    {
        const v = this._val(RENEWAL_CERT);
        return v != null ? `${v} days lead` : '—';
    }
    get waiverSubro()    { return this._bool(WAIVER_SUBRO) ? 'Required' : 'Not required'; }
    get waiverChip()     { return this._bool(WAIVER_SUBRO) ? 'chip ca' : 'chip cgr'; }
}