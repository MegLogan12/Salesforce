import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getWorkOrders from '@salesforce/apex/CommunityRecordController.getWorkOrders';

export default class CommunityWorkOrders extends NavigationMixin(LightningElement) {
    @api recordId;
    data;

    @wire(getWorkOrders, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.data = data;
        } else if (error) {
            this.data = { rows: [], completeCount: 0, scheduledCount: 0, qiDueCount: 0 };
        }
    }

    get loaded() { return !!this.data; }
    get hasRows() { return this.data && this.data.rows && this.data.rows.length > 0; }

    handleNewWorkOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WorkOrder', actionName: 'new' },
            state: { defaultFieldValues: `Community__c=${this.recordId}` }
        });
    }
}