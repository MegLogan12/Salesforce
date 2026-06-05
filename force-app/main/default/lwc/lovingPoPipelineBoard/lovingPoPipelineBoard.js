import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getPipelineData from '@salesforce/apex/LovingPoPipelineController.getPipelineData';

// Column definitions ordered by pipeline stage
const COLUMN_DEFS = [
    { key: 'pendingReview',     label: 'Pending CS Review',      headerClass: 'col-header ch-slate'   },
    { key: 'pendingApproval',   label: 'Pending Approval',       headerClass: 'col-header ch-slate'   },
    { key: 'packageCheck',      label: 'Package Match Check',    headerClass: 'col-header ch-amber'   },
    { key: 'takeoffRequested',  label: 'Ready for Takeoff',      headerClass: 'col-header ch-amber'   },
    { key: 'takeoffScheduled',  label: 'Takeoff Scheduled',      headerClass: 'col-header ch-blue'    },
    { key: 'takeoffProgress',   label: 'Takeoff In Progress',    headerClass: 'col-header ch-blue'    },
    { key: 'takeoffComplete',   label: 'Takeoff Complete',       headerClass: 'col-header ch-teal'    },
    { key: 'workOrderCreated',  label: 'Work Order Created',     headerClass: 'col-header ch-teal'    },
    { key: 'clear',             label: 'Clear for Schedule',     headerClass: 'col-header ch-green'   },
    { key: 'other',             label: 'Other / Unknown',        headerClass: 'col-header ch-slate'   }
];

// Map controller's mapToBoardColumn return values to column keys
// (matches the test assertions in LovingPoPipelineControllerTest)
function deriveBoardKey(status, stage) {
    if (!status && !stage) return 'other';
    const s = (status || '').toLowerCase();
    const g = (stage || '').toLowerCase();

    if (s === 'pending cs review')    return 'pendingReview';
    if (s === 'pending approval')     return 'pendingApproval';
    if (s === 'package match check')  return 'packageCheck';
    if (s === 'ready for takeoff')    return 'takeoffRequested';
    if (s === 'takeoff scheduled')    return 'takeoffScheduled';
    if (s === 'takeoff in progress')  return 'takeoffProgress';
    if (s === 'takeoff complete')     return 'takeoffComplete';
    if (s === 'work order created')   return 'workOrderCreated';
    if (s === 'clear for schedule')   return 'clear';

    // Fallback to stage
    if (g.includes('work order created'))  return 'workOrderCreated';
    if (g.includes('clear for schedule'))  return 'clear';
    if (g.includes('ready for takeoff'))   return 'takeoffRequested';
    if (g.includes('takeoff complete'))    return 'takeoffComplete';
    if (g.includes('takeoff in progress')) return 'takeoffProgress';
    if (g.includes('takeoff scheduled'))   return 'takeoffScheduled';
    if (g.includes('package match'))       return 'packageCheck';
    if (g.includes('pending approval'))    return 'pendingApproval';
    if (g.includes('pending cs'))         return 'pendingReview';

    return 'other';
}

function cardClass(status) {
    const s = (status || '').toLowerCase();
    if (s === 'clear for schedule' || s === 'work order created') return 'po-card card-green';
    if (s.includes('pending') || s.includes('review'))           return 'po-card card-amber';
    if (s.includes('takeoff'))                                    return 'po-card card-blue';
    return 'po-card card-slate';
}

import { applyFullWidthLayout } from 'c/lovingLayoutUtils';
export default class LovingPoPipelineBoard extends NavigationMixin(LightningElement) {
    /** Optional — when placed on Takeoff record page, filters context visually */
    @api recordId;

    @track columns = [];
    loaded = false;
    hasError = false;
    errorMessage = '';
    _wiredResult;

    @wire(getPipelineData)
    onPipeline(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this._buildColumns(data);
            this.hasError = false;
            this.loaded = true;
        } else if (error) {
            this.errorMessage = error?.body?.message || 'Failed to load pipeline data.';
            this.hasError = true;
            this.loaded = true;
        }
    }

    _buildColumns(pipeline) {
        const buckets = {};
        for (const def of COLUMN_DEFS) {
            buckets[def.key] = [];
        }

        const records = pipeline?.records || [];
        for (const card of records) {
            const key = deriveBoardKey(card.status, card.stage);
            const bucket = buckets[key] ?? buckets['other'];
            bucket.push({
                id: card.id,
                name: card.name || card.purchaseOrderName || '—',
                builder: card.builderName || '—',
                lotName: card.lotName || '—',
                status: card.status || '—',
                displayStatus: card.displayStatus || card.status || '—',
                takeoffStatus: card.takeoffStatus || null,
                nextAction: card.nextAction || null,
                cardClass: cardClass(card.status)
            });
        }

        this.columns = COLUMN_DEFS.map((def) => ({
            ...def,
            cards: buckets[def.key] || [],
            count: (buckets[def.key] || []).length,
            hasCards: (buckets[def.key] || []).length > 0
        }));
    }

    get totalCount() {
        return this.columns.reduce((acc, c) => acc + c.count, 0);
    }

    get subtitle() {
        if (this.recordId) {
            return `Takeoff context: ${this.recordId}`;
        }
        return 'All active POs across the pipeline';
    }

    handleCardClick(event) {
        const poId = event.currentTarget.dataset.id;
        if (!poId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/r/Purchase_Order__c/${poId}/view`
            }
        });
    }

    async handleRefresh() {
        this.loaded = false;
        if (this._wiredResult) {
            await refreshApex(this._wiredResult);
        }
    }
    renderedCallback() {
        applyFullWidthLayout(this.template.host);
    }

}
