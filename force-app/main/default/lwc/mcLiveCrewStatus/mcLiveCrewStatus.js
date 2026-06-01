import { LightningElement, track, wire } from 'lwc';
import getActiveWorkOrders from '@salesforce/apex/MeasuringCupController.getActiveToday';

export default class McLiveCrewStatus extends LightningElement {
    @track crews = [];
    @track loaded = false;

    connectedCallback() {
        this.refresh();
    }

    async refresh() {
        try {
            const data = await getActiveWorkOrders();
            this.crews = data || [];
            this.loaded = true;
        } catch (e) {
            console.error('Failed to load crew status', e);
            this.loaded = true;
        }
    }
}