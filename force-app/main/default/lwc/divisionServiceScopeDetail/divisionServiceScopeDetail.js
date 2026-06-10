import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import HOME_TYPES      from '@salesforce/schema/Account.Home_Types__c';
import SCOPE_SUMMARY   from '@salesforce/schema/Account.Scope_Summary__c';
import SCOPE_APPLIES   from '@salesforce/schema/Account.Scope_Applies_To__c';
import SCOPE_SOURCE    from '@salesforce/schema/Account.Scope_Source__c';
import SCOPE_CATS      from '@salesforce/schema/Account.Scope_Cost_Categories__c';
import SCHED_LEAD      from '@salesforce/schema/Account.Scheduling_Lead_Time_Days__c';
import SVC_RESP_HRS    from '@salesforce/schema/Account.Service_Call_Response_Hours__c';
import LOT_READY_APPVR from '@salesforce/schema/Account.Lot_Readiness_Approver__c';
import LOT_RELEASE     from '@salesforce/schema/Account.Lot_Release_Trigger__c';
import ENGLISH_CREW    from '@salesforce/schema/Account.English_Speaking_Crew_Required__c';
import SPEED_LIMIT     from '@salesforce/schema/Account.Speed_Limit_MPH__c';
import STAGING_RULE    from '@salesforce/schema/Account.Staging_Area_Rule__c';
import DRAINAGE_STD    from '@salesforce/schema/Account.Drainage_Standard__c';
import EROSION_RULE    from '@salesforce/schema/Account.Erosion_Control_Rule__c';
import PINE_MULCH      from '@salesforce/schema/Account.Pine_Straw_Or_Mulch__c';
import ADDITIONAL_NOTES from '@salesforce/schema/Account.Additional_Scope_Notes__c';
import DUR_SFD_SM      from '@salesforce/schema/Account.Duration_SFD_Small__c';
import DUR_SFD_LG      from '@salesforce/schema/Account.Duration_SFD_Large__c';
import DUR_CONDO       from '@salesforce/schema/Account.Duration_Condo__c';
import DUR_TOWNHOME    from '@salesforce/schema/Account.Duration_Townhome__c';
import FWO_OOS         from '@salesforce/schema/Account.FWO_Required_For_OOS__c';
import SEASONAL_TREE   from '@salesforce/schema/Account.Seasonal_Tree_Lead_Time_Notes__c';
import CARE_GUIDE      from '@salesforce/schema/Account.Care_Guide_Required__c';
import UTIL_LOCATE     from '@salesforce/schema/Account.Utility_Locate_Lead_Hours__c';
import PUNCH_DAYS      from '@salesforce/schema/Account.Punch_Response_Days__c';
import WARRANTY_PGM    from '@salesforce/schema/Account.Warranty_Program__c';
import WARRANTY_PERIOD from '@salesforce/schema/Account.Warranty_Period_Months__c';
import PLANT_HEALTH    from '@salesforce/schema/Account.Plant_Health_Warranty__c';
import DRAINAGE_WP     from '@salesforce/schema/Account.Drainage_Warranty_Policy__c';
import RESEED_POL      from '@salesforce/schema/Account.Reseed_Policy__c';
import EROSION_GULLY   from '@salesforce/schema/Account.Erosion_Gully_Repair_Policy__c';
import FOUND_WATER_TOL from '@salesforce/schema/Account.Foundation_Water_Tolerance_Hrs__c';
import SWALE_TOL       from '@salesforce/schema/Account.Swale_Tolerance_Hrs__c';

const FIELDS = [
    HOME_TYPES, SCOPE_SUMMARY, SCOPE_APPLIES, SCOPE_SOURCE, SCOPE_CATS,
    SCHED_LEAD, SVC_RESP_HRS, LOT_READY_APPVR, LOT_RELEASE,
    ENGLISH_CREW, SPEED_LIMIT, STAGING_RULE, DRAINAGE_STD, EROSION_RULE, PINE_MULCH,
    ADDITIONAL_NOTES, DUR_SFD_SM, DUR_SFD_LG, DUR_CONDO, DUR_TOWNHOME,
    FWO_OOS, SEASONAL_TREE, CARE_GUIDE,
    UTIL_LOCATE, PUNCH_DAYS, WARRANTY_PGM, WARRANTY_PERIOD,
    PLANT_HEALTH, DRAINAGE_WP, RESEED_POL, EROSION_GULLY,
    FOUND_WATER_TOL, SWALE_TOL
];

export default class DivisionServiceScopeDetail extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    account;

    get isLoaded() { return !!this.account.data; }
    get hasError() { return !!this.account.error; }

    _val(field) { return getFieldValue(this.account.data, field); }
    _str(field) { return this._val(field) || '—'; }
    _bool(field){ const v = this._val(field); return v === true || v === 'true'; }

    get homeTypes()       { return this._str(HOME_TYPES); }
    get scopeSummary()    { return this._str(SCOPE_SUMMARY); }
    get scopeApplies()    { return this._str(SCOPE_APPLIES); }
    get scopeSource()     { return this._str(SCOPE_SOURCE); }
    get scopeCats()       { return this._str(SCOPE_CATS); }
    get schedLead()       { return this._val(SCHED_LEAD)    != null ? `${this._val(SCHED_LEAD)} days` : '—'; }
    get svcRespHrs()      { return this._val(SVC_RESP_HRS)  != null ? `${this._val(SVC_RESP_HRS)} hrs` : '—'; }
    get lotReadyApprover(){ return this._str(LOT_READY_APPVR); }
    get lotReleaseTrigger(){ return this._str(LOT_RELEASE); }
    get englishCrew()     { return this._bool(ENGLISH_CREW) ? 'Required' : 'Not required'; }
    get englishCrewChip() { return this._bool(ENGLISH_CREW) ? 'slds-badge cs-badge-red' : 'slds-badge slds-badge_lightest'; }
    get speedLimit()      { return this._val(SPEED_LIMIT)   != null ? `${this._val(SPEED_LIMIT)} mph` : '—'; }
    get stagingRule()     { return this._str(STAGING_RULE); }
    get drainageStd()     { return this._str(DRAINAGE_STD); }
    get erosionRule()     { return this._str(EROSION_RULE); }
    get pineMulch()       { return this._str(PINE_MULCH); }
    get additionalNotes() { return this._str(ADDITIONAL_NOTES); }
    get durSfdSm()        { return this._val(DUR_SFD_SM)  != null ? `${this._val(DUR_SFD_SM)} min` : '—'; }
    get durSfdLg()        { return this._val(DUR_SFD_LG)  != null ? `${this._val(DUR_SFD_LG)} min` : '—'; }
    get durCondo()        { return this._val(DUR_CONDO)   != null ? `${this._val(DUR_CONDO)} min`   : '—'; }
    get durTownhome()     { return this._val(DUR_TOWNHOME)!= null ? `${this._val(DUR_TOWNHOME)} min` : '—'; }
    get fwoOos()          { return this._bool(FWO_OOS) ? 'Required' : 'Not required'; }
    get fwoChip()         { return this._bool(FWO_OOS) ? 'slds-badge cs-badge-amber' : 'slds-badge slds-badge_lightest'; }
    get seasonalTree()    { return this._str(SEASONAL_TREE); }
    get careGuide()       { return this._bool(CARE_GUIDE) ? 'Required' : 'Not required'; }
    get careGuideChip()   { return this._bool(CARE_GUIDE) ? 'slds-badge cs-badge-aqua' : 'slds-badge slds-badge_lightest'; }
    get utilLocate()      { return this._val(UTIL_LOCATE)   != null ? `${this._val(UTIL_LOCATE)} hrs` : '—'; }
    get punchDays()       { return this._val(PUNCH_DAYS)    != null ? `${this._val(PUNCH_DAYS)} days` : '—'; }
    get warrantyPgm()     { return this._str(WARRANTY_PGM); }
    get warrantyPeriod()  { return this._val(WARRANTY_PERIOD) != null ? `${this._val(WARRANTY_PERIOD)} months` : '—'; }
    get plantHealth()     { return this._str(PLANT_HEALTH); }
    get drainageWp()      { return this._str(DRAINAGE_WP); }
    get reseedPol()       { return this._str(RESEED_POL); }
    get erosionGully()    { return this._str(EROSION_GULLY); }
    get foundWaterTol()   { return this._val(FOUND_WATER_TOL) != null ? `${this._val(FOUND_WATER_TOL)} hrs` : '—'; }
    get swaleTol()        { return this._val(SWALE_TOL)    != null ? `${this._val(SWALE_TOL)} hrs` : '—'; }
}