import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getWorkspaceData from '@salesforce/apex/ODLLeadListController.getWorkspaceData';

const FILTERS = [
    { value: 'all', label: 'All' },
    { value: 'New', label: 'New' },
    { value: 'Contacted', label: 'Contacted' },
    { value: 'Working', label: 'Working' },
    { value: 'Nurturing', label: 'Nurturing' },
    { value: 'overdue', label: 'Overdue Follow-Up' }
];

export default class OdlLeadWorkspace extends NavigationMixin(LightningElement) {
    selectedFilter = 'all';
    searchTerm = '';
    data;
    error;
    wiredResult;

    @wire(getWorkspaceData)
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

    get isLoading() {
        return !this.data && !this.error;
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
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const rows = (this.data?.rows || []).map((row) => ({
            ...row,
            isOverdue:
                row.followUpDue &&
                row.followUpDue !== 'No follow-up due' &&
                new Date(row.followUpDue) < today,
            searchableText: [row.name, row.status, row.leadSource, row.odPath, row.ownerName]
                .filter(Boolean)
                .join(' ')
                .toLowerCase()
        }));

        return rows.filter((row) => {
            if (!this.matchesFilter(row)) return false;
            if (!this.searchTerm) return true;
            return row.searchableText.includes(this.searchTerm.toLowerCase());
        });
    }

    get hasRows() {
        return this.visibleRows.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && !this.hasRows;
    }

    matchesFilter(row) {
        switch (this.selectedFilter) {
            case 'New':
                return row.status === 'New';
            case 'Contacted':
                return row.status === 'Contacted';
            case 'Working':
                return row.status === 'Working';
            case 'Nurturing':
                return row.status === 'Nurturing';
            case 'overdue':
                return row.isOverdue;
            default:
                return true;
        }
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

    handleConvertLead(event) {
        const recordId = event.currentTarget.dataset.id || event.currentTarget.dataset.recordId;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }

    handleDisqualify(event) {
        const recordId = event?.currentTarget?.dataset?.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'edit' }
            });
        }
    }

    handleLogActivity(event) {
        const recordId = event.currentTarget.dataset.id || event.currentTarget.dataset.recordId;
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: recordId || '' }
        });
    }

    handleSendEmail(event) {
        const recordId = event?.currentTarget?.dataset?.id || '';
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.SendEmail' },
            state: { recordId }
        });
    }
}
