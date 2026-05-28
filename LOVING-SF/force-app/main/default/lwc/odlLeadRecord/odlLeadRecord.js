import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getLeadRecord from '@salesforce/apex/ODL_LeadController.getLeadRecord';

const UMB_STAGES = ['New', 'Contacted', 'Qualified', 'Converted', 'Closed'];
const CB_STAGES = ['New', 'Contacted', 'Site Visit Needed', 'Qualified', 'Converted', 'Closed'];
const LC_STAGES = ['New', 'Contacted', 'Qualified', 'Converted', 'Closed'];

export default class OdlLeadRecord extends LightningElement {
    @api recordId;
    @track lead = {};
    @track tasks = [];
    isLoaded = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getLeadRecord, { leadId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.lead = data.lead || {};
            this.tasks = (data.tasks || []).map(t => ({
                ...t,
                activityDateFormatted: t.ActivityDate ? new Date(t.ActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'
            }));
            this.isLoaded = true;
        } else if (error) {
            this.isLoaded = true;
        }
    }

    get isUmb() { return this.lead.ODL_Path__c === 'UMB'; }
    get isCustomBuild() { return this.lead.ODL_Path__c === 'Custom Build'; }
    get isLawnCare() { return this.lead.ODL_Path__c === 'Lawn Care'; }

    get lobChipClass() {
        if (this.isUmb) return 'chip co';
        if (this.isCustomBuild) return 'chip cp';
        if (this.isLawnCare) return 'chip ct';
        return 'chip cgr';
    }

    get pathSteps() {
        const stages = this.isCustomBuild ? CB_STAGES : UMB_STAGES;
        const current = this.lead.Status || '';
        let found = false;
        return stages.map(s => {
            let cssClass = 'path-step';
            if (s === current) { cssClass = 'path-step on'; found = true; }
            else if (!found) { cssClass = 'path-step done'; }
            return { label: s, cssClass };
        });
    }

    get lastTouchFormatted() {
        return this.lead.LastActivityDate ? new Date(this.lead.LastActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—';
    }

    get voicemailLabel() { return this.lead.Voicemail_Left__c ? 'Left ' + (this.lead.Last_Voicemail_Date__c ? new Date(this.lead.Last_Voicemail_Date__c).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '') : 'None'; }
    get vmChipClass() { return this.lead.Voicemail_Left__c ? 'chip ca' : 'chip cgr'; }
    get noTasks() { return this.tasks.length === 0; }
}
