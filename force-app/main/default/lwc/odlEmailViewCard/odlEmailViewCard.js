import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEmailSummary from '@salesforce/apex/ODLEmailViewController.getEmailSummary';
import getRelatedEmails from '@salesforce/apex/ODLEmailViewController.getRelatedEmails';
import getEmailDetail from '@salesforce/apex/ODLEmailViewController.getEmailDetail';
import createFollowUpTask from '@salesforce/apex/ODLEmailViewController.createFollowUpTask';

const SEND_EMAIL_ACTIONS = {
    Case: 'Case.SendEmail',
    Quote: 'Quote.SendEmail',
    ServiceAppointment: 'ServiceAppointment.SendEmail',
    WorkOrder: 'WorkOrder.SendEmail',
    WorkOrderLineItem: 'WorkOrderLineItem.SendEmail'
};

export default class OdlEmailViewCard extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @api cardTitle = 'Email History';
    @api cardSubtitle = 'Related customer emails, logged messages, and follow-up communications';

    summary;
    rows;
    detail;
    summaryWire;
    rowsWire;
    detailError;
    selectedEmailId;
    selectedSourceType;
    createPending = false;

    @wire(getEmailSummary, { recordId: '$recordId' })
    wiredSummary(result) {
        this.summaryWire = result;
        if (result.data) {
            this.summary = result.data;
        }
    }

    @wire(getRelatedEmails, { recordId: '$recordId', limitSize: 20, offsetSize: 0 })
    wiredRows(result) {
        this.rowsWire = result;
        if (result.data) {
            this.rows = result.data;
            if ((!this.selectedEmailId || !this.selectedSourceType) && this.rows.length > 0) {
                this.selectRow(this.rows[0].id, this.rows[0].sourceType);
            }
        }
    }

    get cardIsReady() {
        return this.recordId && this.summary && this.rows;
    }

    get isLoading() {
        return !this.summary && !this.summaryError && !this.rowsError;
    }

    get summaryError() {
        return this.summaryWire && this.summaryWire.error;
    }

    get rowsError() {
        return this.rowsWire && this.rowsWire.error;
    }

    get showError() {
        return Boolean(this.summaryError || this.rowsError || this.detailError);
    }

    get errorMessage() {
        const error = this.summaryError || this.rowsError || this.detailError;
        if (!error) {
            return '';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((row) => row.message).join(', ');
        }
        return error.body ? error.body.message : error.message;
    }

    get showSourceUnavailable() {
        return this.summary && this.summary.sourceAvailable === false;
    }

    get sourceUnavailableReason() {
        return this.summary ? this.summary.unavailableReason : '';
    }

    get showSummary() {
        return this.summary && this.summary.sourceAvailable !== false;
    }

    get showEmailTable() {
        return this.showSummary && this.totalEmails > 0;
    }

    get showEmptyState() {
        return this.showSummary && this.totalEmails === 0;
    }

    get totalEmails() {
        return this.summary ? this.summary.totalEmails : 0;
    }

    get lastEmailDate() {
        return this.summary ? this.summary.lastEmailDate : null;
    }

    get lastEmailDirection() {
        return this.summary && this.summary.lastEmailDirection ? this.summary.lastEmailDirection : 'Not available';
    }

    get lastEmailOwner() {
        return this.summary && this.summary.lastEmailOwner ? this.summary.lastEmailOwner : 'Not available';
    }

    get needsReplyLabel() {
        return this.summary && this.summary.unreadOrNeedsReplyLabel ? this.summary.unreadOrNeedsReplyLabel : 'Unavailable';
    }

    get emailRows() {
        return (this.rows || []).map((row) => ({
            ...row,
            rowClass: row.id === this.selectedEmailId ? 'selected-row' : '',
            directionClass: `status-chip ${this.directionTone(row.direction)}`
        }));
    }

    get selectedDetail() {
        if (this.detail) {
            return this.detail;
        }
        const fallback = (this.rows || []).find((row) => row.id === this.selectedEmailId);
        return fallback
            ? {
                  ...fallback,
                  plainTextPreview: fallback.previewText
              }
            : null;
    }

    get disableOpenEmail() {
        return !this.selectedEmailId;
    }

    get disableSendEmail() {
        return !this.resolveSendEmailAction();
    }

    get sendEmailTitle() {
        return this.disableSendEmail
            ? 'Send Email is not available because no standard email composer action is configured for this record.'
            : 'Send Email';
    }

    get disableLogEmail() {
        return true;
    }

    get logEmailTitle() {
        return 'Log Email is not available because no standard email logging action is configured for this record.';
    }

    get disableReply() {
        return true;
    }

    get replyTitle() {
        return 'Reply is not available because no standard email composer action is configured for this record.';
    }

    get disableFollowUp() {
        return !this.recordId || this.createPending;
    }

    get followUpTitle() {
        return this.disableFollowUp ? 'A related record is required before a follow-up task can be created.' : 'Create Follow-Up Task';
    }

    directionTone(directionValue) {
        switch (directionValue) {
            case 'Inbound':
                return 'inbound';
            case 'Outbound':
                return 'outbound';
            case 'Logged Email':
                return 'logged';
            case 'System Email':
                return 'system';
            default:
                return 'neutral';
        }
    }

    selectEmailRow(event) {
        this.selectRow(event.currentTarget.dataset.id, event.currentTarget.dataset.source);
    }

    async selectRow(emailId, sourceType) {
        this.selectedEmailId = emailId;
        this.selectedSourceType = sourceType;
        this.detailError = undefined;
        if (sourceType === 'EmailMessage' || sourceType === 'Task') {
            try {
                this.detail = await getEmailDetail({ emailMessageId: emailId });
            } catch (error) {
                this.detail = undefined;
                this.detailError = error;
            }
        }
    }

    async refreshCard() {
        await Promise.all([refreshApex(this.summaryWire), refreshApex(this.rowsWire)]);
        if (this.selectedEmailId && this.selectedSourceType) {
            await this.selectRow(this.selectedEmailId, this.selectedSourceType);
        }
    }

    openSelectedEmail(event) {
        const emailId = event.currentTarget.dataset.id;
        const sourceType = event.currentTarget.dataset.source;
        this.selectRow(emailId, sourceType);
        this.navigateToRecord(emailId);
    }

    openEmail() {
        if (this.selectedEmailId) {
            this.navigateToRecord(this.selectedEmailId);
        }
    }

    sendEmail() {
        const apiName = this.resolveSendEmailAction();
        if (!apiName) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName
            },
            state: {
                recordId: this.recordId
            }
        });
    }

    logEmail() {
        this.showToast('Unavailable', this.logEmailTitle, 'warning');
    }

    replyToEmail() {
        this.showToast('Unavailable', this.replyTitle, 'warning');
    }

    async createFollowUpTask() {
        if (!this.recordId) {
            return;
        }
        this.createPending = true;
        try {
            const selected = this.selectedDetail;
            const subject = selected && selected.subject ? `Follow up: ${selected.subject}` : 'Follow up on customer email';
            const dueDate = this.tomorrowIsoDate();
            const result = await createFollowUpTask({
                recordId: this.recordId,
                emailMessageId: this.selectedEmailId,
                subject,
                dueDate,
                ownerId: null
            });
            this.showToast('Task created', `Follow-up task ${result.subject} was created.`, 'success');
            await this.refreshCard();
        } catch (error) {
            const message = error.body ? error.body.message : error.message;
            this.showToast('Task creation failed', message, 'error');
        } finally {
            this.createPending = false;
        }
    }

    resolveSendEmailAction() {
        return SEND_EMAIL_ACTIONS[this.objectApiName] || null;
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    tomorrowIsoDate() {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const year = tomorrow.getFullYear();
        const month = `${tomorrow.getMonth() + 1}`.padStart(2, '0');
        const day = `${tomorrow.getDate()}`.padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}