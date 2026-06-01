import { LightningElement, api } from 'lwc';

export default class LovingLotHighlights extends LightningElement {
    @api lot;

    get pipelineClass() {
        return `chip ${this.lot?.pipelineClass || 'cgr'}`;
    }

    get lotStatusClass() {
        return `chip ${this.lot?.lotStatusClass || 'cgr'}`;
    }
}