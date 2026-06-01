import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import SERVICE_MODEL from '@salesforce/schema/Community__c.Service_Model__c';
import PRICING_SCHEDULE from '@salesforce/schema/Community__c.Pricing_Schedule__c';
import PHASES from '@salesforce/schema/Community__c.Phases__c';
import LOT_NUMBERS from '@salesforce/schema/Community__c.Lot_Numbers__c';
import NUM_LOTS from '@salesforce/schema/Community__c.Number_Of_Lots__c';

const FIELDS = [SERVICE_MODEL, PRICING_SCHEDULE, PHASES, LOT_NUMBERS, NUM_LOTS];

export default class CommunityStage extends LightningElement {
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
            this.error = (error.body && error.body.message) ? error.body.message : 'Unable to load community stage.';
        }
    }

    get isLoaded() {
        return this._record !== undefined;
    }

    get hasError() {
        return !!this.error;
    }

    get serviceModel() {
        return getFieldValue(this._record, SERVICE_MODEL) || '—';
    }

    get pricingSchedule() {
        return getFieldValue(this._record, PRICING_SCHEDULE) || '—';
    }

    get phases() {
        return getFieldValue(this._record, PHASES) || null;
    }

    get hasPhases() {
        return !!this.phases;
    }

    get lotNumbers() {
        return getFieldValue(this._record, LOT_NUMBERS) || '—';
    }

    get numLots() {
        return getFieldValue(this._record, NUM_LOTS) || '—';
    }
}