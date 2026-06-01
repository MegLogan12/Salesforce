import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { updateRecord } from 'lightning/uiRecordApi';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getLawnCareRecord from '@salesforce/apex/ODL_OpportunityController.getLawnCareRecord';

const NEW_TASK_ACTION = 'Global.NewTask';
const LOG_CALL_ACTION = 'Global.LogACall';
const NEW_EVENT_ACTION = 'Global.NewEvent';
const NEW_NOTE_ACTION = 'Global.NewNote';
const SEND_EMAIL_ACTION = 'Global.SendEmail';
const LC_STAGES = ['Inquiry', 'Estimate', 'Service Plan', 'Contract', 'First Service', 'Active'];
const CLOSED_STAGE_LABELS = new Set(['job completed', 'closed won', 'closed lost', 'cancelled', 'canceled', 'complete']);

export default class OdlLawnCareRecord extends NavigationMixin(LightningElement) {
    @api recordId;

    @track opp = {};
    @track tasks = [];
    @track notes = [];
    @track files = [];
    @track openItems = [];
    focusSection;
    hasAppliedFocus = false;
    isLoaded = false;
    loadError = false;
    loadErrorMessage = '';
    wiredResult;
    hasRedirectedToWinningPage = false;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(CurrentPageReference)
    wiredPageReference(pageReference) {
        this.focusSection = pageReference?.state?.c__focusSection || null;
        this.hasAppliedFocus = false;
    }

    @wire(getLawnCareRecord, { opportunityId: '$recordId' })
    wiredData(result) {
        this.wiredResult = result;
        const { error, data } = result;
        if (data) {
            this.loadError = false;
            this.loadErrorMessage = '';
            this.opp = data.opp || {};
            this.tasks = (data.tasks || []).map((task) => ({
                ...task,
                url: task.Id ? `/${task.Id}` : null,
                activityDateFormatted: task.ActivityDate
                    ? new Date(`${task.ActivityDate}T12:00:00`).toLocaleDateString('en-US', { month: '2-digit', day: '2-digit', year: 'numeric' })
                    : '—'
            }));
            this.notes = data.notes || [];
            this.files = data.files || [];
            this.openItems = data.openItems || [];
            this.isLoaded = true;
            this.hasAppliedFocus = false;
            if (!this.isLawnCareRecord && !this.hasRedirectedToWinningPage) {
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
            this.opp = {};
            this.tasks = [];
            this.notes = [];
            this.files = [];
            this.openItems = [];
            this.isLoaded = true;
            this.loadError = true;
            this.loadErrorMessage = error?.body?.message || error?.message || 'Unable to load the Lawn Care opportunity.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Opportunity load failed',
                    message: this.loadErrorMessage,
                    variant: 'error'
                })
            );
        }
    }

    renderedCallback() {
        if (!this.focusSection || this.hasAppliedFocus || !this.showLawnCareShell) {
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

    get showLawnCareShell() {
        return this.isLoaded && !this.loadError && this.isLawnCareRecord;
    }

    get pathSteps() {
        if (!this.isLawnCareRecord) {
            return [];
        }
        const current = this.opp.StageName || '';
        let currentSeen = false;
        return LC_STAGES.map((label) => {
            const isCurrent = label === current;
            const state = currentSeen ? 'upcoming' : (isCurrent ? 'current' : 'done');
            if (isCurrent) {
                currentSeen = true;
            }
            return {
                label,
                cssClass: `path-step ${state}`,
                disabled: isCurrent
            };
        });
    }

    get hasPathSteps() {
        return this.pathSteps.length > 0;
    }

    get heroSubtitle() {
        return [this.accountName, this.propertyName, this.opp.ODL_Path__c].filter(Boolean).join(' · ');
    }

    get lobLabel() {
        const recordTypeName = this.opp?.RecordType?.DeveloperName;
        if (recordTypeName === 'UMB' || this.opp?.Type === 'UpgradeMyBackyard' || this.opp?.Type === 'UMB') {
            return 'UMB';
        }
        if (recordTypeName === 'Design_Build' || this.opp?.Type === 'Design Build' || this.opp?.Type === 'Custom Build') {
            return 'Design Build';
        }
        return 'Lawn Care';
    }

    get isLawnCareRecord() {
        return this.lobLabel === 'Lawn Care';
    }

    get showNextStageAction() {
        const stageName = (this.opp?.StageName || '').trim().toLowerCase();
        return !CLOSED_STAGE_LABELS.has(stageName);
    }

    get accountName() {
        return this.opp?.Account?.Name || '—';
    }

    get accountUrl() {
        return this.opp?.AccountId ? `/${this.opp.AccountId}` : null;
    }

    get propertyName() {
        return this.opp?.Homeowner_Property__r?.Name || '';
    }

    get propertyUrl() {
        return this.opp?.Homeowner_Property__c ? `/${this.opp.Homeowner_Property__c}` : null;
    }

    get emailAddress() {
        return this.opp?.Account?.PersonEmail || '';
    }

    get phoneNumber() {
        return this.opp?.Account?.PersonMobilePhone || this.opp?.Account?.Phone || '';
    }

    get disableEmail() {
        return !this.emailAddress;
    }

    get disableCall() {
        return !this.phoneNumber;
    }

    get amountFormatted() {
        return this.formatCurrency(this.opp.Amount);
    }

    get closeDateFormatted() {
        return this.formatDate(this.opp.CloseDate);
    }

    get monthlyBillingFormatted() {
        return this.formatCurrency(this.opp.Monthly_Billing__c);
    }

    get estimateStatus() {
        return this.opp.Estimate_Status__c || '—';
    }

    get serviceInterest() {
        return this.opp.Services_Selected__c || '—';
    }

    get billingFrequency() {
        return this.opp.Billing_Frequency__c || '—';
    }

    get contractTerm() {
        return this.opp.Contract_Term__c || '—';
    }

    get lotSizeDisplay() {
        const value = this.opp?.Homeowner_Property__r?.Lot_Size__c;
        return value ? `${value} sqft` : '—';
    }

    get irrigationDisplay() {
        return this.opp?.Homeowner_Property__r?.Irrigation__c || '—';
    }

    get gateAccessDisplay() {
        return this.opp?.Homeowner_Property__r?.Gate_Access__c || '—';
    }

    get hasProperty() {
        return Boolean(this.opp?.Homeowner_Property__c);
    }

    get hasServicePlan() {
        return Boolean(this.opp?.Services_Selected__c || this.opp?.Billing_Frequency__c || this.opp?.Monthly_Billing__c || this.opp?.Contract_Term__c);
    }

    get showServicePlanSection() {
        return this.isLawnCareRecord && this.hasServicePlan;
    }

    get hasTasks() {
        return this.tasks.length > 0;
    }

    get notesCount() {
        return this.notes.length;
    }

    get filesCount() {
        return this.files.length;
    }

    get openItemsCount() {
        return this.openItems.length;
    }

    get hasNotes() {
        return this.notes.length > 0;
    }

    get hasFiles() {
        return this.files.length > 0;
    }

    get hasOpenItems() {
        return this.openItems.length > 0;
    }

    get voicemailLabel() {
        return this.opp?.Voicemail_Left__c ? 'Yes' : 'No';
    }

    get lastTouchFormatted() {
        return this.opp?.LastActivityDate ? this.formatDate(this.opp.LastActivityDate) : '—';
    }

    get lastActivityLabel() {
        if (!this.hasTasks) {
            return '—';
        }
        return this.sortedTasksDesc[0]?.Subject || '—';
    }

    get sortedTasksDesc() {
        return [...this.tasks].sort((a, b) => (a.ActivityDate < b.ActivityDate ? 1 : -1));
    }

    get nextTaskLabel() {
        if (!this.nextTask) {
            return '—';
        }
        return this.nextTask.Subject || '—';
    }

    get nextFollowUpFormatted() {
        if (!this.nextTask) {
            return '—';
        }
        return this.nextTask.activityDateFormatted || '—';
    }

    get nextTask() {
        const today = new Date().toISOString().slice(0, 10);
        const future = this.tasks
            .filter((task) => task.ActivityDate && task.ActivityDate >= today && task.Status !== 'Completed')
            .sort((a, b) => (a.ActivityDate > b.ActivityDate ? 1 : -1));
        return future[0] || null;
    }

    get nextActionItems() {
        const items = [];
        if (this.nextTask) {
            items.push({
                label: this.nextTask.Subject || 'Next Follow-Up',
                dateText: this.nextTask.activityDateFormatted
            });
        }
        if (this.hasOpenItems) {
            this.openItems.slice(0, 3).forEach((item) => items.push({ label: item, dateText: '' }));
        }
        if (!items.length) {
            return [];
        }
        return items.slice(0, 4);
    }

    get hasNextActionItems() {
        return this.nextActionItems.length > 0;
    }

    formatCurrency(value) {
        if (value == null || value === '') {
            return '—';
        }
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(value);
    }

    formatDate(value) {
        if (!value) {
            return '—';
        }
        return new Date(`${value}T12:00:00`).toLocaleDateString('en-US', {
            month: '2-digit',
            day: '2-digit',
            year: 'numeric'
        });
    }

    createTask() {
        this.navigateQuickAction(NEW_TASK_ACTION);
    }

    logCall() {
        this.navigateQuickAction(LOG_CALL_ACTION);
    }

    scheduleEvent() {
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
        if (!stageName || stageName === this.opp.StageName) {
            return;
        }
        try {
            await updateRecord({
                fields: {
                    Id: this.recordId,
                    StageName: stageName
                }
            });
            await this.refreshData();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Opportunity updated',
                    message: `Stage updated to ${stageName}.`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Stage update failed',
                    message: error?.body?.message || error?.message || 'Unable to update the opportunity stage.',
                    variant: 'error'
                })
            );
        }
    }

    async handleNextStage() {
        const currentIndex = LC_STAGES.indexOf(this.opp.StageName);
        if (currentIndex === -1 || currentIndex === LC_STAGES.length - 1) {
            return;
        }
        const nextStage = LC_STAGES[currentIndex + 1];
        await this.handleSelectStage({
            currentTarget: {
                dataset: { stage: nextStage }
            }
        });
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

    handleOpenAccount() {
        if (!this.opp?.AccountId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.opp.AccountId,
                actionName: 'view'
            }
        });
    }

    handleOpenProperty() {
        if (!this.opp?.Homeowner_Property__c) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.opp.Homeowner_Property__c,
                actionName: 'view'
            }
        });
    }

    async refreshData() {
        if (this.wiredResult) {
            await refreshApex(this.wiredResult);
        }
    }
}