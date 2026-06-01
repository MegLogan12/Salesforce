import { LightningElement, api, wire } from 'lwc';
import getPageData from '@salesforce/apex/HomeownerAccountPageController.getPageData';

export default class HomeownerAccountSidebar extends LightningElement {
    @api recordId;

    pageData;
    errorMessage;

    @wire(getPageData, { accountId: '$recordId' })
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.pageData = undefined;
            this.errorMessage = this.reduceError(error);
        }
    }

    reduceError(error) {
        if (!error) {
            return '';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error.body ? error.body.message : error.message;
    }

    get nextActions() {
        if (!this.pageData) {
            return [];
        }

        const actions = [];
        if ((this.pageData.kpis?.openOpportunities || 0) > 0) {
            const firstOpp = this.pageData.opportunities?.[0];
            if (firstOpp?.secondaryText) {
                actions.push(`${firstOpp.label}: follow up by ${firstOpp.secondaryText}.`);
            } else if (firstOpp?.status) {
                actions.push(`${firstOpp.label}: currently in ${firstOpp.status}.`);
            }
        }
        if ((this.pageData.paymentMilestones || []).length > 0) {
            const firstMilestone = this.pageData.paymentMilestones[0];
            actions.push(`${firstMilestone.label}: ${firstMilestone.status}.`);
        }
        if ((this.pageData.kpis?.openWorkOrders || 0) > 0) {
            const firstWorkOrder = this.pageData.workOrders?.[0];
            if (firstWorkOrder?.serviceAppointmentLabel && firstWorkOrder?.scheduledDateText) {
                actions.push(`${firstWorkOrder.label}: ${firstWorkOrder.serviceAppointmentLabel} on ${firstWorkOrder.scheduledDateText}.`);
            } else if (firstWorkOrder?.serviceAppointmentLabel) {
                actions.push(`${firstWorkOrder.label}: ${firstWorkOrder.serviceAppointmentLabel}.`);
            } else if (firstWorkOrder?.status) {
                actions.push(`${firstWorkOrder.label}: ${firstWorkOrder.status}.`);
            }
        }
        return actions.slice(0, 3);
    }

    get latestInteraction() {
        return this.pageData?.interactions?.[0];
    }

    get latestOpportunity() {
        return this.pageData?.opportunities?.[0];
    }

    get hasNextActions() {
        return this.nextActions.length > 0;
    }

    get milestoneRows() {
        return this.pageData?.paymentMilestones || [];
    }

    get hasLatestInteraction() {
        return Boolean(this.latestInteraction);
    }

    get nextFollowUp() {
        return this.latestOpportunity?.secondaryText || '—';
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

    get openDepositLabel() {
        return this.formatCurrency(this.sumMilestones((row) => this.isDeposit(row) && !this.isPaid(row)));
    }

    get depositPostedLabel() {
        return this.formatCurrency(this.sumMilestones((row) => this.isPaid(row)));
    }

    get finalDueLaterLabel() {
        return this.formatCurrency(this.sumMilestones((row) => !this.isDeposit(row) && !this.isPaid(row)));
    }

    get lastTouchDate() {
        return this.latestInteraction?.dateText || '—';
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
        return this.milestoneRows.reduce((sum, row) => {
            if (!predicate(row)) {
                return sum;
            }

            const numericValue = Number(String(row.notesPreview || '0').replace(/[^0-9.-]/g, ''));
            return sum + (Number.isFinite(numericValue) ? numericValue : 0);
        }, 0);
    }

    formatCurrency(amount) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(amount || 0);
    }
}