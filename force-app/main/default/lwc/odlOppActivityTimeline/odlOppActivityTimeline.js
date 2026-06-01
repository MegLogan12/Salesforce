import { LightningElement, api } from 'lwc';

export default class OdlOppActivityTimeline extends LightningElement {
    @api interactions = [];
    @api lastAction = '';
    @api lastActionDate = '';

    get hasInteractions() {
        return Array.isArray(this.interactions) && this.interactions.length > 0;
    }
}
