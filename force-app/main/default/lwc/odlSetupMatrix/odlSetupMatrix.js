import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';

export default class OdlSetupMatrix extends LightningElement {
    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }
}