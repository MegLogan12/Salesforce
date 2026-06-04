import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import getWorkspaceData from '@salesforce/apex/ODLOpportunityWorkspaceController.getWorkspaceData';

const CHIP_DEFS = [
    { key: 'all',       label: 'All Open',        test: () => true },
    { key: 'umb',       label: 'UMB',              test: r => r.lob === 'UpgradeMyBackyard' },
    { key: 'design',    label: 'Design Build',     test: r => r.lob === 'Design Build' },
    { key: 'disc',      label: 'Discovery',        test: r => r.stageName === 'Discovery' },
    { key: 'consult',   label: 'Consult Sched.',   test: r => r.stageName === 'Consult Scheduled' },
    { key: 'design_ip', label: 'Design In Prog.',  test: r => r.stageName === 'Design In Progress' },
    { key: 'qr',        label: 'Quote Review',     test: r => r.stageName === 'Quote Review' },
    { key: 'cs',        label: 'Contract Sent',    test: r => r.stageName === 'Contract Sent' },
    { key: 'dp',        label: 'Deposit Pending',  test: r => r.stageName === 'Deposit Pending' },
    { key: 'vm',        label: 'Voicemail',        test: r => r.voicemailLeft === true },
    { key: 'fudue',     label: 'Follow-Up Due',    test: r => r.followUpChipClass === 'chip chip-red' || r.followUpChipClass === 'chip chip-amber' },
    { key: 'wo',        label: 'WO Ready',         test: r => r.woReady === true },
    { key: 'noact',     label: 'No Activity',      test: r => r.lastActivityResult === 'No Activity' },
    { key: 'hival',     label: 'High Value',       test: r => (r.amount || 0) >= 50000 }
];

function followUpScore(row) {
    if (!row.followUpDate) return 999;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const fu = new Date(row.followUpDate);
    const days = Math.round((fu - today) / 86400000);
    return days;
}

function compareDates(a, b, asc) {
    const av = a ? new Date(a).getTime() : 0;
    const bv = b ? new Date(b).getTime() : 0;
    return asc ? av - bv : bv - av;
}

export default class OdlOpportunityWorkspaceLive extends NavigationMixin(LightningElement) {
    @track activeKpi = 'all';
    @track activeChip = 'all';
    @track selectedOwner = '';
    @track searchText = '';
    @track sortField = 'followUp';
    @track sortAsc = true;

    workspaceData;
    loadError;
    objectInfo;

    @wire(getObjectInfo, { objectApiName: OPPORTUNITY_OBJECT })
    wiredObjectInfo({ data }) {
        if (data) this.objectInfo = data;
    }

    @wire(getWorkspaceData)
    wiredWorkspace({ data, error }) {
        if (data) {
            this.workspaceData = data;
            this.loadError = null;
        } else if (error) {
            this.loadError = this.reduceError(error);
            this.workspaceData = null;
        }
    }

    get hasError() { return Boolean(this.loadError); }
    get errorMessage() { return this.loadError || ''; }
    get ownerNames() { return this.workspaceData?.ownerNames || []; }

    get allRows() {
        return (this.workspaceData?.rows || []).map(r => ({
            ...r,
            actionBtnClass: r.woReady ? 'btn-action wo-ready' : 'btn-action'
        }));
    }

    get kpiCards() {
        return (this.workspaceData?.kpis || []).map(k => ({
            ...k,
            cardClass: (this.activeKpi === k.key && this.activeChip === 'all')
                ? 'kpi-card active' : 'kpi-card'
        }));
    }

    get kpiFilteredRows() {
        const rows = this.allRows;
        switch (this.activeKpi) {
            case 'umb':       return rows.filter(r => r.lob === 'UpgradeMyBackyard');
            case 'design':    return rows.filter(r => r.lob === 'Design Build');
            case 'woReady':   return rows.filter(r => r.woReady === true);
            case 'voicemail': return rows.filter(r => r.voicemailLeft === true);
            case 'followUp':  return rows.filter(r =>
                r.followUpChipClass === 'chip chip-red' || r.followUpChipClass === 'chip chip-amber');
            default:          return rows;
        }
    }

    get chipList() {
        const base = this.kpiFilteredRows;
        return CHIP_DEFS.map(def => ({
            key: def.key,
            label: def.label,
            count: base.filter(def.test).length,
            cls: this.activeChip === def.key ? 'filter-chip active' : 'filter-chip'
        }));
    }

    get filteredRows() {
        let rows = this.kpiFilteredRows;

        const chipDef = CHIP_DEFS.find(d => d.key === this.activeChip);
        if (chipDef && this.activeChip !== 'all') {
            rows = rows.filter(chipDef.test);
        }

        if (this.selectedOwner) {
            rows = rows.filter(r => r.ownerName === this.selectedOwner);
        }

        if (this.searchText) {
            const q = this.searchText.toLowerCase();
            rows = rows.filter(r => {
                const hay = [
                    r.oppName, r.accountName, r.ownerName, r.packageDisplay,
                    r.stageName, r.voucherCode, r.campaignName, r.nextActionText
                ].filter(Boolean).join(' ').toLowerCase();
                return hay.includes(q);
            });
        }

        return this.sortRows(rows);
    }

    get visibleRows() { return this.filteredRows; }
    get rowCount() { return this.filteredRows.length; }
    get isEmpty() { return this.filteredRows.length === 0; }

    sortRows(rows) {
        return [...rows].sort((a, b) => {
            if (this.sortField === 'amount') {
                const diff = (b.amount || 0) - (a.amount || 0);
                return this.sortAsc ? -diff : diff;
            }
            if (this.sortField === 'activity') {
                return compareDates(a.lastActivityDate, b.lastActivityDate, this.sortAsc);
            }
            // Default: follow-up urgency (overdue first) then oldest activity
            const fuDiff = followUpScore(a) - followUpScore(b);
            if (fuDiff !== 0) return fuDiff;
            return compareDates(a.lastActivityDate, b.lastActivityDate, true);
        });
    }

    get sortIconAmount() {
        return this.sortField === 'amount' ? (this.sortAsc ? ' ▲' : ' ▼') : '';
    }
    get sortIconActivity() {
        return this.sortField === 'activity' ? (this.sortAsc ? ' ▲' : ' ▼') : '';
    }
    get sortIconFollowUp() {
        return this.sortField === 'followUp' ? (this.sortAsc ? ' ▲' : ' ▼') : '';
    }

    handleKpiClick(event) {
        this.activeKpi = event.currentTarget.dataset.key;
        this.activeChip = 'all';
    }

    handleChipClick(event) {
        this.activeChip = event.currentTarget.dataset.key;
    }

    handleOwnerChange(event) {
        this.selectedOwner = event.target.value;
    }

    handleSearchInput(event) {
        this.searchText = event.target.value;
    }

    handleSortAmount() {
        if (this.sortField === 'amount') {
            this.sortAsc = !this.sortAsc;
        } else {
            this.sortField = 'amount';
            this.sortAsc = false;
        }
    }

    handleSortActivity() {
        if (this.sortField === 'activity') {
            this.sortAsc = !this.sortAsc;
        } else {
            this.sortField = 'activity';
            this.sortAsc = false;
        }
    }

    handleSortFollowUp() {
        if (this.sortField === 'followUp') {
            this.sortAsc = !this.sortAsc;
        } else {
            this.sortField = 'followUp';
            this.sortAsc = true;
        }
    }

    handleOpenRecord(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' }
        });
    }

    handleOpenAccount(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' }
        });
    }

    handleNewUmb() {
        const rtId = this.findRecordTypeId('UMB');
        const state = { defaultFieldValues: encodeDefaultFieldValues({ StageName: 'Discovery' }) };
        if (rtId) state.recordTypeId = rtId;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Opportunity', actionName: 'new' },
            state
        });
    }

    handleNewDesignBuild() {
        const rtId = this.findRecordTypeId('Design_Build');
        const state = { defaultFieldValues: encodeDefaultFieldValues({ StageName: 'Discovery' }) };
        if (rtId) state.recordTypeId = rtId;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Opportunity', actionName: 'new' },
            state
        });
    }

    handleActionClick(event) {
        const id = event.currentTarget.dataset.id;
        const action = event.currentTarget.dataset.action;
        if (!id || !action) return;
        const taskActions = ['New Task', 'Log Activity', 'Log Call', 'Schedule', 'Confirm'];
        if (taskActions.includes(action)) {
            this[NavigationMixin.Navigate]({
                type: 'standard__quickAction',
                attributes: { apiName: 'Global.NewTask' },
                state: { recordId: id }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: id, actionName: 'view' }
            });
        }
    }

    findRecordTypeId(developerName) {
        const infos = this.objectInfo?.recordTypeInfos || {};
        const found = Object.values(infos).find(i => i.developerName === developerName);
        return found?.recordTypeId || null;
    }

    reduceError(error) {
        if (!error) return '';
        if (Array.isArray(error.body)) return error.body.map(e => e.message).join(', ');
        return error.body?.message || error.message || 'Unable to load opportunities.';
    }

    handleLogCall(event) {
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: id || '' }
        });
    }

    handleNewActivity(event) {
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: id || '' }
        });
    }

    handleSendEmail() {
        console.log('handleSendEmail');
    }
}
