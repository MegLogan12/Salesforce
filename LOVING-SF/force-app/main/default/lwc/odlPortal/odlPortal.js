import { LightningElement, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';

export default class OdlPortal extends LightningElement {
    @api recordId;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    get contactName() { return 'Sarah'; }
    get propertyAddress() { return '—'; }
    get propertyAccessNotes() { return '—'; }
    get propertyUtilityReview() { return '—'; }
    get propertyCustomerPrep() { return '—'; }
}
