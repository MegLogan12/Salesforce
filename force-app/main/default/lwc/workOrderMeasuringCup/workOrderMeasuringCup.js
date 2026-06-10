import { LightningElement, api, wire } from 'lwc';
import getMeasuringCup from '@salesforce/apex/WorkOrderRecordController.getMeasuringCup';

export default class WorkOrderMeasuringCup extends LightningElement {
    @api recordId;
    data;
    err;

    @wire(getMeasuringCup, { workOrderId: '$recordId' })
    wired({ data, error }) {
        if (data) this.data = data;
        else if (error) this.err = error;
    }

    get loaded() { return !!this.data; }

    get guardrails() {
        if (!this.data) return [];
        return [
            { key: 'mileage', label: 'Mileage Guardrail', flag: this.data.mileageFlag, cls: this.data.mileageFlag ? 'pill pr' : 'pill pg', text: this.data.mileageFlag ? 'Flag' : 'OK' },
            { key: 'ot', label: 'OT Risk', flag: this.data.otFlag, cls: this.data.otFlag ? 'pill pr' : 'pill pg', text: this.data.otFlag ? 'Flag' : 'OK' },
            { key: 'rtn', label: 'RTN Window', flag: this.data.rtnFlag, cls: this.data.rtnFlag ? 'pill pr' : 'pill pg', text: this.data.rtnFlag ? 'Flag' : 'OK' }
        ];
    }
}