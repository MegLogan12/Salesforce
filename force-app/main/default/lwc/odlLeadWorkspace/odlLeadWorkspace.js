import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { refreshApex } from '@salesforce/apex';
import getWorkspaceData from '@salesforce/apex/ODLLeadListController.getWorkspaceData';

const FILTERS = [
    { value: 'all', label: 'All Homeowner Leads' },
    { value: 'umb', label: 'UpgradeMyBackyard' },
    { value: 'design', label: 'Design Build' },
    { value: 'lawn', label: 'Lawn Care' },
    { value: 'voicemail', label: 'Voicemail Left' },
    { value: 'followup', label: 'Follow-Up Due' }
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

    get title() {
        return this.data?.title || 'Homeowner Lead List';
    }

    get subtitle() {
        return this.data?.subtitle || '';
    }

    get isLoading() {
        return !this.data && !this.error;
    }

    get errorMessage() {
        if (!this.error) return '';
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
            searchableText: [
                row.name,
                row.odPath,
                row.leadSource,
                row.status,
                row.interest,
                row.lastAction,
                row.followUpTask,
                row.ownerName
            ]
                .filter(Boolean)
                .join(' ')
                .toLowerCase(),
            pathClass: row.odPath === 'Design Build'
                ? 'path-chip design-chip'
                : row.odPath === 'Lawn Care'
                    ? 'path-chip lawn-chip'
                    : 'path-chip homeowner-chip'
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
        return !this.isLoading && !this.errorMessage && this.visibleRows.length === 0;
    }

    matchesFilter(row) {
        switch (this.selectedFilter) {
            case 'umb':
                return row.odPath === 'UpgradeMyBackyard';
            case 'design':
                return row.odPath === 'Design Build';
            case 'lawn':
                return row.odPath === 'Lawn Care';
            case 'voicemail':
                return row.lastActionCategory === 'voicemail';
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
                objectApiName: 'Lead',
                actionName: 'view'
            }
        });
    }

    handleNewLead() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Lead',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: encodeDefaultFieldValues({
                    Status: 'New',
                    Lead_Type__c: 'Homeowner',
                    Company: 'Homeowner'
                })
            }
        });
    }

    async handleRefresh() {
        await refreshApex(this.wiredResult);
    }
}