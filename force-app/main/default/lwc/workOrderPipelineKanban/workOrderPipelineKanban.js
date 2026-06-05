import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPipeline from '@salesforce/apex/WorkOrderPipelineController.getPipeline';

function applyFullWidthLayout(host) {
    try {
        if (typeof window === 'undefined' || !host) return false;
        const rect = host.getBoundingClientRect();
        if (!rect || rect.width === 0) return false;
        const vw = window.innerWidth;
        if (rect.right < vw - 20) {
            host.style.setProperty('width', `${vw - rect.left}px`, 'important');
            host.style.setProperty('max-width', 'none', 'important');
        }
        if (rect.top > 95) {
            host.style.setProperty('margin-top', `-${Math.round(rect.top - 90)}px`, 'important');
        }
        return true;
    } catch (e) {
        return false;
    }
}
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
    renderedCallback() {
        applyFullWidthLayout(this.template.host);
    }

}