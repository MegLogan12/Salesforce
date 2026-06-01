import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getCooMetrics from '@salesforce/apex/ODL_DashboardController.getCooMetrics';

export default class OdlCooCommand extends LightningElement {
    @track lobMetrics = [];
    @track atRiskOpps = [];
    totalPipelineFormatted = '—';
    umbPipelineFormatted = '—';
    cbPipelineFormatted = '—';
    lcPipelineFormatted = '—';
    overdueCount = 0;
    atRiskCount = 0;
    errorMessage = '';

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getCooMetrics)
    wiredData({ error, data }) {
        if (data) {
            this.errorMessage = '';
            this.totalPipelineFormatted = data.totalPipeline ? '$' + this.shortNum(data.totalPipeline) : '—';
            this.overdueCount = data.overdueCount || 0;
            this.atRiskCount = data.atRiskCount || 0;
            this.lobMetrics = (data.lobMetrics || []).map(l => ({
                ...l,
                chipClass: l.lob === 'UMB' ? 'chip co' : l.lob === 'Custom Build' ? 'chip cp' : l.lob === 'Lawn Care' ? 'chip ct' : 'chip cgr',
                totalFormatted: l.total ? '$' + Number(l.total).toLocaleString() : '—',
                weightedFormatted: l.weighted ? '$' + Number(l.weighted).toLocaleString() : '—'
            }));
            const umb = this.lobMetrics.find(l => l.lob === 'UMB');
            const cb = this.lobMetrics.find(l => l.lob === 'Custom Build');
            const lc = this.lobMetrics.find(l => l.lob === 'Lawn Care');
            this.umbPipelineFormatted = umb ? umb.totalFormatted : '—';
            this.cbPipelineFormatted = cb ? cb.totalFormatted : '—';
            this.lcPipelineFormatted = lc ? lc.totalFormatted : '—';
            this.atRiskOpps = (data.atRiskOpps || []).map(o => ({
                ...o,
                lobChipClass: o.ODL_Path__c === 'UMB' ? 'chip co' : o.ODL_Path__c === 'Custom Build' ? 'chip cp' : o.ODL_Path__c === 'Lawn Care' ? 'chip ct' : 'chip cgr',
                lastActivityFormatted: o.LastActivityDate ? new Date(o.LastActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : 'Never'
            }));
        } else if (error) {
            this.errorMessage = (error.body && error.body.message) ? error.body.message : 'Unable to load COO metrics.';
        }
    }

    get hasError() { return !!this.errorMessage; }

    shortNum(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(2) + 'M';
        if (n >= 1000) return Math.round(n / 1000) + 'K';
        return Number(n).toLocaleString();
    }

    get noMetrics() { return this.lobMetrics.length === 0; }
    get noAtRisk() { return this.atRiskOpps.length === 0; }
}