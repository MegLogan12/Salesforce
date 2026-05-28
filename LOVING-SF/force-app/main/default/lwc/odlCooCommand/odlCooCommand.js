import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getCooMetrics from '@salesforce/apex/ODL_DashboardController.getCooMetrics';

export default class OdlCooCommand extends LightningElement {
    @track lobMetrics = [];
    @track atRiskOpps = [];
    totalPipelineFormatted = '—';
    overdueCount = 0;
    atRiskCount = 0;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getCooMetrics)
    wiredData({ error, data }) {
        if (data) {
            this.totalPipelineFormatted = data.totalPipeline ? '$' + Number(data.totalPipeline).toLocaleString() : '—';
            this.overdueCount = data.overdueCount || 0;
            this.atRiskCount = data.atRiskCount || 0;
            this.lobMetrics = (data.lobMetrics || []).map(l => ({
                ...l,
                chipClass: l.lob === 'UMB' ? 'chip co' : l.lob === 'Custom Build' ? 'chip cp' : l.lob === 'Lawn Care' ? 'chip ct' : 'chip cgr',
                totalFormatted: l.total ? '$' + Number(l.total).toLocaleString() : '—'
            }));
            this.atRiskOpps = (data.atRiskOpps || []).map(o => ({
                ...o,
                lobChipClass: o.ODL_Path__c === 'UMB' ? 'chip co' : o.ODL_Path__c === 'Custom Build' ? 'chip cp' : o.ODL_Path__c === 'Lawn Care' ? 'chip ct' : 'chip cgr',
                lastActivityFormatted: o.LastActivityDate ? new Date(o.LastActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : 'Never',
                amountFormatted: o.Amount ? '$' + Number(o.Amount).toLocaleString() : '—'
            }));
        }
    }

    get noMetrics() { return this.lobMetrics.length === 0; }
    get noAtRisk() { return this.atRiskOpps.length === 0; }
}
