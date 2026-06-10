import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class LovingFmFlagSiteNotReadyAction extends LightningElement {
    @api recordId;

    get inputVariables() {
        return [{ name: 'recordId', type: 'String', value: this.recordId }];
    }

    handleStatusChange(event) {
        if (['FINISHED', 'FINISHED_SCREEN'].includes(event.detail.status)) {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
}
