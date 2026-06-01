import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getPrepData from '@salesforce/apex/OneOnOnePrepController.getPrepData';

export default class OneOnOnePrep extends NavigationMixin(LightningElement) {
    @api recordId;

    @track prepData  = null;
    @track error     = null;
    @track isLoading = true;

    _wiredResult;

    @wire(getPrepData, { recordId: '$recordId' })
    wiredData(result) {
        this._wiredResult = result;
        if (result.data) {
            this.prepData  = result.data;
            this.error     = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error     = result.error?.body?.message || 'Unable to load 1:1 data.';
            this.isLoading = false;
        }
    }

    // ── Computed getters ──────────────────────────────────────────────────────

    get recordName() {
        return this.prepData?.name ?? '';
    }

    get meetingDateLabel() {
        return this.prepData?.meetingDateLabel ?? '';
    }

    get hasMeetingDate() {
        return !!this.prepData?.meetingDateLabel;
    }

    get recordStatus() {
        return this.prepData?.status ?? '';
    }

    get hasStatus() {
        return !!this.prepData?.status;
    }

    get recordAttendees() {
        return this.prepData?.attendees ?? '';
    }

    get hasAttendees() {
        return !!this.prepData?.attendees;
    }

    get recordNotes() {
        return this.prepData?.notes ?? '';
    }

    get hasNotes() {
        return !!this.prepData?.notes;
    }

    get actionItems() {
        const rows = this.prepData?.actionItems ?? [];
        return rows.map(r => ({
            ...r,
            statusChipFull: 'status-chip ' + (r.statusChip || 'chip-neutral')
        }));
    }

    get hasActionItems() {
        return (this.prepData?.actionItems ?? []).length > 0;
    }

    get actionItemCount() {
        return (this.prepData?.actionItems ?? []).length;
    }

    get hasError() {
        return !!this.error;
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleOpenRecord(evt) {
        const recordId = evt.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }

    handleNewActionItem() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Action_Item__c', actionName: 'new' }
        });
    }
}
