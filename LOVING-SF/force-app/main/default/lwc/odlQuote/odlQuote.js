import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getUmbRecord from '@salesforce/apex/ODL_OpportunityController.getUmbRecord';

export default class OdlQuote extends LightningElement {
    @api recordId;
    @track opp = {};
    isLoaded = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getUmbRecord, { opportunityId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.opp = data.opp || {};
            this.isLoaded = true;
        } else if (error) {
            this.isLoaded = true;
        }
    }

    get quoteNumber() { return this.opp.Name ? this.opp.Name.replace(/[^0-9-]/g, '') : '—'; }
    get amountFormatted() { return this.opp.Amount ? '$' + Number(this.opp.Amount).toLocaleString() : '—'; }
    get depositFormatted() { return this.opp.Deposit_Due__c ? '$' + Number(this.opp.Deposit_Due__c).toLocaleString() : '—'; }
    get finalPaymentFormatted() {
        if (this.opp.Amount && this.opp.Deposit_Due__c) return '$' + (Number(this.opp.Amount) - Number(this.opp.Deposit_Due__c)).toLocaleString();
        return '—';
    }
    get quoteStatusChipClass() {
        const s = this.opp.Quote_Status__c;
        if (s === 'Accepted') return 'chip cg';
        if (s === 'Sent') return 'chip cb2';
        if (s === 'Rejected') return 'chip cr';
        return 'chip cgr';
    }
    get contractChipClass() {
        const s = this.opp.Contract_Status__c;
        if (s === 'Signed') return 'chip cg';
        if (s === 'Sent') return 'chip cb2';
        return 'chip cgr';
    }
    get depositStatus() { return this.opp.StageName === 'Deposit Paid' ? 'Paid' : 'Pending'; }
    get depositStatusChipClass() { return this.opp.StageName === 'Deposit Paid' ? 'chip cg' : 'chip ca'; }
}
