import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getVouchers from '@salesforce/apex/ODLVoucherWorkspaceController.getVouchers';

const FILTERS = [
    { value: 'all', label: 'All' },
    { value: 'Available', label: 'Available' },
    { value: 'Reserved', label: 'Reserved' },
    { value: 'Redeemed', label: 'Redeemed' },
    { value: 'Expired', label: 'Expired' }
];

export default class OdlVoucherWorkspace extends NavigationMixin(LightningElement) {
    selectedFilter = 'all';
    searchTerm = '';
    rows;
    error;
    wiredResult;

    @wire(getVouchers)
    wiredVouchers(result) {
        this.wiredResult = result;
        if (result.data) {
            this.rows = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.rows = undefined;
        }
    }

    get isLoading() {
        return !this.rows && !this.error;
    }

    get errorMessage() {
        if (!this.error) return '';
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((e) => e.message).join(', ');
        }
        return this.error.body?.message || this.error.message;
    }

    get filters() {
        return FILTERS.map((f) => ({
            ...f,
            className: f.value === this.selectedFilter ? 'filter-chip active' : 'filter-chip'
        }));
    }

    get visibleRows() {
        return (this.rows || []).filter((row) => {
            if (this.selectedFilter !== 'all' && row.status !== this.selectedFilter) return false;
            if (!this.searchTerm) return true;
            const term = this.searchTerm.toLowerCase();
            return (
                (row.name || '').toLowerCase().includes(term) ||
                (row.voucherCode || '').toLowerCase().includes(term) ||
                (row.voucherType || '').toLowerCase().includes(term) ||
                (row.opportunityName || '').toLowerCase().includes(term) ||
                (row.accountName || '').toLowerCase().includes(term) ||
                (row.status || '').toLowerCase().includes(term)
            );
        });
    }

    get hasRows() {
        return this.visibleRows.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && !this.hasRows;
    }

    handleFilterClick(event) {
        this.selectedFilter = event.currentTarget.dataset.value;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value || '';
    }

    handleOpenRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    async handleRefresh() {
        await refreshApex(this.wiredResult);
    }

    handleApplyVoucher(event) {
        const recordId = event?.currentTarget?.dataset?.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }

    handleVoid(event) {
        const recordId = event?.currentTarget?.dataset?.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'edit' }
            });
        }
    }
}
