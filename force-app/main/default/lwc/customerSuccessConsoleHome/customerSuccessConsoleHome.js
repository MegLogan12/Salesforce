import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getHomeData from '@salesforce/apex/CustomerSuccessHomeController.getHomeData';

export default class CustomerSuccessConsoleHome extends NavigationMixin(LightningElement) {
    @track pageData  = null;
    @track error     = null;
    @track isLoading = true;

    _wiredResult;

    @wire(getHomeData)
    wiredData(result) {
        this._wiredResult = result;
        if (result.data) {
            this.pageData  = result.data;
            this.error     = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error     = result.error?.body?.message || 'Unable to load data.';
            this.isLoading = false;
        }
    }

    // ── KPI getters ───────────────────────────────────────────────────────────
    get openCases()          { return this.pageData?.kpis?.openCases         ?? '—'; }
    get escalatedCases()     { return this.pageData?.kpis?.escalatedCases    ?? '—'; }
    get avgResolutionDays()  { return this.pageData?.kpis?.avgResolutionDays ?? '—'; }
    get warrantyCases()      { return this.pageData?.kpis?.warrantyCases     ?? '—'; }

    get hasError() { return !!this.error; }

    // ── Table data ────────────────────────────────────────────────────────────
    get recentCases() {
        if (!this.pageData?.recentCases) return [];
        return this.pageData.recentCases.map(row => ({
            ...row,
            priorityClass: row.priority === 'High' || row.isEscalated
                ? 'status-chip chip-high'
                : 'status-chip chip-ok',
            rowClass: row.isEscalated ? 'row-escalated' : ''
        }));
    }

    get hasRecentCases()     { return this.recentCases.length > 0; }

    get overdueFollowUps()    { return this.pageData?.overdueFollowUps ?? []; }
    get hasOverdueFollowUps() { return this.overdueFollowUps.length > 0; }

    // ── Handlers ──────────────────────────────────────────────────────────────
    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleNewCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Case', actionName: 'new' }
        });
    }

    handleNewTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'new' }
        });
    }

    handleOpenCases() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Case', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }

    handleEscalatedCases() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Case', actionName: 'list' },
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
}
