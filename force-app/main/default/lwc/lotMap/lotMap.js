import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLotsForCommunity from '@salesforce/apex/LotMapController.getLotsForCommunity';

export default class LotMap extends NavigationMixin(LightningElement) {
    @api recordId;
    payload;
    error;

    @wire(getLotsForCommunity, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.payload = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.payload = undefined;
        }
    }

    get hasData() {
        return this.payload && this.payload.tiles && this.payload.tiles.length > 0;
    }

    get showEmpty() {
        return this.payload && (!this.payload.tiles || this.payload.tiles.length === 0);
    }

    get tiles() {
        return this.payload ? this.payload.tiles : [];
    }

    get totalLots() { return this.payload ? this.payload.totalLots : 0; }
    get completeCount() { return this.payload ? this.payload.completeCount : 0; }
    get inProductionCount() { return this.payload ? this.payload.inProductionCount : 0; }
    get scheduledCount() { return this.payload ? this.payload.scheduledCount : 0; }
    get pendingCount() { return this.payload ? this.payload.pendingCount : 0; }
    get fjOpenCount() { return this.payload ? this.payload.fjOpenCount : 0; }
    get availableCount() { return this.payload ? this.payload.availableCount : 0; }

    handleTileClick(event) {
        const lotId = event.currentTarget.dataset.id;
        if (!lotId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: lotId,
                objectApiName: 'Lot__c',
                actionName: 'view'
            }
        });
    }
}