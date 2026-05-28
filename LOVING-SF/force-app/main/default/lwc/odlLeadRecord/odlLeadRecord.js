import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getLeadRecord from '@salesforce/apex/ODL_LeadController.getLeadRecord';

const STAGES = ['New', 'Contacted', 'Qualified', 'Converted', 'Closed'];
const FMT = { month: 'short', day: 'numeric' };

function fmtDate(d) {
    if (!d) return '—';
    return new Date(d + 'T12:00:00').toLocaleDateString('en-US', FMT);
}

export default class OdlLeadRecord extends NavigationMixin(LightningElement) {
    @api recordId;
    @track lead = {};
    @track tasks = [];
    @track campaignName = null;
    isLoaded = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getLeadRecord, { leadId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.lead = data.lead || {};
            this.tasks = data.tasks || [];
            this.campaignName = data.campaignName || null;
            this.isLoaded = true;
        } else if (error) {
            this.isLoaded = true;
        }
    }

    get isUmb()         { return this.lead.ODL_Path__c === 'UMB'; }
    get isCustomBuild() { return this.lead.ODL_Path__c === 'Custom Build'; }
    get isLawnCare()    { return this.lead.ODL_Path__c === 'Lawn Care'; }

    get lobChipClass() {
        if (this.isUmb) return 'chip co';
        if (this.isCustomBuild) return 'chip cp';
        if (this.isLawnCare) return 'chip ct';
        return 'chip cgr';
    }

    get leadSubtitle() {
        if (this.isCustomBuild) return 'Custom Build homeowner lead. Discovery, site complexity, and site visit readiness.';
        if (this.isLawnCare)    return 'Lawn Care homeowner lead. Maintenance and recurring service qualification.';
        return 'UMB homeowner lead. Packaged backyard upgrade with package-fit and conversion cards.';
    }

    get conversionTarget() {
        if (this.isCustomBuild) return 'Homeowner Account, Contact, Property, Custom Build Opportunity';
        if (this.isLawnCare)    return 'Homeowner Account, Contact, Property, Lawn Care Opportunity';
        return 'Homeowner Account, Contact, Property, UMB Opportunity';
    }

    get campaignDisplay() { return this.campaignName || '—'; }

    get pathSteps() {
        const current = this.lead.Status || '';
        let found = false;
        return STAGES.map(s => {
            let cssClass = 'path-step';
            if (s === current)  { cssClass = 'path-step on'; found = true; }
            else if (!found)    { cssClass = 'path-step done'; }
            return { label: s, cssClass };
        });
    }

    get taskRows() {
        if (!this.tasks || this.tasks.length === 0) return [];
        const sorted = [...this.tasks].sort((a, b) => {
            const da = a.ActivityDate || '9999', db = b.ActivityDate || '9999';
            return da < db ? -1 : da > db ? 1 : 0;
        });
        return sorted.map((t, i) => ({
            ...t,
            activityLabel: t.TaskSubtype || t.Subject || '—',
            dateFormatted: fmtDate(t.ActivityDate),
            outcome: t.CallDisposition || (t.Description ? t.Description.substring(0, 60) : '—'),
            nextTask: i < sorted.length - 1 ? (sorted[i + 1].Subject || '—') : '—',
            nextDue:  (i < sorted.length - 1 && sorted[i + 1].ActivityDate)
                          ? fmtDate(sorted[i + 1].ActivityDate) : '—'
        }));
    }

    get noTasks() { return this.tasks.length === 0; }

    get openTaskCount() {
        return this.tasks.filter(t => t.Status !== 'Completed').length;
    }

    get lastTouchFormatted() { return fmtDate(this.lead.LastActivityDate); }

    get voicemailLabel() {
        if (!this.lead.Voicemail_Left__c) return 'None';
        const d = fmtDate(this.lead.Last_Voicemail_Date__c);
        return d !== '—' ? 'Left ' + d : 'Yes';
    }
    get vmChipClass() { return this.lead.Voicemail_Left__c ? 'chip ca' : 'chip cgr'; }

    get nextFollowUpFormatted() {
        const open = this.tasks
            .filter(t => t.ActivityDate && t.Status !== 'Completed')
            .sort((a, b) => (a.ActivityDate > b.ActivityDate ? 1 : -1));
        return open.length > 0 ? fmtDate(open[0].ActivityDate) : '—';
    }

    createTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'new' },
            state: { defaultFieldValues: encodeDefaultFieldValues({ WhoId: this.recordId, Subject: 'Follow Up' }) }
        });
    }

    logCall() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'new' },
            state: { defaultFieldValues: encodeDefaultFieldValues({ WhoId: this.recordId, Subject: 'Call', TaskSubtype: 'Call' }) }
        });
    }

    sendText() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'new' },
            state: { defaultFieldValues: encodeDefaultFieldValues({ WhoId: this.recordId, Subject: 'Send Text', TaskSubtype: 'Email' }) }
        });
    }

    convertLead() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: 'Lead', actionName: 'convert' }
        });
    }

    draftEmail() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: { recordId: this.recordId, objectApiName: 'Lead', relationshipApiName: 'ActivityHistories', actionName: 'view' }
        });
    }

    viewActivity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: { recordId: this.recordId, objectApiName: 'Lead', relationshipApiName: 'ActivityHistories', actionName: 'view' }
        });
    }

    viewTasks() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }
}
