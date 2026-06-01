import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getCommunities from '@salesforce/apex/CommunitiesViewController.getCommunities';

export default class LovingCommunitiesView extends NavigationMixin(LightningElement) {
    @track allCommunities = [];
    @track searchTerm     = '';
    @track error          = null;
    @track isLoading      = true;

    _wiredResult;

    @wire(getCommunities)
    wiredData(result) {
        this._wiredResult = result;
        if (result.data) {
            this.allCommunities = result.data;
            this.error          = null;
            this.isLoading      = false;
        } else if (result.error) {
            this.error     = result.error?.body?.message || 'Unable to load communities.';
            this.isLoading = false;
        }
    }

    // ── Computed getters ──────────────────────────────────────────────────────

    get filteredCommunities() {
        if (!this.searchTerm) return this.allCommunities;
        const q = this.searchTerm.toLowerCase();
        return this.allCommunities.filter(c =>
            (c.name || '').toLowerCase().includes(q) ||
            (c.builderAccountName || '').toLowerCase().includes(q)
        );
    }

    get hasCommunities() {
        return this.filteredCommunities.length > 0;
    }

    get totalCount() {
        return this.allCommunities.length;
    }

    get filteredCount() {
        return this.filteredCommunities.length;
    }

    get hasError() {
        return !!this.error;
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    handleSearch(evt) {
        this.searchTerm = evt.target.value;
    }

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
}
