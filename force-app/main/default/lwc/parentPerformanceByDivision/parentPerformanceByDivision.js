import { LightningElement, api, wire } from 'lwc';
import getDivisionsWithRollup from '@salesforce/apex/ParentAccountRollupController.getDivisionsWithRollup';

export default class ParentPerformanceByDivision extends LightningElement {
    @api recordId;
    rawRows;
    error;

    @wire(getDivisionsWithRollup, { parentAccountId: '$recordId' })
    wired({ data, error }) {
        if (data) { this.rawRows = data; this.error = undefined; }
        else if (error) { this.rawRows = undefined; this.error = error.body ? error.body.message : error.message; }
    }

    get hasRows() { return this.rawRows && this.rawRows.length > 0; }
    get hasError() { return !!this.error; }

    get cards() {
        if (!this.rawRows) return [];
        return this.rawRows.map((r, idx) => {
            // Determine pill based on "age" using contract start date if present
            let pillClass = 'pill pg';
            let pillLabel = 'Anchor';
            let fillColor = '#2e844a';
            const now = new Date();
            if (r.contractStart) {
                const start = new Date(r.contractStart);
                const monthsOld = (now.getFullYear() - start.getFullYear()) * 12 + (now.getMonth() - start.getMonth());
                if (monthsOld < 6) { pillClass = 'pill pa'; pillLabel = 'New'; fillColor = '#ba7517'; }
                else if (monthsOld < 18) { pillClass = 'pill pb'; pillLabel = 'Ramping'; fillColor = '#0070d2'; }
            } else if (idx === 0) {
                pillClass = 'pill pg'; pillLabel = 'Anchor';
            } else if (idx === 1) {
                pillClass = 'pill pb'; pillLabel = 'Ramping'; fillColor = '#0070d2';
            } else {
                pillClass = 'pill pa'; pillLabel = 'New'; fillColor = '#ba7517';
            }
            const renewLabel = r.contractEnd ? 'Contract renews ' + this.formatMonth(r.contractEnd) : 'Contract renewal not set';
            return {
                key: r.id,
                name: r.name,
                market: r.market,
                pillClass,
                pillLabel,
                ytdRevenue: r.ytdRevenueDisplay,
                subLine: `YTD revenue : ${r.avgGpDisplay} GP`,
                fillStyle: `width:${r.completePct || 0}%;background:${fillColor}`,
                lotsRatio: r.lotsRatio + ' lots',
                footer: `${r.activeCommunities || 0} active communities : ${r.openWoCount || 0} open WOs`,
                renewLabel
            };
        });
    }

    formatMonth(d) {
        try {
            return new Date(d).toLocaleDateString('en-US', { month: 'short', year: 'numeric' });
        } catch (e) { return d; }
    }
}