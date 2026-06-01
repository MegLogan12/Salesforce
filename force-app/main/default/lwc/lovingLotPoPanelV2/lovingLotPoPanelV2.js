import { LightningElement, api } from 'lwc';

export default class LovingLotPoPanelV2 extends LightningElement {
    @api lot;

    get title() {
        return this.lot?.poObjectLabel || 'Builder PO';
    }

    get fields() {
        return this.lot?.poSummaryFields || [];
    }
}