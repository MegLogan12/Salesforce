import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getClosePageData from '@salesforce/apex/ODLOpportunityCloseController.getClosePageData';
import markClosedWon from '@salesforce/apex/ODLOpportunityCloseController.markClosedWon';

export default class OdlOpportunityClose extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isConfirming = false;
    @track isUpdating = false;

    _wiredResult;

    @wire(getClosePageData, { opportunityId: '$recordId' })
    wiredData(result) {
        this._wiredResult = result;
    }

    get pageData() { return this._wiredResult?.data ?? null; }
    get hasError() { return Boolean(this._wiredResult?.error); }
    get isLoading() { return !this._wiredResult?.data && !this._wiredResult?.error; }

    get opportunityName() { return this.pageData?.opportunityRecord?.Name ?? ''; }
    get stageName() { return this.pageData?.opportunityRecord?.StageName ?? ''; }
    get accountName() { return this.pageData?.opportunityRecord?.Account?.Name ?? ''; }
    get readiness() { return this.pageData?.readiness ?? null; }
    get paymentSchedule() { return this.pageData?.paymentSchedule ?? null; }
    get isUmb() { return this.pageData?.isUmb ?? false; }
    get woReady() { return this.readiness?.woReady ?? false; }
    get isNotWoReady() { return !this.woReady; }
    get isNotConfirming() { return !this.isConfirming; }

    get isAlreadyClosed() {
        const s = this.stageName;
        return s === 'Closed Won' || s === 'Closed Lost';
    }

    get showCloseAction() {
        return this.pageData != null && !this.isAlreadyClosed;
    }

    get closeButtonDisabled() {
        return !this.woReady || this.isUpdating;
    }

    get closeButtonClass() {
        return this.woReady
            ? 'btn-close-won btn-close-won-active'
            : 'btn-close-won';
    }

    get confirmButtonLabel() {
        return this.isUpdating ? 'Closing…' : 'Yes, Mark as Closed Won';
    }

    handleConfirmClose() {
        if (!this.woReady) return;
        this.isConfirming = true;
    }

    handleCancelClose() {
        this.isConfirming = false;
    }

    async handleMarkClosedWon() {
        this.isUpdating = true;
        try {
            await markClosedWon({ opportunityId: this.recordId });
            this.isConfirming = false;
            await refreshApex(this._wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Closed Won',
                message: 'Opportunity marked as Closed Won.',
                variant: 'success'
            }));
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: this.recordId, actionName: 'view' }
            });
        } catch (err) {
            const msg = err?.body?.message ?? 'Failed to close opportunity.';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: msg,
                variant: 'error'
            }));
        } finally {
            this.isUpdating = false;
        }
    }
}
