import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getRecordData from '@salesforce/apex/ODLServiceAppointmentConsoleController.getRecordData';

export default class OdlServiceAppointmentRecordWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;
    pageData;

    @wire(getRecordData, { serviceAppointmentId: '$recordId' })
    wiredData({ data }) {
        if (data) this.pageData = data;
    }

    get disableOpenWorkOrder() { return !this.pageData?.workOrderId; }
    get hasNoActivity() { return !this.pageData?.activityRows?.length; }
    get hasNoOpenItems() { return !this.pageData?.openItems?.length; }
    get hasActivity() { return !this.hasNoActivity; }
    get hasOpenItems() { return !this.hasNoOpenItems; }

    handleOpenWorkOrder() {
        if (!this.pageData?.workOrderId) return;
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: this.pageData.workOrderId, objectApiName: 'WorkOrder', actionName: 'view' } });
    }
    handleEdit() {
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: this.recordId, objectApiName: 'ServiceAppointment', actionName: 'edit' } });
    }
    handleNewTask() {
        this[NavigationMixin.Navigate]({ type: 'standard__quickAction', attributes: { apiName: 'Global.NewTask' }, state: { recordId: this.recordId } });
    }
    handleNewEvent() {
        const state = encodeDefaultFieldValues({
            Subject: this.pageData?.appointmentNumber || 'Service Appointment',
            Location: this.pageData?.address || '',
            Description: this.pageData?.subject || ''
        });
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Event', actionName: 'new' }, state: { defaultFieldValues: state } });
    }
}