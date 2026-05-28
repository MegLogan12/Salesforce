import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getLeadList from '@salesforce/apex/ODL_LeadController.getLeadList';

export default class OdlLeadList extends LightningElement {
    @track leads = [];
    @track activeFilter = 'All';
    @track searchTerm = '';
    error;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getLeadList, { odlPath: '' })
    wiredLeads({ error, data }) {
        if (data) {
            this.leads = data.map(l => ({
                ...l,
                lobChipClass: l.ODL_Path__c === 'UMB' ? 'chip co' : l.ODL_Path__c === 'Custom Build' ? 'chip cp' : l.ODL_Path__c === 'Lawn Care' ? 'chip ct' : 'chip cgr',
                lastActivityFormatted: l.LastActivityDate ? new Date(l.LastActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—',
                lastActivityLabel: l.Voicemail_Left__c ? 'Voicemail left' : (l.LastActivityDate ? 'Activity' : '—')
            }));
        } else if (error) {
            this.error = error;
        }
    }

    get filteredLeads() {
        let result = this.leads;
        if (this.activeFilter === 'Voicemail') {
            result = result.filter(l => l.Voicemail_Left__c);
        } else if (this.activeFilter === 'FollowUp') {
            result = result.filter(l => l.Last_Voicemail_Date__c);
        } else if (this.activeFilter !== 'All') {
            result = result.filter(l => l.ODL_Path__c === this.activeFilter);
        }
        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            result = result.filter(l => (l.Name || '').toLowerCase().includes(term) || (l.Company || '').toLowerCase().includes(term));
        }
        return result;
    }

    get allChipClass() { return this.activeFilter === 'All' ? 'filter-chip on' : 'filter-chip'; }
    get umbChipClass() { return this.activeFilter === 'UMB' ? 'filter-chip on' : 'filter-chip'; }
    get cbChipClass() { return this.activeFilter === 'Custom Build' ? 'filter-chip on' : 'filter-chip'; }
    get lcChipClass() { return this.activeFilter === 'Lawn Care' ? 'filter-chip on' : 'filter-chip'; }

    filterAll() { this.activeFilter = 'All'; }
    filterUmb() { this.activeFilter = 'UMB'; }
    filterCb() { this.activeFilter = 'Custom Build'; }
    filterLc() { this.activeFilter = 'Lawn Care'; }
    filterVoicemail() { this.activeFilter = 'Voicemail'; }
    filterFollowUp() { this.activeFilter = 'FollowUp'; }

    handleSearch(e) { this.searchTerm = e.target.value; }
    get noLeads() { return this.filteredLeads.length === 0; }
}
