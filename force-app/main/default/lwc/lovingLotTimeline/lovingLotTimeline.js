import { LightningElement, api } from 'lwc';

export default class LovingLotTimeline extends LightningElement {
    _items = [];

    @api
    get items() {
        return this._items;
    }
    set items(value) {
        this._items = (value || []).map((item) => ({
            ...item,
            rowClass: `timeline-row ${item.complete ? 'done' : 'future'}`
        }));
    }
}