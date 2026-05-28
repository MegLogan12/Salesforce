import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getCampaignMetrics from '@salesforce/apex/ODL_DashboardController.getCampaignMetrics';

export default class OdlCampaigns extends LightningElement {
    @track campaigns = [];
    activeCount = 0;
    totalMembers = 0;
    totalRevenue = '—';

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getCampaignMetrics)
    wiredData({ error, data }) {
        if (data) {
            this.campaigns = (data.campaigns || []).map(c => ({
                ...c,
                revenueFormatted: c.ExpectedRevenue ? '$' + Number(c.ExpectedRevenue).toLocaleString() : '—'
            }));
            this.activeCount = data.activeCount || 0;
            this.totalMembers = data.totalMembers || 0;
            this.totalRevenue = data.totalRevenue ? '$' + Number(data.totalRevenue).toLocaleString() : '—';
        }
    }

    get noCampaigns() { return this.campaigns.length === 0; }
}
