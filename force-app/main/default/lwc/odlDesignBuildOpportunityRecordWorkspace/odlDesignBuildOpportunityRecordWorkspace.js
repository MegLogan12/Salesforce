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

export default class OdlDesignBuildOpportunityRecordWorkspace extends NavigationMixin(LightningElement) {
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
            if (!this.isDesignBuildRecord && !this.hasRedirectedToWinningPage) {
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

    get hasData() {
        return Boolean(this.pageData);
    }

    get opportunityRecord() {
        return this.pageData?.opportunityRecord || {};
    }

    get isDesignBuildRecord() {
        const recordType = this.opportunityRecord?.RecordType?.DeveloperName;
        const type = (this.opportunityRecord?.Type || '').trim();
        return recordType === 'Design_Build' || type === 'Design Build' || type === 'Custom Build';
    }

    get accountUrl() {
        return this.pageData?.accountUrl;
    }

    get accountName() {
        return this.pageData?.accountName || '';
    }

    get showNextStageAction() {
        const stageName = (this.opportunityRecord.StageName || '').trim().toLowerCase();
        return !CLOSED_STAGE_LABELS.has(stageName);
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

    get formattedAmount() {
        return this.opportunityRecord.Amount == null ? '' : this.formatCurrency(this.opportunityRecord.Amount);
    }

    get heroSubtitle() {
        return [
            this.accountName,
            this.pageData?.propertyRecord?.label,
            'Design Build'
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

    get projectVision() {
        return this.firstNonBlank([
            this.opportunityRecord.Services_Selected__c,
            this.opportunityRecord.Selected_Requirements__c,
            'No discovery summary has been captured yet.'
        ]);
    }

    get budgetComfort() {
        return this.firstNonBlank([
            this.opportunityRecord.Budget__c,
            'Budget not yet captured'
        ]);
    }

    get decisionMakers() {
        return this.accountName || 'Account not linked';
    }

    get timelineValue() {
        return this.firstNonBlank([
            this.opportunityRecord.Timeline__c,
            'Timeline not yet captured'
        ]);
    }

    get nextTaskStatus() {
        return this.pageData?.nextFollowUpSubject ? 'Scheduled' : 'Not Scheduled';
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
        return (this.pageData?.interactions || []).filter((row) => !this.siteVisitRows.some((siteRow) => siteRow.id === row.id)).slice(0, 4);
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

    get hasStagePath() {
        return (this.pageData?.stagePath || []).length > 0;
    }

    get stagePathItems() {
        const stagePath = this.pageData?.stagePath || [];
        let currentSeen = false;
        return stagePath.map((label) => {
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

    get estimateStatus() {
        return this.pageData?.quotes?.[0]?.status || 'Not Started';
    }

    get projectedCost() {
        return this.opportunityRecord.Budget__c || 'Pending';
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

    get hasVoucher() {
        return Boolean(this.pageData?.voucherRecord);
    }

    get openVouchers() {
        return this.pageData?.vouchers || [];
    }

    get hasOpenVouchers() {
        return this.openVouchers.length > 0;
    }

    get hasQuotes() {
        return (this.pageData?.quotes || []).length > 0;
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

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(value);
    }

    firstNonBlank(values) {
        return values.find((value) => value && String(value).trim()) || '';
    }

    handleNewTask() {
        this.navigateQuickAction(NEW_TASK_ACTION);
    }

    handleLogCall() {
        this.navigateQuickAction(LOG_CALL_ACTION);
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
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Opportunity updated',
                    message: `Stage updated to ${stageName}.`,
                    variant: 'success'
                })
            );
        } catch (error) {
            const message = Array.isArray(error?.body)
                ? error.body.map((item) => item.message).join(', ')
                : (error?.body?.message || error?.message || 'Unable to update the opportunity stage.');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Stage update failed',
                    message,
                    variant: 'error'
                })
            );
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
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Opportunity advanced',
                    message: `Stage updated to ${nextStage}.`,
                    variant: 'success'
                })
            );
        } catch (error) {
            const message = Array.isArray(error?.body)
                ? error.body.map((item) => item.message).join(', ')
                : (error?.body?.message || error?.message || 'Unable to advance the opportunity stage.');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Stage update failed',
                    message,
                    variant: 'error'
                })
            );
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

    handleNewEvent() {
        this.navigateQuickAction(NEW_EVENT_ACTION);
    }

    handleNewNote() {
        this.navigateQuickAction(NEW_NOTE_ACTION);
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