import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCommandCenterData from '@salesforce/apex/LovingWoCommandCenterController.getCommandCenterData';

export default class LovingWoCommandCenter extends NavigationMixin(LightningElement) {

    @track isLoading = false;
    @track errorMessage = null;
    @track _data = null;

    @wire(getCommandCenterData)
    wiredData({ data, error }) {
        if (data) {
            this._data = data;
            this.errorMessage = null;
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : 'Failed to load Work Order data.';
            this._data = null;
        }
    }

    // ── KPI ──────────────────────────────────────────────────────────────────

    get kpi() {
        if (this._data && this._data.kpi) return this._data.kpi;
        return { openWos: 0, scheduled: 0, fmReview: 0, blocked: 0 };
    }

    // ── Column card arrays ────────────────────────────────────────────────────

    get productionInstallCards() {
        return this._cards('productionInstall');
    }
    get finishJobCards() {
        return this._cards('finishJob');
    }
    get warrantyCards() {
        return this._cards('warranty');
    }
    get customerCareCards() {
        return this._cards('customerCare');
    }
    get aquaCards() {
        return this._cards('aqua');
    }
    get siteGradingCards() {
        return this._cards('siteGrading');
    }

    _cards(bucket) {
        if (!this._data || !this._data[bucket]) return [];
        return this._data[bucket].map(c => Object.assign({}, c, {
            woAmountFormatted: c.woAmount != null
                ? '$' + Number(c.woAmount).toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })
                : null
        }));
    }

    // ── Counts ────────────────────────────────────────────────────────────────

    get productionInstallCount() { return this._count('productionInstall'); }
    get finishJobCount()          { return this._count('finishJob'); }
    get warrantyCount()           { return this._count('warranty'); }
    get customerCareCount()       { return this._count('customerCare'); }
    get aquaCount()               { return this._count('aqua'); }
    get siteGradingCount()        { return this._count('siteGrading'); }

    _count(bucket) {
        return (this._data && this._data[bucket]) ? this._data[bucket].length : 0;
    }

    // ── Has-cards booleans ────────────────────────────────────────────────────

    get hasProductionInstall() { return this._count('productionInstall') > 0; }
    get hasFinishJob()          { return this._count('finishJob') > 0; }
    get hasWarranty()           { return this._count('warranty') > 0; }
    get hasCustomerCare()       { return this._count('customerCare') > 0; }
    get hasAqua()               { return this._count('aqua') > 0; }
    get hasSiteGrading()        { return this._count('siteGrading') > 0; }

    // ── Actions ───────────────────────────────────────────────────────────────

    handleOpenWo(event) {
        const woId = event.currentTarget.dataset.id;
        if (!woId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: woId, actionName: 'view' }
        });
    }
}