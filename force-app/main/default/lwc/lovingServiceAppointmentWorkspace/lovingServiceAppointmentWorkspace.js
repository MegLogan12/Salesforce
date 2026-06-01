import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getWorkspace from '@salesforce/apex/LovingSAWorkspaceController.getWorkspace';

const SEND_EMAIL_ACTION = 'Global.SendEmail';
const LOG_CALL_ACTION = 'Global.LogACall';
const NEW_TASK_ACTION = 'Global.NewTask';
const NEW_EVENT_ACTION = 'Global.NewEvent';
const NEW_NOTE_ACTION = 'Global.NewNote';

const TABS = [
    { id: 'overview', label: 'Overview' },
    { id: 'crew', label: 'Crew + Route' },
    { id: 'builder', label: 'Parent Work Order' },
    { id: 'proof', label: 'Proof + Closeout' },
    { id: 'activity', label: 'Activity' }
];

export default class LovingServiceAppointmentWorkspace extends NavigationMixin(LightningElement) {
    static shellStyleId = 'loving-service-appointment-shell-style';
    @api recordId;
    activeTab = 'overview';
    workspace;
    error;

    @wire(getWorkspace, { serviceAppointmentId: '$recordId' })
    wiredWorkspace({ data, error }) {
        this.workspace = data;
        this.error = error;
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

    ensureShellStyle() {
        if (typeof window === 'undefined' || typeof document === 'undefined') {
            return;
        }
        if (!window.location.pathname.includes('/lightning/r/ServiceAppointment/')) {
            return;
        }
        if (document.getElementById(LovingServiceAppointmentWorkspace.shellStyleId)) {
            return;
        }
        const style = document.createElement('style');
        style.id = LovingServiceAppointmentWorkspace.shellStyleId;
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
        document.getElementById(LovingServiceAppointmentWorkspace.shellStyleId)?.remove();
    }

    get errorMessage() {
        return this.error?.body?.message || this.error?.message || 'This Service Appointment could not be loaded.';
    }

    get header() {
        return this.workspace?.header || {};
    }

    get builderAppLabel() {
        return 'Home Builder Operations';
    }

    get builderSearchPlaceholder() {
        return 'Search builder appointments, work orders, routes, crews, lot context, and customer success handoffs...';
    }

    get userInitials() {
        return 'ML';
    }

    get builderNavTabs() {
        return [
            { id: 'home', label: 'Home', className: 'sf-tab', disabled: false },
            { id: 'accounts', label: 'Accounts', className: 'sf-tab', disabled: false },
            { id: 'builderPo', label: 'Builder PO', className: 'sf-tab', disabled: false },
            { id: 'takeoff', label: 'Takeoff', className: 'sf-tab', disabled: false },
            { id: 'workorders', label: 'Work Order', className: 'sf-tab', disabled: !this.header.workOrderId },
            { id: 'scheduling', label: 'Scheduling', className: 'sf-tab on', disabled: false },
            { id: 'customerSuccess', label: 'Customer Success', className: 'sf-tab', disabled: false },
            { id: 'aqua', label: 'Aqua', className: 'sf-tab', disabled: false }
        ];
    }

    get crumbItems() {
        const values = [
            this.header.builderName,
            this.header.communityName,
            this.header.lotName
        ].filter((value) => value && value !== 'Not linked' && value !== '—');

        if (!values.length && this.header.serviceTerritory && this.header.serviceTerritory !== 'Not linked') {
            values.push(this.header.serviceTerritory);
        }
        if (this.header.workOrderNumber && this.header.workOrderNumber !== 'Not linked') {
            values.push(this.header.workOrderNumber);
        }
        if (!values.length && this.header.appointmentNumber) {
            values.push(this.header.appointmentNumber);
        }

        return values.map((value, index) => ({
            value,
            separatorKey: `${value}-${index}-separator`,
            isLast: index === values.length - 1
        }));
    }

    get headerMetaItems() {
        const rawItems = [
            { key: 'appointmentType', value: this.header.appointmentType, className: 'pill purple' },
            { key: 'status', value: this.header.status, className: 'pill blue' },
            { key: 'scheduledWindow', value: this.header.scheduledWindow, className: '' },
            { key: 'serviceTerritory', value: this.header.serviceTerritory, className: '' },
            { key: 'assignedResource', value: this.header.assignedResource, className: '' },
            { key: 'contactName', value: this.header.contactName, className: '' }
        ];

        return rawItems.filter((item) => this.isMeaningfulMetaValue(item.value));
    }

    get tabs() {
        return TABS.map((tab) => ({
            ...tab,
            className: `tab-button${this.activeTab === tab.id ? ' active' : ''}`
        }));
    }

    get kpis() {
        return (this.workspace?.kpis || []).map((kpi) => ({
            ...kpi,
            className: `kpi ${kpi.tone || 'gray'}`
        }));
    }

    get overviewRows() { return this.workspace?.overviewRows || []; }
    get typeRows() { return this.workspace?.typeRows || []; }
    get routeRows() { return this.workspace?.routeRows || []; }
    get builderRows() { return this.workspace?.builderRows || []; }
    get proofRows() { return this.workspace?.proofRows || []; }
    get activityRows() { return this.workspace?.activity || []; }
    get visionKpis() { return (this.workspace?.kpis || []).slice(0, 6); }

    get showOverview() { return this.activeTab === 'overview'; }
    get showCrew() { return this.activeTab === 'crew'; }
    get showBuilder() { return this.activeTab === 'builder'; }
    get showProof() { return this.activeTab === 'proof'; }
    get showActivity() { return this.activeTab === 'activity'; }

    get executionRows() {
        return this.routeRows.slice(0, 4);
    }

    get routeTimeline() {
        const tones = ['blue', 'aqua', 'amber', 'green'];
        return this.routeRows.map((row, index) => ({
            ...row,
            shortLabel: String(index + 1),
            dotClass: `dot ${tones[index % tones.length]}`
        }));
    }

    get disableOpenWorkOrder() {
        return !this.header.workOrderId;
    }

    get disableOpenAccount() {
        return !this.header.accountId;
    }

    get disableOpenContact() {
        return !this.header.contactId;
    }

    get disableEmail() {
        return !this.header.contactEmail;
    }

    get disableCall() {
        return !this.header.contactPhone;
    }

    get phoneHref() {
        return this.header.contactPhone ? `tel:${this.header.contactPhone}` : '';
    }

    isMeaningfulMetaValue(value) {
        return value && !['Not linked', '—', 'Unknown'].includes(value);
    }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.id;
    }

    handleBuilderTabClick(event) {
        const target = event.currentTarget.dataset.id;
        if (!target) {
            return;
        }
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
                if (!this.header.workOrderId) {
                    return;
                }
                this.openWorkOrder();
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

    openWorkOrder() {
        if (!this.header.workOrderId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/r/WorkOrder/${this.header.workOrderId}/view`
            }
        });
    }

    handleEditAppointment() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'ServiceAppointment',
                actionName: 'edit'
            }
        });
    }

    handleEmail() {
        if (this.disableEmail) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: SEND_EMAIL_ACTION
            },
            state: {
                recordId: this.recordId,
                defaultFieldValues: `ToAddress=${encodeURIComponent(this.header.contactEmail)}`
            }
        });
    }

    handleCall() {
        if (this.disableCall) {
            return;
        }
        window.open(this.phoneHref, '_self');
    }

    handleLogCall() {
        this.navigateQuickAction(LOG_CALL_ACTION);
    }

    handleNewTask() {
        this.navigateQuickAction(NEW_TASK_ACTION);
    }

    handleNewNote() {
        this.navigateQuickAction(NEW_NOTE_ACTION);
    }

    handleNewEvent() {
        this.navigateQuickAction(NEW_EVENT_ACTION);
    }

    handleOpenFiles() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/r/ServiceAppointment/${this.recordId}/related/AttachedContentDocuments/view`
            }
        });
    }

    openAccount() {
        if (this.disableOpenAccount) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/r/Account/${this.header.accountId}/view`
            }
        });
    }

    openContact() {
        if (this.disableOpenContact) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/r/Contact/${this.header.contactId}/view`
            }
        });
    }

    openCalendarEvent() {
        const fieldValues = encodeDefaultFieldValues({
            Subject: `${this.header.appointmentNumber || 'Service Appointment'}${this.header.workOrderNumber ? ' · ' + this.header.workOrderNumber : ''}`,
            Location: this.header.address || '',
            StartDateTime: this.header.schedStartIso || '',
            EndDateTime: this.header.schedEndIso || '',
            Description: [
                this.header.appointmentType || '',
                this.header.workOrderSubject || '',
                this.header.builderName || '',
                this.header.communityName || '',
                this.header.lotName || ''
            ].filter(Boolean).join(' · ')
        });
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Event',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: fieldValues,
                navigationLocation: 'RELATED_LIST'
            }
        });
    }

    navigateQuickAction(apiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName },
            state: { recordId: this.recordId }
        });
    }
}