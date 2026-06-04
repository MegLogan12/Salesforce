import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLVisibleWorkspaceController.getPageData';

const NEW_TASK_ACTION = 'Global.NewTask';
const STATUS_PATH = ['Created', 'Scheduled', 'In Progress', 'Punch', 'Closeout', 'Closed'];

export default class OdlWorkOrderFieldExecutionWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    pageData;
    error;

    @wire(getPageData, { recordId: '$recordId' })
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.pageData = undefined;
        }
    }

    get hasData() {
        return Boolean(this.pageData);
    }

    get showHomeBuilderWorkspace() {
        return this.pageData?.routeWorkspace === 'homebuilder';
    }

    get summaryFields() {
        return this.getSectionFields('Work Order Summary');
    }

    get executionFields() {
        return this.getSectionFields('Execution Details');
    }

    get homeownerFields() {
        return this.getSectionFields('Homeowner / Property');
    }

    get opportunityFields() {
        return this.getSectionFields('Opportunity Context');
    }

    get workOrderNumber() {
        return this.getFieldValue('Work Order Summary', 'Work Order Number');
    }

    get statusValue() {
        return this.getFieldValue('Work Order Summary', 'Status');
    }

    get divisionValue() {
        return this.getFieldValue('Work Order Summary', 'Division');
    }

    get jobTypeValue() {
        return this.getFieldValue('Work Order Summary', 'Job Type');
    }

    get opportunityName() {
        return this.getFieldValue('Opportunity Context', 'Opportunity');
    }

    get opportunityUrl() {
        return this.getFieldUrl('Opportunity Context', 'Opportunity');
    }

    get opportunityId() {
        return this.recordIdFromUrl(this.opportunityUrl);
    }

    get disableOpenOpportunity() {
        return !this.opportunityId;
    }

    get accountName() {
        return this.getFieldValue('Homeowner / Property', 'Account');
    }

    get accountUrl() {
        return this.getFieldUrl('Homeowner / Property', 'Account');
    }

    get accountId() {
        return this.recordIdFromUrl(this.accountUrl);
    }

    get disableOpenAccount() {
        return !this.accountId;
    }

    get fieldManagerValue() {
        return this.getFieldValue('Execution Details', 'Field Manager');
    }

    get scheduledDateValue() {
        return this.getFieldValue('Execution Details', 'Scheduled Date');
    }

    get targetCompletionValue() {
        return this.appointmentRows[this.appointmentRows.length - 1]?.dateText || this.scheduledDateValue;
    }

    get fileRows() {
        return this.getSectionRows('Files / Photos').map((row, index) => ({ ...row, key: `file-${index}` }));
    }

    get hasNoFiles() {
        return this.fileRows.length === 0;
    }

    get hasFiles() {
        return !this.hasNoFiles;
    }

    get appointmentRows() {
        return this.getSectionRows('Related Service Appointments').map((row, index) => ({ ...row, key: `appt-${index}` }));
    }

    get appointmentCount() {
        return String(this.appointmentRows.length);
    }

    get punchRows() {
        const sourceRows = this.getSectionRows('Closeout / Warranty Handoff').length
            ? this.getSectionRows('Closeout / Warranty Handoff')
            : this.getSectionRows('Change Orders');
        return sourceRows.map((row, index) => ({
            ...row,
            key: `punch-${index}`,
            ownerText: row.subtext || this.fieldManagerValue || 'Field Team',
            dueText: row.dateText || this.scheduledDateValue
        }));
    }

    get hasNoPunchItems() {
        return this.punchRows.length === 0;
    }

    get hasPunchItems() {
        return !this.hasNoPunchItems;
    }

    get statusPath() {
        const current = (this.statusValue || '').toLowerCase();
        let currentSeen = false;
        return STATUS_PATH.map((label) => {
            const normalizedLabel = label.toLowerCase();
            const isCurrent = normalizedLabel === current || (current.includes('progress') && normalizedLabel === 'in progress');
            const state = currentSeen ? 'upcoming' : (isCurrent ? 'current' : 'done');
            if (isCurrent) currentSeen = true;
            return {
                label,
                className: `path-step ${state}`
            };
        });
    }

    get openItemsCount() {
        return String((this.pageData?.openItems || []).length);
    }

    get errorMessage() {
        if (!this.error) return '';
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((item) => item.message).join(', ');
        }
        return this.error.body ? this.error.body.message : this.error.message;
    }

    getSectionFields(title) {
        return (this.pageData?.sections || []).find((section) => section.title === title)?.fields || [];
    }

    getSectionRows(title) {
        return (this.pageData?.sections || []).find((section) => section.title === title)?.rows || [];
    }

    getFieldValue(sectionTitle, fieldLabel) {
        return this.getSectionFields(sectionTitle).find((item) => item.label === fieldLabel)?.value || '';
    }

    getFieldUrl(sectionTitle, fieldLabel) {
        return this.getSectionFields(sectionTitle).find((item) => item.label === fieldLabel)?.url || '';
    }

    recordIdFromUrl(url) {
        if (!url) return '';
        const clean = url.split('?')[0];
        const segments = clean.split('/').filter(Boolean);
        return segments.length ? segments[segments.length - 1] : '';
    }

    handleOpenMobileView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'view' }
        });
    }

    handleEditWorkOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }

    handleNewTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: NEW_TASK_ACTION },
            state: { recordId: this.recordId }
        });
    }

    handleOpenAppointments() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'WorkOrder',
                relationshipApiName: 'ServiceAppointments',
                actionName: 'view'
            }
        });
    }

    handleOpenFiles() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/r/WorkOrder/${this.recordId}/related/AttachedContentDocuments/view`
            }
        });
    }

    handleOpenOpportunity() {
        if (!this.opportunityId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.opportunityId,
                objectApiName: 'Opportunity',
                actionName: 'view'
            }
        });
    }

    handleOpenAccount() {
        if (!this.accountId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.accountId,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    handleOpenActivity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'WorkOrder',
                relationshipApiName: 'ActivityHistories',
                actionName: 'view'
            }
        });
    }

    handleUpdatePunchItem() {
        console.log('handleUpdatePunchItem');
    }
}