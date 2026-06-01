import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPageData from '@salesforce/apex/HomeownerAccountPageController.getPageData';
import createScheduledInteraction from '@salesforce/apex/HomeownerAccountPageController.createScheduledInteraction';

const RINGCENTRAL_ACTION = 'Account.Call_with_RingCentral';
const SEND_EMAIL_ACTION = 'Global.SendEmail';
const NEW_NOTE_ACTION = 'Global.NewNote';
const NEW_TASK_ACTION = 'Global.NewTask';
const LOG_CALL_ACTION = 'Global.LogACall';
const NEW_EVENT_ACTION = 'Global.NewEvent';

export default class HomeownerAccountCommandCenter extends NavigationMixin(LightningElement) {
    @api recordId;

    pageData;
    error;
    isLoading = true;
    wiredResult;
    selectedScheduleType;
    showScheduleModal = false;
    isSavingSchedule = false;
    scheduleForm = {
        startDateTime: '',
        durationMinutes: 30,
        notes: ''
    };

    @wire(getPageData, { accountId: '$recordId' })
    wiredPageData(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.pageData = data;
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.pageData = undefined;
            this.error = error;
            this.isLoading = false;
        }
    }

    get accountRecord() {
        return this.pageData ? this.pageData.accountRecord : {};
    }

    get propertyContext() {
        return this.pageData ? this.pageData.propertyContext || {} : {};
    }

    get accountType() {
        return this.accountRecord.Type || '';
    }

    get customerHealth() {
        return this.accountRecord.Customer_Health__c || '';
    }

    get preferredContactMethod() {
        return this.accountRecord.Preferred_Contact_Method__c || '';
    }

    get portalStatus() {
        return this.accountRecord.Portal_Status__c || '';
    }

    get smsOptInLabel() {
        const value = this.accountRecord.SMS_Opt_In__c;
        if (value === true) {
            return 'Yes';
        }
        if (value === false) {
            return 'No';
        }
        return '';
    }

    get hasAccountType() {
        return Boolean(this.accountType);
    }

    get ownerName() {
        return this.accountRecord.Owner ? this.accountRecord.Owner.Name : '';
    }

    get primaryContactDisplay() {
        return this.pageData?.contactDisplay || this.accountRecord.Name || '';
    }

    get householdDisplayName() {
        return this.pageData?.householdDisplayName || this.accountRecord.Name || '';
    }

    get secondaryContactName() {
        return this.pageData?.secondaryContactName || '';
    }

    get mailingAddress() {
        return this.pageData?.mailingAddress || '';
    }

    get phoneDisplay() {
        return this.accountRecord.PersonMobilePhone || this.accountRecord.Phone || '';
    }

    get phoneHref() {
        const raw = this.accountRecord.PersonMobilePhone || this.accountRecord.Phone;
        return raw ? `tel:${raw}` : '';
    }

    get disableCall() {
        return !this.phoneHref;
    }

    get emailDisplay() {
        return this.pageData?.householdEmailDisplay || this.accountRecord.PersonEmail || '';
    }

    get disableEmail() {
        return !(this.pageData?.householdEmailDisplay || this.accountRecord.PersonEmail);
    }

    get emailTitle() {
        return this.disableEmail
            ? 'Email is unavailable because this homeowner does not have an email address.'
            : 'Open email composer';
    }

    get relationshipStatus() {
        if (!this.pageData) {
            return 'Loading';
        }
        if (this.openCases > 0) {
            return 'Needs attention';
        }
        if (this.openWorkOrders > 0) {
            return 'Active project';
        }
        if (this.openOpportunities > 0) {
            return 'Active sales path';
        }
        return 'Monitoring';
    }

    get relationshipStatusClass() {
        if (this.openCases > 0) {
            return 'chip chip-alert';
        }
        if (this.openWorkOrders > 0) {
            return 'chip chip-good';
        }
        if (this.openOpportunities > 0) {
            return 'chip chip-warn';
        }
        return 'chip chip-neutral';
    }

    get openOpportunities() {
        return this.pageData ? this.pageData.kpis.openOpportunities : 0;
    }

    get openWorkOrders() {
        return this.pageData ? this.pageData.kpis.openWorkOrders : 0;
    }

    get openCases() {
        return this.pageData ? this.pageData.kpis.openCases : 0;
    }

    get scheduledInteractions() {
        return this.pageData ? this.pageData.kpis.scheduledInteractions : 0;
    }

    get openTasks() {
        return this.pageData ? this.pageData.kpis.openTasks : 0;
    }

    get propertyProjectLabel() {
        return this.propertyContext.projectLabel || '';
    }

    get propertyProjectUrl() {
        return this.propertyContext.projectUrl;
    }

    get propertyCommunity() {
        return this.propertyContext.communityName || '';
    }

    get propertyRecordLabel() {
        return this.propertyContext.propertyName || this.propertyContext.propertyLabel || '';
    }

    get propertyRecordUrl() {
        return this.propertyContext.propertyUrl;
    }

    get propertyRecordId() {
        const url = this.propertyRecordUrl;
        if (!url) {
            return '';
        }
        const match = String(url).match(/\/([a-zA-Z0-9]{15,18})(?:\/|$)/);
        return match ? match[1] : '';
    }

    get propertyLot() {
        return this.propertyContext.lotLabel || '';
    }

    get propertyPackage() {
        return this.normalizePackage(this.propertyContext.packageName);
    }

    get propertyLayoutLabel() {
        if (this.propertyContext.layoutUrl) {
            return 'Open layout';
        }
        if (this.propertyContext.layoutAttached) {
            return 'Attached';
        }
        return '';
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

    get hasPropertyNote() {
        return Boolean(this.propertyContext.note);
    }

    get hasOpportunities() {
        return this.pageData && this.pageData.opportunities && this.pageData.opportunities.length > 0;
    }

    get hasPropertyContext() {
        const ctx = this.propertyContext;
        return Boolean(
            this.propertyRecordUrl ||
            this.propertyRecordLabel ||
            ctx.address ||
            this.propertyCommunity ||
            this.propertyProjectUrl ||
            this.propertyProjectLabel ||
            ctx.accessType ||
            ctx.drainageRisk ||
            ctx.utilityReviewStatus ||
            ctx.customerReadiness ||
            ctx.note
        );
    }

    get hasWorkOrders() {
        return this.pageData && this.pageData.workOrders && this.pageData.workOrders.length > 0;
    }

    get hasDesignReviews() {
        return this.pageData && this.pageData.designReviews && this.pageData.designReviews.length > 0;
    }

    get hasPaymentMilestones() {
        return this.pageData && this.pageData.paymentMilestones && this.pageData.paymentMilestones.length > 0;
    }

    get hasVouchers() {
        return this.pageData && this.pageData.vouchers && this.pageData.vouchers.length > 0;
    }

    get hasFiles() {
        return this.pageData && this.pageData.files && this.pageData.files.length > 0;
    }

    get hasNotes() {
        return this.pageData && this.pageData.notes && this.pageData.notes.length > 0;
    }

    get hasInteractions() {
        return this.pageData && this.pageData.interactions && this.pageData.interactions.length > 0;
    }

    get hasMissingData() {
        return this.pageData && this.pageData.missingData && this.pageData.missingData.length > 0;
    }

    get missingDataItems() {
        return this.pageData?.missingData || [];
    }

    get latestInteraction() {
        return this.pageData?.interactions?.length ? this.pageData.interactions[0] : null;
    }

    get hasLatestInteraction() {
        return Boolean(this.latestInteraction);
    }

    get pageLayoutClass() {
        return 'page-layout';
    }

    get latestInteractionDate() {
        return this.latestInteraction?.dateText || '';
    }

    get lastTouchDate() {
        return this.latestInteraction?.dateText || '—';
    }

    get latestInteractionType() {
        return this.latestInteraction?.interactionType || '';
    }

    get latestInteractionSubject() {
        return this.latestInteraction?.subjectText || this.latestInteraction?.label || '';
    }

    get nextActionRows() {
        return [
            ...(this.pageData?.opportunities || []),
            ...(this.pageData?.workOrders || [])
        ]
            .filter((row) => row.secondaryText || row.subjectText || row.dateText)
            .slice(0, 4);
    }

    get hasNextActionRows() {
        return this.nextActionRows.length > 0;
    }

    get nextActions() {
        const actions = [];
        const firstOpp = this.pageData?.opportunities?.[0];
        if (firstOpp) {
            if (firstOpp.secondaryText) {
                actions.push(`${firstOpp.label}: follow up by ${firstOpp.secondaryText}.`);
            } else if (firstOpp.status) {
                actions.push(`${firstOpp.label}: currently in ${firstOpp.status}.`);
            }
        }

        const firstMilestone = this.paymentSummaryItems[0];
        if (firstMilestone) {
            actions.push(`${firstMilestone.label}: ${firstMilestone.status}.`);
        }

        const firstWorkOrder = this.pageData?.workOrders?.[0];
        if (firstWorkOrder) {
            if (firstWorkOrder.serviceAppointmentLabel && firstWorkOrder.scheduledDateText) {
                actions.push(`${firstWorkOrder.label}: ${firstWorkOrder.serviceAppointmentLabel} on ${firstWorkOrder.scheduledDateText}.`);
            } else if (firstWorkOrder.serviceAppointmentLabel) {
                actions.push(`${firstWorkOrder.label}: ${firstWorkOrder.serviceAppointmentLabel}.`);
            } else if (firstWorkOrder.status) {
                actions.push(`${firstWorkOrder.label}: ${firstWorkOrder.status}.`);
            }
        }

        return actions.slice(0, 3);
    }

    get hasNextActions() {
        return this.nextActions.length > 0;
    }

    get paymentSummaryItems() {
        return (this.pageData?.paymentMilestones || []).slice(0, 4);
    }

    get openTaskCount() {
        return this.pageData?.kpis?.openTasks || 0;
    }

    get voicemailStatus() {
        const voicemailRow = (this.pageData?.interactions || []).find((row) => {
            const interactionType = (row.interactionType || '').toLowerCase();
            const subject = (row.subjectText || row.label || '').toLowerCase();
            return interactionType.includes('voicemail') || subject.includes('voicemail');
        });

        if (!voicemailRow) {
            return 'None';
        }

        return voicemailRow.dateText ? `Left ${voicemailRow.dateText}` : 'Left';
    }

    get nextFollowUp() {
        return this.pageData?.opportunities?.[0]?.secondaryText || '—';
    }

    get openDepositLabel() {
        return this.formatCurrency(this.sumMilestones((row) => this.isDeposit(row) && !this.isPaid(row)));
    }

    get depositPostedLabel() {
        return this.formatCurrency(this.sumMilestones((row) => this.isPaid(row)));
    }

    get finalDueLaterLabel() {
        return this.formatCurrency(this.sumMilestones((row) => !this.isDeposit(row) && !this.isPaid(row)));
    }

    get scheduleTypeLabel() {
        switch (this.selectedScheduleType) {
            case 'call':
                return 'Call';
            case 'virtual':
                return 'Virtual Visit';
            case 'onsite':
                return 'Onsite';
            default:
                return 'Interaction';
        }
    }

    get scheduleNotesLabel() {
        return this.selectedScheduleType === 'call' ? 'Call summary' : 'Visit notes';
    }

    get scheduleSaveDisabled() {
        return this.isSavingSchedule || !this.scheduleForm.startDateTime;
    }

    get ringCentralTitle() {
        return this.phoneHref
            ? 'Call this homeowner in RingCentral.'
            : 'Call is unavailable because this homeowner does not have a phone number.';
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

    isDeposit(row) {
        const label = `${row?.label || ''} ${row?.status || ''}`.toLowerCase();
        return label.includes('deposit');
    }

    isPaid(row) {
        const status = (row?.status || '').toLowerCase();
        const secondary = (row?.secondaryText || '').toLowerCase();
        return status.includes('paid') || secondary.includes('paid');
    }

    sumMilestones(predicate) {
        return this.paymentSummaryItems.reduce((sum, row) => {
            if (!predicate(row)) {
                return sum;
            }

            const numericValue = Number(String(row.notesPreview || '0').replace(/[^0-9.-]/g, ''));
            return sum + (Number.isFinite(numericValue) ? numericValue : 0);
        }, 0);
    }

    formatCurrency(amount) {
        const value = Number(amount) || 0;
        return value.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
    }

    handleLeaveNote() {
        this.navigateQuickAction(NEW_NOTE_ACTION);
    }

    handleEditAccount() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'edit'
            }
        });
    }

    handleEditProperty() {
        if (!this.propertyRecordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.propertyRecordId,
                actionName: 'edit'
            }
        });
    }

    handleEmail() {
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
                defaultFieldValues: `ToAddress=${encodeURIComponent(this.emailDisplay)}`
            }
        });
    }

    handleRingCentralCall() {
        if (this.disableCall) {
            return;
        }
        this.navigateQuickAction(RINGCENTRAL_ACTION);
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

    handleRefreshSection() {
        refreshApex(this.wiredResult);
    }

    handleJumpSection(event) {
        const sectionName = event.currentTarget.dataset.section;
        if (!sectionName) {
            return;
        }
        const target = this.template.querySelector(`[data-section-anchor="${sectionName}"]`);
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    handleScheduleSelect(event) {
        this.selectedScheduleType = event.detail.value;
        this.scheduleForm = {
            startDateTime: this.defaultStartDateTime(),
            durationMinutes: 30,
            notes: ''
        };
        this.showScheduleModal = true;
    }

    handleScheduleInput(event) {
        const { name, value } = event.target;
        this.scheduleForm = {
            ...this.scheduleForm,
            [name]: value
        };
    }

    closeScheduleModal() {
        this.showScheduleModal = false;
        this.selectedScheduleType = null;
    }

    async saveScheduledInteraction() {
        if (!this.scheduleForm.startDateTime || !this.selectedScheduleType) {
            return;
        }
        this.isSavingSchedule = true;
        try {
            const result = await createScheduledInteraction({
                accountId: this.recordId,
                interactionType: this.selectedScheduleType,
                startDateTime: this.scheduleForm.startDateTime,
                durationMinutes: Number(this.scheduleForm.durationMinutes) || 30,
                notes: this.scheduleForm.notes
            });

            const messageParts = [`${this.scheduleTypeLabel} created.`];
            let variant = 'success';
            if (result && result.confirmationMessage) {
                messageParts.push(result.confirmationMessage);
                if (!result.confirmationSent) {
                    variant = 'warning';
                }
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Scheduled',
                    message: messageParts.join(' '),
                    variant
                })
            );
            await refreshApex(this.wiredResult);
            this.closeScheduleModal();
        } catch (error) {
            const message = error.body ? error.body.message : error.message;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Schedule failed',
                    message,
                    variant: 'error'
                })
            );
        } finally {
            this.isSavingSchedule = false;
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

    defaultStartDateTime() {
        const nextHour = new Date();
        nextHour.setMinutes(0, 0, 0);
        nextHour.setHours(nextHour.getHours() + 1);
        const year = nextHour.getFullYear();
        const month = `${nextHour.getMonth() + 1}`.padStart(2, '0');
        const day = `${nextHour.getDate()}`.padStart(2, '0');
        const hours = `${nextHour.getHours()}`.padStart(2, '0');
        const minutes = `${nextHour.getMinutes()}`.padStart(2, '0');
        return `${year}-${month}-${day}T${hours}:${minutes}`;
    }
}