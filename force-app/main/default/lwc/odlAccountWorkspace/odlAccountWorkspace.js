import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getWorkspaceData from '@salesforce/apex/ODLAccountWorkspaceController.getWorkspaceData';

// ── Filter definitions (same order as HTML prototype) ──────────────────────
const FILTER_DEFS = [
    { key: 'all',       label: 'All Accounts'       },
    { key: 'customers', label: 'Active Customers'   },
    { key: 'prospects', label: 'Prospects'           },
    { key: 'leads',     label: 'Leads'               },
    { key: 'openopp',   label: 'Open Opportunity'   },
    { key: 'job',       label: 'Job in Progress'    },
    { key: 'warranty',  label: 'Open Warranty'      },
    { key: 'repeat',    label: 'Repeat Candidates'  },
    { key: 'builder',   label: 'Builder-Sourced'    },
    { key: 'noact',     label: 'No Activity 30d'    },
    { key: 'risk',      label: 'At Risk'            }
];

// ── Market values from org picklist ───────────────────────────────────────
const MARKETS = ['Triad', 'Columbia', 'Greenville', 'Charlotte-North', 'Charlotte-South', 'Asheville', 'Charlotte'];

// ── Owner avatar palette ───────────────────────────────────────────────────
const AVATAR_COLORS = [
    '#2d5f8a', '#6b4e9e', '#2e7d5b', '#b07d12',
    '#c0392b', '#5b6470', '#e2622b'
];

// ── Chip color maps ────────────────────────────────────────────────────────
const LIFECYCLE_CLASS = {
    'Lead':             'chip c-slate',
    'Prospect':         'chip c-blue',
    'Active Customer':  'chip c-green',
    'Repeat Customer':  'chip c-purple',
    'Past Customer':    'chip c-slate'
};
const HEALTH_CLASS = {
    'Healthy':  'chip c-green',
    'Watch':    'chip c-amber',
    'At Risk':  'chip c-red'
};
const OPP_STAGE_CLASS = {
    'Discovery':        'chip c-slate',
    'Consult Scheduled':'chip c-blue',
    'Design In Progress':'chip c-blue',
    'Quote Review':     'chip c-blue',
    'Contract Sent':    'chip c-amber',
    'Deposit Pending':  'chip c-amber',
    'Closed Won':       'chip c-green',
    'Closed Lost':      'chip c-red'
};
const JOB_STATUS_CLASS = {
    'In Progress':     'chip c-blue',
    'Approved':        'chip c-green',
    'Scheduled':       'chip c-amber',
    'Ready to Schedule':'chip c-amber'
};
const SOURCE_CLASS = {
    'Phone Inquiry':    'chip c-blue',
    'Web':              'chip c-blue',
    'Partner':          'chip c-amber',
    'Internal':         'chip c-amber',
    'Other':            'chip c-slate'
};
const ACTIVITY_CLASS = {
    'No Activity':                          'chip c-red',
    'Left Voicemail':                       'chip c-amber',
    'Email Sent':                           'chip c-blue',
    'Call Completed':                       'chip c-green',
    'Consult Scheduled':                    'chip c-blue',
    'Quote Sent':                           'chip c-orange',
    'Activity Logged':                      'chip c-slate',
    'Activity Logged - Result Not Categorized': 'chip c-slate'
};

// ── KPI accent colors ──────────────────────────────────────────────────────
const KPI_ACCENTS = {
    customers: 'var(--green)',
    openopp:   'var(--blue)',
    job:       'var(--orange)',
    warranty:  'var(--red)',
    repeat:    'var(--purple)',
    noact:     'var(--slate)'
};

export default class OdlAccountWorkspace extends NavigationMixin(LightningElement) {

    @track _allRows     = [];
    @track activeFilter = 'all';
    @track searchTerm   = '';
    @track activeMarket = '';
    @track activeOwner  = '';
    @track sortField    = null;
    @track sortDir      = 1;
    @track isLoading    = true;
    @track errorMessage = null;

    homeOwnerRecordTypeId = null;
    _wiredResult;
    _ownerColorMap = {};

    // ── Wire ────────────────────────────────────────────────────────────────

    @wire(getWorkspaceData)
    wiredData(result) {
        this._wiredResult = result;
        if (result.data) {
            this._allRows = result.data.rows || [];
            this.homeOwnerRecordTypeId = result.data.homeOwnerRecordTypeId;
            this._buildOwnerColorMap();
            this.isLoading   = false;
            this.errorMessage = null;
        } else if (result.error) {
            this.errorMessage = this._extractError(result.error);
            this.isLoading   = false;
        }
    }

    _buildOwnerColorMap() {
        let i = 0;
        this._allRows.forEach(r => {
            if (r.ownerId && !this._ownerColorMap[r.ownerId]) {
                this._ownerColorMap[r.ownerId] =
                    AVATAR_COLORS[i % AVATAR_COLORS.length];
                i++;
            }
        });
    }

    // ── Computed states ─────────────────────────────────────────────────────

    get isLoaded()  { return !this.isLoading && !this.errorMessage; }
    get hasError()  { return !!this.errorMessage; }

    // Permission placeholders — wire to profileInfo or permset if needed
    get canCreateAccount()       { return true; }
    get canCreateOpportunity()   { return true; }
    get canAccessReports()       { return true; }
    get cannotCreateAccount()    { return !this.canCreateAccount; }
    get cannotCreateOpportunity(){ return !this.canCreateOpportunity; }
    get cannotAccessReports()    { return !this.canAccessReports; }
    get accountDisabledReason()  { return 'You do not have permission to create Accounts.'; }
    get oppDisabledReason()      { return 'Opportunity create access is missing.'; }
    get reportsDisabledReason()  { return 'Report folder access is missing.'; }

    // ── Filtering helpers ───────────────────────────────────────────────────

    _passSearch(r) {
        if (this.activeMarket && r.market !== this.activeMarket) return false;
        if (this.activeOwner  && r.ownerId !== this.activeOwner)  return false;
        const q = (this.searchTerm || '').trim().toLowerCase();
        if (!q) return true;
        const haystack = [
            r.name, r.primaryContact, r.market,
            r.source, r.ownerName, r.openOppName
        ].join(' ').toLowerCase();
        return haystack.includes(q);
    }

    _passChip(r, filter) {
        switch (filter) {
            case 'all':       return true;
            case 'customers': return r.lifecycle === 'Active Customer' || r.lifecycle === 'Repeat Customer';
            case 'prospects': return r.lifecycle === 'Prospect';
            case 'leads':     return r.lifecycle === 'Lead';
            case 'openopp':   return !!r.openOppId;
            case 'job':       return !!r.activeJobId;
            case 'warranty':  return r.openWarrantyCount > 0;
            case 'repeat':    return (r.lifecycle === 'Repeat Customer' || r.lifecycle === 'Past Customer') && !r.openOppId;
            case 'builder':   return (r.source || '').includes('Partner') || (r.source || '').includes('Builder');
            case 'noact':     return this._daysSince(r.lastActivityDate) >= 30;
            case 'risk':      return r.health === 'At Risk';
            default:          return true;
        }
    }

    _daysSince(dateStr) {
        if (!dateStr) return 9999;
        const ms = Date.now() - new Date(dateStr).getTime();
        return Math.floor(ms / 86400000);
    }

    _defaultSort(a, b) {
        const rank = r => {
            if (r.openWarrantyCount > 0 || r.health === 'At Risk') return 0;
            if (r.openOppId)  return 1;
            if (r.activeJobId) return 2;
            return 3;
        };
        const ra = rank(a), rb = rank(b);
        if (ra !== rb) return ra - rb;
        return (b.lifetimeValue || 0) - (a.lifetimeValue || 0);
    }

    // Rows after search/market/owner but NOT chip — used for chip counts
    get _searchRows() {
        return this._allRows.filter(r => this._passSearch(r));
    }

    // Rows after all filters + sort
    get _filteredRows() {
        let rows = this._searchRows.filter(r =>
            this._passChip(r, this.activeFilter));
        if (this.sortField) {
            const dir = this.sortDir;
            const f   = this.sortField;
            rows = [...rows].sort((a, b) => {
                const av = f === 'ltv'
                    ? (a.lifetimeValue || 0)
                    : new Date(a.lastActivityDate || 0).getTime();
                const bv = f === 'ltv'
                    ? (b.lifetimeValue || 0)
                    : new Date(b.lastActivityDate || 0).getTime();
                return (av > bv ? 1 : av < bv ? -1 : 0) * dir;
            });
        } else {
            rows = [...rows].sort((a, b) => this._defaultSort(a, b));
        }
        return rows;
    }

    // ── Display rows (enriched with computed UI properties) ─────────────────

    get displayRows() {
        return this._filteredRows.map(r => {
            const ds = this._daysSince(r.lastActivityDate);
            const dateLabel = r.lastActivityDate
                ? new Date(r.lastActivityDate).toLocaleDateString('en-US',
                    { month: 'short', day: 'numeric' })
                : '—';
            const ownerInitials = (r.ownerName || '')
                .split(' ').map(p => p[0] || '').join('').slice(0, 2).toUpperCase();
            return {
                ...r,
                contactMarket: [r.primaryContact, r.market]
                    .filter(Boolean).join(' · '),
                ltvDisplay: r.lifetimeValue != null
                    ? '$' + Number(r.lifetimeValue).toLocaleString('en-US')
                    : '—',
                lifecycleClass:  LIFECYCLE_CLASS[r.lifecycle]     || 'chip c-slate',
                healthClass:     HEALTH_CLASS[r.health]           || 'chip c-slate',
                oppStageClass:   OPP_STAGE_CLASS[r.openOppStage]  || 'chip c-slate',
                jobStatusClass:  JOB_STATUS_CLASS[r.activeJobStatus] || 'chip c-slate',
                sourceClass:     SOURCE_CLASS[r.source]           || 'chip c-slate',
                activityClass:   ACTIVITY_CLASS[r.lastActivityResult] || 'chip c-slate',
                openOppAmountDisplay: r.openOppAmount != null
                    ? '$' + Number(r.openOppAmount).toLocaleString('en-US')
                    : '',
                activityDateLabel: ds >= 30
                    ? `${dateLabel} · ${ds}d ago`
                    : dateLabel,
                ownerInitials,
                ownerAvatarStyle:
                    `background:${this._ownerColorMap[r.ownerId] || '#5b6470'}`,
                hasOpenOpp:    !!r.openOppId,
                hasActiveJob:  !!r.activeJobId,
                hasOpenWarranty: r.openWarrantyCount > 0
            };
        });
    }

    get displayCount() { return this._filteredRows.length; }
    get totalCount()   { return this._allRows.length; }

    get isEmpty() {
        return this.isLoaded && this._filteredRows.length === 0;
    }
    get emptyTitle() {
        const f = FILTER_DEFS.find(x => x.key === this.activeFilter);
        return f && f.key !== 'all'
            ? `No ${f.label.toLowerCase()} match this filter.`
            : 'No homeowner accounts match the selected filters.';
    }
    get emptyMessage() {
        return this.searchTerm
            ? `Nothing matches "${this.searchTerm}". Clear the search or pick another filter.`
            : 'Adjust the filter or search to see the customer book.';
    }

    // ── KPI cards ────────────────────────────────────────────────────────────

    get _kpiCounts() {
        const rows = this._allRows;
        const openOpps = rows.filter(r => r.openOppId);
        return {
            customers:    rows.filter(r =>
                r.lifecycle === 'Active Customer' || r.lifecycle === 'Repeat Customer').length,
            openOppCount: openOpps.length,
            openOppAmt:   openOpps.reduce((s, r) => s + (r.openOppAmount || 0), 0),
            jobCount:     rows.filter(r => r.activeJobId).length,
            warrantyCount:rows.filter(r => r.openWarrantyCount > 0).length,
            repeatCount:  rows.filter(r =>
                (r.lifecycle === 'Repeat Customer' || r.lifecycle === 'Past Customer')
                && !r.openOppId).length,
            noactCount:   rows.filter(r =>
                this._daysSince(r.lastActivityDate) >= 30).length
        };
    }

    get kpiCards() {
        const c = this._kpiCounts;
        const f = this.activeFilter;
        const pipelineLabel = c.openOppAmt > 0
            ? '$' + Number(c.openOppAmt).toLocaleString('en-US') + ' pipeline'
            : 'no open pipeline';
        const cards = [
            { key: 'customers', label: 'Active Customer Accounts', count: c.customers,    meta: 'active and repeat',        accent: KPI_ACCENTS.customers },
            { key: 'openopp',   label: 'Open Opportunities',       count: c.openOppCount, meta: pipelineLabel,              accent: KPI_ACCENTS.openopp   },
            { key: 'job',       label: 'Jobs in Progress',         count: c.jobCount,     meta: 'work order in field',      accent: KPI_ACCENTS.job       },
            { key: 'warranty',  label: 'Open Warranty Cases',      count: c.warrantyCount,meta: 'service risk',             accent: KPI_ACCENTS.warranty  },
            { key: 'repeat',    label: 'Repeat / Cross-Sell',      count: c.repeatCount,  meta: 'past value, no open deal', accent: KPI_ACCENTS.repeat    },
            { key: 'noact',     label: 'No Activity 30+ Days',     count: c.noactCount,   meta: 'needs a touch',            accent: KPI_ACCENTS.noact     }
        ];
        return cards.map(k => ({
            ...k,
            cssClass:    `kpi${f === k.key ? ' kpi-on' : ''}`,
            accentStyle: `--kpi-accent:${k.accent}`
        }));
    }

    // ── Filter chips ─────────────────────────────────────────────────────────

    get filterChips() {
        const rows  = this._searchRows;
        const active = this.activeFilter;
        return FILTER_DEFS.map(fd => ({
            key:     fd.key,
            label:   fd.label,
            count:   rows.filter(r => this._passChip(r, fd.key)).length,
            cssClass:`chip-f${active === fd.key ? ' chip-on' : ''}`
        }));
    }

    // ── Market and owner selectors ────────────────────────────────────────────

    get marketOptions() {
        return MARKETS.map(m => ({ value: m, label: m }));
    }

    get ownerOptions() {
        const seen = new Set();
        return this._allRows
            .filter(r => r.ownerId && r.ownerName && !seen.has(r.ownerId)
                && seen.add(r.ownerId))
            .map(r => ({ value: r.ownerId, label: r.ownerName }));
    }

    // ── Sort icons ────────────────────────────────────────────────────────────

    get ltvSortIcon() {
        if (this.sortField !== 'ltv') return '↕';
        return this.sortDir > 0 ? '▲' : '▼';
    }
    get actSortIcon() {
        if (this.sortField !== 'act') return '↕';
        return this.sortDir > 0 ? '▲' : '▼';
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    handleKpiClick(event) {
        this.activeFilter = event.currentTarget.dataset.filter;
    }
    handleChipClick(event) {
        this.activeFilter = event.currentTarget.dataset.filter;
    }
    handleSearch(event) {
        this.searchTerm = event.target.value;
    }
    handleMarketChange(event) {
        this.activeMarket = event.target.value;
    }
    handleOwnerChange(event) {
        this.activeOwner = event.target.value;
    }
    handleSort(event) {
        const f = event.currentTarget.dataset.field;
        if (this.sortField === f) {
            this.sortDir *= -1;
        } else {
            this.sortField = f;
            this.sortDir   = 1;
        }
    }
    handleShowAll() {
        this.activeFilter = 'all';
        this.searchTerm   = '';
        this.activeMarket = '';
        this.activeOwner  = '';
    }
    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult);
    }

    // ── Navigation ────────────────────────────────────────────────────────────

    handleOpenAccount(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' }
        });
    }
    handleOpenOpp(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' }
        });
    }
    handleOpenJob(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' }
        });
    }
    handleNewAccount() {
        const state = this.homeOwnerRecordTypeId
            ? { recordTypeId: this.homeOwnerRecordTypeId }
            : {};
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Account', actionName: 'new' },
            state
        });
    }
    handleNewOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Opportunity', actionName: 'new' }
        });
    }
    handleOpenReports() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Report', actionName: 'list' }
        });
    }
    handleNextAction(event) {
        const verb    = event.currentTarget.dataset.verb;
        const acctId  = event.currentTarget.dataset.id;
        const oppId   = event.currentTarget.dataset.opp;
        const jobId   = event.currentTarget.dataset.job;

        if (verb === 'Open Case') {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: 'Case', actionName: 'new' }
            });
        } else if ((verb === 'Open Opp') && oppId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: oppId, actionName: 'view' }
            });
        } else if ((verb === 'Open Job') && jobId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: jobId, actionName: 'view' }
            });
        } else if ((verb === 'Open') && acctId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: acctId, actionName: 'view' }
            });
        } else if ((verb === 'Call' || verb === 'Email') && acctId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: 'Task', actionName: 'new' },
                state: { defaultFieldValues: `WhatId=${acctId}` }
            });
        }
    }
    handleRowMenu(event) {
        const acctId = event.currentTarget.dataset.id;
        const oppId  = event.currentTarget.dataset.opp;
        const jobId  = event.currentTarget.dataset.job;
        // Dispatch event so a parent container or utility bar can render a menu
        this.dispatchEvent(new CustomEvent('rowmenu', {
            detail: { accountId: acctId, oppId, jobId },
            bubbles: true, composed: true
        }));
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    suppressClick(event) { event.preventDefault(); }

    _extractError(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred. Please refresh the page.';
    }
}
