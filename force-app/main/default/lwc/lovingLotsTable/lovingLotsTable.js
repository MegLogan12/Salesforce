import { LightningElement, api } from 'lwc';

export default class LovingLotsTable extends LightningElement {
    _columns = [];

    @api
    get columns() {
        return this._columns;
    }

    set columns(value) {
        this._columns = (value || []).map((column) => ({
            ...column,
            headerClass: column.numeric ? 'num' : ''
        }));
    }

    @api rows = [];
    @api lotCount = 0;
    @api objectPluralLabel = 'Lots';

    get rowCount() {
        return (this.rows || []).length;
    }

    openLot(event) {
        this.dispatchEvent(new CustomEvent('openlot', { detail: event.currentTarget.dataset.id }));
    }
}