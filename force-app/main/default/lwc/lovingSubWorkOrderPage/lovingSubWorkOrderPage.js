import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import FIRST_NAME from '@salesforce/schema/User.FirstName';
import LAST_NAME from '@salesforce/schema/User.LastName';
import getSubWorkOrderPageData from '@salesforce/apex/LovingSubWorkOrderController.getSubWorkOrderPageData';

const NEW_TASK_ACTION = 'Global.NewTask';
const NEW_NOTE_ACTION = 'Global.NewNote';

export default class LovingSubWorkOrderPage extends NavigationMixin(LightningElement) {
    @api recordId;

    _dto       = null;
    _error     = null;
    _loading   = true;
    _activeTab = 'overview';
    _wiredPage;

    @wire(getRecord, { recordId: userId, fields: [FIRST_NAME, LAST_NAME] })
    currentUser;

    @wire(getSubWorkOrderPageData, { workOrderId: '$recordId' })
    wiredPage(result) {
        this._wiredPage = result;
        const { data, error } = result;
        if (data) {
            this._dto     = data;
            this._error   = null;
            this._loading = false;
        } else if (error) {
            this._error   = (error && error.body && error.body.message) ? error.body.message : 'Failed to load work order';
            this._loading = false;
        }
    }

    // ── Tab management ───────────────────────────────────────────────────────
    handleTabSelect(event) {
        this._activeTab = event.currentTarget.dataset.tab;
    }

    get showOverview()  { return this._activeTab === 'overview'; }
    get showScope()     { return this._activeTab === 'scope'; }
    get showSchedule()  { return this._activeTab === 'schedule'; }
    get showCloseout()  { return this._activeTab === 'closeout'; }
    get showPhotos()    { return this._activeTab === 'photos'; }
    get showActivity()  { return this._activeTab === 'activity'; }

    get tabOverviewCss()  { return this._activeTab === 'overview'  ? 'subtab on' : 'subtab'; }
    get tabScopeCss()     { return this._activeTab === 'scope'     ? 'subtab on' : 'subtab'; }
    get tabScheduleCss()  { return this._activeTab === 'schedule'  ? 'subtab on' : 'subtab'; }
    get tabCloseoutCss()  { return this._activeTab === 'closeout'  ? 'subtab on' : 'subtab'; }
    get tabPhotosCss()    { return this._activeTab === 'photos'    ? 'subtab on' : 'subtab'; }
    get tabActivityCss()  { return this._activeTab === 'activity'  ? 'subtab on' : 'subtab'; }

    // ── State getters ────────────────────────────────────────────────────────
    get isLoading()    { return this._loading; }
    get hasError()     { return !!this._error; }
    get errorMsg()     { return this._error; }
    get dto()          { return this._dto || {}; }
    get header()       { return this._dto?.header || {}; }
    get shortPath()    { return this._dto?.shortPath || []; }
    get parentSummary(){ return this._dto?.parentSummary || {}; }
    get sourceSummary(){ return this._dto?.sourceSummary || {}; }
    get scopeItems() {
        return (this._dto?.scopeItems || []).map(item => ({
            ...item,
            chargeClass: item.isBillable ? 'chip cr' : 'chip cg'
        }));
    }
    get hasScopeItems(){ return this.scopeItems.length > 0; }
    get schedule()     { return this._dto?.scheduleSummary || {}; }
    get closeout()     { return this._dto?.closeoutSummary || {}; }
    get warnings()     { return this._dto?.warnings || []; }
    get hasWarnings()  { return this.warnings.length > 0; }
    get primaryWarning(){ return this.warnings[0] || null; }
    get actions()      { return this._dto?.actions || []; }
    get documents()    { return this._dto?.documents || []; }
    get hasDocuments() { return this.documents.length > 0; }
    get activity()     { return this._dto?.activity || []; }

    // ── Type detection ───────────────────────────────────────────────────────
    get isFinishedJob()   { return this.header.workOrderType === 'Finished Job'; }
    get isWarranty()      { return this.header.workOrderType === 'Warranty'; }
    get isCustomerCare()  {
        const t = this.header.workOrderType;
        return t === 'Customer Care' || t === 'Site Visit';
    }

    // ── Record icon style ────────────────────────────────────────────────────
    get recIconStyle() {
        const bg = this.header.iconBgColor || '#534ab7';
        return 'background:' + bg + ';';
    }

    get builderAppLabel() {
        return 'Home Builder Operations';
    }

    get builderSearchPlaceholder() {
        return 'Search builder POs, takeoffs, work orders, schedules, customer success, and aqua...';
    }

    get userInitials() {
        const first = (getFieldValue(this.currentUser?.data, FIRST_NAME) || '')[0] || '';
        const last  = (getFieldValue(this.currentUser?.data, LAST_NAME)  || '')[0] || '';
        return (first + last).toUpperCase() || '--';
    }

    get builderNavTabs() {
        return [
            { id: 'home', label: 'Home', className: 'sf-tab', disabled: false },
            { id: 'accounts', label: 'Accounts', className: 'sf-tab', disabled: false },
            { id: 'builderPo', label: 'Builder PO', className: 'sf-tab', disabled: false },
            { id: 'takeoff', label: 'Takeoff', className: 'sf-tab', disabled: false },
            { id: 'workorders', label: 'Work Order', className: 'sf-tab on', disabled: false },
            { id: 'scheduling', label: 'Scheduling', className: 'sf-tab', disabled: false },
            { id: 'customerSuccess', label: 'Customer Success', className: 'sf-tab', disabled: false },
            { id: 'aqua', label: 'Aqua', className: 'sf-tab', disabled: false }
        ];
    }

    // ── Warning banner class ─────────────────────────────────────────────────
    get warningBannerClass() {
        const sev = this.primaryWarning?.severity;
        if (sev === 'error')   return 'ab ab-r';
        if (sev === 'info')    return 'ab ab-b';
        return 'ab ab-a';
    }

    // ── Highlights bar ────────────────────────────────────────────────────────
    get highlightsItems() {
        const h  = this.header;
        const src = this.sourceSummary;
        const cls = 'hl-value';
        const amb = 'hl-value amber';
        const red = 'hl-value red';
        const grn = 'hl-value green';

        if (this.isFinishedJob) {
            return [
                { id: 'parentWo',  label: 'Parent WO',        value: h.parentWorkOrderName || '—', hlValueClass: cls },
                { id: 'stage',     label: 'Stage',            value: h.currentPathStep     || '—', hlValueClass: amb },
                { id: 'reason',    label: 'Reason',           value: src.fjReasonCode      || '—', hlValueClass: red },
                { id: 'charge',    label: 'Charge',           value: h.billableType        || 'Free Correction', hlValueClass: grn },
                { id: 'remaining', label: 'Remaining Items',  value: String(this.scopeItems.length), hlValueClass: amb },
                { id: 'photos',    label: 'Photos',           value: (this.closeout.photoCount || 0) + ' / ' + (this.closeout.photoRequired || 4), hlValueClass: cls }
            ];
        }
        if (this.isWarranty) {
            return [
                { id: 'parentWo',  label: 'Parent WO',        value: h.parentWorkOrderName || '—', hlValueClass: cls },
                { id: 'stage',     label: 'Stage',            value: h.currentPathStep     || '—', hlValueClass: amb },
                { id: 'coverage',  label: 'Coverage',         value: src.warrantyCoverageStatus || 'Pending', hlValueClass: amb },
                { id: 'type',      label: 'Type',             value: src.warrantyCoverageType   || '—', hlValueClass: cls },
                { id: 'billable',  label: 'Billable',         value: h.billableType        || '—', hlValueClass: amb },
                { id: 'siteVisit', label: 'Site Visit',       value: '—', hlValueClass: cls }
            ];
        }
        if (this.isCustomerCare) {
            return [
                { id: 'case',      label: 'Case',             value: src.caseNumber        || '—', hlValueClass: cls },
                { id: 'stage',     label: 'Stage',            value: h.currentPathStep     || '—', hlValueClass: amb },
                { id: 'priority',  label: 'Priority',         value: src.casePriorityTier  || '—', hlValueClass: red },
                { id: 'epoDays',   label: 'EPO Days',         value: '—', hlValueClass: amb },
                { id: 'billable',  label: 'Billable',         value: h.billableType        || '—', hlValueClass: cls },
                { id: 'owner',     label: 'Owner',            value: src.caseCmName        || '—', hlValueClass: cls }
            ];
        }
        return [];
    }

    // ── Navigation ───────────────────────────────────────────────────────────
    handleOpenParent() {
        if (!this.header.parentWorkOrderId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/lightning/r/WorkOrder/${this.header.parentWorkOrderId}/view` }
        });
    }

    handleRefresh() {
        this._loading = true;
        refreshApex(this._wiredPage).then(() => { this._loading = false; });
    }

    handleSave() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }

    handleConfirmScope() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }

    handleClassifyWarranty() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }

    handleNewAction() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'new' },
            state: { defaultFieldValues: 'WhatId=' + (this.recordId || '') }
        });
    }

    handleNewTask() {
        this.navigateQuickAction(NEW_TASK_ACTION);
    }

    handleNewNote() {
        this.navigateQuickAction(NEW_NOTE_ACTION);
    }

    handleOpenFiles() {
        if (!this.recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/lightning/r/Work_Order__c/${this.recordId}/related/AttachedContentDocuments/view` }
        });
    }

    handleOpenDocument(event) {
        const url = event.currentTarget.dataset.url;
        if (!url) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url }
        });
    }

    handleOpenWorkOrder() {
        if (this.recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: `/lightning/r/WorkOrder/${this.recordId}/view` }
            });
        }
    }

    handleEditWorkOrder() {
        if (this.recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: this.recordId, actionName: 'edit' }
            });
        }
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
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: { objectApiName: 'Takeoff__c', actionName: 'home' }
                });
                break;
            case 'workorders':
                this.handleOpenWorkOrder();
                break;
            case 'scheduling':
                this[NavigationMixin.Navigate]({
                    type: 'standard__navItemPage',
                    attributes: { apiName: 'Scheduling_Console' }
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

    navigateQuickAction(apiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName },
            state: { recordId: this.recordId }
        });
    }
}