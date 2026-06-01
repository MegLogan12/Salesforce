import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLTasksActivityController.getPageData';

export default class OdlTasksActivityWorkspace extends NavigationMixin(LightningElement) {
    searchTerm = '';
    pageData;
    error;

    @wire(getPageData)
    wiredData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.error = undefined;
        } else if (error) {
            this.error = (error.body && error.body.message) || 'Unable to load task data.';
            this.pageData = undefined;
        }
    }

    get rows() { return this.pageData?.taskRows || []; }
    get filteredRows() {
        const term = this.searchTerm.trim().toLowerCase();
        if (!term) return this.rows;
        return this.rows.filter((row) =>
            [row.subject, row.relatedLabel, row.lob, row.type, row.ownerName, row.status]
                .some((value) => String(value || '').toLowerCase().includes(term))
        );
    }
    get hasError() { return !!this.error; }
    get hasNoRows() { return !this.error && this.filteredRows.length === 0; }
    get hasRows() { return !this.error && this.filteredRows.length > 0; }
    get overdueCount() { return this.pageData?.overdueCount || 0; }
    get dueTodayCount() { return this.pageData?.dueTodayCount || 0; }
    get voicemailCount() { return this.pageData?.voicemailCount || 0; }
    get completedTodayCount() { return this.pageData?.completedTodayCount || 0; }
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

    handleSearch(event) { this.searchTerm = event.target.value; }
    handleNewTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' }
        });
    }
    handleNewEvent() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewEvent' }
        });
    }
}