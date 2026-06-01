import { LightningElement, api } from 'lwc';

export default class OdlGenericRecordWorkspace extends LightningElement {
    @api recordId;
    @api objectApiName;
}
