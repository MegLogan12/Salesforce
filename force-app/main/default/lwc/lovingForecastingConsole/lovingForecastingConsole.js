import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getHomeData from '@salesforce/apex/ForecastingConsoleController.getHomeData';

export default class LovingForecastingConsole extends NavigationMixin(LightningElement) {
    @api pageTitle = 'Forecasting & Hiring';
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

    get openHireRequests() {
        return this.pageData?.openHireRequests ?? '—';
    }

    get activeCrew() {
        return this.pageData?.activeCrew ?? '—';
    }

    get recentHireRequests() {
        return this.pageData?.recentHireRequests ?? [];
    }

    get hasHireRequests() {
        return (this.pageData?.recentHireRequests ?? []).length > 0;
    }

    get recentCrews() {
        return this.pageData?.recentCrews ?? [];
    }

    get hasCrews() {
        return (this.pageData?.recentCrews ?? []).length > 0;
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

    handleOpenHireRequests() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Hire_Request__c', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleNewHireRequest() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Hire_Request__c', actionName: 'new' }
        });
    }

    handleOpenCrews() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Crew__c', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleNewCrew() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Crew__c', actionName: 'new' }
        });
    }
}
