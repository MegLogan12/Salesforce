import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getCustomBuildRecord from '@salesforce/apex/ODL_OpportunityController.getCustomBuildRecord';

const CB_STAGES = ['Inquiry', 'Discovery', 'Site Visit', 'Concept', 'Estimate', 'Proposal', 'Contract', 'Deposit', 'Pre-Con', 'Construction', 'Punch', 'Final Paid'];

export default class OdlCustomBuildRecord extends NavigationMixin(LightningElement) {
    @api recordId;
    @track opp = {};
    @track tasks = [];
    isLoaded = false;
    errorMessage = '';

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
            this.errorMessage = '';
            this.isLoaded = true;
        } else if (error) {
            this.opp = {};
            this.tasks = [];
            this.errorMessage = (error.body && error.body.message) ? error.body.message : 'Unable to load this opportunity.';
            this.isLoaded = true;
        }
    }

    // True only when the wire returned a real Opportunity record; guards the
    // template against dereferencing opp.Account.Name / opp.Owner.Name on {}.
    get hasOpp() { return this.opp != null && this.opp.Id != null; }
    get loadErrorLabel() { return this.errorMessage || 'This opportunity could not be loaded.'; }

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

    // Site visit + scope items come from the opportunity's live related Tasks — never hardcoded.
    get scopeRows() {
        return this.tasks.map(t => ({
            id: t.Id,
            item: t.Subject || '—',
            status: t.Status || '—',
            statusChipClass: t.IsClosed ? 'chip cg' : 'chip cgr',
            owner: (t.Owner && t.Owner.Name) ? t.Owner.Name : '—',
            dateFormatted: t.activityDateFormatted
        }));
    }
    get noScopeRows() { return this.scopeRows.length === 0; }

    // Stage-derived guidance — computed from the live StageName, not static content.
    get nextActions() {
        const stage = this.opp.StageName || '';
        const map = {
            'Prospecting':            ['Complete discovery call', 'Confirm property and scope interest', 'Schedule site visit'],
            'Consultation Scheduled': ['Confirm site visit prep with homeowner', 'Assign designer for the visit', 'Review property notes before arrival'],
            'Design In Progress':     ['Complete measurements and photos on site', 'Draft scope of work', 'Note drainage, access, and utility concerns'],
            'Proposal Presented':     ['Send estimate to homeowner', 'Walk through scope within 24 hours', 'Follow up if no response in 3 days'],
            'Contract Sent':          ['Follow up within 48 hours', 'Answer contract questions', 'Confirm deposit amount'],
            'Contract Signed':        ['Collect deposit', 'Confirm build schedule', 'Send kickoff summary'],
            'Deposit Paid':           ['Schedule install and confirm crew', 'Order materials', 'Send prep checklist']
        };
        return map[stage] || ['Advance opportunity to next stage when ready'];
    }
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
    // Inline edit — standard record edit modals (FLS + validation enforced)
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
}