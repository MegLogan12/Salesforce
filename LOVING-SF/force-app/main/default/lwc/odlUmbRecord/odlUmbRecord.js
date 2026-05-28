import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getUmbRecord from '@salesforce/apex/ODL_OpportunityController.getUmbRecord';

const UMB_STAGES = ['Intake', 'Design Review', 'Consult', 'Quote Review', 'Contract Sent', 'Deposit Paid', 'Scheduled', 'Final Paid'];

export default class OdlUmbRecord extends LightningElement {
    @api recordId;
    @track opp = {};
    @track tasks = [];
    isLoaded = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getUmbRecord, { opportunityId: '$recordId' })
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
        return UMB_STAGES.map(s => {
            let cssClass = 'path-step';
            if (s === current) { cssClass = 'path-step on'; found = true; }
            else if (!found) cssClass = 'path-step done';
            return { label: s, cssClass };
        });
    }

    get amountFormatted() { return this.opp.Amount ? '$' + Number(this.opp.Amount).toLocaleString() : '—'; }
    get closeDateFormatted() { return this.opp.CloseDate ? new Date(this.opp.CloseDate + 'T12:00:00').toLocaleDateString('en-US', {month:'long', day:'numeric', year:'numeric'}) : '—'; }
    get depositDueFormatted() { return this.opp.Deposit_Due__c ? '$' + Number(this.opp.Deposit_Due__c).toLocaleString() : '—'; }
    get customerViewedFormatted() { return this.opp.Customer_Viewed_Date__c ? new Date(this.opp.Customer_Viewed_Date__c + 'T12:00:00').toLocaleDateString('en-US', {month:'short', day:'numeric', year:'numeric'}) : '—'; }
    get lastTouchFormatted() { return this.opp.LastActivityDate ? new Date(this.opp.LastActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'; }
    get voicemailLabel() { return this.opp.Voicemail_Left__c ? 'Left ' + (this.opp.Last_Voicemail_Date__c ? new Date(this.opp.Last_Voicemail_Date__c + 'T12:00:00').toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '') : 'None'; }
    get vmChipClass() { return this.opp.Voicemail_Left__c ? 'chip ca' : 'chip cgr'; }
    get hasProperty() { return this.opp.Homeowner_Property__c != null; }
    get portalPublishedLabel() { return this.opp.Portal_Published__c ? 'Yes' : 'No'; }
    get portalChipClass() { return this.opp.Portal_Published__c ? 'chip cg' : 'chip cgr'; }
    get designChipClass() {
        const d = this.opp.Design_Status__c;
        if (d === 'Approved') return 'chip cg';
        if (d === 'Rejected') return 'chip cr';
        if (d === 'In Review') return 'chip ca';
        return 'chip cgr';
    }
    get drainageChipClass() {
        const d = this.opp.Homeowner_Property__r && this.opp.Homeowner_Property__r.Drainage_Risk__c;
        return d === 'High' ? 'chip cr' : d === 'Medium' ? 'chip ca' : 'chip cg';
    }
    get utilityChipClass() {
        const u = this.opp.Homeowner_Property__r && this.opp.Homeowner_Property__r.Utility_Review_Status__c;
        return (u === 'Review Needed' || u === 'Likely Required') ? 'chip cb2' : u === 'Complete' ? 'chip cg' : 'chip cgr';
    }
    get retreatStatus() { return this.opp.Selected_Package__c === 'Retreat' ? 'Selected' : 'Available'; }
    get entertainerStatus() { return this.opp.Selected_Package__c === 'Entertainer' ? 'Selected' : 'Available'; }
    get signatureStatus() { return this.opp.Selected_Package__c === 'Signature' ? 'Selected' : 'Available'; }
    get retreatChipClass() { return this.opp.Selected_Package__c === 'Retreat' ? 'chip co' : 'chip cg'; }
    get entertainerChipClass() { return this.opp.Selected_Package__c === 'Entertainer' ? 'chip co' : 'chip cg'; }
    get signatureChipClass() { return this.opp.Selected_Package__c === 'Signature' ? 'chip co' : 'chip cg'; }
    get noTasks() { return this.tasks.length === 0; }
    get nextActions() {
        const actions = [];
        if (this.opp.StageName === 'Quote Review') actions.push('Call homeowner to review quote', 'If no response, send text reminder', 'Move to Contract Sent after acceptance');
        else if (this.opp.StageName === 'Consult') actions.push('Schedule consultation call', 'Review design options with customer');
        else actions.push('Advance opportunity to next stage');
        return actions;
    }
}
