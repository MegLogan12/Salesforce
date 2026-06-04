import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getHomePageData from '@salesforce/apex/ODLConsoleHomeController.getHomePageData';

const CURRENCY_FORMATTER = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});

export default class OdlConsoleHome extends NavigationMixin(LightningElement) {
    @track pageData = null;
    @track error = null;
    @track isLoading = true;

    _wiredResult;

    @wire(getHomePageData)
    wiredData(result) {
        this._wiredResult = result;
        if (result.data) {
            this.pageData = result.data;
            this.error = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error?.body?.message || 'Unable to load data.';
            this.isLoading = false;
        }
    }

    // ── Computed KPI values ────────────────────────────────────────────────────
    get totalOpps() {
        return this.pageData?.kpis?.totalOpenOpps ?? '—';
    }

    get umbCount() {
        return this.pageData?.kpis?.umbCount ?? '—';
    }

    get umbPipeline() {
        const v = this.pageData?.kpis?.umbPipeline;
        return v != null ? CURRENCY_FORMATTER.format(v) : '—';
    }

    get odlCount() {
        return this.pageData?.kpis?.odlCount ?? '—';
    }

    get odlPipeline() {
        const v = this.pageData?.kpis?.odlPipeline;
        return v != null ? CURRENCY_FORMATTER.format(v) : '—';
    }

    get designBuildCount() {
        return this.pageData?.kpis?.designBuildCount ?? '—';
    }

    get overdueTasks() {
        return this.pageData?.kpis?.overdueTasks ?? '—';
    }

    get openLeads() {
        return this.pageData?.kpis?.openLeads ?? '—';
    }

    get lobRows() {
        if (!this.pageData?.lobRows) return [];
        return this.pageData.lobRows.map(row => ({
            ...row,
            pipelineFormatted: row.pipeline != null ? CURRENCY_FORMATTER.format(row.pipeline) : '$0',
            isEmpty: (row.openOpps || 0) === 0
        }));
    }

    get recentActivity() {
        return this.pageData?.recentActivity ?? [];
    }

    get hasActivity() {
        return this.recentActivity.length > 0;
    }

    get hasError() {
        return !!this.error;
    }

    // ── Navigation handlers ────────────────────────────────────────────────────
    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleOpenOpportunities() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Opportunity', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleOpenLeads() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Lead', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleOpenTasks() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleOpenReports() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Report', actionName: 'list' }
        });
    }

    handleOpenRecord(evt) {
        const recordId = evt.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }

    handleOpenRelated(evt) {
        const recordId = evt.currentTarget.dataset.related;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }

    handleNewOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Opportunity', actionName: 'new' }
        });
    }

    handleNewLead() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Lead', actionName: 'new' }
        });
    }

    handleCompleteTask(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    handleNewTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' }
        });
    }
}
