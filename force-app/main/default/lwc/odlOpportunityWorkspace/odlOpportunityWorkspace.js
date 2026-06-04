import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getWorkspaceData from '@salesforce/apex/ODLHomeownerOppListController.getWorkspaceData';

const FILTERS = [
    { value: 'all', label: 'All Homeowners' },
    { value: 'umb', label: 'UpgradeMyBackyard' },
    { value: 'design', label: 'Design Build' },
    { value: 'voicemail', label: 'Left Voicemail' },
    { value: 'email', label: 'Sent Email' },
    { value: 'call', label: 'Call Complete' },
    { value: 'followup', label: 'Follow-Up Due' }
];

export default class OdlOpportunityWorkspace extends NavigationMixin(LightningElement) {
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

    get title() {
        return this.data?.title || 'Homeowner Opportunity List';
    }

    get subtitle() {
        return this.data?.subtitle || '';
    }

    get isLoading() {
        return !this.data && !this.error;
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((row) => row.message).join(', ');
        }
        return this.error.body?.message || this.error.message;
    }

    get filters() {
        return FILTERS.map((filter) => ({
            ...filter,
            className: filter.value === this.selectedFilter ? 'filter-chip active' : 'filter-chip'
        }));
    }

    get visibleRows() {
        const rows = (this.data?.rows || []).map((row) => ({
            ...row,
            hasAmount: row.amount !== null && row.amount !== undefined,
            searchableText: [
                row.name,
                row.accountName,
                row.projectPath,
                row.stage,
                row.packageOrService,
                row.lastAction,
                row.ownerName,
                row.openItem
            ]
                .filter(Boolean)
                .join(' ')
                .toLowerCase(),
            pathClass:
                row.projectPath === 'Design Build' ? 'path-chip design-chip' : 'path-chip homeowner-chip'
        }));

        return rows.filter((row) => {
            if (!this.matchesFilter(row)) {
                return false;
            }
            if (!this.searchTerm) {
                return true;
            }
            return row.searchableText.includes(this.searchTerm.toLowerCase());
        });
    }

    get hasRows() {
        return this.visibleRows.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && this.visibleRows.length === 0;
    }

    matchesFilter(row) {
        switch (this.selectedFilter) {
            case 'umb':
                return row.projectPath === 'UpgradeMyBackyard';
            case 'design':
                return row.projectPath === 'Design Build';
            case 'voicemail':
                return row.lastActionCategory === 'voicemail';
            case 'email':
                return row.lastActionCategory === 'email';
            case 'call':
                return row.lastActionCategory === 'call';
            case 'followup':
                return row.followUpDue && row.followUpDue !== 'No follow-up due';
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
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    async handleRefresh() {
        await refreshApex(this.wiredResult);
    }

    handleLogCall(event) {
        const recordId = event.currentTarget.dataset.id || event.currentTarget.dataset.recordId;
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: recordId || '' }
        });
    }

    handleNewActivity(event) {
        const recordId = event.currentTarget.dataset.id || event.currentTarget.dataset.recordId;
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: recordId || '' }
        });
    }

    handleSendEmail() {
        console.log('handleSendEmail');
    }
}