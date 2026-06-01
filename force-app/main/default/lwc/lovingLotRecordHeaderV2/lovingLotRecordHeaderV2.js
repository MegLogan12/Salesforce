import { LightningElement, api } from 'lwc';

export default class LovingLotRecordHeaderV2 extends LightningElement {
    @api lot;

    get lotStatusClass() {
        return `chip ${this.lot?.lotStatusClass || 'cgr'}`;
    }

    get objectLabel() {
        return this.lot?.objectLabel || 'Lot';
    }

    get objectPluralLabel() {
        return this.lot?.objectPluralLabel || 'Lots';
    }

    handleEditRecord() {
        this.dispatchEvent(new CustomEvent('editrecord'));
    }

    handleViewWorkOrders() {
        this.dispatchEvent(new CustomEvent('viewworkorders'));
    }

    handleNewWorkOrder() {
        this.dispatchEvent(new CustomEvent('newworkorder'));
    }
}