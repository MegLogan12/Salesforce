import { LightningElement, api } from 'lwc';

export default class LovingLotPoPanel extends LightningElement {
    @api lot;

    get title() {
        return this.lot?.poObjectLabel || 'Builder PO';
    }

    get fields() {
        return this.lot?.poSummaryFields || [];
    }
}