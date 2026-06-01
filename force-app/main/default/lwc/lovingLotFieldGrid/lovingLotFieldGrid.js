import { LightningElement, api } from 'lwc';

export default class LovingLotFieldGrid extends LightningElement {
    @api fields = [];

    handleEdit(event) {
        this.dispatchEvent(new CustomEvent('editfield', {
            detail: {
                fieldApiName: event.currentTarget.dataset.field,
                label: event.currentTarget.dataset.label,
                objectApiName: event.currentTarget.dataset.object
            },
            bubbles: true,
            composed: true
        }));
    }
}