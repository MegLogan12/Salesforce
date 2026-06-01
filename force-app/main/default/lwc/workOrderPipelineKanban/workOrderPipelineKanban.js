import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPipeline from '@salesforce/apex/WorkOrderPipelineController.getPipeline';

export default class WorkOrderPipelineKanban extends NavigationMixin(LightningElement) {
    @track columns = [];
    error;

    @wire(getPipeline)
    onPipeline({ data, error }) {
        if (data) {
            // Deep copy to avoid frozen wire data
            this.columns = JSON.parse(JSON.stringify(data));
            this.error = null;
        } else if (error) {
            console.error('Pipeline wire error', error);
            this.error = error;
        }
    }

    get totalCount() {
        return this.columns.reduce((acc, c) => acc + (c.count || 0), 0);
    }

    handleNewWorkOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WorkOrder', actionName: 'new' }
        });
    }
}