import { LightningElement, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';

export default class OdlPortal extends LightningElement {
    @api recordId;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }
}
