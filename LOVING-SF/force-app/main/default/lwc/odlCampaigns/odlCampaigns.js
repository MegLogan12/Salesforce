import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getCampaignMetrics from '@salesforce/apex/ODL_DashboardController.getCampaignMetrics';

export default class OdlCampaigns extends LightningElement {
    @track campaigns = [];
    @track campaignMembers = [];
    activeCount = 0;
    totalMembers = 0;
    conversionRate = '—';
    voucherPending = 0;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getCampaignMetrics)
    wiredData({ error, data }) {
        if (data) {
            this.campaigns = (data.campaigns || []).map(c => ({
                ...c,
                revenueFormatted: c.ExpectedRevenue ? '$' + Number(c.ExpectedRevenue).toLocaleString() : '—',
                lobLabel: c.Description || '—',
                lobChipClass: 'chip cgr'
            }));
            this.activeCount = data.activeCount || 0;
            this.totalMembers = data.totalMembers || 0;
            const leads = data.totalLeads || 0;
            const converted = data.convertedLeads || 0;
            this.conversionRate = leads > 0 ? Math.round((converted / leads) * 100) + '%' : '—';
            this.voucherPending = data.voucherPending || 0;
        }
    }

    get noCampaigns() { return this.campaigns.length === 0; }
    get noMembers() { return this.campaignMembers.length === 0; }
}
