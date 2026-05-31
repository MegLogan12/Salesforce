import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

/**
 * lovingForemanPreShiftAction
 * Thin LWC wrapper for LOVING_Foreman_PreShift_VehicleCheck Screen Flow.
 * Launched as a Quick Action on WorkOrder from FSL Mobile.
 * Passes recordId to the flow. Closes the action modal on FINISHED or ERROR.
 */
export default class LovingForemanPreShiftAction extends LightningElement {
    @api recordId;

    get inputVars() {
        return [
            { name: 'recordId', type: 'String', value: this.recordId }
        ];
    }

    handleStatusChange(evt) {
        const status = evt.detail.status;
        if (status === 'FINISHED' || status === 'ERROR' || status === 'FINISHED_SCREEN') {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
}