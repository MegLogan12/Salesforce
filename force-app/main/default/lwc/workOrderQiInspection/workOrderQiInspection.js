import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getQiInspection from '@salesforce/apex/WorkOrderQiController.getQiInspection';
import saveLines from '@salesforce/apex/WorkOrderQiController.saveLines';

export default class WorkOrderQiInspection extends LightningElement {
    @api recordId;

    @track inspection = null;
    @track lines = [];
    @track isLoading = true;
    @track isSaving  = false;
    @track saveError = null;

    _wiredResult;

    @wire(getQiInspection, { workOrderId: '$recordId' })
    wiredData(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.error) { this.inspection = null; this.lines = []; return; }
        if (result.data) {
            this.inspection = result.data.inspection;
            this.lines = (result.data.lines || []).map(l => ({
                ...l,
                resultClass: l.Result__c === 'Pass'
                    ? 'slds-badge slds-theme_success'
                    : l.Result__c === 'Fail'
                        ? 'slds-badge slds-theme_error'
                        : 'slds-badge'
            }));
        }
    }

    get hasNoInspection() { return !this.inspection; }

    get resultBadgeClass() {
        const r = (this.inspection && this.inspection.Result__c) || '';
        if (r === 'Excellent' || r === 'Acceptable') return 'slds-badge slds-theme_success';
        if (r.includes('Rework'))                    return 'slds-badge slds-theme_error';
        return 'slds-badge';
    }

    handleScoreChange(event) {
        const lineId = event.target.dataset.id;
        const val    = Number(event.target.value);
        this.lines = this.lines.map(l =>
            l.Id === lineId
                ? { ...l, Score__c: val,
                    resultClass: val >= 9 ? 'slds-badge slds-theme_success' : 'slds-badge slds-theme_error' }
                : l
        );
    }

    handleNoteChange(event) {
        const lineId = event.target.dataset.id;
        const val    = event.target.value;
        this.lines = this.lines.map(l => l.Id === lineId ? { ...l, Note__c: val } : l);
    }

    async handleSave() {
        this.isSaving  = true;
        this.saveError = null;
        try {
            const payload = this.lines.map(l => ({ Id: l.Id, Score__c: l.Score__c, Note__c: l.Note__c }));
            await saveLines({ lineData: JSON.stringify(payload) });
            await refreshApex(this._wiredResult);
            this.dispatchEvent(new ShowToastEvent({ title: 'Saved', message: 'QI scores saved.', variant: 'success' }));
        } catch (e) {
            this.saveError = (e.body && e.body.message) ? e.body.message : String(e);
        } finally {
            this.isSaving = false;
        }
    }
}