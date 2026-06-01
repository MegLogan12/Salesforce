import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import generateAndAttachQuotePDF from '@salesforce/apex/OpportunityQuotePDFController.generateAndAttachQuotePDF';

const FIELDS = ['Opportunity.Name'];

export default class GenerateQuotePdfButton extends NavigationMixin(LightningElement) {
    @api recordId;
    isLoading = false;
    opportunityName;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    opportunity({ error, data }) {
        if (data) {
            this.opportunityName = data.fields.Name.value;
        } else if (error) {
            console.error('Error loading opportunity:', error);
        }
    }

    handleGeneratePDF() {
        this.isLoading = true;

        generateAndAttachQuotePDF({ opportunityId: this.recordId })
            .then((contentDocumentId) => {
                this.isLoading = false;
                
                // Show success message
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Quote PDF generated and attached successfully!',
                        variant: 'success'
                    })
                );

                // Navigate to the generated PDF file
                this[NavigationMixin.Navigate]({
                    type: 'standard__namedPage',
                    attributes: {
                        pageName: 'filePreview'
                    },
                    state: {
                        selectedRecordId: contentDocumentId
                    }
                });

                // Refresh the files related list
                this.dispatchEvent(new CustomEvent('refresh'));
            })
            .catch((error) => {
                this.isLoading = false;
                console.error('Error generating PDF:', error);
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error generating PDF',
                        message: error.body?.message || 'An error occurred while generating the PDF',
                        variant: 'error'
                    })
                );
            });
    }
}