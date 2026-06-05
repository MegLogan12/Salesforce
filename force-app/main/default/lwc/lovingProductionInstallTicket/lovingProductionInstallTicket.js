import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getWorkspace from '@salesforce/apex/LovingWOWorkspaceController.getWorkspace';

const IDENTITY_LABELS = new Set([
    'Work Order Number', 'Lot', 'Builder', 'Community', 'Site Address', 'Builder PO'
]);

const STATE_LABELS = new Set([
    'Work Type', 'Master Status', 'Execution Status', 'Billing State',
    'QI Outcome', 'Customer Care State', 'Parent WorkOrder'
]);

const PROOF_LABELS = new Set([
    'Required Photo Proof', 'QI Status', 'Customer Care State',
    'Total Scope Price', 'Total Cost', 'Gross Profit', 'Invoice Amount'
]);

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
export default class LovingProductionInstallTicket extends NavigationMixin(LightningElement) {
    @api recordId;
    workspace;
    loaded = false;
    hasError = false;
    errorMessage = '';

    @wire(getWorkspace, { workOrderId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.workspace = data;
            this.hasError = false;
            this.loaded = true;
        } else if (error) {
            this.errorMessage = error?.body?.message || 'Failed to load production install workspace.';
            this.hasError = true;
            this.loaded = true;
        }
    }

    get header() {
        return this.workspace?.header || {};
    }

    get summaryRows() {
        return this.workspace?.summaryRows || [];
    }

    get identityRows() {
        return this.summaryRows.filter((r) => IDENTITY_LABELS.has(r.label));
    }

    get stateRows() {
        return this.summaryRows.filter((r) => STATE_LABELS.has(r.label));
    }

    get relatedAppointments() {
        return this.workspace?.relatedAppointments || [];
    }

    get hasAppointments() {
        return this.relatedAppointments.length > 0;
    }

    get lineItems() {
        return this.workspace?.lineItems || [];
    }

    get hasLineItems() {
        return this.lineItems.length > 0;
    }

    get closeoutRows() {
        return this.workspace?.closeoutRows || [];
    }

    get proofRows() {
        return this.closeoutRows.filter((r) => PROOF_LABELS.has(r.label));
    }

    get identitySubtitle() {
        const h = this.header;
        const parts = [h.builderName, h.communityName, h.lotName].filter(Boolean);
        if (h.poNumber) parts.push(`PO ${h.poNumber}`);
        return parts.join(' • ');
    }

    handleOpenAppointment(event) {
        const saId = event.currentTarget.dataset.id;
        if (!saId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/lightning/r/ServiceAppointment/${saId}/view` }
        });
    }

    handleOpenFiles() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/r/WorkOrder/${this.recordId}/related/AttachedContentDocuments/view`
            }
        });
    }
    renderedCallback() {
        applyFullWidthLayout(this.template.host);
    }

}
