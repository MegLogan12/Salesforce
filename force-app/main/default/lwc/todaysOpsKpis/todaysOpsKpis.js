import { LightningElement, wire } from 'lwc';
import getKpis from '@salesforce/apex/HomeDashboardController.getKpis';

export default class TodaysOpsKpis extends LightningElement {
    kpis;

    @wire(getKpis)
    onKpis({ data }) {
        if (data) this.kpis = data;
    }

    get pendingApprovalClass() {
        return this.kpis?.pendingApproval > 5 ? 'kpi-tile kpi-warn' : 'kpi-tile kpi-info';
    }

    get hireRequestsClass() {
        return this.kpis?.openHireRequests > 0 ? 'kpi-tile kpi-warn' : 'kpi-tile';
    }

    get actionItemsClass() {
        return this.kpis?.openActionItems > 10 ? 'kpi-tile kpi-warn' : 'kpi-tile';
    }
}