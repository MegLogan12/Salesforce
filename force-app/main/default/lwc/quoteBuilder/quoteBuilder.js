import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class QuoteBuilder extends NavigationMixin(LightningElement) {

    @track builderWo     = '';
    @track builderSource = '';
    @track builderNotes  = '';
    @track lineItems     = [];

    get hasLineItems() {
        return this.lineItems && this.lineItems.length > 0;
    }

    get validationIssues() {
        const issues = [];
        if (!this.builderWo.trim()) issues.push('Work Order is required');
        if (!this.builderSource)   issues.push('Source is required');
        if (!this.hasLineItems)    issues.push('At least one line item is required');
        return issues;
    }

    get hasValidationIssues() {
        return this.validationIssues.length > 0;
    }

    // ── Field change handlers ──────────────────────────────────────
    onBuilderWoChange(event)     { this.builderWo     = event.target.value; }
    onBuilderSourceChange(event) { this.builderSource = event.target.value; }
    onBuilderNotesChange(event)  { this.builderNotes  = event.target.value; }

    // ── Line item management ───────────────────────────────────────
    addLineItem() {
        const idx = this.lineItems.length;
        this.lineItems = [
            ...this.lineItems,
            { idx, item: '', cause: '', qty: '1', type: 'Billable' }
        ];
    }

    onLineItemChange(event) {
        const idx   = parseInt(event.currentTarget.dataset.idx, 10);
        const field = event.currentTarget.dataset.field;
        this.lineItems = this.lineItems.map(li =>
            li.idx === idx ? { ...li, [field]: event.target.value } : li
        );
    }

    onLineItemTypeChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this.lineItems = this.lineItems.map(li =>
            li.idx === idx ? { ...li, type: event.target.value } : li
        );
    }

    // ── Actions ────────────────────────────────────────────────────
    // Quote__c.Work_Order__c is a lookup that requires a record Id; the
    // Work Order field on this form is free-text ("WO number or search").
    // Only prefill the lookup when the entered value is a valid Salesforce Id,
    // otherwise the prefill silently fails (or errors) on a non-Id string.
    buildDefaultFieldValues(status) {
        const parts = ['Status__c=' + status];
        const wo = (this.builderWo || '').trim();
        if (/^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/.test(wo)) {
            parts.push('Work_Order__c=' + wo);
        }
        return parts.join(',');
    }

    saveQuoteDraft() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Quote__c', actionName: 'new' },
            state: {
                defaultFieldValues: this.buildDefaultFieldValues('Draft')
            }
        });
    }

    sendQuote() {
        if (this.hasValidationIssues) {
            this.dispatchEvent(new ShowToastEvent({
                title   : 'Required fields missing',
                message : this.validationIssues.join(', '),
                variant : 'warning'
            }));
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Quote__c', actionName: 'new' },
            state: {
                defaultFieldValues: this.buildDefaultFieldValues('Sent')
            }
        });
    }
}