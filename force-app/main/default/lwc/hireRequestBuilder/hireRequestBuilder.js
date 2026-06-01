import { LightningElement, track, wire } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import calculateROI from '@salesforce/apex/CapacityForecastService.calculateROI';

const SERVICE_LINES = ['Landscape', 'Aqua', 'Irrigation', 'Lawn Care', 'Customer Success'];
const ROLE_TYPES = ['Foreman', 'Technician', 'Lead', 'Other'];

export default class HireRequestBuilder extends LightningElement {
    @track serviceLine = 'Landscape';
    @track roleType = 'Technician';
    @track quantity = 1;
    @track annualCost = 70000;
    @track y1Revenue = 0;
    @track justification = '';
    @track driverCommunities = '';

    @track totalCost = 0;
    @track y1ROI = 0;
    @track roiPct = 0;
    @track monthsToPayback = 0;

    get serviceLineOptions() {
        return SERVICE_LINES.map(v => ({ label: v, value: v }));
    }

    get roleTypeOptions() {
        return ROLE_TYPES.map(v => ({ label: v, value: v }));
    }

    handleField(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this[field] = value;
        this.recompute();
    }

    async recompute() {
        if (!this.quantity || !this.annualCost) return;
        try {
            const result = await calculateROI({
                hoursPerWeek: 40,
                revenuePerHour: 95,
                utilizationPct: 80,
                annualCost: parseFloat(this.annualCost),
                quantity: parseInt(this.quantity, 10)
            });
            this.totalCost = result.totalAnnualCost;
            this.y1Revenue = result.y1RevenueCapacity;
            this.y1ROI = result.y1ROI;
            this.roiPct = result.roiPct;
            this.monthsToPayback = result.monthsToPayback;
        } catch (e) {
            console.error('ROI calc failed', e);
        }
    }

    async submit() {
        const fields = {
            Service_Line__c: this.serviceLine,
            Role_Type__c: this.roleType,
            Quantity__c: parseInt(this.quantity, 10),
            Annual_Cost_Per_Person__c: parseFloat(this.annualCost),
            Y1_Revenue_Capacity__c: parseFloat(this.y1Revenue),
            Justification__c: this.justification,
            Status__c: 'Submitted'
        };
        try {
            const rec = await createRecord({ apiName: 'Hire_Request__c', fields });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Hire Request submitted',
                message: 'Routed to VP Field Operations for review',
                variant: 'success'
            }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error submitting request',
                message: e.body?.message || e.message,
                variant: 'error'
            }));
        }
    }
}