import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class LovingForemanFlowAction extends LightningElement {
    @api recordId;
    @api flowApiName;

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
