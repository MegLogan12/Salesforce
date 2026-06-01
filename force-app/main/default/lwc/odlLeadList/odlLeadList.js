import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getLeadList from '@salesforce/apex/ODL_LeadController.getLeadList';

const FMT = { month: 'short', day: 'numeric' };

function fmtDate(d) {
    if (!d) return '—';
    return new Date(d + 'T12:00:00').toLocaleDateString('en-US', FMT);
}

export default class OdlLeadList extends NavigationMixin(LightningElement) {
    @track leads = [];
    @track activeFilter = 'All';
    @track activeOwner = '';
    @track searchTerm = '';
    error;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getLeadList, { odlPath: '' })
    wiredLeads({ error, data }) {
        if (data) {
            this.leads = data.map(l => {
                const openActs = l.OpenActivities || [];
                const histActs = l.ActivityHistories || [];
                const nextOpen = openActs.length > 0 ? openActs[0] : null;
                const lastDone = histActs.length > 0 ? histActs[0] : null;

                const lastDesc = lastDone
                    ? ((lastDone.Subject || 'Activity') + ', ' + fmtDate(lastDone.ActivityDate))
                    : (l.LastActivityDate ? ('Activity, ' + fmtDate(l.LastActivityDate)) : '—');

                const vmDate = l.Last_Voicemail_Date__c ? fmtDate(l.Last_Voicemail_Date__c) : '';
                return {
                    ...l,
                    lobChipClass: l.ODL_Path__c === 'UMB' ? 'chip co'
                        : l.ODL_Path__c === 'Custom Build' ? 'chip cp'
                        : l.ODL_Path__c === 'Lawn Care' ? 'chip ct' : 'chip cgr',
                    lastActivityDesc: lastDesc,
                    lastActivityFormatted: fmtDate(l.LastActivityDate),
                    voicemailLabel: vmDate ? 'Yes, ' + vmDate : 'Yes',
                    followUpTask: nextOpen ? (nextOpen.Subject || '—') : '—',
                    followUpDue: nextOpen ? fmtDate(nextOpen.ActivityDate) : '—'
                };
            });
        } else if (error) {
            this.error = error;
            this.leads = [];
        }
    }

    get hasError() {
        return Boolean(this.error);
    }

    get errorMessage() {
        if (!this.error) return '';
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((row) => row.message).join(', ');
        }
        return this.error.body?.message || this.error.message || 'Unable to load leads.';
    }

    get filteredLeads() {
        let result = [...this.leads];
        if (this.activeFilter === 'Voicemail') {
            result = result.filter(l => l.Voicemail_Left__c);
        } else if (this.activeFilter === 'FollowUp') {
            result = result.filter(l => l.followUpTask !== '—');
        } else if (this.activeFilter !== 'All') {
            result = result.filter(l => l.ODL_Path__c === this.activeFilter);
        }
        if (this.activeOwner) {
            result = result.filter(l => l.OwnerId === this.activeOwner);
        }
        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            result = result.filter(l =>
                (l.Name || '').toLowerCase().includes(term) ||
                (l.Company || '').toLowerCase().includes(term) ||
                (l.Service_Interest__c || '').toLowerCase().includes(term)
            );
        }
        return result;
    }

    get ownerOptions() {
        const seen = new Set();
        return this.leads
            .filter(l => l.Owner && l.Owner.Name && !seen.has(l.OwnerId) && seen.add(l.OwnerId))
            .map(l => ({ value: l.OwnerId, label: l.Owner.Name }));
    }

    get allChipClass() { return this.activeFilter === 'All'          ? 'filter-chip on' : 'filter-chip'; }
    get umbChipClass() { return this.activeFilter === 'UMB'          ? 'filter-chip on' : 'filter-chip'; }
    get cbChipClass()  { return this.activeFilter === 'Custom Build'  ? 'filter-chip on' : 'filter-chip'; }
    get lcChipClass()  { return this.activeFilter === 'Lawn Care'     ? 'filter-chip on' : 'filter-chip'; }
    get vmChipClass()  { return this.activeFilter === 'Voicemail'     ? 'filter-chip on' : 'filter-chip'; }
    get fuChipClass()  { return this.activeFilter === 'FollowUp'      ? 'filter-chip on' : 'filter-chip'; }
    get noLeads()      { return this.filteredLeads.length === 0; }

    filterAll()      { this.activeFilter = 'All'; }
    filterUmb()      { this.activeFilter = 'UMB'; }
    filterCb()       { this.activeFilter = 'Custom Build'; }
    filterLc()       { this.activeFilter = 'Lawn Care'; }
    filterVoicemail(){ this.activeFilter = 'Voicemail'; }
    filterFollowUp() { this.activeFilter = 'FollowUp'; }

    handleOwnerFilter(e) { this.activeOwner = e.target.value; }
    handleSearch(e)      { this.searchTerm = e.target.value; }

    navigateToLead(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                actionName: 'view'
            }
        });
    }

    newLead() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Lead', actionName: 'new' }
        });
    }
}