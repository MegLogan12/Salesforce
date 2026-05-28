import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getCustomBuildRecord from '@salesforce/apex/ODL_OpportunityController.getCustomBuildRecord';

const CB_STAGES = ['Inquiry', 'Discovery', 'Site Visit', 'Concept', 'Estimate', 'Proposal', 'Contract', 'Deposit', 'Pre-Con', 'Construction', 'Punch', 'Final Paid'];

export default class OdlCustomBuildRecord extends LightningElement {
    @api recordId;
    @track opp = {};
    @track tasks = [];
    isLoaded = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getCustomBuildRecord, { opportunityId: '$recordId' })
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
        return CB_STAGES.map(s => {
            let cssClass = 'path-step';
            if (s === current) { cssClass = 'path-step on'; found = true; }
            else if (!found) cssClass = 'path-step done';
            return { label: s, cssClass };
        });
    }

    get amountFormatted() { return this.opp.Amount ? '$' + Number(this.opp.Amount).toLocaleString() : '—'; }
    get closeDateFormatted() { return this.opp.CloseDate ? new Date(this.opp.CloseDate + 'T12:00:00').toLocaleDateString('en-US', {month:'long', day:'numeric', year:'numeric'}) : '—'; }
    get projectedCostFormatted() { return this.opp.Projected_Cost__c ? '$' + Number(this.opp.Projected_Cost__c).toLocaleString() : 'Pending'; }
    get lastTouchFormatted() { return this.opp.LastActivityDate ? new Date(this.opp.LastActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'; }
    get voicemailLabel() { return this.opp.Voicemail_Left__c ? 'Left' : 'None'; }
    get vmChipClass() { return this.opp.Voicemail_Left__c ? 'chip ca' : 'chip cgr'; }
    get hasProperty() { return this.opp.Homeowner_Property__c != null; }
    get drainageChipClass() {
        const d = this.opp.Homeowner_Property__r && this.opp.Homeowner_Property__r.Drainage_Risk__c;
        return d === 'High' ? 'chip cr' : d === 'Medium' ? 'chip ca' : 'chip cg';
    }
    get utilityChipClass() {
        const u = this.opp.Homeowner_Property__r && this.opp.Homeowner_Property__r.Utility_Review_Status__c;
        return (u === 'Review Needed' || u === 'Likely Required') ? 'chip cb2' : u === 'Complete' ? 'chip cg' : 'chip cgr';
    }
    get noTasks() { return this.tasks.length === 0; }

    get nextFollowUpFormatted() {
        const today = new Date();
        const future = this.tasks
            .filter(t => t.ActivityDate && new Date(t.ActivityDate) >= today)
            .sort((a, b) => new Date(a.ActivityDate) - new Date(b.ActivityDate));
        return future.length > 0 ? future[0].activityDateFormatted : '—';
    }
}
