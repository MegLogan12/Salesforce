import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLVisibleWorkspaceController.getPageData';

const NEW_TASK_ACTION = 'Global.NewTask';

export default class OdlCampaignWorkspace extends NavigationMixin(LightningElement) {
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

    get recordUrl() {
        return this.recordId ? `/${this.recordId}` : '';
    }

    get memberRows() {
        return (this.getSectionRows('Campaign Members') || []).map((row, index) => ({
            ...row,
            key: `member-${index}`,
            followUpText: row.secondaryText || 'Review member'
        }));
    }

    get hasNoMembers() {
        return this.memberRows.length === 0;
    }

    get hasMembers() {
        return !this.hasNoMembers;
    }

    get campaignType() {
        return this.getFieldValue('Campaign Summary', 'Campaign Type');
    }

    get campaignLob() {
        return this.normalizeLob(this.campaignType);
    }

    get ownerValue() {
        return this.getFieldValue('Builder Sponsor', 'Owner');
    }

    get activeCampaignsValue() {
        return this.isActiveStatus ? '1' : '0';
    }

    get memberCountValue() {
        return this.getFieldValue('Offer / Voucher Details', 'Voucher Count') ? String(this.memberRows.length) : String(this.memberRows.length);
    }

    get leadCountValue() {
        return String((this.getSectionRows('Leads') || []).length);
    }

    get opportunityCountValue() {
        return String((this.getSectionRows('Opportunities') || []).length);
    }

    get revenueValue() {
        const revenue = this.getFieldValue('Campaign Summary', 'Expected Revenue');
        return revenue || '$0';
    }

    get voucherPendingValue() {
        const submitted = this.toInt(this.getFieldValue('Offer / Voucher Details', 'Submitted Count'));
        const validated = this.toInt(this.getFieldValue('Offer / Voucher Details', 'Validated Count'));
        const reserved = this.toInt(this.getFieldValue('Offer / Voucher Details', 'Reserved Count'));
        return String(submitted + validated + reserved);
    }

    get leadConversionValue() {
        const oppCount = this.toInt(this.opportunityCountValue);
        const leadCount = this.toInt(this.leadCountValue);
        if (!leadCount) {
            return '0%';
        }
        return `${Math.round((oppCount / leadCount) * 100)}%`;
    }

    get isActiveStatus() {
        return (this.pageData?.badges || []).includes('In Progress') || (this.pageData?.badges || []).includes('Active') || (this.pageData?.badges || []).includes('Started');
    }

    get hasOpenItems() {
        return (this.pageData?.openItems || []).length > 0;
    }

    get errorMessage() {
        if (!this.error) return '';
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((item) => item.message).join(', ');
        }
        return this.error.body ? this.error.body.message : this.error.message;
    }

    getSectionRows(title) {
        return (this.pageData?.sections || []).find((section) => section.title === title)?.rows || [];
    }

    getFieldValue(sectionTitle, fieldLabel) {
        const section = (this.pageData?.sections || []).find((item) => item.title === sectionTitle);
        const field = (section?.fields || []).find((item) => item.label === fieldLabel);
        return field?.value || '';
    }

    toInt(value) {
        const parsed = parseInt(String(value || '0').replace(/[^0-9-]/g, ''), 10);
        return Number.isNaN(parsed) ? 0 : parsed;
    }

    normalizeLob(value) {
        const normalized = String(value || '').toLowerCase();
        if (normalized.includes('backyard') || normalized.includes('voucher') || normalized.includes('umb')) {
            return 'UMB';
        }
        if (normalized.includes('design')) {
            return 'Custom Build';
        }
        return value || 'Outdoor Living';
    }

    handleNewTask() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: NEW_TASK_ACTION },
            state: { recordId: this.recordId }
        });
    }

    handleNewCampaign() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Campaign', actionName: 'new' }
        });
    }

    handleOpenVoucherQueue() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Voucher__c', actionName: 'list' }
        });
    }

    handleReviewMembers() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Campaign',
                relationshipApiName: 'CampaignMembers',
                actionName: 'view'
            }
        });
    }

    handleOpenReports() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Report', actionName: 'list' }
        });
    }
}