import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

/**
 * lovingForemanFlagIssueAction
 * Thin LWC wrapper for LOVING_Foreman_FlagIssue Screen Flow.
 * Launched as a Quick Action on WorkOrder from FSL Mobile.
 * Passes recordId to the flow. Closes the action modal on FINISHED or ERROR.
 */
export default class LovingForemanFlagIssueAction extends LightningElement {
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