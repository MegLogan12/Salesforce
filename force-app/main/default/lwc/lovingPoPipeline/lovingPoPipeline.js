import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPipelineData from '@salesforce/apex/LovingPoPipelineController.getPipelineData';
import updatePoStatus from '@salesforce/apex/LovingPoPipelineController.updatePoStatus';
import createOrGetTakeoff from '@salesforce/apex/LovingPoPipelineController.createOrGetTakeoff';

const BOARD_STAGES = [
    { key: 'received',         label: 'PO Received',          num: 1, rule: 'PO landed in Salesforce and is ready for package review.',             cls: ''         },
    { key: 'packageCheck',     label: 'Package Match Check',  num: 2, rule: 'Compare PO work lines to the package source of truth.',                cls: 'warn'     },
    { key: 'csmReview',        label: 'CSM Review',           num: 3, rule: 'Mismatch or missing data requires Customer Success review.',          cls: 'warn'     },
    { key: 'takeoffRequested', label: 'Takeoff Requested',   num: 4, rule: 'Package matched or exception approved; create the FM takeoff.',       cls: 'forecast' },
    { key: 'takeoffScheduled', label: 'Takeoff Scheduled',   num: 5, rule: 'Field Manager takeoff appointment is on the calendar.',               cls: 'forecast' },
    { key: 'takeoffProgress',  label: 'Takeoff In Progress', num: 6, rule: 'Field Manager is measuring and confirming scope.',                     cls: 'forecast' },
    { key: 'takeoffComplete',  label: 'Takeoff Complete',    num: 7, rule: 'Takeoff is complete and ready for standard WorkOrder creation.',       cls: 'clear'    },
    { key: 'workOrderCreated', label: 'WorkOrder Created',   num: 8, rule: 'Standard WorkOrder has been created and linked back to the PO.',      cls: 'schedule' },
    { key: 'clear',            label: 'Clear for Schedule',  num: 9, rule: 'WorkOrders are clean enough for Scheduling to begin.',                cls: 'clear'    }
];

const FILTER_OPTIONS = [
    { value: 'all',        label: 'All' },
    { value: 'validate',   label: 'Needs Review' },
    { value: 'forecast',   label: 'Takeoff Queue' },
    { value: 'scheduling', label: 'WorkOrder Queue' },
    { value: 'clear',      label: 'Clear for Schedule' }
];

const STATUS_OPTIONS = [
    { value: 'Pending Takeoff',      label: 'PO Received' },
    { value: 'Package Match Check',  label: 'Package Match Check' },
    { value: 'Pending CS Review',    label: 'CSM Review' },
    { value: 'Ready for Takeoff',    label: 'Takeoff Requested' },
    { value: 'Takeoff Scheduled',    label: 'Takeoff Scheduled' },
    { value: 'Takeoff In Progress',  label: 'Takeoff In Progress' },
    { value: 'Takeoff Complete',     label: 'Takeoff Complete' },
    { value: 'Work Order Created',   label: 'WorkOrder Created' },
    { value: 'Clear for Schedule',   label: 'Clear for Schedule' },
    { value: 'Closed',               label: 'Closed / Converted' },
    { value: 'Cancelled',            label: 'Cancelled / Void' },
    { value: 'Exception',            label: 'Exception (Legacy)' },
    { value: 'NFI',                  label: 'NFI (Legacy)' }
];

function mapToBoardColumn(pipelineStage, status, bucket) {
    if (pipelineStage === 'Validate') return 'csmReview';
    if (pipelineStage === 'Forecast') return 'takeoffRequested';
    if (pipelineStage === 'Scheduling') return 'workOrderCreated';
    if (pipelineStage === 'Clear') return 'clear';

    if (pipelineStage === 'PO Received') return 'received';
    if (pipelineStage === 'Package Match Check') return 'packageCheck';
    if (pipelineStage === 'CSM Review') return 'csmReview';
    if (pipelineStage === 'Takeoff Requested') return 'takeoffRequested';
    if (pipelineStage === 'Takeoff Scheduled') return 'takeoffScheduled';
    if (pipelineStage === 'Takeoff In Progress') return 'takeoffProgress';
    if (pipelineStage === 'Takeoff Complete') return 'takeoffComplete';
    if (pipelineStage === 'WorkOrder Created') return 'workOrderCreated';
    if (pipelineStage === 'Clear for Schedule') return 'clear';
    if (pipelineStage === 'Closed / Converted') return 'closed';
    if (pipelineStage === 'Cancelled / Void') return 'cancelled';

    if (status === 'Clear for Schedule') return 'clear';
    if (status === 'Work Order Created') return 'workOrderCreated';
    if (status === 'Takeoff Complete') return 'takeoffComplete';
    if (status === 'Takeoff In Progress') return 'takeoffProgress';
    if (status === 'Takeoff Scheduled') return 'takeoffScheduled';
    if (status === 'Ready for Takeoff') return 'takeoffRequested';
    if (status === 'Pending CS Review' || status === 'Exception' || status === 'NFI') return 'csmReview';
    if (status === 'Package Match Check') return 'packageCheck';
    if (status === 'Closed') return 'closed';
    if (status === 'Cancelled') return 'cancelled';
    return 'received';
}

export default class LovingPoPipeline extends NavigationMixin(LightningElement) {

    @track isLoading      = false;
    @track rawRecords     = [];
    @track builderNames   = [];
    @track kpiAll         = 0;
    @track kpiValidate    = 0;
    @track kpiForecast    = 0;
    @track kpiClear       = 0;
    @track kpiSched       = 0;
    @track kpiValue       = '$0';

    @track activeFilter   = 'all';
    @track builderFilter  = '';
    @track searchTerm     = '';

    @track showDetail     = false;
    @track selectedPo     = null;

    @track showModal      = false;
    @track modalNewStatus = '';
    @track modalError     = null;
    @track isSaving       = false;

    @track actionResult   = null;

    connectedCallback() {
        this.loadPipeline();
    }

    loadPipeline() {
        this.isLoading = true;
        getPipelineData()
            .then(result => {
                this.kpiAll      = result.openCount      || 0;
                this.kpiValidate = result.reviewCount    || 0;
                this.kpiForecast = result.forecastCount  || 0;
                this.kpiClear    = result.clearCount     || 0;
                this.kpiSched    = result.workOrderCount || 0;
                this.kpiValue    = this.formatCurrency(result.openPOValue || 0);
                this.builderNames = result.builderNames  || [];
                this.rawRecords   = (result.records || []).map(po => this.enrichPo(po));
                if (result.debugMessage) {
                    console.error('Pipeline debug:', result.debugMessage);
                }
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Unable to load PO pipeline',
                    message: err.body ? err.body.message : err.message,
                    variant: 'error'
                }));
            })
            .finally(() => { this.isLoading = false; });
    }

    enrichPo(po) {
        const col = po.boardColumn || mapToBoardColumn(po.pipelineStage, po.status, po.pipelineBucket);
        return {
            ...po,
            boardColumn:     col,
            cardClass:       'po-card',
            amountFormatted: this.formatCurrency(po.totalAmount || 0),
            statusChipClass: col === 'packageCheck' || col === 'csmReview' ? 'chip amber'  :
                             col === 'workOrderCreated' ? 'chip purple'  :
                             col === 'clear'      ? 'chip green'   :
                             col === 'takeoffRequested' || col === 'takeoffScheduled' || col === 'takeoffProgress' || col === 'takeoffComplete' ? 'chip blue' :
                             col === 'received'   ? 'chip gray'    : 'chip aqua',
            statusLabel:     po.status || 'New'
        };
    }

    _stage(key) {
        const recs = this.filteredRecords
            .filter(r => r.boardColumn === key)
            .map(r => ({ ...r, cardClass: this.selectedPo && this.selectedPo.id === r.id ? 'po-card on' : 'po-card' }));
        return { records: recs, count: recs.length, hasRecords: recs.length > 0 };
    }

    get st1() { return this._stage('received'); }
    get st2() { return this._stage('packageCheck'); }
    get st3() { return this._stage('csmReview'); }
    get st4() { return this._stage('takeoffRequested'); }
    get st5() { return this._stage('takeoffScheduled'); }
    get st6() { return this._stage('takeoffProgress'); }
    get st7() { return this._stage('takeoffComplete'); }
    get st8() { return this._stage('workOrderCreated'); }
    get st9() { return this._stage('clear'); }

    get stageColumns() {
        return BOARD_STAGES.map(stage => {
            const column = this._stage(stage.key);
            return {
                ...stage,
                ...column,
                cssClass: ('stage board-stage ' + (stage.cls || '')).trim()
            };
        });
    }

    get filteredRecords() {
        let recs = this.rawRecords;
        if (this.builderFilter) recs = recs.filter(r => r.builderName === this.builderFilter);
        if (this.searchTerm) {
            const q = this.searchTerm.toLowerCase();
            recs = recs.filter(r =>
                (r.name          || '').toLowerCase().includes(q) ||
                (r.builderName   || '').toLowerCase().includes(q) ||
                (r.communityName || '').toLowerCase().includes(q) ||
                (r.itemName      || '').toLowerCase().includes(q)
            );
        }
        const f = this.activeFilter;
        if (f === 'validate') {
            recs = recs.filter(r => ['packageCheck', 'csmReview'].includes(r.boardColumn));
        }
        if (f === 'forecast') {
            recs = recs.filter(r => ['takeoffRequested', 'takeoffScheduled', 'takeoffProgress', 'takeoffComplete'].includes(r.boardColumn));
        }
        if (f === 'scheduling') {
            recs = recs.filter(r => r.boardColumn === 'workOrderCreated');
        }
        if (f === 'clear') {
            recs = recs.filter(r => r.boardColumn === 'clear');
        }
        return recs;
    }

    get filterOptions() {
        return FILTER_OPTIONS.map(f => ({
            ...f,
            cssClass: f.value === this.activeFilter ? 'filter on' : 'filter'
        }));
    }

    get statusOptions()  { return STATUS_OPTIONS; }

    get noPoSelected()         { return !this.selectedPo; }
    get detailTitle()          { return this.selectedPo ? this.selectedPo.name + ' · ' + (this.selectedPo.statusLabel || '') : ''; }

    get primaryActionLabel() {
        if (!this.selectedPo) return 'Move Status';
        const col = this.selectedPo.boardColumn;
        if (col === 'received' || col === 'packageCheck' || col === 'csmReview') return 'Move Status';
        if (col === 'takeoffRequested' || col === 'takeoffScheduled' || col === 'takeoffProgress' || col === 'takeoffComplete') return 'Open Takeoff';
        if (col === 'workOrderCreated' || col === 'clear') return 'Open Record';
        if (col === 'scheduling')                return 'View Work Order';
        return 'Move Status';
    }

    get primaryActionClass() {
        const col = this.selectedPo ? this.selectedPo.boardColumn : '';
        return (col === 'clear' || col === 'scheduling') ? 'btn success' : 'btn primary';
    }

    get saveLabel()             { return this.isSaving ? 'Saving...' : 'Move PO'; }
    get validationBannerClass() { return this.actionResult ? (this.actionResult.passed ? 'notice green' : 'notice red') : ''; }
    get validationIcon()        { return this.actionResult ? (this.actionResult.passed ? '✓' : '⚠') : ''; }

    get validationChecklist() {
        if (!this.selectedPo) return [];
        const po = this.selectedPo;
        return [
            { label: 'Builder assigned',       ok: !!po.builderName,       value: po.builderName       || 'Not set' },
            { label: 'Community set',           ok: !!po.communityName,     value: po.communityName     || 'Not set' },
            { label: 'Division assigned',       ok: !!po.divisionName,      value: po.divisionName      || 'Not set' },
            { label: 'Estimated Start Date',    ok: !!po.estimatedStartDate, value: po.estimatedStartDate || 'Required to advance' },
            { label: 'Amount set',              ok: !!po.totalAmount,       value: po.amountFormatted },
            { label: 'Item specified',          ok: !!po.itemName,          value: po.itemName           || 'Not set' },
            { label: 'Work Order linked',       ok: !!po.workOrderId,       value: po.workOrderId        ? 'Linked' : 'Not linked' }
        ].map((item, idx) => ({
            ...item,
            icon:      item.ok ? '✓' : (idx + 1),
            flowClass: item.ok ? 'flow done' : 'flow active'
        }));
    }

    get stageFlows() {
        if (!this.selectedPo) return [];
        const currentIdx = BOARD_STAGES.findIndex(s => s.key === this.selectedPo.boardColumn);
        return BOARD_STAGES.map((s, idx) => ({
            label:     s.label,
            rule:      s.rule,
            icon:      idx < currentIdx ? '✓' : (idx + 1),
            flowClass: idx < currentIdx ? 'flow done' : (idx === currentIdx ? 'flow active' : 'flow')
        }));
    }

    handleFilterClick(evt)   { this.activeFilter  = evt.currentTarget.dataset.value; }
    handleBuilderChange(evt) { this.builderFilter  = evt.target.value; }
    handleSearchInput(evt)   { this.searchTerm     = evt.target.value; }

    handlePoSelect(evt) {
        const id = evt.currentTarget.dataset.id;
        const po = this.rawRecords.find(r => r.id === id);
        if (po) {
            this.selectedPo   = { ...po };
            this.actionResult = null;
            this.showDetail   = true;
        }
    }

    handleNewPo() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Purchase_Order__c', actionName: 'new' }
        });
    }

    handleBackToBoard()  { this.showDetail = false; }

    handleOpenRecord() {
        if (!this.selectedPo) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.selectedPo.id, actionName: 'view' }
        });
    }

    handlePrimaryAction() {
        if (!this.selectedPo) return;
        const col = this.selectedPo.boardColumn;
        if (col === 'received' || col === 'packageCheck' || col === 'csmReview') {
            this.handleOpenModal();
        } else if (col === 'takeoffRequested' || col === 'takeoffScheduled' || col === 'takeoffProgress' || col === 'takeoffComplete') {
            this.handleOpenTakeoff();
        } else {
            this.handleOpenRecord();
        }
    }

    handleOpenModal() {
        if (!this.selectedPo) return;
        this.modalNewStatus = '';
        this.modalError     = null;
        this.showModal      = true;
    }

    handleCloseModal()            { this.showModal = false; this.modalError = null; }
    handleModalBackdropClick(evt) { if (evt.target === evt.currentTarget) this.handleCloseModal(); }
    handleModalClick(evt)         { evt.stopPropagation(); }
    handleStatusChange(evt)       { this.modalNewStatus = evt.target.value; }

    handleSaveValidation() {
        if (!this.selectedPo || !this.modalNewStatus) {
            this.modalError = 'Please select a status to move this PO to.';
            return;
        }
        this.isSaving   = true;
        this.modalError = null;
        updatePoStatus({ poId: this.selectedPo.id, newStatus: this.modalNewStatus })
            .then(result => {
                this.actionResult = { passed: result.passed, message: result.message };
                if (result.passed) {
                    this.showModal = false;
                    this.dispatchEvent(new ShowToastEvent({ title: result.message, variant: 'success' }));
                    this.loadPipeline();
                } else {
                    this.modalError = result.message;
                }
            })
            .catch(err => { this.modalError = 'Save failed: ' + (err.body ? err.body.message : err.message); })
            .finally(() => { this.isSaving = false; });
    }

    handleOpenTakeoff() {
        if (!this.selectedPo) return;
        this.isLoading = true;
        createOrGetTakeoff({ poId: this.selectedPo.id })
            .then(takeoffId => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: takeoffId, actionName: 'view' }
                });
            })
            .catch(err => { this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body ? err.body.message : err.message, variant: 'error' })); })
            .finally(() => { this.isLoading = false; });
    }

    formatCurrency(val) {
        const n = Number(val);
        if (isNaN(n) || n === 0) return '$0';
        if (n >= 1000000) return '$' + (n / 1000000).toFixed(1) + 'M';
        if (n >= 1000)    return '$' + (n / 1000).toFixed(1) + 'k';
        return '$' + n.toFixed(0);
    }
}