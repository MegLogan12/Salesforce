import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getWorkOrders    from '@salesforce/apex/LovingWorkOrderListController.getWorkOrders';
import getFilterOptions from '@salesforce/apex/LovingWorkOrderListController.getFilterOptions';
import getRevenueSummary from '@salesforce/apex/LovingWorkOrderRevenueService.getRevenueSummary';

const TYPE_FILTERS = [
    { label: 'All Types',          value: 'All Types' },
    { label: 'Production Install', value: 'Production Install' },
    { label: 'Finished Job',       value: 'Finished Job' },
    { label: 'Warranty',           value: 'Warranty' },
    { label: 'Customer Success',   value: 'Customer Success' },
    { label: 'Site Visit',         value: 'Site Visit' },
    { label: 'Lawn Care',          value: 'Lawn Care' },
    { label: 'Aqua Service',       value: 'Aqua Service' }
];

export default class LovingWorkOrderListView extends NavigationMixin(LightningElement) {

    @track _typeFilter   = 'All Types';
    @track _fmFilter     = 'All FMs';
    @track _statusFilter = 'All Statuses';
    @track _search       = '';
    @track _searchInput  = '';

    _listResult  = null;
    _listError   = null;
    _listLoading = true;

    _revResult  = null;
    _revError   = null;
    _revLoading = true;

    // ── Wire: work order list ─────────────────────────────────────────────────
    @wire(getWorkOrders, {
        typeFilter:   '$_typeFilter',
        fmFilter:     '$_fmFilter',
        statusFilter: '$_statusFilter',
        search:       '$_search'
    })
    wiredList({ data, error }) {
        if (data) {
            this._listResult  = data;
            this._listError   = null;
            this._listLoading = false;
        } else if (error) {
            this._listError   = error?.body?.message || 'Failed to load work orders';
            this._listLoading = false;
        }
    }

    // ── Wire: filter options ─────────────────────────────────────────────────
    _filterOpts = null;
    @wire(getFilterOptions)
    wiredOpts({ data }) {
        if (data) this._filterOpts = data;
    }

    // ── Wire: revenue KPI strip ──────────────────────────────────────────────
    get _revenueIds()    { return this._listResult?.workOrderIds || []; }
    get _revenueLabel()  { return this._listResult?.filterLabel  || 'All Active Work Orders'; }

    @wire(getRevenueSummary, {
        workOrderIds: '$_revenueIds',
        filterLabel:  '$_revenueLabel'
    })
    wiredRevenue({ data, error }) {
        if (data) {
            this._revResult  = data;
            this._revError   = null;
            this._revLoading = false;
        } else if (error) {
            this._revError   = error?.body?.message || 'Failed to load revenue data';
            this._revLoading = false;
        }
    }

    // ── Type filter chips ────────────────────────────────────────────────────
    get typeFilterChips() {
        return TYPE_FILTERS.map(f => ({
            ...f,
            chipClass: f.value === this._typeFilter
                ? 'filter-chip on'
                : 'filter-chip'
        }));
    }

    // ── FM and status dropdown options ───────────────────────────────────────
    get fmOptions() {
        return this._filterOpts?.fmOptions || [{ label: 'All FMs', value: 'All FMs' }];
    }

    get statusOptions() {
        return this._filterOpts?.statusOptions || [{ label: 'All Statuses', value: 'All Statuses' }];
    }

    // ── Header data ──────────────────────────────────────────────────────────
    get resultCount()  { return this._listResult?.totalCount || 0; }
    get headerChip()   { return this.resultCount + ' results'; }
    get isLoading()    { return this._listLoading; }
    get hasListError() { return !!this._listError; }
    get listErrorMsg() { return this._listError; }
    get rows()         { return this._listResult?.rows || []; }
    get hasRows()      { return this.rows.length > 0; }

    // ── Revenue KPI cards ────────────────────────────────────────────────────
    get revLoading()   { return this._revLoading; }
    get rev()          { return this._revResult || {}; }

    _fmt(val) {
        if (val == null) return '$0';
        const n = Number(val);
        if (n >= 1000000) return '$' + (n / 1000000).toFixed(1) + 'M';
        if (n >= 1000)    return '$' + Math.round(n).toLocaleString('en-US');
        return '$' + Math.round(n);
    }

    get kpiWoCount()       { return this.rev.woCount        != null ? String(this.rev.woCount) : '0'; }
    get kpiProjected()     { return this._fmt(this.rev.projectedRevenue); }
    get kpiInvoiced()      { return this._fmt(this.rev.invoiced); }
    get kpiPaid()          { return this._fmt(this.rev.paid); }
    get kpiUnbilled()      { return this._fmt(this.rev.unbilled); }
    get kpiOutstanding()   { return this._fmt(this.rev.outstanding); }
    get kpiOutstandingClass() {
        const v = Number(this.rev.outstanding);
        return v > 0 ? 'kpi kr' : 'kpi kg';
    }

    // ── Event handlers ───────────────────────────────────────────────────────
    handleTypeChip(event) {
        this._typeFilter   = event.currentTarget.dataset.value;
        this._listLoading  = true;
    }

    handleFmChange(event) {
        this._fmFilter    = event.target.value;
        this._listLoading = true;
    }

    handleStatusChange(event) {
        this._statusFilter = event.target.value;
        this._listLoading  = true;
    }

    handleSearchInput(event) {
        this._searchInput = event.target.value;
    }

    handleSearchKey(event) {
        if (event.key === 'Enter') {
            this._search       = this._searchInput;
            this._listLoading  = true;
        }
    }

    handleNewWO() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Work_Order__c', actionName: 'new' }
        });
    }

    handleRowClick(event) {
        const woId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: woId, actionName: 'view' }
        });
    }

    handleImport() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Import',
            message: 'Use the Salesforce Data Import Wizard or Data Loader to import Work Orders in bulk.',
            variant: 'info'
        }));
    }

    handleListSettings() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'List Settings',
            message: 'Customize list columns via your Salesforce List View settings.',
            variant: 'info'
        }));
    }
}