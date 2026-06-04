import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPayments          from '@salesforce/apex/StripeService.getPayments';
import createCheckoutSession from '@salesforce/apex/StripeService.createCheckoutSession';
import refreshPaymentStatus  from '@salesforce/apex/StripeService.refreshPaymentStatus';

const STATUS_BADGE = {
    Complete: 'slds-theme_success',
    Pending:  'slds-theme_warning',
    Expired:  'slds-theme_shade',
    Canceled: 'slds-theme_shade'
};

export default class StripePaymentCollector extends LightningElement {
    @api recordId;

    @track showForm       = false;
    @track isCreating     = false;
    @track isRefreshing   = false;
    @track newAmount      = '';
    @track newDescription = '';

    _wiredResult;

    @wire(getPayments, { workOrderId: '$recordId' })
    wiredPayments(result) {
        this._wiredResult = result;
    }

    get payments() {
        const data = this._wiredResult?.data;
        if (!data?.length) return null;
        const fmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
        return data.map(p => ({
            ...p,
            formattedAmount: fmt.format(p.Amount__c ?? 0),
            formattedDate:   p.CreatedDate ? new Date(p.CreatedDate).toLocaleDateString() : '',
            badgeClass:      STATUS_BADGE[p.Status__c] ?? '',
            isPending:       p.Status__c === 'Pending'
        }));
    }

    get noPayments() {
        return !this._wiredResult?.data?.length && !this._wiredResult?.error;
    }

    get isLoading() {
        return !this._wiredResult;
    }

    handleShowForm()          { this.showForm = true; }
    handleCancelForm()        { this.showForm = false; this.newAmount = ''; this.newDescription = ''; }
    handleAmountChange(e)     { this.newAmount = e.detail.value; }
    handleDescriptionChange(e){ this.newDescription = e.detail.value; }

    handleCopyLink(e) {
        const url = e.currentTarget.dataset.url;
        navigator.clipboard.writeText(url).then(() => {
            this.toast('Link copied!', 'Payment URL copied to clipboard.', 'success');
        });
    }

    handleOpenLink(e) {
        window.open(e.currentTarget.dataset.url, '_blank');
    }

    async handleCreatePayment() {
        if (!this.newAmount || parseFloat(this.newAmount) <= 0) {
            this.toast('Enter an amount', 'Amount must be greater than $0.', 'warning');
            return;
        }
        this.isCreating = true;
        try {
            const result = await createCheckoutSession({
                workOrderId:  this.recordId,
                amount:       parseFloat(this.newAmount),
                description:  this.newDescription || null
            });
            await refreshApex(this._wiredResult);
            this.showForm       = false;
            this.newAmount      = '';
            this.newDescription = '';
            window.open(result.checkoutUrl, '_blank');
            this.toast('Payment link created', 'The Stripe Checkout link has opened in a new tab. Share it with the customer.', 'success');
        } catch (err) {
            this.toast('Error', err.body?.message ?? 'Could not create payment link.', 'error');
        } finally {
            this.isCreating = false;
        }
    }

    async handleRefresh(e) {
        const paymentId = e.currentTarget.dataset.id;
        this.isRefreshing = true;
        try {
            const status = await refreshPaymentStatus({ paymentRecordId: paymentId });
            await refreshApex(this._wiredResult);
            const msg = status === 'Complete' ? 'Payment confirmed — marked Complete.'
                      : status === 'Expired'  ? 'The payment link has expired.'
                      : 'Still pending — no payment yet.';
            this.toast('Status updated', msg, status === 'Complete' ? 'success' : 'info');
        } catch (err) {
            this.toast('Error', err.body?.message ?? 'Could not refresh status.', 'error');
        } finally {
            this.isRefreshing = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
