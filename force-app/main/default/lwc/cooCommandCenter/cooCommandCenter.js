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

    get gates() {
        return GATES;
    }

    get showDivisionBanner() {
        if (!this.divisions || this.divisions.length === 0) return false;
        return this.divisions.every(d => d.revenueT12M == null);
    }

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
                gpPctFormatted: fmtPct(row.gpPct),
                onTimePctFormatted: fmtPct(row.onTimePct)
            }));
        } else if (error) {
            console.error('getDivisionSummary error', error);
        }
    }

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
