import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getPrepView from '@salesforce/apex/OneOnOnePrepController.getPrepView';

export default class OneOnOnePrep extends NavigationMixin(LightningElement) {
    @api recordId;

    @track prepData  = null;
    @track error     = null;
    @track isLoading = true;

    _wiredResult;

    @wire(getPrepView, { oneOnOneId: '$recordId' })
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
        const m = this.prepData?.managerName;
        const d = this.prepData?.directReportName;
        if (m && d) return `${m} & ${d}`;
        return m || d || '';
    }

    get meetingDateLabel() {
        return null;
    }

    get hasMeetingDate() {
        return false;
    }

    get recordStatus() {
        return '';
    }

    get hasStatus() {
        return false;
    }

    get recordAttendees() {
        const m = this.prepData?.managerName ?? '';
        const d = this.prepData?.directReportName ?? '';
        return [m, d].filter(Boolean).join(', ');
    }

    get hasAttendees() {
        return !!(this.prepData?.managerName || this.prepData?.directReportName);
    }

    get recordNotes() {
        return this.prepData?.existingNotes ?? '';
    }

    get hasNotes() {
        return !!this.prepData?.existingNotes;
    }

    get actionItems() {
        const rows = this.prepData?.openActionItems ?? [];
        return rows.map(r => ({
            id: r.Id,
            name: r.Name,
            status: r.Status__c ?? '',
            dueDateLabel: r.Due_Date__c ?? '',
            isOverdue: false,
            statusChipFull: 'status-chip chip-neutral'
        }));
    }

    get hasActionItems() {
        return (this.prepData?.openActionItems ?? []).length > 0;
    }

    get actionItemCount() {
        return (this.prepData?.openActionItems ?? []).length;
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
