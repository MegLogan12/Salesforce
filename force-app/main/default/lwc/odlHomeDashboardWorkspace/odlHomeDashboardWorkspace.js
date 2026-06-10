import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDashboardData   from '@salesforce/apex/ODLHomeDashboardController.getDashboardData';
import getPipelineByLob   from '@salesforce/apex/LovingCooController.getPipelineByLob';
import getGpSummary       from '@salesforce/apex/LovingCooController.getGpSummary';
import getActivityRisks   from '@salesforce/apex/LovingCooController.getActivityRisks';

// Named-page navigation targets — Outdoor Living Console app pages
// (Salesforce named page API names — no alternative to these string references)
const NAV = {
    home:          '/lightning/n/Outdoor_Living_Home',
    leads:         '/lightning/n/Outdoor_Living_Leads',
    opportunities: '/lightning/n/Outdoor_Living_Opportunities',
    campaigns:     '/lightning/n/Outdoor_Living_Campaigns',
    tasks:         '/lightning/n/Outdoor_Living_Tasks',
    quotes:        '/lightning/n/Outdoor_Living_Quotes',
    workOrders:    '/lightning/n/Outdoor_Living_Work_Orders',
    calendar:      '/lightning/n/Outdoor_Living_Calendar',
};

const NAV_ITEMS = [
    { label: 'Home Page',      url: NAV.home          },
    { label: 'Account',        url: '/lightning/cmp/c__odlHomeownerAccountsTab' },
    { label: 'Leads',          url: NAV.leads         },
    { label: 'Opportunities',  url: NAV.opportunities },
    { label: 'Campaigns',      url: NAV.campaigns     },
    { label: 'Tasks',          url: NAV.tasks         },
    { label: 'Quote',          url: NAV.quotes        },
    { label: 'Work Order',     url: NAV.workOrders    },
    { label: 'Calendar',       url: NAV.calendar      },
];

const COMPACT = new Intl.NumberFormat('en-US', {
    style:                 'currency',
    currency:              'USD',
    notation:              'compact',
    maximumFractionDigits: 1
});

const FULL_CURRENCY = new Intl.NumberFormat('en-US', {
    style:                 'currency',
    currency:              'USD',
    maximumFractionDigits: 0
});

export default class OdlHomeDashboardWorkspace extends NavigationMixin(LightningElement) {

    navItems = NAV_ITEMS;

    _dashboard = {
        opportunityCount: 0,
        workOrderCount:   0,
        voucherCount:     0,
        quoteCount:       0
    };
    _pipelineRows    = [];
    _gpSummary       = { greenCount: 0, yellowCount: 0, redCount: 0, blockedCount: 0, totalRevenuePending: 0 };
    _activityRisks   = [];
    errorMessage     = '';

    // ── Wires ─────────────────────────────────────────────────────────────────

    @wire(getDashboardData)
    wiredDashboard({ data, error }) {
        if (data)  this._dashboard = data;
        else if (error) this._captureError(error, 'Unable to load dashboard data.');
    }

    @wire(getPipelineByLob)
    wiredPipeline({ data, error }) {
        if (data)  this._pipelineRows = data;
        else if (error) this._captureError(error, 'Unable to load pipeline data.');
    }

    @wire(getGpSummary)
    wiredGpSummary({ data, error }) {
        if (data)  this._gpSummary = data;
        else if (error) this._captureError(error, 'Unable to load GP summary.');
    }

    @wire(getActivityRisks)
    wiredActivityRisks({ data, error }) {
        if (data)  this._activityRisks = data;
        else if (error) this._captureError(error, 'Unable to load activity risk data.');
    }

    // ── Computed — dashboard ───────────────────────────────────────────────────

    get dashboard()    { return this._dashboard; }
    get gpSummary()    { return this._gpSummary; }
    get hasError()     { return !!this.errorMessage; }
    get hasPipelineRows() { return (this._pipelineRows || []).length > 0; }
    get hasActivityRisk() { return (this._activityRisks || []).length > 0; }

    get grossProfitDisplay() {
        return FULL_CURRENCY.format(this._gpSummary.totalRevenuePending || 0);
    }

    // ── Computed — KPI chips ───────────────────────────────────────────────────

    get totalPipelineDisplay() {
        const total = (this._pipelineRows || []).reduce((s, r) => s + (r.pipeline || 0), 0);
        return COMPACT.format(total);
    }

    get totalFollowUpsDue() {
        return (this._pipelineRows || []).reduce((s, r) => s + (r.followUpsDue || 0), 0);
    }

    get totalAtRisk() {
        return (this._pipelineRows || []).reduce((s, r) => s + (r.atRisk || 0), 0);
    }

    get umbPipelineDisplay()         { return COMPACT.format(this._lobPipeline('UMB'));          }
    get customBuildPipelineDisplay() { return COMPACT.format(this._lobPipeline('Custom Build')); }
    get lawnCarePipelineDisplay()    { return COMPACT.format(this._lobPipeline('Lawn Care'));     }

    _lobPipeline(lob) {
        const row = (this._pipelineRows || []).find(r => r.lob === lob);
        return row ? (row.pipeline || 0) : 0;
    }

    // ── Computed — table rows ──────────────────────────────────────────────────

    get formattedPipelineRows() {
        return (this._pipelineRows || []).map(r => ({
            ...r,
            pipelineDisplay: FULL_CURRENCY.format(r.pipeline || 0),
            weightedDisplay: FULL_CURRENCY.format(r.weighted || 0)
        }));
    }

    get activityRiskRows() {
        return (this._activityRisks || []).map(r => ({
            ...r,
            riskChip: r.risk === 'Needs touch' ? 'risk-chip chip-needs-touch' : 'risk-chip chip-monitor'
        }));
    }

    // ── Navigation handlers ────────────────────────────────────────────────────

    handleOpenOpportunities() {
        this[NavigationMixin.Navigate]({
            type:       'standard__navItemPage',
            attributes: { apiName: 'Outdoor_Living_Opportunities' }
        });
    }

    handleOpenLeads() {
        this[NavigationMixin.Navigate]({
            type:       'standard__objectPage',
            attributes: { objectApiName: 'Lead', actionName: 'list' },
            state:      { filterName: 'Recent' }
        });
    }

    handleOpenTasks() {
        this[NavigationMixin.Navigate]({
            type:       'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'list' },
            state:      { filterName: 'Recent' }
        });
    }

    handleNewOpportunity() {
        this[NavigationMixin.Navigate]({
            type:       'standard__objectPage',
            attributes: { objectApiName: 'Opportunity', actionName: 'new' }
        });
    }

    handleNewLead() {
        this[NavigationMixin.Navigate]({
            type:       'standard__objectPage',
            attributes: { objectApiName: 'Lead', actionName: 'new' }
        });
    }

    handleOpenRecord(evt) {
        const recordId = evt.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type:       'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }

    // ── Error helper ───────────────────────────────────────────────────────────

    _captureError(error, fallback) {
        if (this.errorMessage) return;
        this.errorMessage = (error?.body?.message) || fallback;
    }
}
