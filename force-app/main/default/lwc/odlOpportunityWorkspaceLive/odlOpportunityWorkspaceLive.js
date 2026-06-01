import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import getPageData from '@salesforce/apex/ODLOpportunityListController.getPageData';

export default class OdlOpportunityWorkspaceLive extends NavigationMixin(LightningElement) {
    @track activeFilter = 'All Homeowner Opportunities';
    @track selectedOwner = '';
    @track selectedStage = '';
    @track searchText = '';
    @track selectedColumns = [
        'opportunity',
        'account',
        'lob',
        'stage',
        'amount',
        'package',
        'lastActivity',
        'lastActivityDate',
        'followUpTask',
        'followUpDue',
        'owner',
        'openItem'
    ];
    @track showColumnPicker = false;

    pageData = { rows: [] };
    objectInfo;
    @track loadError = '';

    @wire(getObjectInfo, { objectApiName: OPPORTUNITY_OBJECT })
    wiredObjectInfo({ data }) {
        if (data) {
            this.objectInfo = data;
        }
    }

    @wire(getPageData)
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = data;
            this.loadError = '';
        } else if (error) {
            this.pageData = { rows: [] };
            this.loadError = this.reduceError(error);
        }
    }

    get hasLoadError() {
        return Boolean(this.loadError);
    }

    reduceError(error) {
        if (!error) {
            return '';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'Unable to load opportunities.';
    }

    get ownerOptions() {
        const owners = new Set();
        this.normalizedRows.forEach((row) => {
            if (row.ownerName) {
                owners.add(row.ownerName);
            }
        });
        return Array.from(owners).sort();
    }

    get stageOptions() {
        const stages = new Set();
        this.normalizedRows.forEach((row) => {
            if (row.stageName) {
                stages.add(row.stageName);
            }
        });
        return Array.from(stages).sort();
    }

    get normalizedRows() {
        return (this.pageData.rows || []).map((row) => {
            const normalized = { ...row };
            normalized.oppHref = row.oppHref || (row.id ? `/lightning/r/Opportunity/${row.id}/view` : '#');
            normalized.accountHref = row.accountHref || (row.accountUrl ? `/lightning/r/Account/${String(row.accountUrl).replace('/', '')}/view` : '');
            normalized.voicemailChipClass = row.voicemailChipClass || (row.voicemailStatus === 'Yes' ? 'chip chip-amber' : 'chip chip-gray');
            normalized.openItemChipClass = row.openItemChipClass || this.deriveOpenItemChipClass(row.openItem);
            normalized.lastActivitySection = this.deriveActivitySection(row);
            return normalized;
        });
    }

    get filteredRows() {
        return this.normalizedRows.filter((row) => {
            if (this.selectedOwner && row.ownerName !== this.selectedOwner) {
                return false;
            }
            if (this.selectedStage && row.stageName !== this.selectedStage) {
                return false;
            }
            if (this.activeFilter === 'UMB' && row.lob !== 'UMB') {
                return false;
            }
            if (this.activeFilter === 'Custom' && row.lob !== 'Custom') {
                return false;
            }
            if (this.activeFilter === 'Lawn Care' && row.lob !== 'Lawn Care') {
                return false;
            }
            if (this.activeFilter === 'Voicemail Left' && row.voicemailStatus !== 'Yes') {
                return false;
            }
            if (this.activeFilter === 'Follow-Up Due' && !row.followUpDue) {
                return false;
            }
            if (this.searchText) {
                const haystack = [
                    row.label,
                    row.accountName,
                    row.ownerName,
                    row.packageDisplay,
                    row.stageName,
                    row.openItem
                ].join(' ').toLowerCase();
                if (!haystack.includes(this.searchText.toLowerCase())) {
                    return false;
                }
            }
            return true;
        });
    }

    get latestUmbHref() {
        const recordId = (this.pageData.latestUmbUrl || '').replace('/', '');
        return recordId ? `/lightning/r/Opportunity/${recordId}/view` : '#';
    }

    get latestCustomHref() {
        const recordId = (this.pageData.latestCustomUrl || '').replace('/', '');
        return recordId ? `/lightning/r/Opportunity/${recordId}/view` : '#';
    }

    get latestLawnHref() {
        const recordId = (this.pageData.latestLawnUrl || '').replace('/', '');
        return recordId ? `/lightning/r/Opportunity/${recordId}/view` : '#';
    }

    get hasLatestUmb() {
        return !!this.pageData.latestUmbUrl;
    }

    get hasLatestCustom() {
        return !!this.pageData.latestCustomUrl;
    }

    get hasLatestLawn() {
        return !!this.pageData.latestLawnUrl;
    }

    get columnOptions() {
        return [
            { key: 'account', label: 'Account' },
            { key: 'lob', label: 'LOB' },
            { key: 'stage', label: 'Stage' },
            { key: 'amount', label: 'Amount' },
            { key: 'package', label: 'Package / Service' },
            { key: 'lastActivity', label: 'Last Activity' },
            { key: 'lastActivityDate', label: 'Last Activity Date' },
            { key: 'voicemail', label: 'Voicemail' },
            { key: 'voicemailDate', label: 'Voicemail Date' },
            { key: 'followUpTask', label: 'Follow-Up Task' },
            { key: 'followUpDue', label: 'Follow-Up Due' },
            { key: 'owner', label: 'Owner' },
            { key: 'openItem', label: 'Open Item' }
        ].map((option) => ({
            ...option,
            checked: this.selectedColumns.includes(option.key)
        }));
    }

    get visibleColumnCount() {
        return this.selectedColumns.length;
    }

    get showAccountColumn() { return this.selectedColumns.includes('account'); }
    get showLobColumn() { return this.selectedColumns.includes('lob'); }
    get showStageColumn() { return this.selectedColumns.includes('stage'); }
    get showAmountColumn() { return this.selectedColumns.includes('amount'); }
    get showPackageColumn() { return this.selectedColumns.includes('package'); }
    get showLastActivityColumn() { return this.selectedColumns.includes('lastActivity'); }
    get showLastActivityDateColumn() { return this.selectedColumns.includes('lastActivityDate'); }
    get showVoicemailColumn() { return this.selectedColumns.includes('voicemail'); }
    get showVoicemailDateColumn() { return this.selectedColumns.includes('voicemailDate'); }
    get showFollowUpTaskColumn() { return this.selectedColumns.includes('followUpTask'); }
    get showFollowUpDueColumn() { return this.selectedColumns.includes('followUpDue'); }
    get showOwnerColumn() { return this.selectedColumns.includes('owner'); }
    get showOpenItemColumn() { return this.selectedColumns.includes('openItem'); }

    handleFilterClick(event) {
        this.activeFilter = event.currentTarget.dataset.filter;
    }

    handleOwnerChange(event) {
        this.selectedOwner = event.target.value;
    }

    handleStageChange(event) {
        this.selectedStage = event.target.value;
    }

    handleSearchInput(event) {
        this.searchText = event.target.value;
    }

    handleToggleColumnPicker() {
        this.showColumnPicker = !this.showColumnPicker;
    }

    handleColumnToggle(event) {
        const columnKey = event.target.dataset.column;
        if (!columnKey) {
            return;
        }
        const next = new Set(this.selectedColumns);
        if (next.has(columnKey)) {
            if (next.size === 1) {
                return;
            }
            next.delete(columnKey);
        } else {
            next.add(columnKey);
        }
        this.selectedColumns = this.columnOptions
            .map((option) => option.key)
            .filter((key) => next.has(key));
    }

    handleNewUmbOpportunity() {
        this.navigateToNewOpportunity('UMB', {
            Type: 'UMB',
            StageName: 'Intake'
        });
    }

    handleNewCustomOpportunity() {
        this.navigateToNewOpportunity('Design_Build', {
            Type: 'Design Build',
            StageName: 'Discovery'
        });
    }

    handleNewLawnOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Opportunity',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: encodeDefaultFieldValues({
                    Type: 'Lawn Care',
                    StageName: 'Intake'
                })
            }
        });
    }

    handleOpenOpportunity(event) {
        event.preventDefault();
        const recordId = (event.currentTarget.dataset.recordId || '').replace('/', '');
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    handleOpenActivity(event) {
        event.preventDefault();
        const recordId = (event.currentTarget.dataset.recordId || '').replace('/', '');
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            },
            state: {
                c__focusSection: event.currentTarget.dataset.section || 'activity'
            }
        });
    }

    handleOpenAccount(event) {
        event.preventDefault();
        const recordId = (event.currentTarget.dataset.recordId || '').replace('/', '');
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    chipClass(label) {
        return this.activeFilter === label ? 'filter-chip active' : 'filter-chip';
    }

    get allChipClass() { return this.chipClass('All Homeowner Opportunities'); }
    get umbChipClass() { return this.chipClass('UMB'); }
    get designChipClass() { return this.chipClass('Custom'); }
    get lawnChipClass() { return this.chipClass('Lawn Care'); }
    get voicemailChipClass() { return this.chipClass('Voicemail Left'); }
    get followupChipClass() { return this.chipClass('Follow-Up Due'); }

    deriveOpenItemChipClass(openItem) {
        if (openItem === 'Customer callback' || openItem === 'Follow-up due') {
            return 'chip chip-amber';
        }
        if (openItem === 'Site visit decision' || openItem === 'Quote follow-up') {
            return 'chip chip-blue';
        }
        if (openItem === 'Awaiting approval' || openItem === 'On track') {
            return 'chip chip-green';
        }
        return 'chip chip-gray';
    }

    deriveActivitySection(row) {
        const text = [row.lastAction, row.followUpTask, row.openItem].filter(Boolean).join(' ').toLowerCase();
        if (text.includes('email') || text.includes('voicemail') || text.includes('call') || text.includes('note')) {
            return 'notes';
        }
        return 'activity';
    }

    navigateToNewOpportunity(recordTypeDeveloperName, defaultFieldValues) {
        const recordTypeId = this.findRecordTypeId(recordTypeDeveloperName);
        const state = {
            defaultFieldValues: encodeDefaultFieldValues(defaultFieldValues)
        };
        if (recordTypeId) {
            state.recordTypeId = recordTypeId;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Opportunity',
                actionName: 'new'
            },
            state
        });
    }

    findRecordTypeId(developerName) {
        const recordTypeInfos = this.objectInfo?.recordTypeInfos || {};
        return Object.values(recordTypeInfos).find((info) => info.developerName === developerName)?.recordTypeId
            || null;
    }
}