import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getHomeData from '@salesforce/apex/CCConsoleHomeController.getHomeData';

function applyFullWidthLayout(host) {
    try {
        if (typeof window === 'undefined' || !host) return false;
        const rect = host.getBoundingClientRect();
        if (!rect || rect.width === 0) return false;
        const vw = window.innerWidth;
        if (rect.right < vw - 20) {
            host.style.setProperty('width', `${vw - rect.left}px`, 'important');
            host.style.setProperty('max-width', 'none', 'important');
        }
        if (rect.top > 95) {
            host.style.setProperty('margin-top', `-${Math.round(rect.top - 90)}px`, 'important');
        }
        return true;
    } catch (e) {
        return false;
    }
}
export default class CcConsoleHome extends NavigationMixin(LightningElement) {
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
    get openCases()     { return this.pageData?.kpis?.openCases     ?? '—'; }
    get criticalCases() { return this.pageData?.kpis?.criticalCases ?? '—'; }
    get openWorkOrders(){ return this.pageData?.kpis?.openWorkOrders ?? '—'; }
    get avgDays() {
        const v = this.pageData?.kpis?.avgDaysSinceCreated;
        return v != null ? v : '—';
    }

    get hasError() { return !!this.error; }

    // ── Table data ────────────────────────────────────────────────────────────
    get recentCases() {
        if (!this.pageData?.recentCases) return [];
        return this.pageData.recentCases.map(row => ({
            ...row,
            priorityClass: row.priority === 'High' || row.isEscalated
                ? 'status-chip chip-high'
                : 'status-chip chip-ok'
        }));
    }

    get hasRecentCases()  { return this.recentCases.length > 0; }

    get overdueTasks()    { return this.pageData?.overdueTasks ?? []; }
    get hasOverdueTasks() { return this.overdueTasks.length > 0; }

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

    handleOpenWorkOrders() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WorkOrder', actionName: 'list' },
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
    renderedCallback() {
        applyFullWidthLayout(this.template.host);
    }

}
