import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLOpportunityRecordController.getPageData';

export default class OdlOpportunityRecordWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    activeTab = 'overview';
    pageData;
    error;

    @wire(getPageData, { opportunityId: '$recordId' })
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.pageData = undefined;
        }
    }

    get hasData() { return Boolean(this.pageData); }
    get hasError() { return Boolean(this.error); }

    get opportunityRecord() { return this.pageData?.opportunityRecord || {}; }
    get accountUrl() { return this.pageData?.accountUrl; }
    get accountName() { return this.pageData?.accountName || 'No account linked'; }
    get projectPath() { return this.pageData?.projectPath || 'Not classified'; }
    get lastAction() { return this.pageData?.lastAction || 'No action logged'; }
    get lastActionDate() { return this.pageData?.lastActionDate || ''; }
    get readiness() { return this.pageData?.readiness; }
    get nextActionText() { return this.pageData?.nextActionText || ''; }
    get nextActionButton() { return this.pageData?.nextActionButton ?? null; }
    get woReady() { return this.pageData?.readiness?.woReady || false; }

    get stagePath() { return this.pageData?.stagePath || []; }
    get hasStagePath() { return this.stagePath.length > 0; }

    get stagePathItems() {
        let currentSeen = false;
        return this.stagePath.map(label => {
            const isCurrent = label === this.opportunityRecord.StageName;
            const state = currentSeen ? 'upcoming' : (isCurrent ? 'current' : 'done');
            if (isCurrent) currentSeen = true;
            return { label, className: `path-step path-step-${state}` };
        });
    }

    get stageChipClass() {
        const stage = this.opportunityRecord.StageName || '';
        const lower = stage.toLowerCase();
        if (lower === 'discovery') return 'chip chip-stone';
        if (lower === 'consult scheduled') return 'chip chip-blue-lt';
        if (lower === 'design in progress') return 'chip chip-blue';
        if (lower === 'quote review') return 'chip chip-amber';
        if (lower === 'contract sent') return 'chip chip-amber';
        if (lower === 'deposit pending') return 'chip chip-orange';
        if (lower === 'closed won') return 'chip chip-green';
        if (lower === 'closed lost') return 'chip chip-red';
        return 'chip chip-gray';
    }

    get amountDisplay() {
        const amount = this.opportunityRecord.Amount;
        if (amount == null) return null;
        return '$' + Math.round(amount).toLocaleString();
    }

    get packageDisplay() {
        const pkg = this.opportunityRecord.BMG_Package__c || this.opportunityRecord.Selected_Package__c;
        if (!pkg) return null;
        const lower = pkg.toLowerCase().trim();
        if (lower === 'retreat' || lower === 'good') return 'Retreat';
        if (lower === 'entertainer' || lower === 'better') return 'Entertainer';
        if (lower === 'signature' || lower === 'best') return 'Signature';
        return pkg;
    }

    get hasInteractions() { return (this.pageData?.interactions || []).length > 0; }
    get hasDesignReviews() { return (this.pageData?.designReviews || []).length > 0; }
    get hasPaymentMilestones() { return (this.pageData?.paymentMilestones || []).length > 0; }
    get hasQuotes() { return (this.pageData?.quotes || []).length > 0; }
    get hasFiles() { return (this.pageData?.files || []).length > 0; }
    get hasVoucher() { return Boolean(this.pageData?.voucherRecord); }
    get hasProperty() { return Boolean(this.pageData?.propertyRecord); }
    get engagement() { return this.pageData?.engagement ?? null; }
    get engagementState() { return this.pageData?.engagement?.state ?? ''; }
    get isDesignBuild() { return this.pageData?.opportunityRecord?.RecordType?.DeveloperName === 'Design_Build'; }

    get missingData() { return this.pageData?.missingData || []; }
    get hasMissingData() { return this.missingData.length > 0; }
    get neitherQuoteNorPayment() { return !this.hasQuotes && !this.hasPaymentMilestones; }

    get errorMessage() {
        if (!this.error) return '';
        if (Array.isArray(this.error.body)) return this.error.body.map(e => e.message).join(', ');
        return this.error.body?.message || this.error.message || 'Unable to load opportunity data.';
    }

    get isOverviewTab() { return this.activeTab === 'overview'; }
    get isCloseTab() { return this.activeTab === 'close'; }
    get tabClassOverview() { return this.activeTab === 'overview' ? 'tab-btn tab-btn-active' : 'tab-btn'; }
    get tabClassClose() { return this.activeTab === 'close' ? 'tab-btn tab-btn-active' : 'tab-btn'; }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleNewTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: this.recordId }
        });
    }

    handleCloseLost() {
        this.activeTab = 'close';
    }

    handleCloseWon() {
        this.activeTab = 'close';
    }

    handleLogCall() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.LogACall' },
            state: { recordId: this.recordId }
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

    handleRecordPayment(event) {
        const recordId = event?.currentTarget?.dataset?.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'edit' }
            });
        }
    }

    handleSendEmail() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.SendEmail' },
            state: { recordId: this.recordId }
        });
    }

    handleSendQuote(event) {
        const recordId = event?.currentTarget?.dataset?.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }
}
