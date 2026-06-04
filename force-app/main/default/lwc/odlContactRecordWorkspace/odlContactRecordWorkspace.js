import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getContactPageData from '@salesforce/apex/ODLContactRecordController.getContactPageData';

export default class OdlContactRecordWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    _wiredResult;

    @wire(getContactPageData, { contactId: '$recordId' })
    wiredData(result) { this._wiredResult = result; }

    get pageData()  { return this._wiredResult?.data ?? null; }
    get hasData()   { return this.pageData != null; }
    get hasError()  { return Boolean(this._wiredResult?.error); }
    get isLoading() { return !this.hasData && !this.hasError; }

    get contactName() {
        const c = this.pageData?.contactRecord;
        return c ? (c.Name ?? '') : '';
    }

    get contactTitle() {
        return this.pageData?.contactRecord?.Title ?? '—';
    }

    get phoneDisplay() {
        const c = this.pageData?.contactRecord;
        return c?.MobilePhone ?? c?.Phone ?? '—';
    }

    get mailingAddress() {
        const c = this.pageData?.contactRecord;
        if (!c) return '—';
        const parts = [c.MailingStreet, c.MailingCity, c.MailingState, c.MailingPostalCode]
            .filter(p => p);
        return parts.join(', ') || '—';
    }

    get smsHighlightLabel() {
        return this.pageData?.smsConsent ? 'Opted in' : 'Not opted in';
    }

    get smsHighlightClass() {
        return this.pageData?.smsConsent ? 'hl-v hl-green' : 'hl-v hl-red';
    }

    get hasDeals() {
        return (this.pageData?.dealsAndService ?? []).length > 0;
    }

    handleRefresh() {
        refreshApex(this._wiredResult);
    }

    handleCall() {
        const phone = this.pageData?.contactRecord?.MobilePhone
            ?? this.pageData?.contactRecord?.Phone;
        if (phone) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: 'tel:' + phone }
            });
        }
    }

    handleLogOutreach() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: this.recordId }
        });
    }

    handleNextActionPrimary() {
        const caseId = this.pageData?.nextActionCaseId;
        const oppId  = this.pageData?.nextActionOppId;
        const navId  = caseId ?? oppId;
        if (navId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: navId, actionName: 'view' }
            });
        }
    }

    handleAddNote() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: this.recordId }
        });
    }

    handleEditContact() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'edit' }
        });
    }

    handleNewActivity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: this.recordId }
        });
    }

    handleOpenRecord(event) {
        const recordId = event.currentTarget.dataset.id || event.currentTarget.dataset.recordId;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }

    handleSendEmail() {
        console.log('handleSendEmail');
    }
}
