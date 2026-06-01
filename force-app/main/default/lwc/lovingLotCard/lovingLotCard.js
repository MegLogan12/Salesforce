import { LightningElement, api } from 'lwc';

export default class LovingLotCard extends LightningElement {
    @api title;
    @api iconLabel;
    @api accent;
    @api full = false;

    get cardClass() {
        const classes = ['card'];
        if (this.full) classes.push('full');
        if (this.accent) classes.push(`accent-${this.accent}`);
        return classes.join(' ');
    }
}