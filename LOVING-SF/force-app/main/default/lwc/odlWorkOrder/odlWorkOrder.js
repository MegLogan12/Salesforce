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
    get propertyName() { return this.workOrder.Homeowner_Property__r ? this.workOrder.Homeowner_Property__r.Name : '—'; }
    get crewName() { return this.workOrder.Owner ? this.workOrder.Owner.Name : '—'; }
    get fieldManagerName() { return this.workOrder.Field_Manager__r ? this.workOrder.Field_Manager__r.Name : '—'; }
    get noLineItems() { return this.lineItems.length === 0; }
    get openPunchCount() { return this.lineItems.filter(li => li.Status !== 'Completed').length; }
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
}
