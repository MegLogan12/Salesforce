import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getAccountData from '@salesforce/apex/ODL_AccountController.getAccountData';
import getAccountOpportunities from '@salesforce/apex/ODL_AccountController.getAccountOpportunities';

export default class OdlAccountRecord extends LightningElement {
    @api recordId;
    @track account = {};
    @track opportunities = [];
    @track tasks = [];
    @track property = null;
    openOppCount = 0;
    activeProjects = 0;
    openTaskCount = 0;
    depositPosted = 0;
    openDeposit = 0;
    finalDueLater = 0;
    primaryContactName = '—';
    isLoaded = false;
    error;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getAccountData, { accountId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.account = data.account || {};
            this.tasks = (data.tasks || []).map(t => ({
                ...t,
                activityDateFormatted: t.ActivityDate
                    ? new Date(t.ActivityDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                    : '—'
            }));
            this.openOppCount = data.openOppCount || 0;
            this.activeProjects = data.activeProjects || 0;
            this.openTaskCount = data.openTaskCount || 0;
            this.depositPosted = data.depositPosted || 0;
            this.openDeposit = data.openDeposit || 0;
            this.finalDueLater = data.finalDueLater || 0;
            const props = (this.account.Homeowner_Properties__r && this.account.Homeowner_Properties__r.records) || [];
            this.property = props.length > 0 ? props[0] : null;
            const contacts = (this.account.Contacts && this.account.Contacts.records) || [];
            this.primaryContactName = contacts.length > 0 ? contacts[0].Name : '—';
            this.isLoaded = true;
        } else if (error) {
            this.error = error;
            this.isLoaded = true;
        }
    }

    @wire(getAccountOpportunities, { accountId: '$recordId' })
    wiredOpps({ error, data }) {
        if (data) {
            this.opportunities = data.map(o => ({
                ...o,
                lobChipClass: this.getLobChipClass(o.ODL_Path__c),
                amountFormatted: o.Amount ? '$' + Number(o.Amount).toLocaleString() : '—',
                lastActivityFormatted: o.LastActivityDate
                    ? new Date(o.LastActivityDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                    : '—'
            }));
        }
    }

    getLobChipClass(path) {
        if (path === 'UMB') return 'chip co';
        if (path === 'Custom Build') return 'chip cp';
        if (path === 'Lawn Care') return 'chip ct';
        return 'chip cgr';
    }

    get depositPostedFormatted() {
        return this.depositPosted ? '$' + Number(this.depositPosted).toLocaleString() : '$0';
    }
    get openDepositFormatted() {
        return this.openDeposit ? '$' + Number(this.openDeposit).toLocaleString() : '$0';
    }
    get finalDueLaterFormatted() {
        return this.finalDueLater ? '$' + Number(this.finalDueLater).toLocaleString() : '$0';
    }

    get healthChipClass() {
        const h = this.account.Customer_Health__c;
        if (h === 'Good' || h === 'Healthy') return 'chip cg';
        if (h === 'At Risk') return 'chip cr';
        return 'chip ca';
    }

    get smsOptInLabel() { return this.account.SMS_Opt_In__c ? 'Yes' : 'No'; }
    get smsChipClass() { return this.account.SMS_Opt_In__c ? 'chip cg' : 'chip cgr'; }

    get portalChipClass() {
        const p = this.account.Portal_Status__c;
        if (p === 'Active') return 'chip cg';
        if (p === 'Invited') return 'chip cb2';
        return 'chip cgr';
    }

    get drainageChipClass() {
        const d = this.property && this.property.Drainage_Risk__c;
        if (d === 'High') return 'chip cr';
        if (d === 'Medium') return 'chip ca';
        return 'chip cg';
    }

    get utilityChipClass() {
        const u = this.property && this.property.Utility_Review_Status__c;
        if (u === 'Review Needed' || u === 'Likely Required') return 'chip cb2';
        if (u === 'Complete') return 'chip cg';
        return 'chip cgr';
    }

    get readinessChipClass() {
        const r = this.property && this.property.Customer_Readiness__c;
        if (!r) return 'chip cgr';
        return 'chip ca';
    }

    get hasProperty() { return this.property != null; }
    get noOpportunities() { return this.opportunities.length === 0; }
    get noTasks() { return this.tasks.length === 0; }

    get lastTouchFormatted() {
        if (!this.tasks || this.tasks.length === 0) return '—';
        const sorted = [...this.tasks].sort((a, b) => {
            const da = a.ActivityDate ? new Date(a.ActivityDate) : new Date(0);
            const db = b.ActivityDate ? new Date(b.ActivityDate) : new Date(0);
            return db - da;
        });
        return sorted[0].activityDateFormatted || '—';
    }

    get voicemailLabel() {
        const vmTask = this.tasks.find(t => t.Subject && t.Subject.toLowerCase().includes('voicemail'));
        if (vmTask) return 'Left ' + (vmTask.activityDateFormatted || '');
        return 'None';
    }

    get vmChipClass() {
        const vmTask = this.tasks.find(t => t.Subject && t.Subject.toLowerCase().includes('voicemail'));
        return vmTask ? 'chip ca' : 'chip cgr';
    }

    get nextFollowUpFormatted() {
        const today = new Date();
        const future = this.tasks
            .filter(t => t.ActivityDate && new Date(t.ActivityDate) >= today)
            .sort((a, b) => new Date(a.ActivityDate) - new Date(b.ActivityDate));
        return future.length > 0 ? future[0].activityDateFormatted : '—';
    }
}
