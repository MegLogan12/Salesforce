import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getCampaignMetrics from '@salesforce/apex/ODL_DashboardController.getCampaignMetrics';

export default class OdlCampaigns extends LightningElement {
    @track allCampaigns = [];
    @track campaignMembers = [];
    @track activeView = 'All';
    @track searchTerm = '';
    activeCount = 0;
    totalMembers = 0;
    conversionRate = '—';
    voucherPending = 0;
    error;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getCampaignMetrics)
    wiredData({ error, data }) {
        if (data) {
            this.error = undefined;
            this.allCampaigns = (data.campaigns || []).map(c => ({
                ...c,
                revenueFormatted: c.ExpectedRevenue ? '$' + Number(c.ExpectedRevenue).toLocaleString() : '—',
                lobLabel: c.Description || '—',
                lobChipClass: 'chip cgr'
            }));
            this.campaignMembers = data.campaignMembers || [];
            this.activeCount = data.activeCount || 0;
            this.totalMembers = data.totalMembers || 0;
            const leads = data.totalLeads || 0;
            const converted = data.convertedLeads || 0;
            this.conversionRate = leads > 0 ? Math.round((converted / leads) * 100) + '%' : '—';
            this.voucherPending = data.voucherPending || 0;
        } else if (error) {
            this.error = (error.body && error.body.message) || 'Unable to load campaign data.';
            this.allCampaigns = [];
            this.campaignMembers = [];
        }
    }

    get campaigns() {
        let base = this.allCampaigns;
        if (this.activeView && this.activeView !== 'All') {
            const v = this.activeView.toLowerCase();
            base = base.filter(c => (c.Type || '').toLowerCase().includes(v));
        }
        if (this.searchTerm) {
            const t = this.searchTerm.toLowerCase();
            base = base.filter(c => (c.Name || '').toLowerCase().includes(t));
        }
        return base;
    }

    get allChipClass() { return this.activeView === 'All' ? 'filter-chip on' : 'filter-chip'; }
    get umbChipClass() { return this.activeView === 'UMB' ? 'filter-chip on' : 'filter-chip'; }
    get cbChipClass() { return this.activeView === 'Custom Build' ? 'filter-chip on' : 'filter-chip'; }
    get lcChipClass() { return this.activeView === 'Lawn Care' ? 'filter-chip on' : 'filter-chip'; }
    get voucherChipClass() { return this.activeView === 'Voucher' ? 'filter-chip on' : 'filter-chip'; }

    showAll() { this.activeView = 'All'; }
    filterUmb() { this.activeView = 'UMB'; }
    filterCb() { this.activeView = 'Custom Build'; }
    filterLc() { this.activeView = 'Lawn Care'; }
    filterVoucher() { this.activeView = 'Voucher'; }
    handleSearch(e) { this.searchTerm = e.target.value; }

    get hasError() { return !!this.error; }
    get noCampaigns() { return !this.error && this.campaigns.length === 0; }
    get noMembers() { return !this.error && this.campaignMembers.length === 0; }
}