import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getAllCommunities from '@salesforce/apex/CommunityRecordController.getAllCommunities';
import updateCommunityStatus from '@salesforce/apex/CommunityRecordController.updateCommunityStatus';

const STATUS_OPTIONS = [
    { value: 'Active',    label: 'Active' },
    { value: 'Built Out', label: 'Built Out' },
    { value: 'On Hold',   label: 'On Hold' },
    { value: 'Closed',    label: 'Closed' }
];

function statusChipCls(status) {
    const base = 'status-chip';
    if (!status) return base + ' chip-gray';
    switch (status) {
        case 'Active':    return base + ' chip-green';
        case 'Built Out': return base + ' chip-purple';
        case 'On Hold':   return base + ' chip-amber';
        case 'Closed':    return base + ' chip-gray';
        default:          return base + ' chip-gray';
    }
}

export default class LovingCommunitiesView extends NavigationMixin(LightningElement) {
    @track _searchTerm = '';
    @track _statusFilter = 'All';
    @track _editingId = null;
    @track _savingId = null;
    @track toast = { show: false, cls: '', icon: '', message: '' };

    _wiredResult;
    _rows = [];
    _error = null;
    _loading = true;

    // Wire: cacheable=true, re-fires when searchTerm or statusFilter change
    // For simplicity we load all and filter client-side (500 record cap is fine)
    @wire(getAllCommunities, { searchTerm: '', statusFilter: 'All' })
    wiredCommunities(result) {
        this._wiredResult = result;
        this._loading = false;
        if (result.data) {
            this._rows = result.data;
            this._error = null;
        } else if (result.error) {
            this._rows = [];
            this._error = result.error.body ? result.error.body.message : String(result.error);
        }
    }

    // ── Computed states ──────────────────────────────────────────────

    get isLoading()    { return this._loading; }
    get hasError()     { return !this._loading && !!this._error; }
    get errorMessage() { return this._error; }

    get viewRows() {
        const search = this._searchTerm.toLowerCase();
        const statusF = this._statusFilter;
        return (this._rows || [])
            .filter(r => {
                const matchSearch = !search || (r.name || '').toLowerCase().includes(search)
                    || (r.builderAccountName || '').toLowerCase().includes(search)
                    || (r.territory || '').toLowerCase().includes(search);
                const matchStatus = statusF === 'All' || r.communityStatus === statusF;
                return matchSearch && matchStatus;
            })
            .map(r => ({
                ...r,
                rowCls: 'cv-row',
                builderAccountUrl: r.builderAccountId ? '/' + r.builderAccountId : null,
                parentBuilderAccountUrl: r.parentBuilderAccountId ? '/' + r.parentBuilderAccountId : null,
                numberOfLots: r.numberOfLots != null ? r.numberOfLots : '—',
                activeLotCount: r.activeLotCount != null ? r.activeLotCount : '—',
                territory: r.territory || '—',
                assignedFmName: r.assignedFmName || '—',
                communityStatus: r.communityStatus || '—',
                statusChipCls: statusChipCls(r.communityStatus),
                isEditing: r.id === this._editingId,
                isSaving: r.id === this._savingId,
                statusOptions: STATUS_OPTIONS.map(o => ({
                    value: o.value,
                    label: o.label,
                    selected: o.value === r.communityStatus
                }))
            }));
    }

    get isEmpty() { return !this._loading && !this._error && (!this.viewRows || this.viewRows.length === 0); }
    get rowCount() { return this.viewRows ? this.viewRows.length : 0; }

    // ── Filter button classes ─────────────────────────────────────────
    _filterCls(val) {
        return 'cv-filter-btn' + (this._statusFilter === val ? ' active' : '');
    }
    get filterAllCls()      { return this._filterCls('All'); }
    get filterActiveCls()   { return this._filterCls('Active'); }
    get filterBuiltOutCls() { return this._filterCls('Built Out'); }
    get filterOnHoldCls()   { return this._filterCls('On Hold'); }
    get filterClosedCls()   { return this._filterCls('Closed'); }

    // ── Handlers ──────────────────────────────────────────────────────

    handleSearch(evt) {
        this._searchTerm = evt.target.value || '';
    }

    handleFilter(evt) {
        this._statusFilter = evt.currentTarget.dataset.filter;
        this._editingId = null;
    }

    handleNav(evt) {
        evt.preventDefault();
        const url = evt.currentTarget.dataset.url;
        if (url) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url }
            });
        }
    }

    handleNew() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Community__c',
                actionName: 'new'
            }
        });
    }

    handleStatusClick(evt) {
        this._editingId = evt.currentTarget.dataset.id;
        // Focus the select after render
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const sel = this.template.querySelector('select.status-select');
            if (sel) sel.focus();
        }, 0);
    }

    handleStatusBlur() {
        // Small delay so onchange fires first if value changed
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this._editingId = null;
        }, 200);
    }

    async handleStatusChange(evt) {
        const rowId = evt.currentTarget.dataset.id;
        const newStatus = evt.target.value;
        this._editingId = null;
        this._savingId = rowId;

        try {
            await updateCommunityStatus({ communityId: rowId, newStatus });
            // Optimistically update the local row so UI reflects change instantly
            this._rows = this._rows.map(r =>
                r.id === rowId ? { ...r, communityStatus: newStatus } : r
            );
            // Also refresh the wire cache
            await refreshApex(this._wiredResult);
            this._showToast('success', '✓', 'Status updated');
        } catch (err) {
            const msg = (err.body && err.body.message) ? err.body.message : String(err);
            this._showToast('error', '✗', 'Save failed: ' + msg);
        } finally {
            this._savingId = null;
        }
    }

    // ── Toast ─────────────────────────────────────────────────────────

    _showToast(type, icon, message) {
        const clsMap = {
            success: 'cv-toast cv-toast-success',
            error:   'cv-toast cv-toast-error'
        };
        this.toast = { show: true, cls: clsMap[type] || 'cv-toast', icon, message };
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.toast = { ...this.toast, show: false }; }, 3000);
    }
}