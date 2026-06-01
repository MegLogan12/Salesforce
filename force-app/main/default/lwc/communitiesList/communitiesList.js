import { LightningElement, api, wire } from 'lwc';
import getCommunitiesForAccount from '@salesforce/apex/ParentAccountRollupController.getCommunitiesForAccount';

// Map server stage strings to local pill classes matching mockup palette.
function stagePillCls(stage) {
    if (!stage) return 'pill pgr';
    const s = stage.toLowerCase();
    if (s.includes('closing') || s.includes('close')) return 'pill pr';
    if (s.includes('takeoff') || s.includes('activated')) return 'pill pa';
    if (s.includes('warranty')) return 'pill pp';
    if (s.includes('active') || s.includes('jobs')) return 'pill pb';
    return 'pill pgr';
}

// Service flag abbreviations shown as small green pills.
const FLAG_ABBRS = [
    { key: 'Production Landscaping', label: 'PL' },
    { key: 'Aqua Service', label: 'Aqua' },
    { key: 'Irrigation', label: 'Irr' },
    { key: 'Lawn Care', label: 'LC' }
];

export default class CommunitiesList extends LightningElement {
    @api recordId;
    rows;
    error;

    @wire(getCommunitiesForAccount, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.rows = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
        }
    }

    get hasRows() { return this.rows && this.rows.length > 0; }
    get count() { return this.rows ? this.rows.length : 0; }

    get activeCount() {
        if (!this.rows) return 0;
        return this.rows.filter(r => {
            const s = (r.stage || '').toLowerCase();
            return s.includes('active') || s.includes('jobs');
        }).length;
    }
    get closingCount() {
        if (!this.rows) return 0;
        return this.rows.filter(r => (r.stage || '').toLowerCase().includes('closing')).length;
    }

    get viewRows() {
        if (!this.rows) return [];
        return this.rows.map(r => {
            const sm = (r.serviceModel || '');
            const flags = FLAG_ABBRS.map(f => ({
                key: r.id + '-' + f.key,
                label: f.label,
                show: sm.toLowerCase().includes(f.key.toLowerCase())
                    || (f.key === 'Aqua Service' && r.aquaCustomer === true)
            })).filter(f => f.show);

            let woDisplay = (r.openWoCount != null && r.openWoCount > 0) ? String(r.openWoCount) : '-';
            let woCls = 'wo-count';
            if (r.openWoCount != null && r.openWoCount > 0) {
                woCls = 'wo-count has-wo';
                const st = (r.stage || '').toLowerCase();
                if (st.includes('closing')) woCls += ' wo-amber';
            }

            const progressPct = r.progressPercent || 0;
            const lotsDisplay = (r.lotsComplete != null && r.totalLots != null)
                ? `${r.lotsComplete}/${r.totalLots}`
                : '-';

            return {
                id: r.id,
                name: r.name,
                recordUrl: r.recordUrl,
                territory: r.territory || '',
                totalLots: r.totalLots,
                subLine: (r.territory ? r.territory + ' \u00B7 ' : '') + (r.totalLots != null ? r.totalLots + ' lots' : ''),
                stage: r.stage || '',
                stageClass: r.stage ? stagePillCls(r.stage) : '',
                fmName: r.fmName || '',
                progressPct,
                progressStyle: `width: ${progressPct}%`,
                lotsDisplay,
                woDisplay,
                woCls,
                flags,
                hasFlags: flags.length > 0,
                activatedDisplay: ''
            };
        });
    }
}