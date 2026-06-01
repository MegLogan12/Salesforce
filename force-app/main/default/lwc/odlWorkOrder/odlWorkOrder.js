import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getWorkOrderRecord from '@salesforce/apex/ODL_WorkController.getWorkOrderRecord';

const WO_STAGES = ['Created', 'Scheduled', 'In Progress', 'Punch', 'Closeout', 'Closed'];

export default class OdlWorkOrder extends NavigationMixin(LightningElement) {
    @api recordId;
    @track workOrder = {};
    @track lineItems = [];
    isLoaded = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getWorkOrderRecord, { workOrderId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.workOrder = data.workOrder || {};
            this.lineItems = (data.lineItems || []).map(li => ({
                ...li,
                statusChipClass: li.Status === 'Completed' ? 'chip cg' : li.Status === 'In Progress' ? 'chip ca' : 'chip cgr',
                ownerName: '—',
                dueDateFormatted: li.EndDate ? new Date(li.EndDate + 'T12:00:00').toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'
            }));
            this.isLoaded = true;
        } else if (error) {
            this.isLoaded = true;
        }
    }

    get pathSteps() {
        const current = this.workOrder.Status || '';
        let found = false;
        return WO_STAGES.map(s => {
            let cssClass = 'path-step';
            if (s === current) { cssClass = 'path-step on'; found = true; }
            else if (!found) cssClass = 'path-step done';
            return { label: s, cssClass };
        });
    }

    get startDateFormatted() { return this.workOrder.StartDate ? new Date(this.workOrder.StartDate + 'T12:00:00').toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'; }
    get endDateFormatted() { return this.workOrder.EndDate ? new Date(this.workOrder.EndDate + 'T12:00:00').toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'; }
    get statusChipClass() {
        const s = this.workOrder.Status;
        if (s === 'Closed' || s === 'Completed') return 'chip cg';
        if (s === 'In Progress') return 'chip ca';
        return 'chip cb2';
    }
    get opportunityName() { return this.workOrder.ODL_Opportunity__r ? this.workOrder.ODL_Opportunity__r.Name : '—'; }
    get recordTypeName() { return this.workOrder.RecordType ? this.workOrder.RecordType.Name : 'Work Order'; }
    get propertyName() { return this.workOrder.Homeowner_Property__r ? this.workOrder.Homeowner_Property__r.Name : '—'; }
    get crewName() { return this.workOrder.Owner ? this.workOrder.Owner.Name : '—'; }
    get fieldManagerName() { return this.workOrder.Field_Manager__r ? this.workOrder.Field_Manager__r.Name : '—'; }
    get noLineItems() { return this.lineItems.length === 0; }
    get openPunchCount() { return this.lineItems.filter(li => li.Status !== 'Completed').length; }
    // Inline edit — standard record edit modals (FLS + validation enforced)
    handleEditWorkOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: 'WorkOrder', actionName: 'edit' }
        });
    }
    handleEditProperty() {
        const propId = this.workOrder.Homeowner_Property__c;
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
    viewFiles() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: { recordId: this.recordId, objectApiName: 'WorkOrder', relationshipApiName: 'AttachedContentDocuments', actionName: 'view' }
        });
    }
    viewActivity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: { recordId: this.recordId, objectApiName: 'WorkOrder', relationshipApiName: 'ActivityHistories', actionName: 'view' }
        });
    }
    logLabor() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Time_Entry__c', actionName: 'new' },
            state: { defaultFieldValues: encodeDefaultFieldValues({ Work_Order__c: this.recordId }) }
        });
    }
    updateMaterials() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Material_Allocation__c', actionName: 'new' },
            state: { defaultFieldValues: encodeDefaultFieldValues({ Work_Order__c: this.recordId }) }
        });
    }
    submitPunchNote() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'new' },
            state: { defaultFieldValues: encodeDefaultFieldValues({ WhatId: this.recordId, Subject: 'Punch Note', Type: 'Note' }) }
        });
    }

    get lastTouchDisplay() {
        const d = this.workOrder.LastModifiedDate;
        return d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : '—';
    }
    get daysSinceLastTouch() {
        const d = this.workOrder.LastModifiedDate;
        if (!d) return null;
        return Math.floor((Date.now() - new Date(d).getTime()) / 86400000);
    }
    get daysSinceLastTouchDisplay() {
        const d = this.daysSinceLastTouch;
        if (d === null) return '—';
        if (d === 0) return 'today';
        if (d === 1) return '1 day ago';
        return `${d} days ago`;
    }
    get stalenessChipClass() {
        const d = this.daysSinceLastTouch;
        if (d === null) return 'chip cgr';
        if (d <= 1) return 'chip cg';
        if (d <= 3) return 'chip ca';
        return 'chip cgr';
    }
    get completedPunchCount() { return this.lineItems.filter(li => li.Status === 'Completed').length; }
    get totalPunchCount() { return this.lineItems.length; }
}