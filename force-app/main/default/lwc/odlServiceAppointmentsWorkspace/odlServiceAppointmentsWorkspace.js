import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getListData from '@salesforce/apex/ODLServiceAppointmentConsoleController.getListData';

export default class OdlServiceAppointmentsWorkspace extends NavigationMixin(LightningElement) {
    searchTerm = '';
    pageData;

    @wire(getListData)
    wiredData({ data }) {
        if (data) this.pageData = data;
    }

    get rows() { return this.pageData?.rows || []; }
    get filteredRows() {
        const term = this.searchTerm.trim().toLowerCase();
        if (!term) return this.rows;
        return this.rows.filter((row) =>
            [row.appointmentNumber, row.status, row.workOrderNumber, row.homeownerName, row.territory, row.crewName, row.address]
                .some((value) => String(value || '').toLowerCase().includes(term))
        );
    }
    get hasNoRows() { return this.filteredRows.length === 0; }
    get hasRows() { return !this.hasNoRows; }
    get totalCount() { return this.pageData?.totalCount || 0; }
    get scheduledCount() { return this.pageData?.scheduledCount || 0; }
    get unscheduledCount() { return this.pageData?.unscheduledCount || 0; }
    get withWorkOrderCount() { return this.pageData?.withWorkOrderCount || 0; }
    handleSearch(event) { this.searchTerm = event.target.value; }
    handleRefresh() { window.location.reload(); }
    handleNewAppointment() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'ServiceAppointment', actionName: 'new' } });
    }
    handleOpenWorkOrders() {
        this[NavigationMixin.Navigate]({ type: 'standard__navItemPage', attributes: { apiName: 'Outdoor_Living_Work_Orders' } });
    }
}