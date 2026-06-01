import { LightningElement, api, wire } from 'lwc';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';

const STATUS_CONFIG = {
    'Active':       { label: 'Active',      barClass: 'bar-active',      chipClass: 'caqua' },
    'Sold':         { label: 'Sold',        barClass: 'bar-sold',        chipClass: 'cp' },
    'In Progress':  { label: 'In Progress', barClass: 'bar-inprogress',  chipClass: 'ca' },
    'Delivered':    { label: 'Delivered',   barClass: 'bar-delivered',   chipClass: 'cg' },
    'Closed':       { label: 'Closed',      barClass: 'bar-closed',      chipClass: 'cgr' },
    'Warranty':     { label: 'Warranty',    barClass: 'bar-warranty',    chipClass: 'cb2' },
};

export default class CommunityProgress extends LightningElement {
    @api recordId;
    _lots;
    error;

    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'Lots__r',
        fields: ['Lot__c.Name', 'Lot__c.Status__c']
    })
    wiredLots({ error, data }) {
        if (data) {
            this._lots = data.records;
            this.error = undefined;
        } else if (error) {
            this._lots = undefined;
            this.error = (error.body && error.body.message) ? error.body.message : 'Unable to load lot data.';
        }
    }

    get isLoaded() {
        return this._lots !== undefined;
    }

    get hasError() {
        return !!this.error;
    }

    get total() {
        return this._lots ? this._lots.length : 0;
    }

    get hasLots() {
        return this.total > 0;
    }

    get statusGroups() {
        if (!this._lots || this._lots.length === 0) return [];
        const counts = {};
        this._lots.forEach(lot => {
            const status = (lot.fields && lot.fields.Status__c && lot.fields.Status__c.value) || 'Unknown';
            counts[status] = (counts[status] || 0) + 1;
        });
        const total = this._lots.length;
        return Object.entries(counts).map(([status, count]) => {
            const cfg = STATUS_CONFIG[status] || { label: status, barClass: 'bar-closed', chipClass: 'cgr' };
            const pct = total > 0 ? (count / total) * 100 : 0;
            return {
                id: status,
                label: cfg.label,
                count,
                pct,
                barClass: 'progress-segment ' + cfg.barClass,
                chipClass: 'chip legend-chip ' + cfg.chipClass,
                barStyle: 'width: ' + pct + '%'
            };
        });
    }
}