import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLWarrantyConsoleController.getPageData';

export default class OdlWarrantyWorkspace extends NavigationMixin(LightningElement) {
    searchTerm = '';
    pageData;
    loadError;
    isLoaded = false;

    @wire(getPageData)
    wiredData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.loadError = undefined;
            this.isLoaded = true;
        } else if (error) {
            this.pageData = undefined;
            this.loadError = (error && error.body && error.body.message)
                ? error.body.message
                : 'Unable to load warranty records.';
            this.isLoaded = true;
        }
    }

    get rows() { return this.pageData?.rows || []; }
    get filteredRows() {
        const term = this.searchTerm.trim().toLowerCase();
        if (!term) return this.rows;
        return this.rows.filter((row) =>
            [row.name, row.status, row.homeownerName, row.workOrderNumber, row.caseNumber, row.caseStatus]
                .some((value) => String(value || '').toLowerCase().includes(term))
        );
    }
    get hasNoRows() { return this.filteredRows.length === 0; }
    get hasRows() { return !this.loadError && !this.hasNoRows; }
    get hasError() { return !!this.loadError; }
    get showEmptyState() { return this.isLoaded && !this.loadError && this.hasNoRows; }
    get totalCount() { return this.pageData?.totalCount || 0; }
    get openCount() { return this.pageData?.openCount || 0; }
    get noCaseCount() { return this.pageData?.noCaseCount || 0; }
    get noWorkOrderCount() { return this.pageData?.noWorkOrderCount || 0; }
    handleSearch(event) { this.searchTerm = event.target.value; }
    handleRefresh() { window.location.reload(); }
    handleOpenCases() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Case', actionName: 'home' } });
    }
    handleNewWarranty() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Warranty_Record__c', actionName: 'new' } });
    }
}