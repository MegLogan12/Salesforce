import { LightningElement, api, wire } from 'lwc';
import getTimeLabor from '@salesforce/apex/WorkOrderRecordController.getTimeLabor';

export default class WorkOrderTimeLabor extends LightningElement {
    @api recordId;
    data;
    error;
    loading = true;

    @wire(getTimeLabor, { workOrderId: '$recordId' })
    wired({ data, error }) {
        this.loading = false;
        if (data) {
            this.data = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.data = undefined;
        }
    }

    get goalHours() { return this.num(this.data && this.data.goalHours); }
    get actualHours() { return this.num(this.data && this.data.actualHours); }
    get varianceHours() { return this.num(this.data && this.data.varianceHours); }

    get bonusLabel() {
        if (!this.data) return '-';
        return this.data.bonusEligible ? 'Yes' : 'No';
    }
    get bonusClass() {
        return this.data && this.data.bonusEligible ? 'kpi-value ok' : 'kpi-value warn';
    }
    get otLabel() {
        if (!this.data) return '-';
        return this.data.otFlag ? 'OT Triggered' : 'Within Plan';
    }
    get otClass() {
        return this.data && this.data.otFlag ? 'kpi-value warn' : 'kpi-value ok';
    }

    get entries() {
        return (this.data && this.data.entries) ? this.data.entries : [];
    }
    get hasEntries() {
        return this.entries.length > 0;
    }

    get barPct() {
        const g = Number(this.data && this.data.goalHours) || 0;
        const a = Number(this.data && this.data.actualHours) || 0;
        if (g <= 0) return '0%';
        const pct = Math.min(150, Math.round((a / g) * 100));
        return pct + '%';
    }

    get barStyle() {
        return 'width:' + this.barPct + ';';
    }

    get barClass() {
        const g = Number(this.data && this.data.goalHours) || 0;
        const a = Number(this.data && this.data.actualHours) || 0;
        if (g <= 0) return 'bar-fill';
        if (a > g) return 'bar-fill over';
        if (a > g * 0.9) return 'bar-fill near';
        return 'bar-fill ok';
    }

    get varianceClass() {
        const v = Number(this.data && this.data.varianceHours) || 0;
        if (v > 0) return 'kpi-value warn';
        if (v < 0) return 'kpi-value ok';
        return 'kpi-value';
    }

    num(v) {
        if (v === null || v === undefined) return '-';
        return Number(v).toFixed(2);
    }
}