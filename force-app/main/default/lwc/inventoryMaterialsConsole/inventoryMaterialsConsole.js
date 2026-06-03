import { LightningElement, wire } from 'lwc';
import getInventory from '@salesforce/apex/InventoryMaterialsController.getInventory';

export default class InventoryMaterialsConsole extends LightningElement {
    view;
    error;
    isLoading = true;

    @wire(getInventory)
    wiredInventory({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.view  = data;
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message ?? error?.message ?? 'Unable to load inventory.';
            this.view  = undefined;
        }
    }

    get hasRows() {
        return !this.isLoading && this.view && this.view.rows && this.view.rows.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.error && (!this.view || !this.view.rows || this.view.rows.length === 0);
    }

    get hasLowStock() {
        return this.view && this.view.lowStockCount > 0;
    }
}
