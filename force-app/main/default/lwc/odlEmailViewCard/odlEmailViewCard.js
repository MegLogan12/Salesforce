import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getEmails from '@salesforce/apex/ODLEmailViewController.getEmails';

export default class OdlEmailViewCard extends NavigationMixin(LightningElement) {
    @api recordId;

    @track emailData  = null;
    @track error      = null;
    @track isLoading  = true;

    _wiredResult;

    @wire(getEmails, { recordId: '$recordId' })
    wiredEmails(result) {
        this._wiredResult = result;
        if (result.data) {
            this.emailData = result.data;
            this.error     = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error     = result.error?.body?.message || 'Unable to load emails.';
            this.isLoading = false;
        }
    }

    // ── Computed getters ──────────────────────────────────────────────────────

    get emails() {
        return this.emailData ?? [];
    }

    get hasEmails() {
        return (this.emailData ?? []).length > 0;
    }

    get emailCount() {
        return (this.emailData ?? []).length;
    }

    get hasError() {
        return !!this.error;
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleOpenTask(evt) {
        const recordId = evt.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }
}
