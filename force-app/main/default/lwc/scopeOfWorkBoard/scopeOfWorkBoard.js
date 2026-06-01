import { LightningElement, api, wire } from 'lwc';
import getScopesOfWork from '@salesforce/apex/ParentAccountRollupController.getScopesOfWork';
import getDivisionKpis from '@salesforce/apex/ParentAccountRollupController.getDivisionKpis';

// LOB: fields to show on card
const FIELD_MAP = {
    'Production Landscaping': [
        { key: 'packageTier', label: 'Package Tier' },
        { key: 'sodType', label: 'Sod Type' },
        { key: 'plantPalette', label: 'Plant Palette' },
        { key: 'mulchSpec', label: 'Mulch Spec' },
        { key: 'streetTreesIncluded', label: 'Street Trees Included' },
        { key: 'gradingIncluded', label: 'Grading Included', type: 'bool' }
    ],
    'Aqua Service': [
        { key: 'serviceType', label: 'Service Type' },
        { key: 'controllerBrand', label: 'Controller Brand' },
        { key: 'zoneCountAvg', label: 'Zone Count (avg)' },
        { key: 'wifiSmartController', label: 'WiFi Smart Controller', type: 'bool' },
        { key: 'backflowRequired', label: 'Backflow Required', type: 'bool' },
        { key: 'permitByLoving', label: 'Permit by LOVING' }
    ],
    'Irrigation': [
        { key: 'serviceType', label: 'Service Type' },
        { key: 'controllerBrand', label: 'Controller Brand' },
        { key: 'zoneCountAvg', label: 'Zone Count (avg)' },
        { key: 'wifiSmartController', label: 'WiFi Smart Controller', type: 'bool' },
        { key: 'backflowRequired', label: 'Backflow Required', type: 'bool' }
    ],
    'Lawn Care': [
        { key: 'frequency', label: 'Frequency' },
        { key: 'designatedServiceDay', label: 'Designated Service Day' },
        { key: 'fertilizationIncluded', label: 'Fertilization' },
        { key: 'weedControl', label: 'Weed Control', type: 'bool' },
        { key: 'aeration', label: 'Aeration' },
        { key: 'overseeding', label: 'Overseeding' }
    ],
    'Lawn Care / Maintenance': [
        { key: 'frequency', label: 'Frequency' },
        { key: 'designatedServiceDay', label: 'Designated Service Day' },
        { key: 'fertilizationIncluded', label: 'Fertilization' },
        { key: 'weedControl', label: 'Weed Control', type: 'bool' },
        { key: 'aeration', label: 'Aeration' },
        { key: 'overseeding', label: 'Overseeding' }
    ],
    'Seasonal Refreshes': [
        { key: 'status', label: 'Status' },
        { key: 'pricePerLot', label: 'Price Per Lot', type: 'currency' }
    ],
    'Refreshes': [
        { key: 'status', label: 'Status' },
        { key: 'pricePerLot', label: 'Price Per Lot', type: 'currency' }
    ],
    'Signature Builds': [
        { key: 'status', label: 'Status' },
        { key: 'pricePerLot', label: 'Price Per Lot', type: 'currency' }
    ],
    'Finishing Touches': [
        { key: 'status', label: 'Status' },
        { key: 'pricePerLot', label: 'Price Per Lot', type: 'currency' }
    ]
};

// LOB accent color class
const ACCENT_MAP = {
    'Production Landscaping': 'accent-green',
    'Aqua Service': 'accent-blue',
    'Irrigation': 'accent-blue',
    'Lawn Care': 'accent-amber',
    'Lawn Care / Maintenance': 'accent-amber',
    'Seasonal Refreshes': 'accent-purple',
    'Refreshes': 'accent-purple',
    'Signature Builds': 'accent-gray',
    'Finishing Touches': 'accent-red'
};

export default class ScopeOfWorkBoard extends LightningElement {
    @api recordId;
    rows;
    kpis;
    error;

    @wire(getScopesOfWork, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.rows = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
        }
    }

    @wire(getDivisionKpis, { accountId: '$recordId' })
    wiredKpis({ data, error }) {
        if (data) {
            this.kpis = data;
            if (!this.error) this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
        }
    }

    get cards() {
        if (!this.rows) return [];
        return this.rows.map(r => {
            const lob = r.lineOfBusiness || 'Scope';
            const fieldSpecs = FIELD_MAP[lob] || [
                { key: 'packageTier', label: 'Package' },
                { key: 'pricePerLot', label: 'Price Per Lot', type: 'currency' }
            ];
            const fields = fieldSpecs.map(f => {
                const raw = r[f.key];
                let display = raw;
                let isEmpty = raw === null || raw === undefined || raw === '';
                if (isEmpty) {
                    display = 'Not set';
                } else if (f.type === 'currency') {
                    display = '$' + Number(raw).toLocaleString();
                } else if (f.type === 'bool') {
                    display = raw ? 'Yes' : 'No';
                }
                return { label: f.label, display, emptyCls: isEmpty ? 'fv em' : 'fv' };
            });
            const isActive = (r.status || '').toLowerCase() === 'active';
            const statusLabel = isActive ? 'Active' : (r.status || 'Not in scope');
            const statusCls = isActive ? 'pill pg' : 'pill pgr';

            // price big text
            let priceBig = '';
            if (r.pricePerLot != null) {
                priceBig = '$' + Number(r.pricePerLot).toLocaleString() + ' / lot';
            } else if (r.pricePerVisit != null) {
                priceBig = '$' + Number(r.pricePerVisit).toLocaleString() + ' / visit';
            }

            return {
                id: r.id,
                title: lob,
                status: statusLabel,
                statusCls,
                accentCls: 'sow-card ' + (ACCENT_MAP[lob] || 'accent-gray'),
                notes: r.notes,
                recordUrl: r.recordUrl,
                priceBig,
                hasPrice: !!priceBig,
                fields
            };
        });
    }

    get hasCards() { return this.cards && this.cards.length > 0; }

    get activeLobs() { return this.rows ? this.rows.filter(r => (r.status || '').toLowerCase() === 'active').length : 0; }
    get totalLobs() { return this.rows ? this.rows.length : 0; }

    get communitiesCount() {
        return this.kpis && this.kpis.activeCommunities != null ? String(this.kpis.activeCommunities) : '-';
    }

    get contractedLots() {
        return this.kpis && this.kpis.totalContractedLots != null ? String(this.kpis.totalContractedLots) : '-';
    }

    // Average price-per-lot across the scopes of work that carry a per-lot price.
    get avgRevPerLot() {
        if (!this.rows) return '-';
        const priced = this.rows.filter(r => r.pricePerLot != null);
        if (priced.length === 0) return '-';
        const total = priced.reduce((sum, r) => sum + Number(r.pricePerLot), 0);
        const avg = Math.round(total / priced.length);
        return '$' + avg.toLocaleString();
    }

    get targetGp() {
        if (!this.kpis || this.kpis.avgGpPercent == null) return '-';
        return Math.round(Number(this.kpis.avgGpPercent)) + '%';
    }
}