import { LightningElement, api } from 'lwc';

export default class McKpiTile extends LightningElement {
    @api label;
    @api value;
    @api unit = '';
    @api status = 'neutral'; // good / warn / bad / neutral
    @api hero = false;

    get tileClass() {
        return 'mc-kpi-tile mc-kpi-' + this.status + (this.hero ? ' mc-kpi-hero' : '');
    }
}