import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getPageData from '@salesforce/apex/ODLCampaignListController.getPageData';

export default class OdlCampaignConsoleWorkspace extends NavigationMixin(LightningElement) {
    searchTerm = '';
    pageData;
    error;
    wiredPageDataResult;

    @wire(getPageData)
    wiredPageData(result) {
        this.wiredPageDataResult = result;
        const { data, error } = result;
        if (data) {
            this.pageData = data;
            this.error = undefined;
        } else if (error) {
            this.error = (error.body && error.body.message) || 'Unable to load campaign data.';
            this.pageData = undefined;
        }
    }

    get rows() {
        return (this.pageData?.rows || []).map((row) => ({
            ...row,
            revenueDisplay: row.revenue == null ? '$0' : `$${Math.round(row.revenue)}`
        }));
    }

    get filteredRows() {
        const term = this.searchTerm.trim().toLowerCase();
        if (!term) return this.rows;
        return this.rows.filter((row) =>
            [row.name, row.type, row.status, row.builderAccount].some((value) =>
                String(value || '').toLowerCase().includes(term)
            )
        );
    }

    get hasError() { return !!this.error; }
    get hasNoRows() { return !this.error && this.filteredRows.length === 0; }
    get hasRows() { return !this.error && this.filteredRows.length > 0; }
    get campaignCount() { return this.rows.length; }
    get memberCount() {
        return this.rows.reduce((sum, row) => sum + (Number(row.memberCount) || 0), 0);
    }
    get leadCount() {
        return this.rows.reduce((sum, row) => sum + (Number(row.leadCount) || 0), 0);
    }
    get opportunityCount() {
        return this.rows.reduce((sum, row) => sum + (Number(row.opportunityCount) || 0), 0);
    }
    get revenueTotalDisplay() {
        const total = this.rows.reduce((sum, row) => sum + (Number(row.revenue) || 0), 0);
        return `$${Math.round(total)}`;
    }
    get activeCount() { return this.pageData?.activeCount || 0; }
    get submittedCount() { return this.pageData?.submittedCount || 0; }
    get validatedCount() { return this.pageData?.validatedCount || 0; }
    get reservedCount() { return this.pageData?.reservedCount || 0; }
    get appliedCount() { return this.pageData?.appliedCount || 0; }
    get builderInvoicePendingCount() { return this.pageData?.builderInvoicePendingCount || 0; }
    get builderInvoicedCount() { return this.pageData?.builderInvoicedCount || 0; }
    get paidByBuilderCount() { return this.pageData?.paidByBuilderCount || 0; }
    get rejectedOrExpiredCount() { return this.pageData?.rejectedOrExpiredCount || 0; }
    get hasSearchTerm() { return !!this.searchTerm.trim(); }

    handleSearch(event) { this.searchTerm = event.target.value; }
    handleRefresh() {
        if (this.wiredPageDataResult) {
            return refreshApex(this.wiredPageDataResult);
        }
        return Promise.resolve();
    }
    handleNewCampaign() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Campaign', actionName: 'new' } });
    }
    handleOpenVouchers() {
        this[NavigationMixin.Navigate]({ type: 'standard__navItemPage', attributes: { apiName: 'Outdoor_Living_Vouchers' } });
    }
    handleOpenLeads() {
        this[NavigationMixin.Navigate]({ type: 'standard__navItemPage', attributes: { apiName: 'Outdoor_Living_Leads' } });
    }
    handleOpenReports() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Report', actionName: 'home' } });
    }
}