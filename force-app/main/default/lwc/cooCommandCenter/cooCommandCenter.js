import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCooKpis from '@salesforce/apex/LovingCooController.getCooKpis';
import getDivisionSummary from '@salesforce/apex/LovingCooController.getDivisionSummary';
import getWoPipeline from '@salesforce/apex/LovingCooController.getWoPipeline';
import getGpSummary from '@salesforce/apex/LovingCooController.getGpSummary';
import escalateGate from '@salesforce/apex/LovingCooController.escalateGate';

const GATES = [
    {
        id: 'G3a',
        label: 'Measuring Cup / QI conflict',
        owner: 'COO',
        action: 'Resolve process conflict'
    },
    {
        id: 'G5',
        label: 'Accounting System',
        owner: 'COO',
        action: 'Choose accounting target'
    },
    {
        id: 'G6',
        label: 'Sod/Turf Forecast model',
        owner: 'COO',
        action: 'Approve model'
    },
    {
        id: 'G9',
        label: 'Builder portal rollout',
        owner: 'COO',
        action: 'Approve timeline'
    }
];

const USD_FORMAT = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});

function fmtCurrency(val) {
    if (val == null) return '—';
    return USD_FORMAT.format(val);
}

function fmtPct(val) {
    if (val == null) return '—';
    return val.toFixed(1) + '%';
}

export default class CooCommandCenter extends LightningElement {
    @track kpis;
    @track pipeline;
    @track gpSummary;
    @track divisions;
    @track activeTab = 'overview';

    get gates() {
        return GATES;
    }

    get gateCount() {
        return GATES.length;
    }

    get divisionCount() {
        return this.divisions ? this.divisions.length : 0;
    }

    // ── Stat card computed values ──────────────────────────────────────────────

    get activeWosStat() {
        return this.kpis ? this.kpis.activeWOs : '—';
    }

    get pendingRevenueStat() {
        return this.gpSummary ? this.gpSummary.totalRevenuePendingFormatted : '—';
    }

    get avgOnTimePct() {
        if (!this.divisions || this.divisions.length === 0) return '—';
        const filled = this.divisions.filter(d => d.onTimePct != null);
        if (filled.length === 0) return '—';
        const avg = filled.reduce((sum, d) => sum + d.onTimePct, 0) / filled.length;
        return fmtPct(avg);
    }

    get avgGpPct() {
        if (!this.divisions || this.divisions.length === 0) return '—';
        const filled = this.divisions.filter(d => d.gpPct != null);
        if (filled.length === 0) return '—';
        const avg = filled.reduce((sum, d) => sum + d.gpPct, 0) / filled.length;
        return fmtPct(avg);
    }

    // ── Tab state ──────────────────────────────────────────────────────────────

    get isOverviewTab()   { return this.activeTab === 'overview'; }
    get isByDivisionTab() { return this.activeTab === 'division'; }
    get isExceptionsTab() { return this.activeTab === 'exceptions'; }
    get isGatesTab()      { return this.activeTab === 'gates'; }

    get overviewTabClass()   { return 'subtab' + (this.activeTab === 'overview'    ? ' active' : ''); }
    get byDivisionTabClass() { return 'subtab' + (this.activeTab === 'division'    ? ' active' : ''); }
    get exceptionsTabClass() { return 'subtab' + (this.activeTab === 'exceptions'  ? ' active' : ''); }
    get gatesTabClass()      { return 'subtab' + (this.activeTab === 'gates'       ? ' active' : ''); }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleOpenGates() {
        this.activeTab = 'gates';
    }

    handleOpenExceptions() {
        this.activeTab = 'exceptions';
    }

    get showDivisionBanner() {
        if (!this.divisions || this.divisions.length === 0) return false;
        return this.divisions.every(d => d.revenueT12M == null);
    }

    // ── Wire adapters ──────────────────────────────────────────────────────────

    @wire(getCooKpis)
    wiredKpis({ data, error }) {
        if (data) {
            this.kpis = data;
        } else if (error) {
            console.error('getCooKpis error', error);
        }
    }

    @wire(getWoPipeline)
    wiredPipeline({ data, error }) {
        if (data) {
            this.pipeline = data;
        } else if (error) {
            console.error('getWoPipeline error', error);
        }
    }

    @wire(getGpSummary)
    wiredGpSummary({ data, error }) {
        if (data) {
            this.gpSummary = Object.assign({}, data, {
                totalRevenuePendingFormatted: fmtCurrency(data.totalRevenuePending)
            });
        } else if (error) {
            console.error('getGpSummary error', error);
        }
    }

    @wire(getDivisionSummary)
    wiredDivisions({ data, error }) {
        if (data) {
            this.divisions = data.map(row => Object.assign({}, row, {
                revenueT12MFormatted: fmtCurrency(row.revenueT12M),
                gpPctFormatted:       fmtPct(row.gpPct),
                onTimePctFormatted:   fmtPct(row.onTimePct),
                healthClass: 'chip ' + (
                    row.onTimePct == null ? 'c-slate' :
                    row.onTimePct >= 90   ? 'c-green' :
                    row.onTimePct >= 80   ? 'c-amber' : 'c-red'
                ),
                healthLabel: (
                    row.onTimePct == null ? 'n/a' :
                    row.onTimePct >= 90   ? 'good' :
                    row.onTimePct >= 80   ? 'watch' : 'low'
                )
            }));
        } else if (error) {
            console.error('getDivisionSummary error', error);
        }
    }

    // ── Gate escalation ────────────────────────────────────────────────────────

    handleEscalate(event) {
        const gateId = event.currentTarget.dataset.gateId;
        const gate = GATES.find(g => g.id === gateId);
        const message = gate
            ? gate.label + ' — action required: ' + gate.action
            : gateId;

        escalateGate({ gateId: gateId, message: message })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Escalation posted',
                        message: 'Gate ' + gateId + ' has been escalated to your Chatter feed.',
                        variant: 'success'
                    })
                );
            })
            .catch(err => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Escalation failed',
                        message: err.body ? err.body.message : 'Unknown error',
                        variant: 'error'
                    })
                );
            });
    }
}
