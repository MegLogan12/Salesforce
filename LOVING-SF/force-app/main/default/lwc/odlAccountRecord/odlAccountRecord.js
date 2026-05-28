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
                activityDateFormatted: t.ActivityDate ? new Date(t.ActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'
            }));
            this.openOppCount = data.openOppCount || 0;
            this.activeProjects = data.activeProjects || 0;
            this.openTaskCount = data.openTaskCount || 0;
            const props = (this.account.Homeowner_Properties__r && this.account.Homeowner_Properties__r.records) || [];
            this.property = props.length > 0 ? props[0] : null;
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
                lastActivityFormatted: o.LastActivityDate ? new Date(o.LastActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—'
            }));
        }
    }

    getLobChipClass(path) {
        if (path === 'UMB') return 'chip co';
        if (path === 'Custom Build') return 'chip cp';
        if (path === 'Lawn Care') return 'chip ct';
        return 'chip cgr';
    }

    get healthChipClass() {
        const h = this.account.Customer_Health__c;
        if (h === 'Good') return 'chip cg';
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

    get hasProperty() { return this.property != null; }
    get noOpportunities() { return this.opportunities.length === 0; }
    get noTasks() { return this.tasks.length === 0; }
}
