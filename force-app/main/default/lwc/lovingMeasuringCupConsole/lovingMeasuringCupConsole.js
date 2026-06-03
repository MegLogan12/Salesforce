import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getHomeData from '@salesforce/apex/MeasuringCupConsoleController.getHomeData';

export default class LovingMeasuringCupConsole extends NavigationMixin(LightningElement) {
    @api pageTitle = 'Measuring Cup';
    @track pageData  = null;
    @track error     = null;
    @track isLoading = true;

    _wiredResult;

    @wire(getHomeData)
    wiredData(result) {
        this._wiredResult = result;
        if (result.data) {
            this.pageData  = result.data;
            this.error     = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error     = result.error?.body?.message || 'Unable to load data.';
            this.isLoading = false;
        }
    }

    // ── Computed getters ──────────────────────────────────────────────────────

    get pendingMeasurements() {
        return this.pageData?.pendingMeasurements ?? '—';
    }

    get completedToday() {
        return this.pageData?.completedToday ?? '—';
    }

    get crewCount() {
        return this.pageData?.crewCount ?? '—';
    }

    get workOrders() {
        const rows = this.pageData?.workOrders ?? [];
        return rows.map(r => ({
            ...r,
            statusChipFull: 'status-chip ' + (r.statusChip || 'chip-neutral')
        }));
    }

    get hasWorkOrders() {
        return (this.pageData?.workOrders ?? []).length > 0;
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

    handleOpenWorkOrders() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WorkOrder', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleNewWorkOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WorkOrder', actionName: 'new' }
        });
    }

    handleOpenCrews() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Crew__c', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }
}
