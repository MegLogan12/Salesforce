import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPipelineData from '@salesforce/apex/LovingPoPipelineController.getPipelineData';
import getPoDetail from '@salesforce/apex/LovingPoPipelineController.getPoDetail';
import getBuilderPoDetail from '@salesforce/apex/LovingPoPipelineController.getBuilderPoDetail';
import getTakeoffDetail from '@salesforce/apex/LovingPoPipelineController.getTakeoffDetail';
import getBuilderPoStatusOptions from '@salesforce/apex/LovingPoPipelineController.getBuilderPoStatusOptions';
import updatePoStatus from '@salesforce/apex/LovingPoPipelineController.updatePoStatus';
import createOrGetTakeoff from '@salesforce/apex/LovingPoPipelineController.createOrGetTakeoff';
import assignTakeoffFieldManager from '@salesforce/apex/LovingPoPipelineController.assignTakeoffFieldManager';
import createProductionWorkOrder from '@salesforce/apex/LovingPoPipelineController.createProductionWorkOrder';
import createScheduleHandoff from '@salesforce/apex/LovingPoPipelineController.createScheduleHandoff';
import updateTakeoffReadiness from '@salesforce/apex/LovingPoPipelineController.updateTakeoffReadiness';
import approveTakeoff from '@salesforce/apex/LovingTakeoffGateController.approveTakeoff';

const PIPELINE_VIEWS = [
    { id: 'pipeline', label: 'Builder PO Queue' },
    { id: 'poDetail', label: 'PO Detail' },
    { id: 'takeoff', label: 'Takeoff Workspace' },
    { id: 'activity', label: 'Activity' },
    { id: 'workorders', label: 'Execution' }
];

const RECORD_VIEWS = [
    { id: 'poDetail', label: 'PO Detail' },
    { id: 'takeoff', label: 'Takeoff Workspace' },
    { id: 'activity', label: 'Activity' },
    { id: 'workorders', label: 'Execution' }
];

const STAGE_FILTERS = [
    { id: 'all', label: 'All Open POs' },
    { id: 'received', label: 'PO Received' },
    { id: 'packageCheck', label: 'Package Match Check' },
    { id: 'csmReview', label: 'CSM Review' },
    { id: 'takeoffRequested', label: 'Takeoff Requested' },
    { id: 'takeoffScheduled', label: 'Takeoff Scheduled' },
    { id: 'takeoffProgress', label: 'Takeoff In Progress' },
    { id: 'takeoffComplete', label: 'Takeoff Complete' },
    { id: 'workOrderCreated', label: 'WorkOrder Created' },
    { id: 'clear', label: 'Clear for Schedule' }
];

export default class LovingPoPipelineBoard extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    @track isLoading = false;
    @track rawRecords = [];
    @track builderNames = [];
    @track poStatusOptions = [];
    @track kpiAll = 0;
    @track kpiValidate = 0;
    @track kpiForecast = 0;
    @track kpiClear = 0;
    @track kpiSched = 0;
    @track kpiValue = '$0';

    @track activeFilter = 'all';
    @track builderFilter = '';
    @track searchTerm = '';
    @track currentView = 'pipeline';
    @track detailData = null;

    @track selectedFieldManagerId = '';
    @track selectedTakeoffDate = '';
    @track takeoffChecklistComplete = false;
    @track takeoffEight11Confirmed = false;
    @track takeoffPhotoCount = 0;

    @track showModal = false;
    @track modalNewStatus = '';
    @track modalError = null;
    @track isSaving = false;
    @track actionResult = null;

    connectedCallback() {
        this.loadStatusOptions();
        if (this.isBuilderPoRecordContext) {
            this.loadBuilderPoDetail(this.recordId);
            return;
        }
        if (this.isTakeoffRecordContext) {
            this.loadTakeoffDetail(this.recordId);
            return;
        }
        if (this.isPurchaseOrderRecordContext) {
            this.loadPoDetail(this.recordId);
            return;
        }
        this.loadPipeline();
    }

    get isBuilderPoRecordContext() {
        return this.objectApiName === 'Builder_PO__c' && !!this.recordId;
    }

    get isPurchaseOrderRecordContext() {
        return this.objectApiName === 'Purchase_Order__c' && !!this.recordId;
    }

    get isTakeoffRecordContext() {
        return this.objectApiName === 'Takeoff__c' && !!this.recordId;
    }

    get isRecordContext() {
        return this.isBuilderPoRecordContext || this.isPurchaseOrderRecordContext || this.isTakeoffRecordContext;
    }

    get recordBannerTitle() {
        if (!this.isRecordContext) {
            return 'Builder PO Queue';
        }
        if (this.isTakeoffView) {
            return this.selectedTakeoff?.name || 'Takeoff';
        }
        if (this.isWoDetailView || this.isWorkOrdersView) {
            return this.selectedWorkOrder?.workOrderNumber || 'Work Order';
        }
        return this.isBuilderPoRecordContext
            ? (this.selectedPo?.name || 'Builder PO')
            : (this.selectedPo?.name || 'Purchase Order');
    }

    get recordBannerSub() {
        if (this.isTakeoffView) {
            return 'FM checklist, package review, routing summary, and execution-child creation surface.';
        }
        if (this.isWoDetailView || this.isWorkOrdersView) {
            return 'Parent work order, sub work orders, execution routing, and scheduling handoff surface.';
        }
        if (this.isBuilderPoRecordContext && this.selectedPo) {
            return 'Home Builder PO command surface with package truth, takeoff state, review flags, and standard WorkOrder bridge.';
        }
        if (this.isTakeoffRecordContext && this.selectedTakeoff) {
            return 'FM checklist, package review, routing summary, and execution-child creation surface.';
        }
        if (this.isPurchaseOrderRecordContext && this.selectedPo) {
            return 'Purchase order command surface with package truth, takeoff state, review flags, and standard WorkOrder bridge.';
        }
        if (this.isRecordContext && this.selectedPo) {
            return `${this.selectedPo.communityName || '—'} · ${this.selectedPo.lotName || '—'} · ${this.selectedPo.status || '—'}`;
        }
        if (this.isRecordContext) {
            return '';
        }
        return `${this.kpiAll || 0} open builder POs · ${this.kpiClear || 0} clear for schedule · ${this.kpiValue || '$0'} total value`;
    }

    get recordEyebrow() {
        if (this.isTakeoffView) {
            return 'Takeoff';
        }
        if (this.isWoDetailView || this.isWorkOrdersView) {
            return 'Work Order';
        }
        if (this.isBuilderPoRecordContext) {
            return 'Builder PO';
        }
        if (this.isTakeoffRecordContext) {
            return 'Takeoff';
        }
        if (this.isPurchaseOrderRecordContext) {
            return 'Purchase Order';
        }
        return 'Builder PO Queue';
    }

    get recordIconLabel() {
        if (this.isTakeoffView) {
            return 'TK';
        }
        if (this.isWoDetailView || this.isWorkOrdersView) {
            return 'WO';
        }
        return 'PO';
    }

    get detailViewLabel() {
        if (this.isTakeoffView) {
            return 'Takeoff Control Center';
        }
        if (this.isWoDetailView || this.isWorkOrdersView) {
            return 'Work Order Command';
        }
        if (this.isTakeoffRecordContext) {
            return 'Takeoff Control Center';
        }
        return this.isPurchaseOrderRecordContext ? 'Purchase Order Detail' : 'Builder PO Detail';
    }

    get builderAppLabel() {
        return 'Home Builder Operations';
    }

    get builderSearchPlaceholder() {
        if (this.isTakeoffView) {
            return 'Search takeoffs, FM checklist, routing summary, review state, and execution children...';
        }
        if (this.isWoDetailView || this.isWorkOrdersView) {
            return 'Search work orders, sub work orders, field routing, schedules, and execution holds...';
        }
        return 'Search builder POs, purchase orders, takeoff status, package match, and review holds...';
    }

    get userInitials() {
        return 'ML';
    }

    get recordButtonLabel() {
        if (this.isTakeoffView) {
            return 'Open Takeoff';
        }
        return this.isPurchaseOrderRecordContext ? 'Open Purchase Order' : 'Open Builder PO';
    }

    get recordPrimaryActionLabel() {
        if (this.isTakeoffView) {
            return this.hasWorkOrder ? 'Open Work Order' : 'Create / Sync Children';
        }
        if (this.hasTakeoff) {
            return 'Open Takeoff';
        }
        return 'Open Takeoff';
    }

    async loadPipeline() {
        this.isLoading = true;
        try {
            const result = await getPipelineData();
            this.kpiAll = result.openCount || 0;
            this.kpiValidate = result.reviewCount || 0;
            this.kpiForecast = result.forecastCount || 0;
            this.kpiClear = result.clearCount || 0;
            this.kpiSched = result.workOrderCount || 0;
            this.kpiValue = this.formatCurrency(result.openPOValue || 0);
            this.builderNames = result.builderNames || [];
            this.rawRecords = (result.records || []).map((po) => this.enrichPo(po));
        } catch (err) {
            this.toast('Unable to load PO pipeline', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadStatusOptions() {
        try {
            this.poStatusOptions = await getBuilderPoStatusOptions();
        } catch (err) {
            this.poStatusOptions = [];
            this.toast('Unable to load Builder PO statuses', this.errorMessage(err), 'error');
        }
    }

    async loadBuilderPoDetail(builderPoId, targetView = 'poDetail') {
        if (!builderPoId) return;
        this.isLoading = true;
        try {
            this.detailData = await getBuilderPoDetail({ builderPoId });
            this.currentView = targetView;
            this.initializeDetailState();
            this.actionResult = null;
        } catch (err) {
            this.currentView = targetView;
            this.detailData = null;
            this.actionResult = { passed: false, message: this.errorMessage(err) };
            this.toast('Unable to load Builder PO workspace', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadPoDetail(poId, targetView = 'poDetail') {
        if (!poId) return;
        this.isLoading = true;
        try {
            this.detailData = await getPoDetail({ poId });
            this.currentView = targetView;
            this.initializeDetailState();
            this.actionResult = null;
        } catch (err) {
            this.toast('Unable to load PO detail', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadTakeoffDetail(takeoffId, targetView = 'takeoff') {
        if (!takeoffId) return;
        this.isLoading = true;
        try {
            this.detailData = await getTakeoffDetail({ takeoffId });
            this.currentView = targetView;
            this.initializeDetailState();
            this.actionResult = null;
        } catch (err) {
            this.currentView = targetView;
            this.detailData = null;
            this.actionResult = { passed: false, message: this.errorMessage(err) };
            this.toast('Unable to load Takeoff workspace', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    initializeDetailState() {
        this.selectedFieldManagerId = this.detailData?.takeoff?.fieldManagerId || '';
        this.selectedTakeoffDate = this.detailData?.takeoff?.scheduledDate || '';
        this.takeoffChecklistComplete = this.detailData?.takeoff?.checklistComplete === true;
        this.takeoffEight11Confirmed = this.detailData?.takeoff?.eight11Confirmed === true;
        this.takeoffPhotoCount = this.detailData?.takeoff?.photoCount || 0;
    }

    async refreshCurrentDetail(targetView = null) {
        if (this.isTakeoffRecordContext) {
            await Promise.all([this.loadPipeline(), this.loadTakeoffDetail(this.recordId, targetView || this.currentView)]);
            return;
        }
        if (!this.selectedPoId) {
            await this.loadPipeline();
            return;
        }
        await Promise.all([this.loadPipeline(), this.loadPoDetail(this.selectedPoId, targetView || this.currentView)]);
    }

    enrichPo(po) {
        const col = po.boardColumn || '';
        return {
            ...po,
            boardColumn: col,
            cardClass: 'po-card',
            amountFormatted: this.formatCurrency(po.totalAmount || 0),
            statusChipClass: col === 'packageCheck' || col === 'csmReview' ? 'chip amber'
                : col === 'workOrderCreated' ? 'chip purple'
                    : col === 'clear' ? 'chip green'
                        : col === 'takeoffRequested' || col === 'takeoffScheduled' || col === 'takeoffProgress' || col === 'takeoffComplete' ? 'chip blue'
                            : col === 'received' ? 'chip gray' : 'chip aqua',
            statusLabel: this.displayPoStatus(po.status) || 'New',
            communityLabel: po.communityName || '—',
            lotLabel: po.lotName || '—'
        };
    }

    get selectedPoId() {
        return this.detailData?.po?.id || null;
    }

    get selectedPo() {
        return this.detailData?.po || null;
    }

    get selectedPoStatusLabel() {
        return this.selectedPo?.status || '—';
    }

    get selectedPoAmountFormatted() {
        return this.selectedPo ? this.formatCurrency(this.selectedPo.totalAmount || 0) : '$0';
    }

    get selectedPurchaseOrderLabel() {
        return this.selectedPo?.purchaseOrderName || this.selectedPo?.name || '—';
    }

    get recordPrimaryRoute() {
        const route = this.normalizedPoLines.find((line) => line.executionScope && line.executionScope !== '—');
        return route?.executionScope || this.selectedWorkOrderType || 'Install';
    }

    get reviewHoldCount() {
        return this.normalizedTakeoffLines.filter((line) => this.isHoldValue(line.review)).length;
    }

    get blankScopeCount() {
        return this.normalizedTakeoffLines.filter((line) => !line.executionScope || line.executionScope === '—').length;
    }

    get takeoffLineCount() {
        return this.normalizedTakeoffLines.length;
    }

    get takeoffRoutedCount() {
        return this.normalizedTakeoffLines.filter((line) => line.routingResult && !this.isHoldValue(line.routingResult)).length;
    }

    get takeoffInstallCount() {
        return this.normalizedTakeoffLines.filter((line) => String(line.executionScope || '').toLowerCase().includes('install')).length;
    }

    get takeoffAquaCount() {
        return this.normalizedTakeoffLines.filter((line) => String(line.executionScope || '').toLowerCase().includes('aqua')).length;
    }

    get customerSuccessReview() {
        return this.reviewHoldCount > 0 ? 'Yes' : 'No';
    }

    get returnRequiredLabel() {
        return this.hasServiceAppointment ? 'No' : 'No';
    }

    get packageVarianceLabel() {
        return this.reviewHoldCount > 0 ? 'Yes' : 'No';
    }

    get builderQuestionLabel() {
        return this.reviewHoldCount > 0 ? `${this.reviewHoldCount} item${this.reviewHoldCount === 1 ? '' : 's'}` : 'None';
    }

    get selectedTakeoff() {
        return this.detailData?.takeoff || null;
    }

    get selectedWorkOrder() {
        return this.detailData?.workOrder || null;
    }

    get selectedWorkOrderNumber() {
        return this.selectedWorkOrder?.workOrderNumber || '—';
    }

    get selectedWorkOrderStatus() {
        return this.selectedWorkOrder?.status || '—';
    }

    get selectedWorkOrderType() {
        return this.selectedWorkOrder?.workType || '—';
    }

    get selectedWorkOrderLineItemCount() {
        return this.selectedWorkOrder?.lineItemCount ?? 0;
    }

    get selectedChildWorkOrderCount() {
        return this.selectedWorkOrder?.childWorkOrderCount ?? 0;
    }

    get selectedChildAppointmentCount() {
        return this.selectedWorkOrder?.childAppointmentCount ?? 0;
    }

    get selectedChildTypeSummary() {
        return this.selectedWorkOrder?.childTypeSummary || '—';
    }

    get selectedServiceAppointment() {
        return this.detailData?.serviceAppointment || null;
    }

    get hasServiceAppointment() {
        return Boolean(this.selectedServiceAppointment?.id);
    }

    get normalizedPoLines() {
        return (this.detailData?.poLines || []).map((line) => ({
            ...line,
            executionScope: line.workType || '—',
            routingResult: this.deriveRoutingResult(line.workType, line.packageMatch, line.matchNotes)
        }));
    }

    get normalizedTakeoffLines() {
        return (this.selectedTakeoff?.lines || []).map((line) => ({
            ...line,
            executionScope: this.deriveExecutionScope(line),
            routingResult: this.deriveTakeoffRoutingResult(line),
            review: line.reviewStatus || 'Clear'
        }));
    }

    get takeoffChecklistRows() {
        return [
            {
                label: 'Site access verified',
                status: this.takeoffChecklistComplete ? 'Yes' : 'No',
                notes: this.takeoffChecklistComplete ? 'Checklist marked complete' : 'Still needs field confirmation'
            },
            {
                label: 'Lot ready for scope review',
                status: this.selectedTakeoff?.status === 'In Progress' || this.selectedTakeoff?.status === 'Approved' ? 'Yes' : 'No',
                notes: valueOrDefault(this.selectedTakeoff?.status, 'Draft')
            },
            {
                label: 'Required photos attached',
                status: this.takeoffPhotoCount > 0 ? 'Yes' : 'No',
                notes: `${this.takeoffPhotoCount || 0} images`
            },
            {
                label: 'Variance or substitution present',
                status: this.reviewHoldCount > 0 ? 'Yes' : 'No',
                notes: this.reviewHoldCount > 0 ? `${this.reviewHoldCount} line review${this.reviewHoldCount === 1 ? '' : 's'}` : 'None'
            },
            {
                label: 'Customer success review required',
                status: this.reviewHoldCount > 0 || this.packageVarianceLabel === 'Yes' ? 'Yes' : 'No',
                notes: this.reviewHoldCount > 0 ? 'Package mismatch or substitution present' : 'Clear'
            }
        ];
    }

    get customerSuccessReviewItems() {
        const items = [];
        if (this.reviewHoldCount > 0) {
            items.push(`Review ${this.reviewHoldCount} held takeoff line${this.reviewHoldCount === 1 ? '' : 's'}`);
        }
        if (this.packageVarianceLabel === 'Yes') {
            items.push('Review package variance before child creation');
        }
        if (this.blankScopeCount > 0) {
            items.push(`Resolve ${this.blankScopeCount} blank scope line${this.blankScopeCount === 1 ? '' : 's'}`);
        }
        if (!items.length) {
            items.push('No customer success review is required.');
        }
        return items;
    }

    get nextActionList() {
        return [
            { label: 'Run or review takeoff', detail: this.hasTakeoff ? valueOrDefault(this.selectedTakeoffStatusLabel, 'Takeoff available') : 'Create or open takeoff', className: 'flow active', icon: '!' },
            { label: 'Confirm route summary', detail: `${this.takeoffRoutedCount} routed · ${this.reviewHoldCount} on hold`, className: this.reviewHoldCount > 0 ? 'flow active' : 'flow done', icon: this.reviewHoldCount > 0 ? '!' : '✓' },
            { label: 'Create or sync sub work orders', detail: `${this.selectedChildWorkOrderCount} child work orders`, className: this.selectedChildWorkOrderCount > 0 ? 'flow done' : 'flow active', icon: this.selectedChildWorkOrderCount > 0 ? '✓' : '!' },
            { label: 'Hand off to scheduling', detail: this.hasServiceAppointment ? this.serviceAppointmentStatus : 'No service appointment yet', className: this.hasServiceAppointment ? 'flow done' : 'flow active', icon: this.hasServiceAppointment ? '✓' : '!' }
        ];
    }

    get isPipelineView() {
        return this.currentView === 'pipeline';
    }

    get isPoDetailView() {
        return this.currentView === 'poDetail';
    }

    get isTakeoffView() {
        return this.currentView === 'takeoff';
    }

    get isWorkOrdersView() {
        return this.currentView === 'workorders';
    }

    get isWoDetailView() {
        return this.currentView === 'woDetail';
    }

    get selectedTakeoffStatusLabel() {
        return this.selectedTakeoff?.status || null;
    }

    get views() {
        const source = this.isRecordContext ? RECORD_VIEWS : PIPELINE_VIEWS;
        return source.map((view) => ({
            ...view,
            label: view.id === 'poDetail' ? this.detailViewLabel : view.label,
            className: view.id === this.currentView ? 'subtab active' : 'subtab',
            disabled: (view.id === 'poDetail' || view.id === 'takeoff' || view.id === 'woDetail') && !this.selectedPoId
        }));
    }

    get builderNavTabs() {
        const active = this.isTakeoffView ? 'takeoff' : (this.isWoDetailView || this.isWorkOrdersView ? 'workorders' : 'builderPo');
        return [
            { id: 'home', label: 'Home', className: active === 'home' ? 'sf-tab on' : 'sf-tab', disabled: false },
            { id: 'accounts', label: 'Accounts', className: active === 'accounts' ? 'sf-tab on' : 'sf-tab', disabled: false },
            { id: 'builderPo', label: 'Builder PO', className: active === 'builderPo' ? 'sf-tab on' : 'sf-tab', disabled: false },
            { id: 'takeoff', label: 'Takeoff', className: active === 'takeoff' ? 'sf-tab on' : 'sf-tab', disabled: !this.hasTakeoff },
            { id: 'workorders', label: 'Work Order', className: active === 'workorders' ? 'sf-tab on' : 'sf-tab', disabled: !this.hasWorkOrder },
            { id: 'scheduling', label: 'Scheduling', className: active === 'scheduling' ? 'sf-tab on' : 'sf-tab', disabled: !this.hasServiceAppointment },
            { id: 'customerSuccess', label: 'Customer Success', className: active === 'customerSuccess' ? 'sf-tab on' : 'sf-tab', disabled: false },
            { id: 'aqua', label: 'Aqua', className: active === 'aqua' ? 'sf-tab on' : 'sf-tab', disabled: false }
        ];
    }

    get activityRows() {
        return this.detailData?.activity || [];
    }

    get hasActivityRows() {
        return this.activityRows.length > 0;
    }

    get isActivityView() {
        return this.currentView === 'activity';
    }

    get filteredRecords() {
        let recs = this.prefilteredRecords;
        if (this.activeFilter !== 'all') {
            recs = recs.filter((r) => r.boardColumn === this.activeFilter);
        }
        return recs;
    }

    get prefilteredRecords() {
        let recs = this.rawRecords;
        if (this.builderFilter) recs = recs.filter((r) => r.builderName === this.builderFilter);
        if (this.searchTerm) {
            const q = this.searchTerm.toLowerCase();
            recs = recs.filter((r) =>
                (r.name || '').toLowerCase().includes(q) ||
                (r.builderName || '').toLowerCase().includes(q) ||
                (r.communityName || '').toLowerCase().includes(q) ||
                (r.itemName || '').toLowerCase().includes(q) ||
                (r.lotName || '').toLowerCase().includes(q)
            );
        }
        return recs;
    }

    get stageFilters() {
        const base = this.prefilteredRecords;
        return STAGE_FILTERS.map((filter) => ({
            ...filter,
            count: filter.id === 'all' ? base.length : base.filter((row) => row.boardColumn === filter.id).length,
            className: this.activeFilter === filter.id ? 'filter on' : 'filter'
        }));
    }

    get statusOptions() {
        return this.poStatusOptions;
    }

    get workOrderRows() {
        return this.rawRecords
            .filter((row) => row.workOrderId || ['workOrderCreated', 'clear'].includes(row.boardColumn))
            .map((row) => ({
                ...row,
                workOrderState: row.status || '—',
                workOrderTone: row.workOrderId ? 'chip purple' : 'chip amber'
            }));
    }

    get hasWorkOrderRows() {
        return this.workOrderRows.length > 0;
    }

    get hasFilteredRecords() {
        return this.filteredRecords.length > 0;
    }

    get hasPoDetail() {
        return Boolean(this.selectedPo);
    }

    get hasTakeoff() {
        return Boolean(this.selectedTakeoff);
    }

    get hasWorkOrder() {
        return Boolean(this.selectedWorkOrder);
    }

    get primaryActionLabel() {
        return this.detailData?.nextAction || 'Next Action';
    }

    get saveLabel() {
        return this.isSaving ? 'Saving...' : 'Move PO';
    }

    get validationBannerClass() {
        return this.actionResult ? (this.actionResult.passed ? 'notice green' : 'notice red') : '';
    }

    get validationIcon() {
        return this.actionResult ? (this.actionResult.passed ? '✓' : '⚠') : '';
    }

    get canCreateWorkOrder() {
        return this.detailData?.canCreateWorkOrder === true;
    }

    get canCreateScheduleHandoff() {
        return this.detailData?.canCreateScheduleHandoff === true;
    }

    get canApproveTakeoff() {
        return this.selectedTakeoff?.canApprove === true;
    }

    get disableApproveTakeoff() {
        return !this.canApproveTakeoff;
    }

    get disableCreateWorkOrder() {
        return !this.canCreateWorkOrder;
    }

    get disableCreateScheduleHandoff() {
        return !this.canCreateScheduleHandoff;
    }

    get disableOpenServiceAppointment() {
        return !this.hasServiceAppointment;
    }

    get serviceAppointmentNumber() {
        return this.selectedServiceAppointment?.appointmentNumber || '—';
    }

    get serviceAppointmentStatus() {
        return this.selectedServiceAppointment?.status || '—';
    }

    get serviceAppointmentScheduledStart() {
        return this.selectedServiceAppointment?.scheduledStart || '—';
    }

    get takeoffGateRows() {
        return (this.detailData?.gateChecks || []).map((gate) => ({
            ...gate,
            className: gate.passed ? 'flow done' : 'flow active',
            icon: gate.passed ? '✓' : '!'
        }));
    }

    get takeoffExitState() {
        return this.selectedPo?.status || '—';
    }

    handleFilterClick(evt) {
        this.activeFilter = evt.currentTarget.dataset.value;
    }

    handleBuilderChange(evt) {
        this.builderFilter = evt.target.value;
    }

    handleSearchInput(evt) {
        this.searchTerm = evt.target.value;
    }

    handleViewChange(evt) {
        const viewId = evt.currentTarget.dataset.id;
        if (!viewId) return;
        if ((viewId === 'poDetail' || viewId === 'takeoff' || viewId === 'woDetail') && !this.selectedPoId) return;
        if (viewId === 'pipeline' && this.rawRecords.length === 0) {
            this.loadPipeline();
        }
        this.currentView = viewId;
    }

    handleBuilderTabClick(evt) {
        const target = evt.currentTarget.dataset.id;
        if (!target) return;
        switch (target) {
            case 'home':
                this[NavigationMixin.Navigate]({
                    type: 'standard__navItemPage',
                    attributes: { apiName: 'LOVING_PO_Pipeline' }
                });
                break;
            case 'accounts':
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: { objectApiName: 'Account', actionName: 'home' }
                });
                break;
            case 'builderPo':
                if (this.isRecordContext) {
                    this.currentView = 'poDetail';
                } else {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__objectPage',
                        attributes: { objectApiName: 'Builder_PO__c', actionName: 'home' }
                    });
                }
                break;
            case 'takeoff':
                if (this.hasTakeoff) {
                    this.currentView = 'takeoff';
                }
                break;
            case 'workorders':
                if (this.hasWorkOrder) {
                    this.currentView = 'woDetail';
                }
                break;
            case 'scheduling':
                if (this.hasServiceAppointment) {
                    this.handleOpenServiceAppointmentRecord();
                }
                break;
            case 'customerSuccess':
                this[NavigationMixin.Navigate]({
                    type: 'standard__navItemPage',
                    attributes: { apiName: 'Customer_Success_Console' }
                });
                break;
            case 'aqua':
                this[NavigationMixin.Navigate]({
                    type: 'standard__navItemPage',
                    attributes: { apiName: 'Aqua_Service_Home' }
                });
                break;
            default:
                break;
        }
    }

    async handlePoSelect(evt) {
        const id = evt.currentTarget.dataset.id;
        await this.loadPoDetail(id, 'poDetail');
    }

    async handleWorkOrderRowSelect(evt) {
        const poId = evt.currentTarget.dataset.poId;
        await this.loadPoDetail(poId, 'woDetail');
    }

    handleNewPo() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Builder_PO__c', actionName: 'new' }
        });
    }

    handleFieldManagerChange(evt) {
        this.selectedFieldManagerId = evt.target.value;
    }

    handleTakeoffDateChange(evt) {
        this.selectedTakeoffDate = evt.target.value;
    }

    handleTakeoffChecklistChange(evt) {
        this.takeoffChecklistComplete = evt.target.checked;
    }

    handleTakeoffEight11Change(evt) {
        this.takeoffEight11Confirmed = evt.target.checked;
    }

    handleTakeoffPhotoCountChange(evt) {
        const value = Number(evt.target.value);
        this.takeoffPhotoCount = Number.isNaN(value) ? 0 : value;
    }

    async handleAssignFieldManager() {
        if (!this.selectedPoId || !this.selectedFieldManagerId) {
            this.toast('Field Manager required', 'Choose a Field Manager before scheduling the takeoff.', 'error');
            return;
        }
        this.isLoading = true;
        try {
            const result = await assignTakeoffFieldManager({
                poId: this.selectedPoId,
                fieldManagerUserId: this.selectedFieldManagerId,
                scheduledDate: this.selectedTakeoffDate || null
            });
            this.actionResult = result;
            this.toast(result.passed ? 'Field Manager updated' : 'Field Manager update failed', result.message, result.passed ? 'success' : 'error');
            await this.refreshCurrentDetail('takeoff');
        } catch (err) {
            this.toast('Field Manager update failed', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleCreateOrOpenTakeoff() {
        if (!this.selectedPoId) return;
        this.isLoading = true;
        try {
            await createOrGetTakeoff({ poId: this.selectedPoId });
            await this.refreshCurrentDetail('takeoff');
        } catch (err) {
            this.toast('Takeoff action failed', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleApproveTakeoff() {
        if (!this.selectedTakeoff?.id) return;
        this.isLoading = true;
        try {
            const result = await approveTakeoff({ takeoffId: this.selectedTakeoff.id });
            this.actionResult = { passed: result.success, message: result.message };
            this.toast(result.success ? 'Takeoff approved' : 'Takeoff approval blocked', result.message, result.success ? 'success' : 'error');
            await this.refreshCurrentDetail('takeoff');
        } catch (err) {
            this.toast('Takeoff approval failed', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSaveTakeoffReadiness() {
        if (!this.selectedTakeoff?.id) return;
        this.isLoading = true;
        try {
            const result = await updateTakeoffReadiness({
                takeoffId: this.selectedTakeoff.id,
                checklistComplete: this.takeoffChecklistComplete,
                eight11Confirmed: this.takeoffEight11Confirmed,
                photoCount: this.takeoffPhotoCount
            });
            this.actionResult = result;
            this.toast(result.passed ? 'Takeoff readiness updated' : 'Takeoff readiness update failed', result.message, result.passed ? 'success' : 'error');
            await this.refreshCurrentDetail('takeoff');
        } catch (err) {
            this.toast('Takeoff readiness update failed', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleCreateWorkOrder() {
        if (!this.selectedPoId) return;
        this.isLoading = true;
        try {
            const result = await createProductionWorkOrder({ poId: this.selectedPoId });
            this.actionResult = result;
            this.toast(result.passed ? 'WorkOrder created' : 'WorkOrder creation blocked', result.message, result.passed ? 'success' : 'error');
            await this.refreshCurrentDetail('woDetail');
        } catch (err) {
            this.toast('WorkOrder creation failed', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleCreateScheduleHandoff() {
        if (!this.selectedPoId) return;
        this.isLoading = true;
        try {
            const result = await createScheduleHandoff({ poId: this.selectedPoId });
            this.actionResult = result;
            this.toast(result.passed ? 'Scheduling handoff created' : 'Scheduling handoff blocked', result.message, result.passed ? 'success' : 'error');
            await this.refreshCurrentDetail('woDetail');
        } catch (err) {
            this.toast('Scheduling handoff failed', this.errorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handlePrimaryAction() {
        switch (this.primaryActionLabel) {
            case 'Create / Open Takeoff':
                await this.handleCreateOrOpenTakeoff();
                break;
            case 'Assign Field Manager':
                await this.handleAssignFieldManager();
                break;
            case 'Approve Takeoff':
                await this.handleApproveTakeoff();
                break;
            case 'Create Production WorkOrder':
                await this.handleCreateWorkOrder();
                break;
            case 'Create Schedule Handoff':
                await this.handleCreateScheduleHandoff();
                break;
            case 'Open WorkOrder':
                this.handleOpenWorkOrderRecord();
                break;
            default:
                this.handleOpenModal();
        }
    }

    handlePrimaryRecordAction() {
        if (this.isTakeoffView) {
            if (this.hasWorkOrder) {
                this.handleOpenWorkOrderRecord();
                return;
            }
            this.handleCreateWorkOrder();
            return;
        }
        this.handleCreateOrOpenTakeoff();
    }

    handleEditRecord() {
        const targetId = this.isRecordContext ? this.recordId : (this.selectedPo?.builderPoId || this.selectedPoId);
        if (!targetId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: targetId, actionName: 'edit' }
        });
    }

    handleOpenPoRecord() {
        if (this.isRecordContext) {
            this.navigateToRecord(this.recordId, 'Builder_PO__c');
            return;
        }
        const targetId = this.selectedPo?.builderPoId || this.selectedPoId;
        if (!targetId) return;
        this.navigateToRecord(targetId, 'Builder_PO__c');
    }

    displayPoStatus(status) {
        return status;
    }

    handleOpenTakeoffRecord() {
        if (!this.selectedTakeoff?.id) return;
        this.navigateToRecord(this.selectedTakeoff.id, 'Takeoff__c');
    }

    handleOpenActivityRecord(evt) {
        const recordId = evt.currentTarget.dataset.id;
        if (!recordId) return;
        this.navigateToRecord(recordId);
    }

    handleOpenWorkOrderRecord() {
        if (!this.selectedWorkOrder?.id) return;
        this.navigateToRecord(this.selectedWorkOrder.id, 'WorkOrder');
    }

    handleOpenServiceAppointmentRecord() {
        if (!this.selectedServiceAppointment?.id) return;
        this.navigateToRecord(this.selectedServiceAppointment.id, 'ServiceAppointment');
    }

    navigateToRecord(recordId, objectApiName = null) {
        if (objectApiName) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: `/lightning/r/${objectApiName}/${recordId}/view` }
            });
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    handleOpenModal() {
        if (!this.selectedPoId) return;
        this.modalNewStatus = '';
        this.modalError = null;
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
        this.modalError = null;
    }

    handleModalBackdropClick(evt) {
        if (evt.target === evt.currentTarget) this.handleCloseModal();
    }

    handleModalClick(evt) {
        evt.stopPropagation();
    }

    handleStatusChange(evt) {
        this.modalNewStatus = evt.target.value;
    }

    async handleSaveValidation() {
        if (!this.selectedPoId || !this.modalNewStatus) {
            this.modalError = 'Please select a status to move this PO to.';
            return;
        }
        this.isSaving = true;
        this.modalError = null;
        try {
            const result = await updatePoStatus({ poId: this.selectedPoId, newStatus: this.modalNewStatus });
            this.actionResult = { passed: result.passed, message: result.message };
            if (result.passed) {
                this.showModal = false;
                this.toast('PO updated', result.message, 'success');
                await this.refreshCurrentDetail();
            } else {
                this.modalError = result.message;
            }
        } catch (err) {
            this.modalError = this.errorMessage(err);
        } finally {
            this.isSaving = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errorMessage(err) {
        return err?.body?.message || err?.message || 'Unknown error';
    }

    formatCurrency(val) {
        const n = Number(val);
        if (Number.isNaN(n) || n === 0) return '$0';
        if (n >= 1000000) return '$' + (n / 1000000).toFixed(1) + 'M';
        if (n >= 1000) return '$' + (n / 1000).toFixed(1) + 'k';
        return '$' + n.toFixed(0);
    }

    deriveRoutingResult(workType, packageMatch, matchNotes) {
        if (matchNotes) {
            return matchNotes;
        }
        if (packageMatch) {
            return packageMatch;
        }
        return workType || 'Pending';
    }

    deriveExecutionScope(line) {
        const status = String(line.reviewStatus || '').toLowerCase();
        if (status.includes('aqua')) {
            return 'Aqua';
        }
        if (status.includes('blank')) {
            return '—';
        }
        if (status.includes('install') || status.includes('clear') || status.includes('approved')) {
            return 'Install';
        }
        if (status.includes('review') || status.includes('hold')) {
            return 'Other';
        }
        return 'Install';
    }

    deriveTakeoffRoutingResult(line) {
        const review = line.reviewStatus || '';
        if (this.isHoldValue(review)) {
            return 'Review hold';
        }
        const scope = this.deriveExecutionScope(line);
        if (scope === 'Aqua') {
            return 'Aqua child';
        }
        if (scope === 'Install') {
            return 'Install child';
        }
        if (scope === '—') {
            return 'Blank scope';
        }
        return review || 'Clear';
    }

    isHoldValue(value) {
        const normalized = String(value || '').toLowerCase();
        return normalized.includes('hold') || normalized.includes('review') || normalized.includes('mismatch') || normalized.includes('variance');
    }
}

function valueOrDefault(value, fallback) {
    return value || fallback;
}