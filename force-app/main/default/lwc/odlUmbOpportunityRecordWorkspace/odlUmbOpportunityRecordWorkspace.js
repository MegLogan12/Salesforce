import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { updateRecord } from 'lightning/uiRecordApi';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getPageData from '@salesforce/apex/ODLOpportunityRecordController.getPageData';
import advanceStage from '@salesforce/apex/ODLOpportunityRecordController.advanceStage';

const NEW_TASK_ACTION = 'Global.NewTask';
const LOG_CALL_ACTION = 'Global.LogACall';
const NEW_EVENT_ACTION = 'Global.NewEvent';
const NEW_NOTE_ACTION = 'Global.NewNote';
const SEND_EMAIL_ACTION = 'Global.SendEmail';
const CLOSED_STAGE_LABELS = new Set(['job completed', 'closed won', 'closed lost', 'cancelled', 'canceled', 'complete']);

export default class OdlUmbOpportunityRecordWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    pageData;
    error;
    wiredResult;
    isAdvancingStage = false;
    focusSection;
    hasAppliedFocus = false;
    hasRedirectedToWinningPage = false;

    @wire(CurrentPageReference)
    wiredPageReference(pageReference) {
        this.focusSection = pageReference?.state?.c__focusSection || null;
        this.hasAppliedFocus = false;
    }

    @wire(getPageData, { opportunityId: '$recordId' })
    wiredPageData(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.pageData = data;
            this.error = undefined;
            this.hasAppliedFocus = false;
            if (!this.isUmbRecord && !this.hasRedirectedToWinningPage) {
                this.hasRedirectedToWinningPage = true;
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        actionName: 'view'
                    }
                });
                return;
            }
        } else if (error) {
            this.error = error;
            this.pageData = undefined;
        }
    }

    renderedCallback() {
        if (!this.focusSection || this.hasAppliedFocus || !this.hasData) {
            return;
        }
        const target = this.template.querySelector(`[data-focus-section="${this.focusSection}"]`);
        if (!target) {
            return;
        }
        this.hasAppliedFocus = true;
        requestAnimationFrame(() => {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        });
    }

    get opportunityRecord() {
        return this.pageData?.opportunityRecord || {};
    }

    get hasData() {
        return Boolean(this.pageData);
    }

    get isUmbRecord() {
        const recordType = this.opportunityRecord?.RecordType?.DeveloperName;
        const type = (this.opportunityRecord?.Type || '').trim();
        return recordType === 'UMB' || type === 'UpgradeMyBackyard' || type === 'UMB';
    }

    get accountUrl() {
        return this.pageData?.accountUrl;
    }

    get accountName() {
        return this.pageData?.accountName || '';
    }

    get emailAddress() {
        return this.opportunityRecord?.Account?.PersonEmail || '';
    }

    get phoneNumber() {
        return this.opportunityRecord?.Account?.PersonMobilePhone || this.opportunityRecord?.Account?.Phone || '';
    }

    get disableEmail() {
        return !this.emailAddress;
    }

    get disableCall() {
        return !this.phoneNumber;
    }

    get projectPath() {
        return this.pageData?.projectPath || '';
    }

    get packageDisplay() {
        return this.normalizePackage(this.opportunityRecord.BMG_Package__c);
    }

    get hasProjectPath() {
        return Boolean(this.projectPath);
    }

    get heroSubtitle() {
        return [
            this.accountName,
            this.pageData?.propertyRecord?.label,
            this.projectPath
        ].filter((value) => value && String(value).trim()).join(' · ');
    }

    get notesCount() {
        return (this.pageData?.notes || []).length;
    }

    get filesCount() {
        return (this.pageData?.files || []).length;
    }

    get quotesCount() {
        return (this.pageData?.quotes || []).length;
    }

    get openItemsCount() {
        return (this.pageData?.missingData || []).length;
    }

    get hasInteractions() {
        return (this.pageData?.interactions || []).length > 0;
    }

    get siteVisitRows() {
        return (this.pageData?.interactions || []).filter((row) => {
            const type = (row.interactionType || '').toLowerCase();
            const label = (row.label || '').toLowerCase();
            const status = (row.status || '').toLowerCase();
            const subtext = (row.subtext || '').toLowerCase();
            const combined = `${type} ${label} ${status} ${subtext}`;
            if (combined.includes('email') || combined.includes('call') || combined.includes('voicemail')) {
                return false;
            }
            return combined.includes('follow-up') || combined.includes('follow up') || combined.includes('visit') || type === 'event';
        });
    }

    get hasSiteVisitRows() {
        return this.siteVisitRows.length > 0;
    }

    get activityRows() {
        return (this.pageData?.interactions || []).filter((row) => !this.siteVisitRows.some((siteRow) => siteRow.id === row.id));
    }

    get hasActivityRows() {
        return this.activityRows.length > 0;
    }

    get stagePath() {
        return this.pageData?.stagePath || [];
    }

    get hasStagePath() {
        return this.stagePath.length > 0;
    }

    get stagePathItems() {
        let currentSeen = false;
        return this.stagePath.map((label) => {
            const isCurrent = label === this.opportunityRecord.StageName;
            const state = currentSeen ? 'upcoming' : (isCurrent ? 'current' : 'done');
            if (isCurrent) {
                currentSeen = true;
            }
            return {
                label,
                className: `path-step ${state}`,
                disabled: isCurrent
            };
        });
    }

    get formattedAmount() {
        const amount = this.opportunityRecord.Amount;
        if (amount == null || amount === '') {
            return '';
        }
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(amount);
    }

    get lastAction() {
        return this.pageData?.lastAction || '';
    }

    get lastActionDate() {
        return this.pageData?.lastActionDate || '';
    }

    get voicemailStatus() {
        if (!this.pageData?.lastAction) {
            return '';
        }
        return this.pageData?.lastActionWasVoicemail ? 'Yes' : 'No';
    }

    get hasDesignReviews() {
        return (this.pageData?.designReviews || []).length > 0;
    }

    get hasPaymentMilestones() {
        return (this.pageData?.paymentMilestones || []).length > 0;
    }

    get hasQuotes() {
        return (this.pageData?.quotes || []).length > 0;
    }

    get hasFiles() {
        return (this.pageData?.files || []).length > 0;
    }

    get hasNotes() {
        return (this.pageData?.notes || []).length > 0;
    }

    get notesSectionRows() {
        return [
            ...(this.pageData?.notes || []),
            ...(this.pageData?.interactions || [])
                .filter((row) => ['Email', 'Voicemail', 'Call'].includes(row.interactionType))
                .map((row) => ({
                    ...row,
                    subtext: row.interactionType
                }))
        ];
    }

    get hasNotesSectionRows() {
        return this.notesSectionRows.length > 0;
    }

    get hasProperty() {
        return Boolean(this.pageData?.propertyRecord);
    }

    get propertyRecordId() {
        return this.pageData?.propertyRecord?.id || null;
    }

    get accountRecordId() {
        const raw = this.pageData?.accountUrl || '';
        return raw ? raw.replace('/', '') : null;
    }

    get hasVoucher() {
        return Boolean(this.pageData?.voucherRecord);
    }

    get showNextStageAction() {
        const stageName = (this.opportunityRecord.StageName || '').trim().toLowerCase();
        return !CLOSED_STAGE_LABELS.has(stageName);
    }

    get openVouchers() {
        return this.pageData?.vouchers || [];
    }

    get hasOpenVouchers() {
        return this.openVouchers.length > 0;
    }

    get hasQuoteOrPaymentData() {
        return this.hasQuotes || this.hasPaymentMilestones;
    }

    get firstQuoteId() {
        return this.pageData?.quotes?.[0]?.id || null;
    }

    get missingData() {
        return this.pageData?.missingData || [];
    }

    get hasMissingData() {
        return this.missingData.length > 0;
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((item) => item.message).join(', ');
        }
        return this.error.body ? this.error.body.message : this.error.message;
    }

    normalizePackage(value) {
        if (!value) {
            return '';
        }
        const normalized = String(value).trim().toLowerCase();
        if (normalized === 'good' || normalized === 'retreat') {
            return 'Retreat';
        }
        if (normalized === 'better' || normalized === 'entertainer') {
            return 'Entertainer';
        }
        if (normalized === 'best' || normalized === 'signature') {
            return 'Signature';
        }
        return value;
    }

    handleNewTask() {
        this.navigateQuickAction(NEW_TASK_ACTION);
    }

    handleLogCall() {
        this.navigateQuickAction(LOG_CALL_ACTION);
    }

    handleNewEvent() {
        this.navigateQuickAction(NEW_EVENT_ACTION);
    }

    handleNewNote() {
        this.navigateQuickAction(NEW_NOTE_ACTION);
    }

    handleEditOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'edit'
            }
        });
    }

    async handleSelectStage(event) {
        const stageName = event.currentTarget.dataset.stage;
        if (!stageName || stageName === this.opportunityRecord.StageName) {
            return;
        }
        try {
            await updateRecord({
                fields: {
                    Id: this.recordId,
                    StageName: stageName
                }
            });
            await refreshApex(this.wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Opportunity updated',
                message: `Stage updated to ${stageName}.`,
                variant: 'success'
            }));
        } catch (error) {
            const message = Array.isArray(error?.body)
                ? error.body.map((item) => item.message).join(', ')
                : (error?.body?.message || error?.message || 'Unable to update the opportunity stage.');
            this.dispatchEvent(new ShowToastEvent({
                title: 'Stage update failed',
                message,
                variant: 'error'
            }));
        }
    }

    async handleNextStage() {
        if (this.isAdvancingStage) {
            return;
        }
        this.isAdvancingStage = true;
        try {
            const nextStage = await advanceStage({ opportunityId: this.recordId });
            await refreshApex(this.wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Opportunity advanced',
                message: `Stage updated to ${nextStage}.`,
                variant: 'success'
            }));
        } catch (error) {
            const message = Array.isArray(error?.body)
                ? error.body.map((item) => item.message).join(', ')
                : (error?.body?.message || error?.message || 'Unable to advance the opportunity stage.');
            this.dispatchEvent(new ShowToastEvent({
                title: 'Stage update failed',
                message,
                variant: 'error'
            }));
        } finally {
            this.isAdvancingStage = false;
        }
    }

    navigateQuickAction(apiName) {
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

    handleEmailHomeowner() {
        if (this.disableEmail) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: SEND_EMAIL_ACTION
            },
            state: {
                recordId: this.recordId,
                defaultFieldValues: `ToAddress=${encodeURIComponent(this.emailAddress)}`
            }
        });
    }

    handleCallHomeowner() {
        if (this.disableCall) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `tel:${this.phoneNumber}`
            }
        });
    }

    handleRefreshSection() {
        refreshApex(this.wiredResult);
    }

    handleOpenAccount() {
        if (!this.accountRecordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.accountRecordId,
                actionName: 'view'
            }
        });
    }

    handleOpenProperty() {
        if (!this.propertyRecordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.propertyRecordId,
                actionName: 'view'
            }
        });
    }

    handleOpenQuote() {
        if (this.firstQuoteId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.firstQuoteId,
                    actionName: 'view'
                }
            });
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Quote',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: encodeDefaultFieldValues({
                    OpportunityId: this.recordId
                })
            }
        });
    }
}