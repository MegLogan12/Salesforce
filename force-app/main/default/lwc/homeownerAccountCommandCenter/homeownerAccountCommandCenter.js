import { LightningElement, api, wire, track } from 'lwc';
import getCommandData from '@salesforce/apex/HomeownerAccountCmdController.getCommandData';

const CURRENCY_FORMATTER = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});

const TAB_OPPS     = 'opps';
const TAB_ACTIVITY = 'activity';
const TAB_LEADS    = 'leads';
const TAB_CASES    = 'cases';

export default class HomeownerAccountCommandCenter extends LightningElement {
    @api recordId;

    @track pageData  = null;
    @track error     = null;
    @track isLoading = true;
    @track activeTab = TAB_OPPS;

    @wire(getCommandData, { accountId: '$recordId' })
    wiredData({ data, error }) {
        if (data) {
            this.pageData  = data;
            this.error     = null;
            this.isLoading = false;
        } else if (error) {
            this.error     = error?.body?.message || 'Unable to load command center data.';
            this.isLoading = false;
        }
    }

    // ── Account info ──────────────────────────────────────────────────────────
    get accountName() {
        return this.pageData?.account?.name ?? '';
    }

    get accountPhone() {
        return this.pageData?.account?.phone;
    }

    get accountEmail() {
        return this.pageData?.account?.email;
    }

    get accountLocation() {
        const a = this.pageData?.account;
        if (!a) return null;
        const parts = [a.billingCity, a.billingState].filter(Boolean);
        return parts.length ? parts.join(', ') : null;
    }

    get accountOwnerName() {
        return this.pageData?.account?.ownerName;
    }

    get hasError() {
        return !!this.error;
    }

    // ── Opportunities ─────────────────────────────────────────────────────────
    get opps() {
        if (!this.pageData?.opps) return [];
        return this.pageData.opps.map(row => ({
            ...row,
            amountFormatted: row.amount != null ? CURRENCY_FORMATTER.format(row.amount) : '—'
        }));
    }

    get hasOpps()   { return this.opps.length > 0; }
    get oppsCount() { return this.opps.length; }

    // ── Activities ────────────────────────────────────────────────────────────
    get activities()      { return this.pageData?.activities ?? []; }
    get hasActivities()   { return this.activities.length > 0; }
    get activitiesCount() { return this.activities.length; }

    // ── Leads ─────────────────────────────────────────────────────────────────
    get leads()      { return this.pageData?.leads ?? []; }
    get hasLeads()   { return this.leads.length > 0; }
    get leadsCount() { return this.leads.length; }

    // ── Cases ─────────────────────────────────────────────────────────────────
    get cases() {
        if (!this.pageData?.cases) return [];
        return this.pageData.cases.map(row => ({
            ...row,
            priorityClass: row.priority === 'High'
                ? 'status-chip chip-high'
                : 'status-chip chip-ok'
        }));
    }

    get hasCases()   { return this.cases.length > 0; }
    get casesCount() { return this.cases.length; }

    // ── Tab state ─────────────────────────────────────────────────────────────
    get isOppsTab()     { return this.activeTab === TAB_OPPS;     }
    get isActivityTab() { return this.activeTab === TAB_ACTIVITY; }
    get isLeadsTab()    { return this.activeTab === TAB_LEADS;    }
    get isCasesTab()    { return this.activeTab === TAB_CASES;    }

    get tabClassOpps()     { return this._tc(TAB_OPPS);     }
    get tabClassActivity() { return this._tc(TAB_ACTIVITY); }
    get tabClassLeads()    { return this._tc(TAB_LEADS);    }
    get tabClassCases()    { return this._tc(TAB_CASES);    }

    _tc(tab) {
        return 'tab-btn' + (this.activeTab === tab ? ' active' : '');
    }

    showOpps()     { this.activeTab = TAB_OPPS;     }
    showActivity() { this.activeTab = TAB_ACTIVITY; }
    showLeads()    { this.activeTab = TAB_LEADS;    }
    showCases()    { this.activeTab = TAB_CASES;    }
}
