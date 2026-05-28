import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getLawnCareRecord from '@salesforce/apex/ODL_OpportunityController.getLawnCareRecord';

const LC_STAGES = ['Inquiry', 'Estimate', 'Service Plan', 'Contract', 'First Service', 'Active'];

export default class OdlLawnCareRecord extends LightningElement {
    @api recordId;
    @track opp = {};
    @track tasks = [];
    isLoaded = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getLawnCareRecord, { opportunityId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.opp = data.opp || {};
            this.tasks = (data.tasks || []).map(t => ({
                ...t,
                activityDateFormatted: t.ActivityDate ? new Date(t.ActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'
            }));
            this.isLoaded = true;
        } else if (error) {
            this.isLoaded = true;
        }
    }

    get pathSteps() {
        const current = this.opp.StageName || '';
        let found = false;
        return LC_STAGES.map(s => {
            let cssClass = 'path-step';
            if (s === current) { cssClass = 'path-step on'; found = true; }
            else if (!found) cssClass = 'path-step done';
            return { label: s, cssClass };
        });
    }

    get amountFormatted() { return this.opp.Amount ? '$' + Number(this.opp.Amount).toLocaleString() : '—'; }
    get closeDateFormatted() { return this.opp.CloseDate ? new Date(this.opp.CloseDate + 'T12:00:00').toLocaleDateString('en-US', {month:'long', day:'numeric', year:'numeric'}) : '—'; }
    get monthlyBillingFormatted() { return this.opp.Monthly_Billing__c ? '$' + Number(this.opp.Monthly_Billing__c).toLocaleString() : '—'; }
    get lastTouchFormatted() { return this.opp.LastActivityDate ? new Date(this.opp.LastActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'; }
    get voicemailLabel() { return this.opp.Voicemail_Left__c ? 'Left' : 'None'; }
    get vmChipClass() { return this.opp.Voicemail_Left__c ? 'chip ca' : 'chip cgr'; }
    get hasProperty() { return this.opp.Homeowner_Property__c != null; }
    get noTasks() { return this.tasks.length === 0; }
}
