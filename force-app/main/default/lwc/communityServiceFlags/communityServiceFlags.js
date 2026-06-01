import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import AQUA_CUSTOMER from '@salesforce/schema/Community__c.Aqua_Customer__c';
import AQUA_INCLUDED from '@salesforce/schema/Community__c.Aqua_Included__c';
import AQUA_ZONES from '@salesforce/schema/Community__c.Aqua_Zones__c';
import AQUA_NOTES from '@salesforce/schema/Community__c.Aqua_Notes__c';
import TEMP_IRRIGATION from '@salesforce/schema/Community__c.Temp_Irrigation_Included__c';
import IRRIGATION_TYPE from '@salesforce/schema/Community__c.Irrigation_Type__c';
import IRRIGATION_ZONE_COUNT from '@salesforce/schema/Community__c.Irrigation_Zone_Count__c';
import IRRIGATION_NOTES from '@salesforce/schema/Community__c.Irrigation_Notes__c';
import MODEL_HOME_DISCOUNT_PCT from '@salesforce/schema/Community__c.Model_Home_Discount_Pct__c';
import MODEL_HOME_DISCOUNT_NOTES from '@salesforce/schema/Community__c.Model_Home_Discount_Notes__c';

const FIELDS = [
    AQUA_CUSTOMER, AQUA_INCLUDED, AQUA_ZONES, AQUA_NOTES,
    TEMP_IRRIGATION, IRRIGATION_TYPE, IRRIGATION_ZONE_COUNT, IRRIGATION_NOTES,
    MODEL_HOME_DISCOUNT_PCT, MODEL_HOME_DISCOUNT_NOTES
];

export default class CommunityServiceFlags extends LightningElement {
    @api recordId;
    _record;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this._record = data;
            this.error = undefined;
        } else if (error) {
            this._record = undefined;
            this.error = (error.body && error.body.message) ? error.body.message : 'Unable to load service flags.';
        }
    }

    get isLoaded() { return this._record !== undefined; }
    get hasError() { return !!this.error; }

    get serviceFlags() {
        if (!this._record) return [];
        const aquaCustomer = getFieldValue(this._record, AQUA_CUSTOMER);
        const aquaIncluded = getFieldValue(this._record, AQUA_INCLUDED);
        const tempIrrigation = getFieldValue(this._record, TEMP_IRRIGATION);
        return [
            {
                id: 'aquaCustomer',
                label: 'Aqua Customer',
                active: aquaCustomer,
                chipClass: 'chip ' + (aquaCustomer ? 'caqua' : 'cgr'),
                chipLabel: aquaCustomer ? 'Yes' : 'No'
            },
            {
                id: 'aquaIncluded',
                label: 'Aqua Included',
                active: aquaIncluded,
                chipClass: 'chip ' + (aquaIncluded ? 'caqua' : 'cgr'),
                chipLabel: aquaIncluded ? 'Yes' : 'No'
            },
            {
                id: 'tempIrrigation',
                label: 'Temp Irrigation',
                active: tempIrrigation,
                chipClass: 'chip ' + (tempIrrigation ? 'cb2' : 'cgr'),
                chipLabel: tempIrrigation ? 'Yes' : 'No'
            }
        ];
    }

    get aquaZones() {
        return getFieldValue(this._record, AQUA_ZONES) || null;
    }

    get hasAquaNotes() {
        return !!getFieldValue(this._record, AQUA_NOTES);
    }

    get aquaNotes() {
        return getFieldValue(this._record, AQUA_NOTES) || '';
    }

    get irrigationType() {
        return getFieldValue(this._record, IRRIGATION_TYPE) || '—';
    }

    get irrigationZoneCount() {
        return getFieldValue(this._record, IRRIGATION_ZONE_COUNT) || null;
    }

    get hasIrrigationNotes() {
        return !!getFieldValue(this._record, IRRIGATION_NOTES);
    }

    get irrigationNotes() {
        return getFieldValue(this._record, IRRIGATION_NOTES) || '';
    }

    get modelHomeDiscount() {
        const val = getFieldValue(this._record, MODEL_HOME_DISCOUNT_PCT);
        return val != null ? val + '%' : null;
    }

    get hasModelHomeDiscount() {
        return getFieldValue(this._record, MODEL_HOME_DISCOUNT_PCT) != null;
    }

    get modelHomeDiscountNotes() {
        return getFieldValue(this._record, MODEL_HOME_DISCOUNT_NOTES) || '';
    }
}