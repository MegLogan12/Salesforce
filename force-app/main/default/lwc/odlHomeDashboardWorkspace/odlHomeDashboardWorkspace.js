import { LightningElement, wire } from 'lwc';
import getDashboardData from '@salesforce/apex/ODLHomeDashboardController.getDashboardData';
import getPipelineByLob from '@salesforce/apex/LovingCooController.getPipelineByLob';
import getGpSummary from '@salesforce/apex/LovingCooController.getGpSummary';

const NAV_ITEMS = [
    { label: 'Home Page', url: '/lightning/n/Outdoor_Living_Home' },
    { label: 'Account', url: '/lightning/cmp/c__odlHomeownerAccountsTab' },
    { label: 'Leads', url: '/lightning/n/Outdoor_Living_Leads' },
    { label: 'Opportunities', url: '/lightning/n/Outdoor_Living_Opportunities' },
    { label: 'Campaigns', url: '/lightning/n/Outdoor_Living_Campaigns' },
    { label: 'Tasks', url: '/lightning/n/Outdoor_Living_Tasks' },
    { label: 'Quote', url: '/lightning/n/Outdoor_Living_Quotes' },
    { label: 'Work Order', url: '/lightning/n/Outdoor_Living_Work_Orders' },
    { label: 'Calendar', url: '/lightning/n/Outdoor_Living_Calendar' },
];

export default class OdlHomeDashboardWorkspace extends LightningElement {
    dashboard = {
        accountCount: 0,
        leadCount: 0,
        opportunityCount: 0,
        campaignCount: 0,
        voucherCount: 0,
        quoteCount: 0,
        workOrderCount: 0,
        serviceAppointmentCount: 0,
        warrantyCount: 0
    };
    pipelineRows = [];
    gpSummary = { greenCount: 0, yellowCount: 0, redCount: 0, blockedCount: 0, totalRevenuePending: 0 };
    errorMessage = '';

    navItems = NAV_ITEMS;

    @wire(getDashboardData)
    wiredDashboard({ data, error }) {
        if (data) {
            this.dashboard = data;
        } else if (error) {
            this.captureError(error, 'Unable to load dashboard data.');
        }
    }

    @wire(getPipelineByLob)
    wiredPipeline({ data, error }) {
        if (data) {
            this.pipelineRows = data;
        } else if (error) {
            this.pipelineRows = [];
            this.captureError(error, 'Unable to load pipeline data.');
        }
    }

    @wire(getGpSummary)
    wiredGpSummary({ data, error }) {
        if (data) {
            this.gpSummary = data;
        } else if (error) {
            this.captureError(error, 'Unable to load gross profit summary.');
        }
    }

    captureError(error, fallback) {
        if (this.errorMessage) return;
        this.errorMessage = (error && error.body && error.body.message) ? error.body.message : fallback;
    }

    get hasError() { return !!this.errorMessage; }

    get pipelineDisplay() {
        return this.formatCurrency((this.pipelineRows || []).reduce((sum, row) => sum + (row.pipeline || 0), 0));
    }

    get weightedPipelineDisplay() {
        return this.formatCurrency((this.pipelineRows || []).reduce((sum, row) => sum + (row.weighted || 0), 0));
    }

    get followUpsDue() {
        return (this.pipelineRows || []).reduce((sum, row) => sum + (row.followUpsDue || 0), 0);
    }

    get atRiskCount() {
        return (this.pipelineRows || []).reduce((sum, row) => sum + (row.atRisk || 0), 0);
    }

    get grossProfitDisplay() {
        return this.formatCurrency(this.gpSummary.totalRevenuePending || 0);
    }

    get hasPipelineRows() {
        return (this.pipelineRows || []).length > 0;
    }

    formatCurrency(value) {
        const amount = Number(value || 0);
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(amount);
    }
}