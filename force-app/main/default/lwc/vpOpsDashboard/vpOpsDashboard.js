import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getHomeData from '@salesforce/apex/VPOpsDashboardController.getHomeData';

import { applyFullWidthLayout } from 'c/lovingLayoutUtils';
export default class VpOpsDashboard extends NavigationMixin(LightningElement) {
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

    get pendingOneOnOnes() {
        return this.pageData?.pendingOneOnOnes ?? '—';
    }

    get openActionItems() {
        return this.pageData?.openActionItems ?? '—';
    }

    get openWorkOrders() {
        return this.pageData?.openWorkOrders ?? '—';
    }

    get crewCount() {
        return this.pageData?.crewCount ?? '—';
    }

    get recentHireRequests() {
        return this.pageData?.recentHireRequests ?? [];
    }

    get hasHireRequests() {
        return (this.pageData?.recentHireRequests ?? []).length > 0;
    }

    get recentActionItems() {
        const rows = this.pageData?.recentActionItems ?? [];
        return rows.map(r => ({
            ...r,
            statusChipFull: 'status-chip ' + (r.statusChip || 'chip-neutral')
        }));
    }

    get hasActionItems() {
        return (this.pageData?.recentActionItems ?? []).length > 0;
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

    handleOpenOneOnOnes() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'OneOnOne__c', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleOpenActionItems() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Action_Item__c', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleOpenWorkOrders() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WorkOrder', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleOpenCrews() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Crew__c', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleOpenReports() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Report', actionName: 'list' }
        });
    }
    renderedCallback() {
        applyFullWidthLayout(this.template.host);
    }

}
