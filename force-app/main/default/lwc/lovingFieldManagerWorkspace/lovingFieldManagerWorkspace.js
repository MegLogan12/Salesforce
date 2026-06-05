import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getWorkspaceData from '@salesforce/apex/FieldManagerWorkspaceController.getWorkspaceData';

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
export default class LovingFieldManagerWorkspace extends NavigationMixin(LightningElement) {
    @track pageData  = null;
    @track error     = null;
    @track isLoading = true;

    _wiredResult;

    @wire(getWorkspaceData)
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

    // ── Computed getters ──────────────────────────────────────────────────────

    get todayAppointments() {
        return this.pageData?.todayAppointments ?? '—';
    }

    get unassignedAppointments() {
        return this.pageData?.unassignedAppointments ?? '—';
    }

    get overdueAppointments() {
        return this.pageData?.overdueAppointments ?? '—';
    }

    get openWorkOrders() {
        return this.pageData?.openWorkOrders ?? '—';
    }

    get appointments() {
        const rows = this.pageData?.appointments ?? [];
        return rows.map(r => ({
            ...r,
            statusChipFull: 'status-chip ' + (r.statusChip || 'chip-neutral')
        }));
    }

    get hasAppointments() {
        return (this.pageData?.appointments ?? []).length > 0;
    }

    get hasError() {
        return !!this.error;
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => {
            this.isLoading = false;
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

    handleOpenAppointments() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'ServiceAppointment', actionName: 'list' },
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

    handleNewWorkOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WorkOrder', actionName: 'new' }
        });
    }
    renderedCallback() {
        applyFullWidthLayout(this.template.host);
    }

}
