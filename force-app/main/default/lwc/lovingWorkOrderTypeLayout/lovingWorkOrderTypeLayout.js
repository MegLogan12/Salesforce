import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import { updateRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import WORKORDER_OBJECT from '@salesforce/schema/WorkOrder';
import WO_TYPE_FIELD from '@salesforce/schema/WorkOrder.Work_Order_Type__c';
import WO_STATUS_FIELD from '@salesforce/schema/WorkOrder.Status';
import getWorkOrderRecord from '@salesforce/apex/LovingWorkOrderTypeController.getWorkOrderRecord';
import submitJobComplete from '@salesforce/apex/LovingWorkOrderTypeController.submitJobComplete';

const INSTALL_TYPES    = new Set(['Production Install', 'Production_Install', 'Plant_Sod_Install']);
const CASE_TYPES       = new Set(['Warranty', 'Customer Success', 'Customer Care', 'Customer_Care']);
const AQUA_TYPES       = new Set(['Aqua Check', 'Aqua_Check', 'Aqua Pickup', 'Aqua_Pickup', 'Aqua Emergency', 'Aqua_Emergency']);
const IRRIGATION_TYPES = new Set(['Irrigation', 'Inground_Irrigation', 'Temporary_Irrigation']);
const GRADING_TYPES    = new Set(['Grading', 'Plant_Sod_Grading', 'Land_Development']);
const EXECUTION_TYPES  = new Set(['Lawn Care', 'Hardscape']);

const NOTICE_MAP = {
    'Production Install': 'PO · Takeoff · Package · QI · Invoice readiness.',
    'Finished Job': 'FM-owned return work. Foreman flags · FM reviews and approves.',
    Warranty: 'Required before scheduling: coverage, responsibility, photos, billable decision.',
    'Customer Success': 'Case or customer issue. Track source, priority, SLA, coverage, and resolution.',
    'Aqua Check': 'Routine health check: sod score, flags, photos, equipment condition, repair needs.',
    'Aqua Pickup': 'Closes temp irrigation. Verify home status, remove equipment, recover inventory.',
    'Aqua Emergency': 'Same-day exception. Required: reason, SLA, issue photo, part use, dispatch priority.',
    'Site Visit': 'Pre-work conditions: measurements, access, red flags, photos, takeoff readiness.',
    Irrigation: 'Zone, controller, valve, head, water source, photos, and repair path.',
    Grading: '24 hrs before install. Separate crew accountability and scheduling proof.',
    'Lawn Care': 'Live schedule, photo proof, and closeout notes.',
    'Hardscape': 'Live schedule, field proof, and closeout notes.',
    'Loading Ticket': 'Verifies truck load. Supplier-delivered material verified at arrival only.',
    'QI Closeout': 'Required: photos, line completion, score, failed items, corrective action, handoff status.'
};

function normalizeType(value) {
    const raw = (value || '').replace(/_/g, ' ').trim();
    switch (raw) {
    case 'Production Install':
    case 'Plant Sod Install':
        return 'Production Install';
    case 'Finished Job':
        return 'Finished Job';
    case 'Customer Care':
    case 'Customer Success':
        return 'Customer Success';
    case 'Aqua New Install':
        return 'Production Install';
    case 'Aqua Check':
        return 'Aqua Check';
    case 'Aqua Pickup':
        return 'Aqua Pickup';
    case 'Aqua Emergency':
        return 'Aqua Emergency';
    case 'Site Visit':
        return 'Site Visit';
    case 'Inground Irrigation':
    case 'Temporary Irrigation':
    case 'Irrigation':
        return 'Irrigation';
    case 'Plant Sod Grading':
    case 'Land Development':
    case 'Grading':
        return 'Grading';
    case 'Lawn Care':
        return 'Lawn Care';
    case 'Hardscape':
        return 'Hardscape';
    case 'Loading Ticket':
        return 'Loading Ticket';
    case 'QI Closeout':
        return 'QI Closeout';
    default:
        return raw;
    }
}

export default class LovingWorkOrderTypeLayout extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isSubmitting = false;
    @track isEditingTypeStage = false;
    @track selectedTypeValue;
    @track selectedStatusValue;
    _wiredResult;

    @wire(getObjectInfo, { objectApiName: WORKORDER_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: WO_TYPE_FIELD })
    woTypePicklist;

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: WO_STATUS_FIELD })
    woStatusPicklist;

    get recordTypeId() {
        return this.objectInfo?.data?.defaultRecordTypeId;
    }

    @wire(getWorkOrderRecord, { woId: '$recordId' })
    wiredWo(result) {
        this._wiredResult = result;
    }

    get dto() {
        return this._wiredResult && this._wiredResult.data ? this._wiredResult.data : null;
    }

    get isLoading() {
        return !this._wiredResult;
    }

    get hasError() {
        return this._wiredResult && this._wiredResult.error;
    }

    get errorMessage() {
        if (!this._wiredResult || !this._wiredResult.error) return '';
        const err = this._wiredResult.error;
        return (err.body && err.body.message) ? err.body.message : 'Unable to load work order record.';
    }

    // Resolved type — checks RecordType.DeveloperName first, falls back to custom picklist
    get woType() {
        if (!this.dto) return '';
        return normalizeType(this.dto.woType || this.dto.recordTypeName || '');
    }

    get woTypeOptions() {
        return (this.woTypePicklist?.data?.values || []).map(v => ({ label: v.label, value: v.value }));
    }

    get statusOptions() {
        return (this.woStatusPicklist?.data?.values || []).map(v => ({ label: v.label, value: v.value }));
    }

    get woTypeLabel() {
        const value = this.woType;
        if (!value) return '';
        if (value === 'Customer Care') return 'Customer Success';
        const opt = this.woTypeOptions.find(o => o.value === value);
        return opt ? opt.label : value;
    }

    get effectiveStatus() {
        if (!this.dto) return 'New';
        const raw = this.dto.status || 'New';
        return raw;
    }

    get statusLabel() {
        const value = this.effectiveStatus;
        const opt = this.statusOptions.find(o => o.value === value);
        return opt ? opt.label : value;
    }

    // --- Notice banner ---

    get noticeText() {
        return NOTICE_MAP[this.woType] || '';
    }

    get noticeClass() {
        const t = this.woType;
        const warn = (t === 'Aqua Emergency' || t === 'Loading Ticket');
        return warn ? 'lwtl-notice lwtl-notice-warn' : 'lwtl-notice';
    }

    // --- Type flags (standard) ---

    get showInstallScope() {
        return this.dto && INSTALL_TYPES.has(this.woType);
    }

    get showCaseLink() {
        return this.dto && CASE_TYPES.has(this.woType);
    }

    get showParentWoLink() {
        return this.dto && (this.woType === 'Finished Job' || this.woType === 'QI Closeout');
    }

    get showSaSection() {
        return this.dto && this.dto.saId != null;
    }

    get showDescriptionSection() {
        // For types with a dedicated type section that handles description, skip the generic card
        const typesWithDescInSection = new Set([
            'Warranty', 'Customer Success', 'Finished Job',
            'Aqua Check', 'Aqua Pickup', 'Aqua Emergency',
            'Site Visit', 'Irrigation', 'Grading', 'Loading Ticket', 'QI Closeout'
        ]);
        if (this.dto && typesWithDescInSection.has(this.woType)) return false;
        return this.dto && !!(this.dto.description || this.dto.jobDescription);
    }

    get hasNotes() {
        return this.dto && (this.dto.invoiceNotes || this.dto.outsidePoNotes);
    }

    get showJobCompleteTimestamp() {
        return this.dto && this.dto.jobCompleteSubmittedAt;
    }

    // --- Type-specific section flags ---

    get showFinishedJobSection() {
        return this.dto && this.woType === 'Finished Job';
    }

    get showWarrantySection() {
        return this.dto && this.woType === 'Warranty';
    }

    get showCustomerCareSection() {
        return this.dto && this.woType === 'Customer Success';
    }

    get showAquaCheckSection() {
        return this.dto && this.woType === 'Aqua Check';
    }

    get showAquaPickupSection() {
        return this.dto && this.woType === 'Aqua Pickup';
    }

    get showAquaEmergencySection() {
        return this.dto && this.woType === 'Aqua Emergency';
    }

    get showSiteVisitSection() {
        return this.dto && this.woType === 'Site Visit';
    }

    get showIrrigationSection() {
        return this.dto && IRRIGATION_TYPES.has(this.woType);
    }

    get showGradingSection() {
        return this.dto && GRADING_TYPES.has(this.woType);
    }

    get showLoadingSection() {
        const t = this.woType;
        return this.dto && t === 'Loading Ticket';
    }

    get showQiSection() {
        const t = this.woType;
        return this.dto && t === 'QI Closeout';
    }

    // --- Path ---

    get pathStyle() {
        const count = this.dto && this.dto.stages ? this.dto.stages.length : 5;
        return '--steps:' + count;
    }

    get stagesWithClasses() {
        if (!this.dto || !this.dto.stages) return [];
        return this.dto.stages.map(s => {
            let cssClass = 'lwtl-step';
            if (s.state === 'done') cssClass += ' lwtl-step-done';
            else if (s.state === 'active') cssClass += ' lwtl-step-active';
            return Object.assign({}, s, { cssClass });
        });
    }

    // --- Gates ---

    get gatesWithClasses() {
        if (!this.dto || !this.dto.gates) return [];
        return this.dto.gates.map(g => {
            const rowClass = 'lwtl-action-row' + (g.complete ? ' lwtl-gate-done' : ' lwtl-gate-pending');
            const iconClass = 'lwtl-gate-icon' + (g.complete ? ' lwtl-gate-icon-done' : ' lwtl-gate-icon-pending');
            const icon = g.complete ? '✓' : '○';
            return Object.assign({}, g, { rowClass, iconClass, icon });
        });
    }

    // --- Quick Actions by record type ---

    get quickActions() {
        if (!this.dto) return [];
        const rt = this.woType;
        const canSubmit = this.dto.canSubmitComplete;
        const blockReason = this.dto.submitBlockReason;
        const submitNote = canSubmit ? 'Ready to submit' : blockReason;
        const submitRow = canSubmit ? 'lwtl-action-row' : 'lwtl-action-row lwtl-action-disabled';
        const saRow = this.dto.saId ? 'lwtl-action-row' : 'lwtl-action-row lwtl-action-disabled';
        const saNote = this.dto.saId ? 'FSL scheduling record' : 'No service appointment linked yet';
        const caseRow = this.dto.caseId ? 'lwtl-action-row' : 'lwtl-action-row lwtl-action-disabled';
        const caseNote = this.dto.caseId ? 'Linked case record' : 'No case linked';
        const parentWoRow = this.dto.parentWoId ? 'lwtl-action-row' : 'lwtl-action-row lwtl-action-disabled';
        const parentWoNote = this.dto.parentWoId ? 'Parent WO record' : 'No source work order linked';

        if (rt === 'Production Install') {
            return [
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Photo', icon: '📷', actionType: 'file', target: null, note: 'Attach closeout photo', rowClass: 'lwtl-action-row' },
                { label: 'Add Invoice Notes', icon: '✏️', actionType: 'edit', target: 'Invoice_Notes__c', note: 'Required before closeout', rowClass: 'lwtl-action-row' },
                { label: 'Flag Finished Job Need', icon: '🚩', actionType: 'navigate', target: 'WorkOrder_new_FinishedJob', note: 'Create FJ from this WO', rowClass: 'lwtl-action-row' },
                { label: 'Submit Job Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (rt === 'Finished Job') {
            return [
                { label: 'Open Source Work Order', icon: '↗', actionType: 'navigate', target: 'WorkOrder', note: parentWoNote, rowClass: parentWoRow },
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Proof Photo', icon: '📷', actionType: 'file', target: null, note: 'Before + after required', rowClass: 'lwtl-action-row' },
                { label: 'Submit Job Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (rt === 'Warranty') {
            return [
                { label: 'Open Source Case', icon: '📋', actionType: 'navigate', target: 'Case', note: caseNote, rowClass: caseRow },
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Issue Photo', icon: '📷', actionType: 'file', target: null, note: 'Required for coverage review', rowClass: 'lwtl-action-row' },
                { label: 'Submit Job Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (rt === 'Customer Success') {
            return [
                { label: 'Open Source Case', icon: '📋', actionType: 'navigate', target: 'Case', note: caseNote, rowClass: caseRow },
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Photo', icon: '📷', actionType: 'file', target: null, note: 'Issue documentation', rowClass: 'lwtl-action-row' },
                { label: 'Submit Job Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (rt === 'Site Visit') {
            return [
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Site Photo', icon: '📷', actionType: 'file', target: null, note: 'Site condition documentation', rowClass: 'lwtl-action-row' },
                { label: 'Submit Job Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (rt === 'Aqua Check') {
            return [
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Check Photos', icon: '📷', actionType: 'file', target: null, note: 'Yard + equipment required', rowClass: 'lwtl-action-row' },
                { label: 'Submit Check Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (rt === 'Aqua Pickup') {
            return [
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Pickup Photo', icon: '📷', actionType: 'file', target: null, note: 'Retrieved equipment required', rowClass: 'lwtl-action-row' },
                { label: 'Submit Pickup Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (rt === 'Aqua Emergency') {
            return [
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Issue Photo', icon: '📷', actionType: 'file', target: null, note: 'Emergency issue photo required', rowClass: 'lwtl-action-row' },
                { label: 'Submit Repair Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (IRRIGATION_TYPES.has(rt)) {
            return [
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Irrigation Photo', icon: '📷', actionType: 'file', target: null, note: 'Controller + zone photo required', rowClass: 'lwtl-action-row' },
                { label: 'Submit Job Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (GRADING_TYPES.has(rt)) {
            return [
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Site Photo', icon: '📷', actionType: 'file', target: null, note: 'Before + after required', rowClass: 'lwtl-action-row' },
                { label: 'Submit Job Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        if (EXECUTION_TYPES.has(rt)) {
            return [
                { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
                { label: 'Upload Field Photo', icon: '📷', actionType: 'file', target: null, note: 'Field proof required', rowClass: 'lwtl-action-row' },
                { label: 'Add Closeout Notes', icon: '✏️', actionType: 'edit', target: 'Invoice_Notes__c', note: 'Required before closeout', rowClass: 'lwtl-action-row' },
                { label: 'Submit Job Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
            ];
        }
        // Default / Loading / QI
        return [
            { label: 'Open Service Appointment', icon: '📅', actionType: 'navigate', target: 'ServiceAppointment', note: saNote, rowClass: saRow },
            { label: 'Upload Photo', icon: '📷', actionType: 'file', target: null, note: null, rowClass: 'lwtl-action-row' },
            { label: 'Submit Job Complete', icon: '✓', actionType: 'submit', target: null, note: submitNote, rowClass: submitRow }
        ];
    }

    get hasLineItems() {
        return !!(this.dto && this.dto.lineItems && this.dto.lineItems.length);
    }

    get lineItems() {
        return this.dto?.lineItems || [];
    }

    get lineItemEmptyMessage() {
        if (this.showInstallScope) {
            return 'No scope rows created yet for this work order.';
        }
        return 'No work order line items are linked yet.';
    }

    // --- Field display object helper (value + css for missing-state) ---

    _fieldObj(val) {
        if (val) return { value: val, css: '' };
        return { value: '—', css: '' };
    }

    // Named field object getters — used for fields that show missing-state UX
    get builderField() {
        const v = this.dto && (this.dto.accountName || this.dto.clientName);
        return this._fieldObj(v || null);
    }
    get divisionField()   { return this._fieldObj(this.dto && this.dto.division       || null); }
    get communityField()  { return this._fieldObj(this.dto && this.dto.communityName  || null); }
    get lotField()        { return this._fieldObj(this.dto && this.dto.lotNumber      || null); }
    get fmField()         { return this._fieldObj(this.dto && this.dto.fieldManagerName || null); }
    get foremanField()    { return this._fieldObj(this.dto && this.dto.foremanName    || null); }
    get crewField()       { return this._fieldObj(this.dto && this.dto.crewName       || null); }
    get poField()         { return this._fieldObj(this.dto && this.dto.poNumber       || null); }
    get builderWoField()  { return this._fieldObj(this.dto && this.dto.builderWoNumber || null); }

    // --- Standard field display getters ---

    get workTypeDisplay() { return (this.dto && this.dto.workTypeName) ? this.dto.workTypeName : '—'; }
    get priorityDisplay() { return (this.dto && this.dto.priority) ? this.dto.priority : '—'; }

    get builderAccountDisplay() {
        if (!this.dto) return '—';
        return this.dto.accountName || this.dto.clientName || '—';
    }

    get contactDisplay() { return (this.dto && this.dto.contactName) ? this.dto.contactName : '—'; }
    get caseDisplay() { return (this.dto && this.dto.caseId) ? this.dto.caseId : 'No case linked'; }
    get parentWoDisplay() { return (this.dto && this.dto.parentWoId) ? this.dto.parentWoId : 'No parent WO'; }

    get descriptionDisplay() {
        if (!this.dto) return '—';
        return this.dto.description || this.dto.jobDescription || '—';
    }

    get totalPriceDisplay() {
        if (!this.dto || this.dto.totalPrice == null) return '—';
        return '$' + Number(this.dto.totalPrice).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    get lineItemCountDisplay() {
        if (!this.dto) return '—';
        return this.dto.lineItemCount != null ? String(this.dto.lineItemCount) : '0';
    }

    // --- Standard FSL: Service Appointment display getters ---

    get saNumberDisplay() { return (this.dto && this.dto.saNumber) ? this.dto.saNumber : '—'; }
    get saStatusDisplay() {
        if (!this.dto || !this.dto.saStatus) return '—';
        const s = this.dto.saStatus;
        return (s === 'None') ? 'Not Scheduled' : s;
    }
    get saScheduledDisplay() { return (this.dto && this.dto.saScheduledStart) ? this.dto.saScheduledStart : '—'; }
    get saEndDisplay() { return (this.dto && this.dto.saScheduledEnd) ? this.dto.saScheduledEnd : '—'; }
    get saDurationDisplay() { return (this.dto && this.dto.saDuration != null) ? this.dto.saDuration + ' min' : '—'; }
    get saTerritoryDisplay() { return (this.dto && this.dto.saTerritory) ? this.dto.saTerritory : '—'; }
    get saActualStartDisplay() { return (this.dto && this.dto.saActualStart) ? this.dto.saActualStart : '—'; }

    // --- LOVING custom field display getters ---

    get photoCountDisplay() { return this.dto ? this.dto.photoCount + ' file(s)' : '—'; }
    get divisionDisplay() { return (this.dto && this.dto.division) ? this.dto.division : '—'; }
    get communityDisplay() { return (this.dto && this.dto.communityName) ? this.dto.communityName : '—'; }
    get lotDisplay() { return (this.dto && this.dto.lotNumber) ? this.dto.lotNumber : '—'; }
    get poDisplay() { return (this.dto && this.dto.poNumber) ? this.dto.poNumber : '—'; }
    get builderWoDisplay() { return (this.dto && this.dto.builderWoNumber) ? this.dto.builderWoNumber : '—'; }
    get fmDisplay() { return (this.dto && this.dto.fieldManagerName) ? this.dto.fieldManagerName : '—'; }
    get foremanDisplay() { return (this.dto && this.dto.foremanName) ? this.dto.foremanName : '—'; }
    get crewDisplay() { return (this.dto && this.dto.crewName) ? this.dto.crewName : '—'; }
    get scheduledDateDisplay() { return (this.dto && this.dto.scheduledDate) ? this.dto.scheduledDate : '—'; }
    get schedProposalDisplay() { return (this.dto && this.dto.scheduleProposalStatus) ? this.dto.scheduleProposalStatus : '—'; }
    get jobHealthDisplay() { return (this.dto && this.dto.jobHealth) ? this.dto.jobHealth : '—'; }
    get sodDisplay() { return (this.dto && this.dto.sodSqft != null) ? this.dto.sodSqft + ' sqft' : '—'; }
    get mulchDisplay() { return (this.dto && this.dto.mulchCy != null) ? this.dto.mulchCy + ' CY' : '—'; }
    get treeDisplay() { return (this.dto && this.dto.treeQty != null) ? this.dto.treeQty + ' ea' : '—'; }
    get plantDisplay() { return (this.dto && this.dto.plantQty != null) ? this.dto.plantQty + ' ea' : '—'; }
    get sodSpeciesDisplay() { return (this.dto && this.dto.sodSpecies) ? this.dto.sodSpecies : '—'; }
    get takeoffLabel() { return this.dto ? (this.dto.takeoffCompleted ? 'Yes' : 'Not complete') : '—'; }
    get takeoffMismatchLabel() { return this.dto ? (this.dto.takeoffMismatch ? 'Mismatch flagged' : 'No mismatch') : '—'; }
    get deliveryQcDisplay() { return (this.dto && this.dto.deliveryQcStatus) ? this.dto.deliveryQcStatus : '—'; }
    get jobCompleteDisplay() { return (this.dto && this.dto.jobCompleteSubmittedAt) ? this.dto.jobCompleteSubmittedAt : '—'; }

    get invoiceAmountDisplay() {
        if (!this.dto || this.dto.invoiceAmount == null) return '—';
        return '$' + Number(this.dto.invoiceAmount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    get statusBadgeClass() {
        if (!this.dto) return 'lwtl-badge';
        const s = this.effectiveStatus;
        if (s === 'In Progress') return 'lwtl-badge lwtl-badge-blue';
        if (s === 'Closed' || s === 'Paid') return 'lwtl-badge lwtl-badge-green';
        if (s === 'Cancelled' || s === 'Cannot Complete') return 'lwtl-badge lwtl-badge-red';
        if (s === 'Pending Takeoff' || s === 'New' || s === 'Ready to Schedule') return 'lwtl-badge lwtl-badge-gray';
        return 'lwtl-badge lwtl-badge-orange';
    }

    get typeBadgeClass() {
        const t = this.woType;
        if (INSTALL_TYPES.has(t)) return 'lwtl-badge lwtl-badge-green';
        if (t === 'Warranty' || t === 'Customer Success') return 'lwtl-badge lwtl-badge-orange';
        if (t === 'Aqua Emergency') return 'lwtl-badge lwtl-badge-red';
        if (AQUA_TYPES.has(t)) return 'lwtl-badge lwtl-badge-blue';
        if (t === 'Site Visit') return 'lwtl-badge';
        if (IRRIGATION_TYPES.has(t) || GRADING_TYPES.has(t) || EXECUTION_TYPES.has(t)) return 'lwtl-badge lwtl-badge-orange';
        return 'lwtl-badge lwtl-badge-gray';
    }

    // Aqua section display helpers (show available DTO data with type-appropriate labels)
    get aquaTechDisplay() { return this.foremanDisplay; }
    get aquaRouteWindowDisplay() { return this.scheduledDateDisplay; }

    // Site Visit measurement summary (shows populated measurements if any)
    get siteVisitMeasurementsDisplay() {
        if (!this.dto) return '—';
        const parts = [];
        if (this.dto.sodSqft) parts.push(this.dto.sodSqft + ' sqft sod');
        if (this.dto.mulchCy) parts.push(this.dto.mulchCy + ' CY mulch');
        if (this.dto.treeQty) parts.push(this.dto.treeQty + ' trees');
        if (this.dto.plantQty) parts.push(this.dto.plantQty + ' plants');
        return parts.length ? parts.join(' · ') : '—';
    }

    // --- Action handlers ---

    handleEditRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'WorkOrder',
                actionName: 'edit'
            }
        });
    }

    handleEditTypeStage() {
        this.isEditingTypeStage = true;
        this.selectedTypeValue = this.woType || null;
        this.selectedStatusValue = this.effectiveStatus || null;
    }

    handleTypeChange(event) {
        this.selectedTypeValue = event.detail.value;
    }

    handleStatusChange(event) {
        this.selectedStatusValue = event.detail.value;
    }

    handleCancelTypeStage() {
        this.isEditingTypeStage = false;
        this.selectedTypeValue = null;
        this.selectedStatusValue = null;
    }

    async handleSaveTypeStage() {
        if (!this.recordId) return;
        let nextStatus = this.selectedStatusValue;
        if (this.dto?.takeoffCompleted === true && nextStatus === 'Pending Takeoff') {
            nextStatus = 'Ready to Schedule';
        }
        try {
            await updateRecord({
                fields: {
                    Id: this.recordId,
                    Work_Order_Type__c: this.selectedTypeValue,
                    Status: nextStatus
                }
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Saved',
                message: 'Type and stage updated.',
                variant: 'success'
            }));
            this.isEditingTypeStage = false;
            this.selectedTypeValue = null;
            this.selectedStatusValue = null;
            await refreshApex(this._wiredResult);
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Save failed',
                message: (err?.body && err.body.message) ? err.body.message : 'Unable to update type/stage.',
                variant: 'error'
            }));
        }
    }

    handleActionClick(event) {
        const actionType = event.currentTarget.dataset.type;
        if (actionType === 'submit') {
            this.handleSubmitComplete();
        } else if (actionType === 'navigate') {
            const target = event.currentTarget.dataset.target;
            if (target === 'ServiceAppointment') {
                if (this.dto?.saId) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: { recordId: this.dto.saId, objectApiName: 'ServiceAppointment', actionName: 'view' }
                    });
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'No Service Appointment',
                        message: 'This work order does not have a linked service appointment yet.',
                        variant: 'info'
                    }));
                }
            } else if (target === 'WorkOrder') {
                if (this.dto && this.dto.parentWoId) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: { recordId: this.dto.parentWoId, objectApiName: 'WorkOrder', actionName: 'view' }
                    });
                }
            } else if (target === 'Case') {
                if (this.dto && this.dto.caseId) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: { recordId: this.dto.caseId, objectApiName: 'Case', actionName: 'view' }
                    });
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'No Case Linked',
                        message: 'This work order does not have a linked case.',
                        variant: 'info'
                    }));
                }
            }
        } else if (actionType === 'file') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordRelationshipPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'WorkOrder',
                    relationshipApiName: 'AttachedContentDocuments',
                    actionName: 'view'
                }
            });
        }
    }

    async handleSubmitComplete() {
        if (!this.dto || !this.dto.canSubmitComplete) return;
        this.isSubmitting = true;
        try {
            const result = await submitJobComplete({ woId: this.recordId });
            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Job Complete Submitted',
                    message: result.message,
                    variant: 'success'
                }));
                await refreshApex(this._wiredResult);
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Cannot Submit',
                    message: result.message,
                    variant: 'error'
                }));
            }
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: (err.body && err.body.message) ? err.body.message : 'Submit failed.',
                variant: 'error'
            }));
        } finally {
            this.isSubmitting = false;
        }
    }
}