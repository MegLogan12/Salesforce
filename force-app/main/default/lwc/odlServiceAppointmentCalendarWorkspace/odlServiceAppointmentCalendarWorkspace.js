import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLServiceAppointmentCalendarController.getPageData';

export default class OdlServiceAppointmentCalendarWorkspace extends NavigationMixin(LightningElement) {
    pageData;

    @wire(getPageData)
    wiredData({ data }) {
        if (data) {
            this.pageData = data;
        }
    }

    get consultCount() { return this.pageData?.consultCount || 0; }
    get siteVisitCount() { return this.pageData?.siteVisitCount || 0; }
    get installCount() { return this.pageData?.installCount || 0; }
    get followUpCount() { return this.pageData?.followUpCount || 0; }
    get rows() { return this.pageData?.rows || []; }
    get lastTouch() { return this.pageData?.lastTouch || ''; }
    get voicemailStatus() { return this.pageData?.voicemailStatus || ''; }
    get nextFollowUp() { return this.pageData?.nextFollowUp || ''; }
    get openTasks() { return this.pageData?.openTasks || 0; }
    get calendarDays() {
        return (this.pageData?.calendarDays || []).map((day) => ({
            ...day,
            showEmpty: !day.events?.length
        }));
    }

    handleToday() {
        window.location.reload();
    }

    handleNewAppointment(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'ServiceAppointment',
                actionName: 'new'
            }
        });
    }
}