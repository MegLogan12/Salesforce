import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import getWorkspaceData from '@salesforce/apex/ODLHomeownerAccountsController.getWorkspaceData';

// Record type developerName for the Homeowner Account — the 18-char Id is
// derived at runtime from getObjectInfo so it stays valid across orgs.
const HOMEOWNER_RECORD_TYPE_DEVELOPER_NAME = 'Home_Owner';

export default class OdlHomeownerAccountsWorkspace extends NavigationMixin(LightningElement) {
    @track activeFilter = 'All Homeowners';
    @track searchText = '';

    pageData = { rows: [] };
    objectInfo;

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    wiredObjectInfo({ data }) {
        if (data) {
            this.objectInfo = data;
        }
    }

    @wire(getWorkspaceData)
    wiredPageData({ data }) {
        if (data) {
            const rows = (data.rows || []).map((row) => ({
                ...row,
                statusClass: this.statusClass(row.status),
                serviceClass: this.serviceClass(row.service)
            }));
            this.pageData = { ...data, rows };
        }
    }

    get filteredRows() {
        return (this.pageData.rows || []).filter((row) => {
            if (this.activeFilter !== 'All Homeowners') {
                const matchesStatus = row.relationshipStatus === this.activeFilter;
                const matchesBucket = row.filterBucket === this.activeFilter;
                if (!matchesStatus && !matchesBucket) {
                    return false;
                }
            }
            if (this.searchText) {
                const haystack = [
                    row.accountName,
                    row.primaryContact,
                    row.ownerName,
                    row.status,
                    row.service,
                    row.lastActivity
                ].join(' ').toLowerCase();
                if (!haystack.includes(this.searchText.toLowerCase())) {
                    return false;
                }
            }
            return true;
        });
    }

    handleFilterClick(event) {
        this.activeFilter = event.currentTarget.dataset.filter;
    }

    handleSearchInput(event) {
        this.searchText = event.target.value;
    }

    chipClass(label) {
        return this.activeFilter === label ? 'filter-chip active' : 'filter-chip';
    }

    statusClass(label) {
        if (!label || label === 'No Active Opportunity') return 'chip cgr';
        if (label.includes('Quote') || label.includes('Proposal') || label.includes('Contract')) return 'chip chip-blue';
        if (label.includes('Consultation') || label.includes('Discovery') || label.includes('Intake')) return 'chip chip-amber';
        if (label.includes('Scheduled') || label.includes('Job') || label.includes('Paid')) return 'chip chip-green';
        return 'chip cgr';
    }

    serviceClass(label) {
        if (label === 'UMB') return 'chip chip-umb';
        if (label === 'Design Build') return 'chip chip-design';
        if (label === 'Lawn Care') return 'chip chip-lawn';
        return 'chip cgr';
    }

    get allChipClass() { return this.chipClass('All Homeowners'); }
    get umbChipClass() { return this.chipClass('UMB'); }
    get designChipClass() { return this.chipClass('Design Build'); }
    get lawnChipClass() { return this.chipClass('Lawn Care'); }
    get noActivityChipClass() { return this.chipClass('No Activity'); }

    handleNewHousehold() {
        const recordTypeId = Object.values(this.objectInfo?.recordTypeInfos || {}).find(
            (info) => info.developerName === HOMEOWNER_RECORD_TYPE_DEVELOPER_NAME
        )?.recordTypeId;
        const state = {
            defaultFieldValues: encodeDefaultFieldValues({
                Type: 'Home Owner'
            })
        };
        if (recordTypeId) {
            state.recordTypeId = recordTypeId;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Account',
                actionName: 'new'
            },
            state
        });
    }
}