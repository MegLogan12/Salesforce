import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generatePublicLink from '@salesforce/apex/DesignFileController.generatePublicLink';

export default class DesignFileUploader extends LightningElement {

    @api recordId;
    @track fileUrl;

    handleUploadFinished(event) {

        const uploadedFiles = event.detail.files;
        const contentDocumentId = uploadedFiles[0].documentId;

        generatePublicLink({ contentDocumentId: contentDocumentId, opportunityId: this.recordId })
            .then(result => {
                this.fileUrl = result;
            })
            .catch(error => {
                console.error(error);
                const message = error && error.body && error.body.message
                    ? error.body.message
                    : 'We could not generate the public link for this file. Please try again.';
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Upload link failed',
                    message,
                    variant: 'error'
                }));
            });
    }
}