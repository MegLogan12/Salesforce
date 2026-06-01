import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getUmbRecord from '@salesforce/apex/ODL_OpportunityController.getUmbRecord';
import updateSelectedPackage from '@salesforce/apex/ODL_OpportunityController.updateSelectedPackage';
import advanceStage from '@salesforce/apex/ODL_OpportunityController.advanceStage';

// Maps actual Opportunity StageName values → display labels shown in the path tracker
// UMB path only — must match live org Opportunity.StageName picklist
const UMB_STAGES = [
    { value: 'Prospecting',            label: 'Intake' },
    { value: 'Consultation Scheduled', label: 'Consult' },
    { value: 'Design In Progress',     label: 'Design' },
    { value: 'Proposal Presented',     label: 'Quote Sent' },
    { value: 'Contract Sent',          label: 'Contract' },
    { value: 'Contract Signed',        label: 'Signed' },
    { value: 'Deposit Paid',           label: 'Deposit' },
    { value: 'Pre-Production',         label: 'Pre-Prod' },
    { value: 'In Progress',            label: 'In Progress' },
    { value: 'Pre Close',              label: 'Pre Close' },
    { value: 'Job Completed',          label: 'Complete' },
];

export default class OdlUmbRecord extends NavigationMixin(LightningElement) {
    @api recordId;
    @track opp = {};
    @track tasks = [];
    @track packageOptions = [];
    @track isSavingPackage = false;
    @track isAdvancingStage = false;
    isLoaded = false;
    errorMessage = '';
    _wiredResult;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getUmbRecord, { opportunityId: '$recordId' })
    wiredData(result) {
        this._wiredResult = result;
        const { error, data } = result;
        if (data) {
            this.opp = data.opp || {};
            this.tasks = (data.tasks || []).map(t => ({
                ...t,
                activityDateFormatted: t.ActivityDate ? new Date(t.ActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'
            }));
            this.packageOptions = (data.packageOptions || []).map(p => ({
                ...p,
                statusLabel: p.selected ? 'Selected' : 'Available',
                statusChipClass: p.selected ? 'chip co' : 'chip cg'
            }));
            this.errorMessage = '';
            this.isLoaded = true;
        } else if (error) {
            this.opp = {};
            this.tasks = [];
            this.packageOptions = [];
            this.errorMessage = (error.body && error.body.message) ? error.body.message : 'Unable to load this opportunity.';
            this.isLoaded = true;
        }
    }

    // True only when the wire returned a real Opportunity record; guards the
    // template against dereferencing opp.Account.Name / opp.Owner.Name on {}.
    get hasOpp() { return this.opp != null && this.opp.Id != null; }
    get loadErrorLabel() { return this.errorMessage || 'This opportunity could not be loaded.'; }

    get noPackageOptions() { return this.packageOptions.length === 0; }

    get pathSteps() {
        const current = this.opp.StageName || '';
        let found = false;
        return UMB_STAGES.map(s => {
            let cssClass = 'path-step';
            if (s.value === current) { cssClass = 'path-step on'; found = true; }
            else if (!found) cssClass = 'path-step done';
            return { label: s.label, value: s.value, cssClass };
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
    get noTasks() { return this.tasks.length === 0; }
    get lastActivityLabel() {
        if (this.tasks.length === 0) return '—';
        const sorted = [...this.tasks].sort((a, b) => (b.ActivityDate || '') > (a.ActivityDate || '') ? 1 : -1);
        return sorted[0].Subject || '—';
    }
    get nextTaskLabel() {
        const today = new Date().toISOString().slice(0, 10);
        const future = this.tasks.filter(t => t.ActivityDate && t.ActivityDate >= today).sort((a, b) => a.ActivityDate > b.ActivityDate ? 1 : -1);
        return future.length > 0 ? (future[0].Subject || '—') : '—';
    }

    get nextFollowUpFormatted() {
        const today = new Date();
        const future = this.tasks
            .filter(t => t.ActivityDate && new Date(t.ActivityDate) >= today)
            .sort((a, b) => new Date(a.ActivityDate) - new Date(b.ActivityDate));
        return future.length > 0 ? future[0].activityDateFormatted : '—';
    }
    createTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'new' },
            state: { defaultFieldValues: encodeDefaultFieldValues({ WhatId: this.recordId, Subject: 'Follow Up' }) }
        });
    }
    logCall() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'new' },
            state: { defaultFieldValues: encodeDefaultFieldValues({ WhatId: this.recordId, Subject: 'Call', TaskSubtype: 'Call' }) }
        });
    }
    draftEmail() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: { recordId: this.recordId, objectApiName: 'Opportunity', relationshipApiName: 'ActivityHistories', actionName: 'view' }
        });
    }
    viewActivity() { this.draftEmail(); }
    viewTasks() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }
    get nextActions() {
        const stage = this.opp.StageName || '';
        const map = {
            'Prospecting':             ['Confirm homeowner name, property, and phone', 'Send intake confirmation text', 'Schedule consultation within 48 hours'],
            'Consultation Scheduled':  ['Confirm appointment with homeowner day before', 'Review property notes and service interest', 'Prepare package options for the conversation'],
            'Design In Progress':      ['Complete site visit and measurements', 'Capture yard photos for the file', 'Note drainage, access, HOA, and scope concerns'],
            'Proposal Presented':      ['Send quote to homeowner via email or portal', 'Call to walk through within 24 hours', 'If no response in 3 days, send text reminder'],
            'Contract Sent':           ['Follow up within 48 hours', 'Answer any contract questions', 'Confirm deposit amount and payment method'],
            'Contract Signed':         ['Confirm deposit amount and collect payment', 'Enter deposit into system and mark received', 'Send homeowner project kickoff summary'],
            'Deposit Paid':            ['Schedule install date and confirm with crew', 'Order materials and verify lead times', 'Send homeowner install prep checklist'],
            'Pre-Production':          ['Confirm materials are ordered and arriving on time', 'Verify crew capacity and install date', 'Check for HOA, permit, or utility requirements'],
            'In Progress':             ['Check in with foreman daily during active build', 'Flag any site issues or scope changes immediately', 'Confirm punch list before final walkthrough'],
            'Pre Close':               ['Walk the site with the homeowner', 'Collect final payment and confirm invoice', 'Complete punch list and photo documentation'],
            'Job Completed':           ['Send thank you and Google review request', 'Confirm final invoice was received and paid', 'Log warranty details and schedule 30-day follow-up'],
        };
        return map[stage] || ['Advance opportunity to next stage when ready'];
    }

    get canAdvanceStage() {
        const terminal = ['Job Completed', 'Closed Lost', 'Closed Won'];
        return !terminal.includes(this.opp.StageName);
    }

    // ── Inline edit — standard record edit modal (FLS + validation enforced) ────
    handleEditOpp() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: 'Opportunity', actionName: 'edit' }
        });
    }

    handleEditProperty() {
        const propId = this.opp.Homeowner_Property__c;
        if (!propId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: propId, objectApiName: 'Homeowner_Property__c', actionName: 'edit' }
        });
    }

    // ── Package selection ──────────────────────────────────────────────────────
    handleSelectPackage(event) {
        const pkg = event.currentTarget.dataset.package;
        if (!pkg || this.isSavingPackage) return;
        this.isSavingPackage = true;
        updateSelectedPackage({ opportunityId: this.recordId, packageName: pkg })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Package Selected', message: pkg + ' package selected.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body ? err.body.message : 'Could not save package.', variant: 'error' }));
            })
            .finally(() => { this.isSavingPackage = false; });
    }

    // ── Stage advance ──────────────────────────────────────────────────────────
    handleAdvanceStage() {
        if (this.isAdvancingStage || !this.canAdvanceStage) return;
        this.isAdvancingStage = true;
        advanceStage({ opportunityId: this.recordId })
            .then(newStage => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Stage Updated', message: 'Moved to ' + newStage, variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body ? err.body.message : 'Could not advance stage.', variant: 'error' }));
            })
            .finally(() => { this.isAdvancingStage = false; });
    }
}