import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

// import getFinishedJobData  from '@salesforce/apex/LovingFinishedJobController.getFinishedJobData';
// import getScopeData        from '@salesforce/apex/LovingFinishedJobController.getScopeData';
// import getCloseoutData     from '@salesforce/apex/LovingFinishedJobController.getCloseoutData';
// import getQiData           from '@salesforce/apex/LovingFinishedJobController.getQiData';
// import getPhotos           from '@salesforce/apex/LovingFinishedJobController.getPhotos';
// import getActivity         from '@salesforce/apex/LovingFinishedJobController.getActivity';
// import approveCloseout     from '@salesforce/apex/LovingFinishedJobController.approveCloseout';

/**
 * lovingFinishedJobPage
 * Record page for Work_Order__c (RecordType = Finish_Job).
 * Data sources: Work_Order__c, Lot__c, Community__c.
 * Real record-driven finish job workspace.
 */
export default class LovingFinishedJobPage extends NavigationMixin(LightningElement) {

    /** Record ID injected by Lightning record page context */
    @api recordId;

    // ── Tab state ──────────────────────────────────────────────────────────────
    @track activeTab = 'overview';
    @track isLoading = false;
    @track errorMsg  = '';

    // ── Raw wire data ──────────────────────────────────────────────────────────
    @track _woData       = null;
    @track _scopeData    = [];
    @track _closeoutData = null;
    @track _qiData       = null;
    @track _photoData    = [];
    @track _activityData = [];

    // Wire result refs for refreshApex
    _woWire;
    _scopeWire;
    _closeoutWire;
    _qiWire;
    _photoWire;
    _activityWire;

    // ── Tab definitions ────────────────────────────────────────────────────────
    get tabs() {
        return [
            { id: 'overview',   label: 'Overview',       cls: this._tcls('overview'),   badge: null },
            { id: 'scope',      label: 'Scope',          cls: this._tcls('scope'),      badge: null },
            { id: 'closeout',   label: 'Closeout',       cls: this._tcls('closeout'),   badge: null },
            { id: 'qi',         label: 'QI Inspection',  cls: this._tcls('qi'),         badge: null },
            { id: 'photos',     label: 'Photos',         cls: this._tcls('photos'),     badge: null },
            { id: 'activity',   label: 'Activity',       cls: this._tcls('activity'),   badge: null }
        ];
    }

    _tcls(id) {
        return 'sf-tab' + (this.activeTab === id ? ' on' : '');
    }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.id;
    }

    // ── Tab panel visibility ───────────────────────────────────────────────────
    get tab1cls() { return 'tc' + (this.activeTab === 'overview'  ? ' on' : ''); }
    get tab2cls() { return 'tc' + (this.activeTab === 'scope'     ? ' on' : ''); }
    get tab3cls() { return 'tc' + (this.activeTab === 'closeout'  ? ' on' : ''); }
    get tab4cls() { return 'tc' + (this.activeTab === 'qi'        ? ' on' : ''); }
    get tab5cls() { return 'tc' + (this.activeTab === 'photos'    ? ' on' : ''); }
    get tab6cls() { return 'tc' + (this.activeTab === 'activity'  ? ' on' : ''); }

    // ── Record header values (sourced from Work_Order__c via wire) ─────────────
    get breadcrumb()       { return this._woData ? this._woData.communityName + ' · ' + this._woData.lotName : 'Finish Job'; }
    get woTitle()          { return this._woData ? this._woData.workOrderName : '—'; }
    get woSubtitle()       { return this._woData ? this._woData.subtitle : 'Loading work order…'; }
    get scopeSubtitle()    { return this._woData ? this._woData.scopeSubtitle : ''; }
    get closeoutSubtitle() { return this._woData ? this._woData.closeoutSubtitle : ''; }
    get qiSubtitle()       { return this._woData ? this._woData.qiSubtitle : ''; }
    get photosSubtitle()   { return this._woData ? this._woData.photosSubtitle : ''; }

    // ── Empty / error states ───────────────────────────────────────────────────
    get emptyStateMessage() { return this._woData ? this._woData.emptyStateMessage : '0 records available in this section.'; }
    get hasWoData()         { return this._woData != null; }
    get hasScopeData()      { return this._scopeData && this._scopeData.length > 0; }
    get hasCloseoutData()   { return this._closeoutData != null; }
    get hasQiData()         { return this._qiData != null; }
    get hasPhotoData()      { return this._photoData && this._photoData.length > 0; }
    get hasActivityData()   { return this._activityData && this._activityData.length > 0; }

    // ── Actions ────────────────────────────────────────────────────────────────
    handleEdit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: 'Work_Order__c', actionName: 'edit' }
        });
    }
}