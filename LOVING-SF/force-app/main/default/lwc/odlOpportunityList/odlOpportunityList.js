import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getOpportunityList from '@salesforce/apex/ODL_OpportunityController.getOpportunityList';

export default class OdlOpportunityList extends LightningElement {
    @track opps = [];
    @track activeFilter = 'All';
    @track searchTerm = '';

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getOpportunityList, { odlPath: '' })
    wiredOpps({ error, data }) {
        if (data) {
            this.opps = data.map(o => ({
                ...o,
                lobChipClass: o.ODL_Path__c === 'UMB' ? 'chip co' : o.ODL_Path__c === 'Custom Build' ? 'chip cp' : o.ODL_Path__c === 'Lawn Care' ? 'chip ct' : 'chip cgr',
                amountFormatted: o.Amount ? '$' + Number(o.Amount).toLocaleString() : '—',
                lastActivityFormatted: o.LastActivityDate ? new Date(o.LastActivityDate).toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—',
                lastActivityLabel: o.Voicemail_Left__c ? 'Voicemail left' : (o.LastActivityDate ? 'Activity' : '—')
            }));
        }
    }

    get filteredOpps() {
        let result = this.opps;
        if (this.activeFilter === 'Voicemail') result = result.filter(o => o.Voicemail_Left__c);
        else if (this.activeFilter !== 'All') result = result.filter(o => o.ODL_Path__c === this.activeFilter);
        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            result = result.filter(o => (o.Name || '').toLowerCase().includes(term) || ((o.Account && o.Account.Name) || '').toLowerCase().includes(term));
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
    get noOpps() { return this.filteredOpps.length === 0; }
}
