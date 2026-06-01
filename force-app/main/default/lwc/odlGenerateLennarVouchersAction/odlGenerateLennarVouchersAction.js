import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class OdlGenerateLennarVouchersAction extends LightningElement {
    @api recordId;

    get inputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    handleStatusChange(event) {
        const status = event.detail?.status;
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
}