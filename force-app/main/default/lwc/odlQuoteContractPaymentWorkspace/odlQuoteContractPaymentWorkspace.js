import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getPageData from '@salesforce/apex/ODLVisibleWorkspaceController.getPageData';

const NEW_TASK_ACTION = 'Global.NewTask';
const SEND_EMAIL_ACTION = 'Global.SendEmail';

export default class OdlQuoteContractPaymentWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    pageData;
    error;

    @wire(getPageData, { recordId: '$recordId' })
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.pageData = undefined;
        }
    }

    get hasData() {
        return Boolean(this.pageData);
    }

    get quoteSummaryFields() {
        return this.getSectionFields('Quote Summary');
    }

    get pricingFields() {
        return this.getSectionFields('Pricing Summary');
    }

    get projectFields() {
        return this.getSectionFields('Opportunity / Project Path');
    }

    get voucherFields() {
        return this.getSectionFields('Voucher Application');
    }

    get opportunityUrl() {
        return this.getFieldUrl('Quote Summary', 'Opportunity');
    }

    get opportunityName() {
        return this.getFieldValue('Quote Summary', 'Opportunity');
    }

    get opportunityStageValue() {
        return this.getFieldValue('Opportunity / Project Path', 'Opportunity Stage');
    }

    get opportunityId() {
        const url = this.opportunityUrl;
        return url ? url.replace('/', '') : '';
    }

    get accountId() {
        const url = this.getFieldUrl('Quote Summary', 'Account');
        return url ? url.replace('/', '') : '';
    }

    get voucherId() {
        const url = this.getFieldUrl('Voucher Application', 'Voucher');
        return url ? url.replace('/', '') : '';
    }

    get disableOpenVoucher() {
        return !this.voucherId;
    }

    get quoteNumber() {
        return this.getFieldValue('Quote Summary', 'Quote Number');
    }

    get statusValue() {
        return this.getFieldValue('Quote Summary', 'Status');
    }

    get grandTotalValue() {
        return this.getFieldValue('Pricing Summary', 'Grand Total');
    }

    get depositAmountValue() {
        const deposit = this.paymentRows.find((row) => (row.triggerText || '').toLowerCase().includes('deposit') || (row.label || '').toLowerCase().includes('deposit'));
        return deposit?.amountText || '$0';
    }

    get finalPaymentAmountValue() {
        const finalPayment = this.paymentRows.find((row) => (row.label || '').toLowerCase().includes('final'));
        return finalPayment?.amountText || '$0';
    }

    get voucherStatusValue() {
        return this.getFieldSubtext('Voucher Application', 'Voucher') || '';
    }

    get quoteLineRows() {
        return this.getSectionRows('Products / Quote Lines').map((row, index) => ({
            ...row,
            key: `line-${index}`,
            lineNumber: index + 1,
            quantityText: this.parseQuantity(row.status),
            unitText: this.parseUnit(row.subtext),
            priceText: this.parsePrice(row.secondaryText),
            billableType: row.label && row.label.toLowerCase().includes('voucher') ? 'No Charge' : 'Billable'
        }));
    }

    get hasNoQuoteLines() {
        return this.quoteLineRows.length === 0;
    }

    get hasQuoteLines() {
        return !this.hasNoQuoteLines;
    }

    get paymentRows() {
        return this.getSectionRows('Payment Milestones').map((row, index) => ({
            ...row,
            key: `payment-${index}`,
            amountText: row.subtext || '$0',
            triggerText: row.secondaryText || row.dateText || ''
        }));
    }

    get hasNoPaymentRows() {
        return this.paymentRows.length === 0;
    }

    get hasPaymentRows() {
        return !this.hasNoPaymentRows;
    }

    get openItemsCount() {
        return String((this.pageData?.openItems || []).length);
    }

    get errorMessage() {
        if (!this.error) return '';
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((item) => item.message).join(', ');
        }
        return this.error.body ? this.error.body.message : this.error.message;
    }

    getSectionFields(title) {
        return (this.pageData?.sections || []).find((section) => section.title === title)?.fields || [];
    }

    getSectionRows(title) {
        return (this.pageData?.sections || []).find((section) => section.title === title)?.rows || [];
    }

    getFieldValue(sectionTitle, fieldLabel) {
        return this.getSectionFields(sectionTitle).find((item) => item.label === fieldLabel)?.value || '';
    }

    getFieldUrl(sectionTitle, fieldLabel) {
        return this.getSectionFields(sectionTitle).find((item) => item.label === fieldLabel)?.url || '';
    }

    getFieldSubtext(sectionTitle, fieldLabel) {
        return this.getSectionFields(sectionTitle).find((item) => item.label === fieldLabel)?.subtext || '';
    }

    parseQuantity(statusText) {
        return statusText ? statusText.replace(/^Qty\s*/i, '') : '1';
    }

    parseUnit(subtext) {
        return subtext ? subtext.replace(/^Unit\s*/i, '') : '';
    }

    parsePrice(text) {
        return text ? text.replace(/^Total\s*/i, '') : '';
    }

    handlePreview() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'view' }
        });
    }

    handleEditQuote() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }

    handleNewTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: NEW_TASK_ACTION },
            state: { recordId: this.recordId }
        });
    }

    handleSendEmail() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: SEND_EMAIL_ACTION },
            state: { recordId: this.recordId }
        });
    }

    handleCreateContract() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Contract', actionName: 'new' },
            state: {
                defaultFieldValues: encodeDefaultFieldValues({
                    AccountId: this.accountId,
                    StartDate: new Date().toISOString().slice(0, 10),
                    ContractTerm: 12,
                    Status: 'Draft',
                    Description: this.opportunityName ? `Outdoor Living contract for ${this.opportunityName}` : 'Outdoor Living contract'
                })
            }
        });
    }

    handleCreateInvoice() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Invoice__c', actionName: 'new' },
            state: {
                defaultFieldValues: encodeDefaultFieldValues({
                    Quote__c: this.recordId
                })
            }
        });
    }

    handleOpenOpportunity() {
        if (!this.opportunityId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.opportunityId, actionName: 'view' }
        });
    }

    handleOpenVoucher() {
        if (!this.voucherId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.voucherId, actionName: 'view' }
        });
    }

    handleOpenActivity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Quote',
                relationshipApiName: 'ActivityHistories',
                actionName: 'view'
            }
        });
    }
}