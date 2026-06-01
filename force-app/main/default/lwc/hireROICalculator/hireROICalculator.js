import { LightningElement, track } from 'lwc';
import calculateROI from '@salesforce/apex/CapacityForecastService.calculateROI';

export default class HireROICalculator extends LightningElement {
    @track quantity = 1;
    @track annualCost = 70000;
    @track hoursPerWeek = 40;
    @track revenuePerHour = 95;
    @track utilizationPct = 80;
    @track result;

    handleField(event) {
        this[event.target.dataset.field] = event.target.value;
    }

    async compute() {
        try {
            this.result = await calculateROI({
                hoursPerWeek: parseFloat(this.hoursPerWeek),
                revenuePerHour: parseFloat(this.revenuePerHour),
                utilizationPct: parseFloat(this.utilizationPct),
                annualCost: parseFloat(this.annualCost),
                quantity: parseInt(this.quantity, 10)
            });
        } catch (e) {
            console.error(e);
        }
    }
}