import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getScorecards from '@salesforce/apex/FMScorecardController.getScorecards';

export default class FmScorecardTable extends NavigationMixin(LightningElement) {

    @track scorecards = [];
    @track isLoading  = true;
    @track errorMsg   = null;

    // Month label for the card header (e.g. "April MTD")
    get monthLabel() {
        return new Date().toLocaleString('en-US', { month: 'long' }) + ' MTD';
    }

    // ── Wire ──────────────────────────────────────
    @wire(getScorecards)
    wiredScorecards({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.scorecards = data.map(r => ({
                ...r,
                qiAverageDisplay   : r.qiAverage  != null ? r.qiAverage.toFixed(1)  : '—',
                fjPercentDisplay   : r.fjPercent   != null ? r.fjPercent.toFixed(1) + '%' : '—',
                lastQiDisplay      : r.lastQiScore != null ? r.lastQiScore.toFixed(1) : '—',
                lastQiDateDisplay  : r.lastQiDate  ? this._formatDate(r.lastQiDate) : '—',
                wosDisplay         : r.wosMtd != null ? r.wosMtd : 0,
                escalDisplay       : r.openEscalations != null ? r.openEscalations : 0,
                rowCss             : 'tbl-row' + (r.rowClass ? ' ' + r.rowClass : ''),
                chipCss            : 'chip ' + (r.statusClass || 'chip-gray'),
                detailCardBg       : r.statusClass === 'chip-amber' ? '#fffbeb'
                                   : r.statusClass === 'chip-red'   ? '#fff1f2'
                                   : '#f0fdf4',
                detailBorderStyle  : r.statusClass === 'chip-amber'
                                   ? 'border-left:4px solid #b45309;'
                                   : r.statusClass === 'chip-red'
                                   ? 'border-left:4px solid #c23934;'
                                   : '',
                detailChBg         : `background:${
                                       r.statusClass === 'chip-amber' ? '#fffbeb'
                                     : r.statusClass === 'chip-red'   ? '#fff1f2'
                                     : '#f0fdf4'};`,
                avatarStyle        : `background:${r.avatarColor || '#4f46e5'};`
            }));
            this.errorMsg = null;
        } else if (error) {
            this.errorMsg = this._errorMessage(error);
        }
    }

    // ── Navigate to FM User record ─────────────────
    handleFmClick(evt) {
        const fmId = evt.currentTarget.dataset.fmid;
        if (!fmId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: fmId, actionName: 'view' }
        });
    }

    // ── Helpers ────────────────────────────────────
    _formatDate(dateStr) {
        if (!dateStr) return '—';
        const d = new Date(dateStr);
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    _errorMessage(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred loading scorecard data.';
    }
}