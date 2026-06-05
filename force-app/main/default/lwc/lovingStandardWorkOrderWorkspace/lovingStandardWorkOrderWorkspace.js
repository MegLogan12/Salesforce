import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import FIRST_NAME from '@salesforce/schema/User.FirstName';
import LAST_NAME from '@salesforce/schema/User.LastName';
import getWorkspace from '@salesforce/apex/LovingWOWorkspaceController.getWorkspace';
import createExecutionChildren from '@salesforce/apex/LovingWOWorkspaceController.createExecutionChildren';
import ensureTakeoffChecklist from '@salesforce/apex/LovingWOWorkspaceController.ensureTakeoffChecklist';
import updateTakeoffReview from '@salesforce/apex/LovingWOWorkspaceController.updateTakeoffReview';
import updateChecklistItem from '@salesforce/apex/LovingWOWorkspaceController.updateChecklistItem';
import updateTakeoffLineScope from '@salesforce/apex/LovingWOWorkspaceController.updateTakeoffLineScope';

const NEW_TASK_ACTION = 'Global.NewTask';
const NEW_NOTE_ACTION = 'Global.NewNote';

export default class LovingStandardWorkOrderWorkspace extends NavigationMixin(LightningElement) {
    static shellStyleId = 'loving-workorder-shell-style';
    @api recordId;
    activeTab = 'summary';
    workspace;
    error;
    wiredResult;
    isCreatingChildren = false;
    isEnsuringTakeoffChecklist = false;
    isSavingTakeoff = false;
    checklistInitAttempted = false;
    takeoffDraft = {};
    checklistDrafts = {};
    takeoffLineDrafts = {};

    @wire(getRecord, { recordId: userId, fields: [FIRST_NAME, LAST_NAME] })
    currentUser;

    @wire(getWorkspace, { workOrderId: '$recordId' })
    wiredWorkspace({ data, error }) {
        this.wiredResult = { data, error };
        this.workspace = data;
        this.error = error;
        if (data) {
            this.initializeDrafts();
            if (this.isParentMode && data.takeoffId && data.takeoffChecklistMissing && !this.checklistInitAttempted) {
                this.checklistInitAttempted = true;
                this.initializeTakeoffChecklist();
            }
        }
    }

    renderedCallback() {
        this.ensureShellStyle();
    }

    disconnectedCallback() {
        this.removeShellStyle();
    }

    get hasData() {
        return !!this.workspace && !!this.workspace.header;
    }

    get builderAppLabel() {
        return 'Home Builder Operations';
    }

    get builderSearchPlaceholder() {
        return 'Search builder POs, takeoffs, work orders, schedules, customer success, and aqua...';
    }

    get userInitials() {
        const first = (getFieldValue(this.currentUser?.data, FIRST_NAME) || '')[0] || '';
        const last = (getFieldValue(this.currentUser?.data, LAST_NAME) || '')[0] || '';
        return (first + last).toUpperCase() || '--';
    }

    get builderNavTabs() {
        return [
            { id: 'home', label: 'Home', className: 'hb-tab', disabled: false },
            { id: 'accounts', label: 'Accounts', className: 'hb-tab', disabled: false },
            { id: 'builderPo', label: 'Builder PO', className: 'hb-tab', disabled: false },
            { id: 'takeoff', label: 'Takeoff', className: 'hb-tab', disabled: !this.workspace?.takeoffId },
            { id: 'workorders', label: 'Work Order', className: 'hb-tab on', disabled: false },
            { id: 'scheduling', label: 'Scheduling', className: 'hb-tab', disabled: false },
            { id: 'customerSuccess', label: 'Customer Success', className: 'hb-tab', disabled: false },
            { id: 'aqua', label: 'Aqua', className: 'hb-tab', disabled: false }
        ];
    }

    ensureShellStyle() {
        if (typeof window === 'undefined' || typeof document === 'undefined') {
            return;
        }
        if (!window.location.pathname.includes('/lightning/r/WorkOrder/')) {
            return;
        }
        if (document.getElementById(LovingStandardWorkOrderWorkspace.shellStyleId)) {
            return;
        }
        const style = document.createElement('style');
        style.id = LovingStandardWorkOrderWorkspace.shellStyleId;
        style.textContent = `
            .flexipageHeader,
            app-flexipage-header {
                display: none !important;
            }
        `;
        document.head.appendChild(style);
    }

    removeShellStyle() {
        if (typeof document === 'undefined') {
            return;
        }
        document.getElementById(LovingStandardWorkOrderWorkspace.shellStyleId)?.remove();
    }

    get tabs() {
        const tabs = this.isChildMode
            ? [
                { id: 'summary', label: 'Sub WorkOrder Summary' },
                { id: 'execution', label: 'Service Appointments' },
                { id: 'scope', label: 'Line Items' },
                { id: 'takeoff', label: 'Parent Takeoff' },
                { id: 'blockers', label: 'Execution Controls' },
                { id: 'proof', label: 'Proof + Closeout' }
            ]
            : [
                { id: 'summary', label: 'Parent Command Center' },
                { id: 'execution', label: 'Sub WorkOrders' },
                { id: 'takeoff', label: 'Takeoff + Routing' },
                { id: 'scope', label: 'Lineage + Scope' },
                { id: 'records', label: 'Files + Notes' },
                { id: 'blockers', label: 'Execution Controls' },
                { id: 'proof', label: 'Billing + QI' }
            ];
        return tabs.map((tab) => ({
            ...tab,
            className: `sf-tab${this.activeTab === tab.id ? ' on' : ''}`
        }));
    }

    get header() {
        return this.workspace?.header || {};
    }

    get kpis() {
        return (this.workspace?.kpis || []).map((kpi) => ({
            ...kpi,
            className: `kpi ${kpi.tone || 'gray'}`
        }));
    }

    get summaryRows() {
        return this.workspace?.summaryRows || [];
    }

    get identityRows() {
        const labels = new Set(['Work Order Number', 'Lot', 'Builder', 'Community', 'Site Address', 'Builder PO']);
        return this.summaryRows.filter((row) => labels.has(row.label));
    }

    get stateRows() {
        const labels = new Set(['Work Type', 'Master Status', 'Execution Status', 'Billing State', 'QI Outcome', 'Customer Care State', 'Parent WorkOrder']);
        return this.summaryRows.filter((row) => labels.has(row.label));
    }

    get executionOverviewRows() {
        const labels = new Set(['Root WorkOrder', 'Parent WorkOrder', 'Direct Child WorkOrders', 'Related ServiceAppointments', 'Package Validation']);
        return this.rollupRows.filter((row) => labels.has(row.label));
    }

    get executionChainRows() {
        const takeoffName = this.takeoffSummaryValueByLabel['Takeoff'] || '—';
        return [
            { label: 'Builder PO', value: this.header.poNumber || '—' },
            { label: 'Takeoff', value: takeoffName },
            {
                label: this.isParentMode ? 'Parent WorkOrder' : 'Parent WorkOrder',
                value: this.isParentMode ? (this.header.workOrderNumber || '—') : (this.header.parentWorkOrderNumber || '—')
            },
            {
                label: this.isParentMode ? 'Sub WorkOrders' : 'Sibling Sub WorkOrders',
                value: this.isParentMode
                    ? String(this.header.childWorkOrderCount ?? 0)
                    : (this.executionOverviewRows.find((row) => row.label === 'Direct Child WorkOrders')?.value || '—')
            },
            {
                label: this.isParentMode ? 'Service Appointments' : 'Assigned Appointments',
                value: this.isParentMode
                    ? String(this.header.childAppointmentCount ?? 0)
                    : String(this.relatedAppointments.length || 0)
            }
        ];
    }

    get financialOverviewRows() {
        const labels = new Set(['Total Scope Price', 'Total Cost', 'Gross Profit', 'Invoice Amount']);
        return this.rollupRows.filter((row) => labels.has(row.label));
    }

    get recordOverviewRows() {
        return this.recordsRows;
    }

    get lineItems() {
        return this.workspace?.lineItems || [];
    }

    get childWorkOrders() {
        return this.workspace?.childWorkOrders || [];
    }

    get childAppointments() {
        return this.workspace?.childAppointments || [];
    }

    get relatedAppointments() {
        return this.workspace?.relatedAppointments || [];
    }

    get rollupRows() {
        return this.workspace?.rollupRows || [];
    }

    get takeoffRows() {
        return this.workspace?.takeoffRows || [];
    }

    get takeoffHeaderRows() {
        const labels = new Set(['Parent WorkOrder', 'Lot', 'Builder', 'Community', 'Takeoff', 'Takeoff Review Status', 'Package Match State', 'Scope Review State']);
        return this.takeoffRows.filter((row) => labels.has(row.label));
    }

    get takeoffStateRows() {
        const labels = new Set([
            'Field Manager',
            'Scheduled Date',
            'FM Completion State',
            'Required Photo Proof',
            'Variance / Substitution Present',
            'Return Required',
            'Return Reason',
            'Customer Success Review Required',
            'Customer Success Review State'
        ]);
        return this.takeoffRows.filter((row) => labels.has(row.label));
    }

    get takeoffRoutingRows() {
        const labels = new Set([
            'Lines Routed',
            'Lines Held for Review',
            'Lines Unrouted',
            'Child WorkOrders Created from Routing'
        ]);
        return this.takeoffRows.filter((row) => labels.has(row.label));
    }

    get takeoffLines() {
        const options = this.workspace?.takeoffLineScopeOptions || [];
        return (this.workspace?.takeoffLines || []).map((line) => {
            const draft = this.takeoffLineDrafts[line.takeoffLineId] || {};
            return {
                ...line,
                executionScopeValue: draft.executionScope ?? (line.executionScope === '—' ? '' : line.executionScope),
                scopeOptions: options
            };
        });
    }

    get takeoffChecklist() {
        return this.workspace?.takeoffChecklist || {};
    }

    get checklistItems() {
        const options = this.workspace?.checklistItemStatusOptions || [];
        return (this.workspace?.checklistItems || []).map((item) => {
            const draft = this.checklistDrafts[item.checklistItemId] || {};
            return {
                ...item,
                statusValue: draft.status ?? item.status,
                notesValue: draft.notes ?? (item.notes === '—' ? '' : item.notes),
                statusOptions: options,
                requiredLabel: item.required ? 'Required' : 'Optional',
                photoRequiredLabel: item.photoRequired ? 'Photo required' : 'Photo optional'
            };
        });
    }

    get takeoffStatusOptions() {
        return this.workspace?.takeoffStatusOptions || [];
    }

    get recordsRows() {
        return this.workspace?.recordsRows || [];
    }

    get handoffRows() {
        return this.workspace?.handoffRows || [];
    }

    get blockerRows() {
        return this.workspace?.blockerRows || [];
    }

    get readinessChecks() {
        return (this.workspace?.readinessChecks || []).map((item) => ({
            ...item,
            className: item.passed ? 'check-dot pass' : 'check-dot fail'
        }));
    }

    get closeoutRows() {
        return this.workspace?.closeoutRows || [];
    }

    get proofFinancialRows() {
        const labels = new Set(['Current Status', 'QI Status', 'Customer Care State', 'Total Scope Price', 'Total Cost', 'Gross Profit', 'Invoice Amount']);
        return this.closeoutRows.filter((row) => labels.has(row.label));
    }

    get activityRows() {
        return this.workspace?.activity || [];
    }

    get showSummary() { return this.activeTab === 'summary'; }
    get showExecution() { return this.activeTab === 'execution'; }
    get showTakeoff() { return this.activeTab === 'takeoff'; }
    get showScope() { return this.activeTab === 'scope'; }
    get showRecords() { return this.activeTab === 'records'; }
    get showBlockers() { return this.activeTab === 'blockers'; }
    get showProof() { return this.activeTab === 'proof'; }

    get disableOpenServiceAppointment() {
        return !this.header.serviceAppointmentId;
    }

    get isParentMode() {
        return this.header?.isParent === true;
    }

    get isChildMode() {
        return this.header?.isChild === true;
    }

    get hasTakeoffChecklist() {
        return !!this.takeoffChecklist?.checklistId;
    }

    get showTakeoffEditor() {
        return this.isParentMode && !!this.workspace?.takeoffId;
    }

    get takeoffSummaryValueByLabel() {
        const rows = this.workspace?.takeoffRows || [];
        const values = {};
        rows.forEach((row) => {
            values[row.label] = row.value;
        });
        return values;
    }

    get packageMatchState() {
        return this.takeoffSummaryValueByLabel['Package Match State'] || '—';
    }

    get returnRequiredState() {
        return this.takeoffSummaryValueByLabel['Return Required'] || '—';
    }

    get customerSuccessReviewRequiredState() {
        return this.takeoffSummaryValueByLabel['Customer Success Review Required'] || '—';
    }

    get requiredPhotoProofState() {
        return this.takeoffSummaryValueByLabel['Required Photo Proof'] || '0';
    }

    get disableCreateChildren() {
        return this.isCreatingChildren || this.isChildMode;
    }

    get disableOpenParentWorkOrder() {
        return !this.header.parentWorkOrderId;
    }

    get disableOpenTakeoffRecord() {
        return !this.workspace?.takeoffId;
    }

    get shellClassName() {
        return `console-shell${this.isChildMode ? ' child-shell' : ' parent-shell'}`;
    }

    get routedReviewCount() {
        return this.takeoffLines.filter((line) => line.routeState === 'Review Hold' || line.routeState === 'Unrouted').length;
    }

    get roleLabel() {
        return this.isChildMode ? 'Sub WorkOrder Execution' : 'Parent WorkOrder Roll-Up';
    }

    get commandSubtitle() {
        const parts = [
            this.header.builderName,
            this.header.communityName,
            this.header.lotName
        ].filter((value) => value && String(value).trim());
        if (this.header.poNumber) {
            parts.push(`PO ${this.header.poNumber}`);
        }
        if (this.isChildMode && this.header.parentWorkOrderNumber) {
            parts.push(`Parent ${this.header.parentWorkOrderNumber}`);
        }
        return parts.join(' • ');
    }

    initializeDrafts() {
        if (!this.workspace?.takeoffId) {
            this.takeoffDraft = {};
            this.checklistDrafts = {};
            return;
        }
        const values = this.takeoffSummaryValueByLabel;
        this.takeoffDraft = {
            status: values['Takeoff Review Status'] || '',
            mismatchFound: (values['Customer Success Review Required'] || '').toLowerCase() === 'yes' || (values['Return Required'] || '').toLowerCase() === 'yes',
            mismatchNotes: values['Return Reason'] === '—' ? '' : values['Return Reason'],
            csApproved: values['Customer Success Review Required'] === 'No',
            notes: '',
            returnReason: values['Return Reason'] === '—' ? '' : values['Return Reason']
        };
        this.checklistDrafts = {};
        this.takeoffLineDrafts = {};
    }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.id;
    }

    openServiceAppointment() {
        if (!this.header.serviceAppointmentId) return;
        this.navigateToLightningRecord(this.header.serviceAppointmentId, 'ServiceAppointment');
    }

    openParentWorkOrder() {
        if (!this.header.parentWorkOrderId) return;
        this.navigateToLightningRecord(this.header.parentWorkOrderId, 'WorkOrder');
    }

    handleOpenChildWorkOrder(event) {
        const workOrderId = event.currentTarget.dataset.id;
        if (!workOrderId) return;
        this.navigateToLightningRecord(workOrderId, 'WorkOrder');
    }

    handleOpenServiceAppointmentRow(event) {
        const serviceAppointmentId = event.currentTarget.dataset.id;
        if (!serviceAppointmentId) return;
        this.navigateToLightningRecord(serviceAppointmentId, 'ServiceAppointment');
    }

    handleOpenTakeoffRecord() {
        if (!this.workspace?.takeoffId) return;
        this.navigateToLightningRecord(this.workspace.takeoffId, 'Takeoff__c');
    }

    handleBuilderTabClick(event) {
        const target = event.currentTarget.dataset.id;
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
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: { objectApiName: 'Builder_PO__c', actionName: 'home' }
                });
                break;
            case 'takeoff':
                this.handleOpenTakeoffRecord();
                break;
            case 'workorders':
                this.navigateToLightningRecord(this.recordId, 'WorkOrder');
                break;
            case 'scheduling':
                this[NavigationMixin.Navigate]({
                    type: 'standard__navItemPage',
                    attributes: { apiName: 'Scheduling_Console_Home' }
                });
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

    handleEditWorkOrder() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'WorkOrder',
                actionName: 'edit'
            }
        });
    }

    handleNewTask() {
        this.navigateQuickAction(NEW_TASK_ACTION);
    }

    handleNewNote() {
        this.navigateQuickAction(NEW_NOTE_ACTION);
    }

    handleCompleteTakeoff() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Complete_Takeoff');
    }

    handleLogIssue() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Log_Issue');
    }

    handleCreateQuoteRequest() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Quote_Request');
    }

    handleMarkSiteReady() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Mark_Site_Ready');
    }

    handleFlagSiteNotReady() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Flag_Site_Not_Ready');
    }

    handleCompleteQI() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Complete_QI');
    }

    handleCreateFinishedJob() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Create_Finished_Job');
    }

    handleCreateWarrantyJob() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Create_Warranty_Job');
    }

    handleRequestReschedule() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Request_Reschedule');
    }

    handle2pmHealthCheck() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_2PM_Health_Check');
    }

    handleApproveCloseout() {
        this.navigateQuickAction('WorkOrder.LOVING_FM_Approve_Closeout');
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

    navigateQuickAction(apiName) {
        if (!this.recordId || !apiName) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName },
            state: { recordId: this.recordId }
        });
    }

    navigateToLightningRecord(recordId, objectApiName) {
        if (!recordId || !objectApiName) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/r/${objectApiName}/${recordId}/view`
            }
        });
    }

    async handleCreateChildren() {
        this.isCreatingChildren = true;
        try {
            const result = await createExecutionChildren({ workOrderId: this.recordId });
            this.dispatchEvent(new ShowToastEvent({
                title: result?.success ? 'Sub WorkOrders Ready' : 'Sub WorkOrders Not Created',
                message: result?.message || 'Request completed without a response message.',
                variant: result?.success ? 'success' : 'warning'
            }));
            if (this.wiredResult) {
                await refreshApex(this.wiredResult);
            }
            this.activeTab = 'execution';
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Sub WorkOrder Creation Failed',
                message: error?.body?.message || error?.message || 'Unknown error.',
                variant: 'error'
            }));
        } finally {
            this.isCreatingChildren = false;
        }
    }

    async initializeTakeoffChecklist() {
        this.isEnsuringTakeoffChecklist = true;
        try {
            const message = await ensureTakeoffChecklist({ workOrderId: this.recordId });
            if (this.wiredResult) {
                await refreshApex(this.wiredResult);
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Takeoff Checklist Ready',
                message,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Takeoff Checklist Initialization Failed',
                message: error?.body?.message || error?.message || 'Unknown error.',
                variant: 'error'
            }));
        } finally {
            this.isEnsuringTakeoffChecklist = false;
        }
    }

    handleTakeoffFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.currentTarget.type === 'checkbox' ? event.currentTarget.checked : event.currentTarget.value;
        this.takeoffDraft = {
            ...this.takeoffDraft,
            [field]: value
        };
    }

    async handleSaveTakeoffReview() {
        this.isSavingTakeoff = true;
        try {
            const message = await updateTakeoffReview({
                takeoffId: this.workspace.takeoffId,
                takeoffStatus: this.takeoffDraft.status,
                mismatchFound: this.takeoffDraft.mismatchFound,
                mismatchNotes: this.takeoffDraft.mismatchNotes,
                csApproved: this.takeoffDraft.csApproved,
                takeoffNotes: this.takeoffDraft.notes,
                returnReason: this.takeoffDraft.returnReason
            });
            if (this.wiredResult) {
                await refreshApex(this.wiredResult);
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Takeoff Review Saved',
                message,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Takeoff Review Save Failed',
                message: error?.body?.message || error?.message || 'Unknown error.',
                variant: 'error'
            }));
        } finally {
            this.isSavingTakeoff = false;
        }
    }

    handleChecklistStatusChange(event) {
        const checklistItemId = event.currentTarget.dataset.id;
        const draft = this.checklistDrafts[checklistItemId] || {};
        this.checklistDrafts = {
            ...this.checklistDrafts,
            [checklistItemId]: {
                ...draft,
                status: event.currentTarget.value
            }
        };
    }

    handleChecklistNotesChange(event) {
        const checklistItemId = event.currentTarget.dataset.id;
        const draft = this.checklistDrafts[checklistItemId] || {};
        this.checklistDrafts = {
            ...this.checklistDrafts,
            [checklistItemId]: {
                ...draft,
                notes: event.currentTarget.value
            }
        };
    }

    async handleSaveChecklistItem(event) {
        const checklistItemId = event.currentTarget.dataset.id;
        const row = this.checklistItems.find((item) => item.checklistItemId === checklistItemId);
        const draft = this.checklistDrafts[checklistItemId] || {};
        try {
            const message = await updateChecklistItem({
                checklistItemId,
                status: draft.status ?? row?.status,
                notes: draft.notes ?? row?.notesValue ?? ''
            });
            if (this.wiredResult) {
                await refreshApex(this.wiredResult);
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Checklist Item Saved',
                message,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Checklist Item Save Failed',
                message: error?.body?.message || error?.message || 'Unknown error.',
                variant: 'error'
            }));
        }
    }

    handleTakeoffLineScopeChange(event) {
        const takeoffLineId = event.currentTarget.dataset.id;
        const draft = this.takeoffLineDrafts[takeoffLineId] || {};
        this.takeoffLineDrafts = {
            ...this.takeoffLineDrafts,
            [takeoffLineId]: {
                ...draft,
                executionScope: event.currentTarget.value
            }
        };
    }

    async handleSaveTakeoffLineScope(event) {
        const takeoffLineId = event.currentTarget.dataset.id;
        const row = this.takeoffLines.find((item) => item.takeoffLineId === takeoffLineId);
        const draft = this.takeoffLineDrafts[takeoffLineId] || {};
        try {
            const message = await updateTakeoffLineScope({
                takeoffLineId,
                executionScope: draft.executionScope ?? row?.executionScopeValue ?? ''
            });
            if (this.wiredResult) {
                await refreshApex(this.wiredResult);
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Takeoff Line Scope Saved',
                message,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Takeoff Line Scope Save Failed',
                message: error?.body?.message || error?.message || 'Unknown error.',
                variant: 'error'
            }));
        }
    }
}