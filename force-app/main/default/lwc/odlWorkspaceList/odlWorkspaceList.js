import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getWorkspaceData from '@salesforce/apex/ODLWorkspaceListController.getWorkspaceData';

export default class OdlWorkspaceList extends NavigationMixin(LightningElement) {
    @api workspaceType;

    selectedPrimaryFilter = 'all';
    selectedSecondaryFilter = 'all';
    selectedTertiaryFilter = 'all';
    searchTerm = '';
    data;
    error;
    wiredResult;

    @wire(getWorkspaceData, { workspaceType: '$workspaceType' })
    wiredWorkspace(result) {
        this.wiredResult = result;
        if (result.data) {
            this.data = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.data = undefined;
        }
    }

    get title() { return this.data?.title || 'ODL Workspace'; }
    get subtitle() { return this.data?.subtitle || ''; }
    get emptyMessage() { return this.data?.emptyMessage || 'No records match the current filters.'; }
    get searchPlaceholder() { return this.data?.searchPlaceholder || 'Search'; }
    get nameLabel() { return this.data?.nameLabel || 'Record'; }
    get pathLabel() { return this.data?.pathLabel || 'Type'; }
    get statusLabel() { return this.data?.statusLabel || 'Status'; }
    get contextOneLabel() { return this.data?.contextOneLabel || 'Context'; }
    get contextTwoLabel() { return this.data?.contextTwoLabel || 'Context'; }
    get contextThreeLabel() { return this.data?.contextThreeLabel || 'Context'; }
    get amountLabel() { return this.data?.amountLabel || 'Amount'; }
    get dateLabel() { return this.data?.dateLabel || 'Date'; }
    get ownerLabel() { return this.data?.ownerLabel || 'Owner'; }
    get openItemLabel() { return this.data?.openItemLabel || 'Open Item'; }
    get primaryFilterLabel() { return this.data?.primaryFilterLabel || 'Filter'; }
    get secondaryFilterLabel() { return this.data?.secondaryFilterLabel || 'Filter'; }
    get tertiaryFilterLabel() { return this.data?.tertiaryFilterLabel || 'Filter'; }
    get primaryFilterOptions() { return this.data?.primaryFilterOptions || []; }
    get secondaryFilterOptions() { return this.data?.secondaryFilterOptions || []; }
    get tertiaryFilterOptions() { return this.data?.tertiaryFilterOptions || []; }
    get nextActions() { return this.data?.nextActions || []; }

    get metricTiles() {
        return (this.data?.metricTiles || []).map((tile) => ({
            ...tile,
            className: `metric-card ${tile.tone || 'neutral'}`
        }));
    }

    get actions() {
        return (this.data?.actions || []).map((action) => ({
            ...action,
            className: action.disabled ? 'secondary-btn disabled-btn' : 'primary-btn'
        }));
    }

    get isLoading() {
        return !this.data && !this.error;
    }

    get errorMessage() {
        if (!this.error) return '';
        if (Array.isArray(this.error.body)) return this.error.body.map((row) => row.message).join(', ');
        return this.error.body?.message || this.error.message;
    }

    get visibleRows() {
        return (this.data?.rows || [])
            .filter((row) => (this.selectedPrimaryFilter === 'all' ? true : row.filterOneValue === this.selectedPrimaryFilter))
            .filter((row) => (this.selectedSecondaryFilter === 'all' ? true : row.filterTwoValue === this.selectedSecondaryFilter))
            .filter((row) => (this.selectedTertiaryFilter === 'all' ? true : row.filterThreeValue === this.selectedTertiaryFilter))
            .filter((row) => (!this.searchTerm ? true : (row.searchText || '').includes(this.searchTerm.toLowerCase())))
            .map((row) => ({
                ...row,
                hasAmount: row.amount !== null && row.amount !== undefined && row.amount !== 0,
                pathClass: row.pathLabel === 'Design Build' ? 'path-chip design-chip' : 'path-chip homeowner-chip'
            }));
    }

    get hasRows() {
        return this.visibleRows.length > 0;
    }

    get hasMetrics() {
        return this.metricTiles.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && this.visibleRows.length === 0;
    }

    handlePrimaryFilterChange(event) { this.selectedPrimaryFilter = event.detail.value; }
    handleSecondaryFilterChange(event) { this.selectedSecondaryFilter = event.detail.value; }
    handleTertiaryFilterChange(event) { this.selectedTertiaryFilter = event.detail.value; }
    handleSearchChange(event) { this.searchTerm = (event.target.value || '').toLowerCase(); }

    handleOpenRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    handleAction(event) {
        const actionType = event.currentTarget.dataset.action;
        const objectApiName = event.currentTarget.dataset.objectApiName;
        if (actionType === 'newRecord' && objectApiName) {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName,
                    actionName: 'new'
                }
            });
        }
    }

    async handleRefresh() {
        await refreshApex(this.wiredResult);
    }
}