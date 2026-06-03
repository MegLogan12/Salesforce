import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCatalog from '@salesforce/apex/InventoryMaterialsController.getCatalog';
import getCostDetail from '@salesforce/apex/InventoryMaterialsController.getCostDetail';
import updateStandardPrice from '@salesforce/apex/InventoryMaterialsController.updateStandardPrice';
import createReorderTask from '@salesforce/apex/InventoryMaterialsController.createReorderTask';

const CATALOG_COLUMNS = [
    { label: 'Name', fieldName: 'name', sortable: true },
    { label: 'SKU', fieldName: 'sku' },
    { label: 'Category', fieldName: 'category' },
    { label: 'Unit', fieldName: 'unitOfMeasure' },
    { label: 'On Hand', fieldName: 'onHand', type: 'number' },
    { label: 'Reorder Pt', fieldName: 'reorderPoint', type: 'number' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'View Cost/GP', name: 'view_cost' }]
        }
    }
];

const TRUCK_STOCK_COLUMNS = [
    { label: 'Name', fieldName: 'name' },
    { label: 'SKU', fieldName: 'sku' },
    { label: 'Category', fieldName: 'category' },
    { label: 'On Hand', fieldName: 'onHand', type: 'number',
      cellAttributes: { class: { fieldName: 'stockClass' } } },
    { label: 'Reorder Pt', fieldName: 'reorderPoint', type: 'number' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'Raise Reorder Task', name: 'reorder' }]
        }
    }
];

const CATEGORIES = ['All', 'Sod', 'Plant', 'Aggregate', 'Irrigation', 'Hardscape'];

export default class InventoryMaterialsConsole extends LightningElement {
    @track catalog = [];
    @track costDetail = null;
    @track selectedProduct = null;
    @track selectedCostId = null;
    @track isLoading = false;
    @track selectedCategory = 'All';
    @track activeTab = 'catalog';
    @track newStdPrice = null;

    catalogColumns = CATALOG_COLUMNS;
    truckStockColumns = TRUCK_STOCK_COLUMNS;

    get categoryOptions() {
        return CATEGORIES.map(c => ({ label: c, value: c }));
    }

    get gpPctDisplay() {
        if (!this.costDetail || this.costDetail.gpPct == null) return 'N/A';
        return (this.costDetail.gpPct * 100).toFixed(1) + '%';
    }

    get lowStockItems() {
        return this.catalog.filter(r => r.lowStock);
    }

    connectedCallback() {
        this.loadCatalog();
    }

    loadCatalog() {
        this.isLoading = true;
        getCatalog({ category: this.selectedCategory })
            .then(data => {
                this.catalog = data.map(r => ({
                    ...r,
                    stockClass: r.lowStock ? 'slds-text-color_error' : ''
                }));
            })
            .catch(err => this.showError(err))
            .finally(() => { this.isLoading = false; });
    }

    handleCategoryChange(evt) {
        this.selectedCategory = evt.detail.value;
        this.loadCatalog();
    }

    handleRefresh() {
        this.loadCatalog();
    }

    handleTabChange(evt) {
        this.activeTab = evt.target.value;
    }

    handleCatalogRowAction(evt) {
        const action = evt.detail.action;
        const row = evt.detail.row;
        if (action.name === 'view_cost') {
            this.selectedProduct = row.productId;
            this.activeTab = 'cost';
            getCostDetail({ productId: row.productId })
                .then(data => {
                    this.costDetail = data;
                    if (data) this.newStdPrice = data.standardPrice;
                })
                .catch(err => this.showError(err));
        }
    }

    handlePriceChange(evt) {
        this.newStdPrice = evt.detail.value;
    }

    handleSavePrice() {
        if (!this.costDetail || !this.costDetail.productId) return;
        getCostDetail({ productId: this.selectedProduct })
            .then(detail => {
                if (!detail) { this.showError('No cost catalog entry to update.'); return null; }
                return updateStandardPrice({ costCatalogId: detail.productId, price: this.newStdPrice });
            })
            .then(() => {
                if (!this) return;
                this.showSuccess('Price updated.');
                this.costDetail = { ...this.costDetail, standardPrice: this.newStdPrice };
            })
            .catch(err => this.showError(err));
    }

    handleReorder(evt) {
        const action = evt.detail.action;
        const row = evt.detail.row;
        if (action.name === 'reorder') {
            createReorderTask({ productId: row.productId })
                .then(() => this.showSuccess('Reorder task created for ' + row.name))
                .catch(err => this.showError(err));
        }
    }

    showSuccess(msg) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: msg, variant: 'success' }));
    }

    showError(err) {
        const msg = (err && err.body && err.body.message) ? err.body.message : String(err);
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
    }
}
