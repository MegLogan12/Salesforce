import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import scan from '@salesforce/apex/ReceivingController.scan';
import post from '@salesforce/apex/ReceivingController.post';
import { createRecord } from 'lightning/uiRecordApi';
import RECEIPT_OBJECT from '@salesforce/schema/Receipt__c';
import RECEIPT_LINE_OBJECT from '@salesforce/schema/Receipt_Line__c';

const LINE_COLUMNS = [
    { label: 'SKU', fieldName: 'sku' },
    { label: 'Product', fieldName: 'productName' },
    { label: 'Qty', fieldName: 'qty', type: 'number', editable: true },
    { label: 'PO Expected', fieldName: 'poExpectedQty', type: 'number' },
    { label: 'PO Received', fieldName: 'poReceivedQty', type: 'number' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'Remove', name: 'remove' }]
        }
    }
];

export default class ScannerReceiving extends LightningElement {
    @track vendorPoId = '';
    @track scannedSku = '';
    @track receiptLines = [];
    @track lastScanResult = null;
    @track postResult = null;
    @track isPosting = false;
    @track receiptId = null;

    lineColumns = LINE_COLUMNS;

    get scanBannerClass() {
        const base = 'slds-notify slds-notify_alert slds-m-bottom_small ';
        return this.lastScanResult && this.lastScanResult.matched
            ? base + 'slds-theme_success'
            : base + 'slds-theme_error';
    }

    get scanBannerIcon() {
        return this.lastScanResult && this.lastScanResult.matched ? 'utility:check' : 'utility:error';
    }

    get postBannerClass() {
        const base = 'slds-notify slds-notify_alert slds-m-top_small ';
        return this.postResult && this.postResult.receiptStatus === 'Posted'
            ? base + 'slds-theme_success'
            : base + 'slds-theme_warning';
    }

    handlePoChange(evt) {
        this.vendorPoId = evt.detail.value;
    }

    handleSkuChange(evt) {
        this.scannedSku = evt.detail.value;
    }

    handleSkuKeydown(evt) {
        if (evt.key === 'Enter') this.handleScan();
    }

    handleScan() {
        if (!this.vendorPoId || !this.scannedSku) {
            this.showError('Please enter a PO Id and SKU.');
            return;
        }
        scan({ sku: this.scannedSku, vendorPoId: this.vendorPoId })
            .then(result => {
                this.lastScanResult = result;
                if (result.matched) {
                    const existing = this.receiptLines.find(l => l.sku === result.sku);
                    if (existing) {
                        this.receiptLines = this.receiptLines.map(l =>
                            l.sku === result.sku ? { ...l, qty: l.qty + 1 } : l
                        );
                    } else {
                        this.receiptLines = [...this.receiptLines, {
                            lineId: result.productId + '_' + Date.now(),
                            sku: result.sku,
                            productName: result.productName,
                            productId: result.productId,
                            poLineId: result.poLineId,
                            qty: 1,
                            poExpectedQty: result.poExpectedQty,
                            poReceivedQty: result.poReceivedQty
                        }];
                    }
                    this.scannedSku = '';
                }
            })
            .catch(err => this.showError(err));
    }

    handleLineAction(evt) {
        if (evt.detail.action.name === 'remove') {
            const lineId = evt.detail.row.lineId;
            this.receiptLines = this.receiptLines.filter(l => l.lineId !== lineId);
        }
    }

    handlePost() {
        if (this.receiptLines.length === 0) {
            this.showError('No lines to post.');
            return;
        }
        this.isPosting = true;

        const fields = {};
        fields['Vendor_PO__c'] = this.vendorPoId;
        fields['Receipt_Date__c'] = new Date().toISOString().substring(0, 10);
        fields['Status__c'] = 'Draft';

        createRecord({ apiName: RECEIPT_OBJECT.objectApiName, fields })
            .then(receipt => {
                this.receiptId = receipt.id;
                const lineCreates = this.receiptLines.map(l => {
                    const lf = {};
                    lf['Receipt__c'] = receipt.id;
                    lf['Product__c'] = l.productId;
                    lf['Qty__c'] = l.qty;
                    lf['Scanned_SKU__c'] = l.sku;
                    lf['PO_Line__c'] = l.poLineId;
                    return createRecord({ apiName: RECEIPT_LINE_OBJECT.objectApiName, fields: lf });
                });
                return Promise.all(lineCreates).then(() => receipt.id);
            })
            .then(receiptId => post({ receiptId }))
            .then(result => {
                this.postResult = result;
                this.receiptLines = [];
                this.showSuccess('Receipt posted: ' + result.receiptStatus);
            })
            .catch(err => this.showError(err))
            .finally(() => { this.isPosting = false; });
    }

    showSuccess(msg) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: msg, variant: 'success' }));
    }

    showError(err) {
        const msg = (err && err.body && err.body.message) ? err.body.message : String(err);
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
    }
}
