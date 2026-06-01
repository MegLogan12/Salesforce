import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getWorkbenchData from '@salesforce/apex/LovingAcctCommLotWorkbenchCtrl.getWorkbenchData';

const PACKAGE_ISSUES = new Set(['Mismatch', 'Mismatch Review', 'Missing Package']);
const CLOSED_STATUSES = new Set(['Closed', 'Completed', 'Canceled', 'Cancelled', 'Void', 'Inactive']);

export default class LovingAccountsView extends NavigationMixin(LightningElement) {
    @track data;
    @track selectedParentId;
    @track selectedDivisionId;
    @track selectedCommunityId;
    @track selectedLotId;

    isLoading = true;
    errorMessage;
    searchTerm = '';
    marketFilter = '';
    activeOnly = true;
    openWorkOnly = false;
    packageIssuesOnly = false;

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            this.data = await getWorkbenchData({
                filtersJson: JSON.stringify({
                    activeOnly: this.activeOnly
                })
            });
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.data = null;
        } finally {
            this.isLoading = false;
        }
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get rawParents() {
        return this.data?.parents || [];
    }

    get rawDivisions() {
        return this.data?.divisions || [];
    }

    get rawCommunities() {
        return this.data?.communities || [];
    }

    get rawLots() {
        return this.data?.lots || [];
    }

    get kpis() {
        return (this.data?.kpis || []).map((kpi) => ({
            ...kpi,
            className: `hb-kpi hb-tone-${kpi.tone || 'blue'}`
        }));
    }

    get parents() {
        const divisions = this.filteredDivisionsBase;
        const communities = this.filteredCommunitiesBase;
        const lots = this.filteredLotsBase;
        const matchingParentIds = new Set([
            ...divisions.map((row) => row.parentId).filter(Boolean),
            ...communities.map((row) => row.parentId).filter(Boolean),
            ...lots.map((row) => row.parentId).filter(Boolean)
        ]);
        return this.decorate(this.rawParents
            .filter((row) => this.matchesSearch(row) || matchingParentIds.has(row.id))
            .map((row) => ({
                ...row,
                divisionCount: divisions.filter((d) => d.parentId === row.id).length,
                communityCount: communities.filter((c) => c.parentId === row.id).length,
                lotCount: lots.filter((l) => l.parentId === row.id).length,
                openIssueLabel: row.issueCount ? `${row.issueCount} open issues` : 'Rollup view only'
            })));
    }

    get divisions() {
        let rows = this.filteredDivisionsBase;
        if (this.selectedParentId) rows = rows.filter((row) => row.parentId === this.selectedParentId);
        return this.decorate(rows);
    }

    get communities() {
        let rows = this.filteredCommunitiesBase;
        if (this.selectedDivisionId) {
            rows = rows.filter((row) => row.divisionId === this.selectedDivisionId);
        } else if (this.selectedParentId) {
            rows = rows.filter((row) => row.parentId === this.selectedParentId);
        }
        return this.decorate(rows);
    }

    get lots() {
        let rows = this.filteredLotsBase;
        if (this.selectedCommunityId) {
            rows = rows.filter((row) => row.communityId === this.selectedCommunityId);
        } else if (this.selectedDivisionId) {
            rows = rows.filter((row) => row.divisionId === this.selectedDivisionId);
        } else if (this.selectedParentId) {
            rows = rows.filter((row) => row.parentId === this.selectedParentId);
        }
        return this.decorate(rows);
    }

    get filteredDivisionsBase() {
        const matchingDivisionIds = new Set([
            ...this.filteredCommunitiesBase.map((row) => row.divisionId).filter(Boolean),
            ...this.filteredLotsBase.map((row) => row.divisionId).filter(Boolean)
        ]);
        return this.rawDivisions.filter((row) => this.matchesAllFilters(row) || matchingDivisionIds.has(row.id));
    }

    get filteredCommunitiesBase() {
        const matchingCommunityIds = new Set(this.filteredLotsBase.map((row) => row.communityId).filter(Boolean));
        return this.rawCommunities.filter((row) => this.matchesAllFilters(row) || matchingCommunityIds.has(row.id));
    }

    get filteredLotsBase() {
        return this.rawLots.filter((row) => this.matchesAllFilters(row));
    }

    get hasParents() {
        return this.parents.length > 0;
    }

    get hasDivisions() {
        return this.divisions.length > 0;
    }

    get hasCommunities() {
        return this.communities.length > 0;
    }

    get hasLots() {
        return this.lots.length > 0;
    }

    get parentCount() {
        return this.parents.length;
    }

    get divisionCount() {
        return this.divisions.length;
    }

    get communityCount() {
        return this.communities.length;
    }

    get lotCount() {
        return this.lots.length;
    }

    get selected() {
        if (this.selectedLotId) return this.decorateOne(this.rawLots.find((row) => row.id === this.selectedLotId));
        if (this.selectedCommunityId) return this.decorateOne(this.rawCommunities.find((row) => row.id === this.selectedCommunityId));
        if (this.selectedDivisionId) return this.decorateOne(this.rawDivisions.find((row) => row.id === this.selectedDivisionId));
        if (this.selectedParentId) return this.decorateOne(this.rawParents.find((row) => row.id === this.selectedParentId));
        return null;
    }

    get hasSelection() {
        return !!this.selected;
    }

    get selectedTitle() {
        return this.selected?.name || 'No selection';
    }

    get selectedTypeLabel() {
        const type = this.selected?.type;
        if (type === 'parent') return 'Builder Parent';
        if (type === 'division') return 'Division Account';
        if (type === 'community') return 'Community';
        if (type === 'lot') return 'Lot';
        return 'Workbench';
    }

    get selectedRecordUrl() {
        return this.selected ? `/${this.selected.id}` : null;
    }

    get selectedActions() {
        const selected = this.selected;
        if (!selected) return [];
        return (selected.actions || []).map((action) => {
            let disabled = !action.enabled;
            let disabledReason = action.disabledReason || '';
            if (action.kind === 'recordOptional') {
                const hasTarget = action.key === 'viewCurrentWorkOrder'
                    ? !!selected.currentWorkOrderId
                    : action.key === 'viewPo'
                        ? !!selected.currentPoId
                        : true;
                disabled = !hasTarget;
                disabledReason = hasTarget ? '' : 'No current record is linked.';
            }
            return {
                ...action,
                disabled,
                disabledReason,
                className: disabled ? 'hb-action hb-action-disabled' : 'hb-action'
            };
        });
    }

    get auditRows() {
        return (this.data?.audit || []).map((row, index) => ({
            ...row,
            key: `${index}-${row.area}`,
            existsLabel: row.exists ? 'Yes' : 'No',
            canUseLabel: row.canUse ? 'Yes' : 'No'
        }));
    }

    decorate(rows) {
        return rows.map((row) => this.decorateOne(row));
    }

    decorateOne(row) {
        if (!row) return null;
        const selected = row.id === this.selectedParentId
            || row.id === this.selectedDivisionId
            || row.id === this.selectedCommunityId
            || row.id === this.selectedLotId;
        return {
            ...row,
            status: row.status || 'Not configured',
            territory: row.territory || 'Not configured',
            packageLabel: row.packageLabel || 'Not configured',
            packageStatus: row.packageStatus || 'Not Configured',
            currentPoName: row.currentPoName || 'None linked',
            currentWorkOrderName: row.currentWorkOrderName || 'None linked',
            address: row.address || row.subtitle || 'Not configured',
            className: `hb-node hb-node-${row.type || 'record'}${selected ? ' selected' : ''}`,
            statusClass: `hb-chip ${this.statusTone(row.status)}`,
            packageClass: `hb-chip ${this.packageTone(row.packageStatus)}`,
            gpsClass: `hb-chip ${row.gpsStatus === 'GPS set' ? 'hb-chip-green' : 'hb-chip-amber'}`
        };
    }

    matchesAllFilters(row) {
        if (!this.matchesSearch(row)) return false;
        if (!this.matchesMarket(row)) return false;
        if (this.openWorkOnly && !(row.openWorkOrderCount > 0 || row.openPoCount > 0)) return false;
        if (this.packageIssuesOnly && !PACKAGE_ISSUES.has(row.packageStatus)) return false;
        if (this.activeOnly && row.type === 'lot' && CLOSED_STATUSES.has(row.status)) return false;
        return true;
    }

    matchesSearch(row) {
        const needle = this.normalizeSearch(this.searchTerm || '');
        if (!needle) return true;
        const tokens = needle.split(' ').filter(Boolean);
        const haystack = [
            row.name,
            row.subtitle,
            row.status,
            row.territory,
            row.fieldManager,
            row.packageLabel,
            row.packageStatus,
            row.address,
            row.currentPoName,
            row.currentWorkOrderName
        ].filter(Boolean).map((value) => this.normalizeSearch(value)).join(' ');
        return tokens.every((token) => haystack.includes(token));
    }

    matchesMarket(row) {
        const needle = this.normalizeSearch(this.marketFilter || '');
        if (!needle) return true;
        const tokens = needle.split(' ').filter(Boolean);
        const haystack = this.normalizeSearch([row.territory, row.subtitle, row.name].filter(Boolean).join(' '));
        return tokens.every((token) => haystack.includes(token));
    }

    normalizeSearch(value) {
        return String(value || '')
            .toLowerCase()
            .replace(/d\\s*\\.\\s*r\\s*\\./g, 'dr')
            .replace(/[^a-z0-9]+/g, ' ')
            .replace(/\\s+/g, ' ')
            .trim();
    }

    statusTone(status) {
        const value = (status || '').toLowerCase();
        if (value.includes('active') || value.includes('operating') || value.includes('rollup')) return 'hb-chip-green';
        if (value.includes('review') || value.includes('missing')) return 'hb-chip-amber';
        if (value.includes('inactive') || value.includes('closed')) return 'hb-chip-gray';
        return 'hb-chip-blue';
    }

    packageTone(status) {
        const value = status || '';
        if (value === 'Configured' || value === 'Match' || value === 'Matched') return 'hb-chip-green';
        if (value === 'Mismatch' || value === 'Mismatch Review' || value === 'Missing Package') return 'hb-chip-red';
        if (value === 'Override') return 'hb-chip-amber';
        return 'hb-chip-gray';
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
    }

    handleMarketFilter(event) {
        this.marketFilter = event.target.value || '';
    }

    handleActiveOnly(event) {
        this.activeOnly = event.target.checked;
        this.loadData();
    }

    handleOpenWorkOnly(event) {
        this.openWorkOnly = event.target.checked;
    }

    handlePackageIssuesOnly(event) {
        this.packageIssuesOnly = event.target.checked;
    }

    handleRefresh() {
        this.loadData();
    }

    handleParentSelect(event) {
        this.selectedParentId = event.currentTarget.dataset.id;
        this.selectedDivisionId = null;
        this.selectedCommunityId = null;
        this.selectedLotId = null;
    }

    handleDivisionSelect(event) {
        const division = this.rawDivisions.find((row) => row.id === event.currentTarget.dataset.id);
        this.selectedParentId = division?.parentId || this.selectedParentId;
        this.selectedDivisionId = event.currentTarget.dataset.id;
        this.selectedCommunityId = null;
        this.selectedLotId = null;
    }

    handleCommunitySelect(event) {
        const community = this.rawCommunities.find((row) => row.id === event.currentTarget.dataset.id);
        this.selectedParentId = community?.parentId || this.selectedParentId;
        this.selectedDivisionId = community?.divisionId || this.selectedDivisionId;
        this.selectedCommunityId = event.currentTarget.dataset.id;
        this.selectedLotId = null;
    }

    handleLotSelect(event) {
        const lot = this.rawLots.find((row) => row.id === event.currentTarget.dataset.id);
        this.selectedParentId = lot?.parentId || this.selectedParentId;
        this.selectedDivisionId = lot?.divisionId || this.selectedDivisionId;
        this.selectedCommunityId = lot?.communityId || this.selectedCommunityId;
        this.selectedLotId = event.currentTarget.dataset.id;
    }

    handleOpenSelected() {
        this.navigateRecord(this.selected.id);
    }

    handleNewAccount() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Account', actionName: 'new' }
        });
    }

    handleKpiClick(event) {
        const key = event.currentTarget.dataset.key;
        if (key === 'packageIssues') {
            this.packageIssuesOnly = !this.packageIssuesOnly;
        } else if (key === 'openWork') {
            this.openWorkOnly = !this.openWorkOnly;
        }
    }

    handleAction(event) {
        const key = event.currentTarget.dataset.key;
        const action = this.selectedActions.find((item) => item.key === key);
        if (!action || action.disabled) return;
        const selected = this.selected;

        if (key === 'viewParent' || key === 'viewCommunity' || key === 'viewLot') {
            this.navigateRecord(selected.id);
        } else if (key === 'viewCurrentWorkOrder' && selected.currentWorkOrderId) {
            this.navigateRecord(selected.currentWorkOrderId);
        } else if (key === 'viewPo' && selected.currentPoId) {
            this.navigateRecord(selected.currentPoId);
        } else if (key === 'viewDivisions') {
            this.selectedDivisionId = null;
            this.selectedCommunityId = null;
            this.selectedLotId = null;
        } else if (key === 'viewCommunities') {
            this.selectedCommunityId = null;
            this.selectedLotId = null;
        } else if (key === 'viewLots') {
            this.selectedLotId = null;
        } else if (key === 'newPo' || key === 'startPo') {
            this.navigateNewPo(selected);
        } else if (action.targetObject) {
            this.navigateObjectHome(action.targetObject);
        }
    }

    navigateRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    navigateObjectHome(objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName,
                actionName: 'home'
            }
        });
    }

    navigateNewPo(selected) {
        const defaults = {};
        if (selected.type === 'division') {
            defaults.Division_Account__c = selected.id;
        } else if (selected.type === 'community') {
            defaults.Community__c = selected.id;
            if (selected.divisionId) defaults.Division_Account__c = selected.divisionId;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Purchase_Order__c',
                actionName: 'new'
            },
            state: Object.keys(defaults).length
                ? { defaultFieldValues: encodeDefaultFieldValues(defaults) }
                : {}
        });
    }

    normalizeError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown Salesforce error.';
    }
}