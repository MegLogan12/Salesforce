import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LovingSiteVisitChecklist extends LightningElement {
    static renderMode = 'light';

    handleSave() {
        // TODO: bind to Site_Visit__c or Opportunity once object is confirmed
        this.dispatchEvent(new ShowToastEvent({
            title: 'Saved',
            message: 'Site visit notes captured.',
            variant: 'success'
        }));
    }
}
