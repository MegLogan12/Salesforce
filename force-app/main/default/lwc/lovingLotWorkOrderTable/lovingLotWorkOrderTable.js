import { LightningElement, api } from 'lwc';

export default class LovingLotWorkOrderTable extends LightningElement {
    @api rows = [];

    get displayRows() {
        return (this.rows || []).map((row) => ({
            ...row,
            statusClassName: `chip ${row.statusClass || 'cgr'}`
        }));
    }
}