import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecentReceipts from '@salesforce/apex/ScannerReceivingController.getRecentReceipts';
import receiveItem      from '@salesforce/apex/ScannerReceivingController.receiveItem';
import { refreshApex }  from '@salesforce/apex';

export default class ScannerReceiving extends LightningElement {

    // ── Form state ────────────────────────────────────────────────────────────
    itemType      = '';
    quantity      = null;
    location      = '';
    locationType  = '';
    workOrderInput = '';   // display-only text — not wired to an Id lookup
    isSaving      = false;

    // ── Recent receipts wire ──────────────────────────────────────────────────
    _wiredReceiptsResult;
    receipts        = [];
    receiptsError;
    isLoadingReceipts = true;

    @wire(getRecentReceipts)
    wiredReceipts(result) {
        this._wiredReceiptsResult = result;
        this.isLoadingReceipts = false;
        const { data, error } = result;
        if (data) {
            this.receipts      = data.map(row => ({
                ...row,
                formattedDate: row.createdDate
                    ? new Date(row.createdDate).toLocaleDateString()
                    : ''
            }));
            this.receiptsError = undefined;
        } else if (error) {
            this.receiptsError = error?.body?.message ?? error?.message ?? 'Unable to load receipts.';
            this.receipts      = [];
        }
    }

    // ── Computed getters ──────────────────────────────────────────────────────

    get hasReceipts() {
        return !this.isLoadingReceipts && this.receipts && this.receipts.length > 0;
    }

    get isEmpty() {
        return !this.isLoadingReceipts && !this.receiptsError && (!this.receipts || this.receipts.length === 0);
    }

    // ── Form handlers ─────────────────────────────────────────────────────────

    handleItemTypeChange(event)     { this.itemType      = event.target.value; }
    handleQuantityChange(event)     { this.quantity       = Number(event.target.value); }
    handleLocationChange(event)     { this.location       = event.target.value; }
    handleLocationTypeChange(event) { this.locationType   = event.target.value; }
    handleWorkOrderChange(event)    { this.workOrderInput = event.target.value; }

    handleReceive() {
        if (!this.itemType || this.quantity == null) {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Validation Error',
                message: 'Item Type and Quantity are required.',
                variant: 'error'
            }));
            return;
        }

        this.isSaving = true;
        receiveItem({
            itemType:    this.itemType,
            quantity:    this.quantity,
            location:    this.location,
            locationType: this.locationType,
            workOrderId: null   // WO text field is display-only (G4 gate for full lookup)
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Success',
                message: `${this.itemType} received successfully.`,
                variant: 'success'
            }));
            this.resetForm();
            return refreshApex(this._wiredReceiptsResult);
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Error',
                message: error?.body?.message ?? error?.message ?? 'Failed to receive item.',
                variant: 'error'
            }));
        })
        .finally(() => {
            this.isSaving = false;
        });
    }

    resetForm() {
        this.itemType      = '';
        this.quantity      = null;
        this.location      = '';
        this.locationType  = '';
        this.workOrderInput = '';
        // Reset lightning-input values via querySelectorAll
        this.template.querySelectorAll('lightning-input').forEach(input => {
            input.value = '';
        });
    }
}
