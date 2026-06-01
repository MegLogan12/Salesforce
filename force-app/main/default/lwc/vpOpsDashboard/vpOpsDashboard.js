import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getKpis             from '@salesforce/apex/HomeDashboardController.getKpis';
import getScorecards       from '@salesforce/apex/FMScorecardController.getScorecards';
import getOpenHireRequests from '@salesforce/apex/VpEscalationsController.getOpenHireRequests';
import getEscalationTasks  from '@salesforce/apex/VpEscalationsController.getEscalationTasks';

export default class VpOpsDashboard extends NavigationMixin(LightningElement) {
    @track currentTab = 'home';

    // ── Wired data ──────────────────────────────────────────────────────────
    @wire(getKpis)
    wiredKpis({ data, error }) {
        if (data) { this._kpis = data; }
    }
    _kpis = {};

    @wire(getScorecards)
    wiredScorecards({ data }) {
        if (data) { this._scorecards = data; }
    }
    _scorecards = [];

    @wire(getOpenHireRequests)
    wiredHR({ data }) {
        if (data) { this._hireRequests = data; }
    }
    _hireRequests = [];

    @wire(getEscalationTasks)
    wiredTasks({ data }) {
        if (data) { this._escalTasks = data; }
    }
    _escalTasks = [];

    // ── Nav badge counts (replaces hardcoded values) ─────────────────────────
    get fmCount()         { return this._scorecards.length  || null; }
    get escalCount()      {
        const n = (this._hireRequests.length || 0) + (this._escalTasks.length || 0);
        return n > 0 ? n : null;
    }
    get fjCount()         { return this._kpis?.activeFjWorkOrders || null; }
    get activeWoCount()   { return this._kpis?.activeWorkOrders   || '—'; }
    get scheduledToday()  { return this._kpis?.scheduledToday     || 0; }
    get inProgressToday() { return this._kpis?.inProgressToday    || 0; }
    get pendingApproval() { return this._kpis?.pendingApproval    || 0; }
    get pendingCloseout() { return this._kpis?.pendingCloseout    || 0; }
    get openHireCount()   { return this._kpis?.openHireRequests   || 0; }
    get oneOnOnesCount()  { return this._kpis?.thisWeekOneOnOnes  || 0; }
    get actionItemCount() { return this._kpis?.openActionItems    || 0; }

    // ── Tab visibility ────────────────────────────────────────────────────────
    get tabHome()    { return this.currentTab === 'home'; }
    get tabFms()     { return this.currentTab === 'fms'; }
    get tabInstall() { return this.currentTab === 'install'; }
    get tabLawn()    { return this.currentTab === 'lawn'; }
    get tabEscal()   { return this.currentTab === 'escal'; }
    get tabFjroll()  { return this.currentTab === 'fjroll'; }
    get tabHealth()  { return this.currentTab === 'health'; }
    get tabQuality() { return this.currentTab === 'quality'; }
    get tabOnes()    { return this.currentTab === 'ones'; }

    tc(id) { return id === this.currentTab ? 'sf-tab on' : 'sf-tab'; }
    get tcHome()    { return this.tc('home'); }
    get tcFms()     { return this.tc('fms'); }
    get tcInstall() { return this.tc('install'); }
    get tcLawn()    { return this.tc('lawn'); }
    get tcEscal()   { return this.tc('escal') + ' urgent'; }
    get tcFjroll()  { return this.tc('fjroll'); }
    get tcHealth()  { return this.tc('health'); }
    get tcQuality() { return this.tc('quality'); }
    get tcOnes()    { return this.tc('ones'); }

    switchTab(event) { this.currentTab = event.currentTarget.dataset.tab; }

    handleVpQaAction(event) {
        const action = event.currentTarget.dataset.action;
        const messages = {
            callFm:      'Dial the FM directly from the Contacts tab on their Employee record.',
            addNote:     'Open the 1:1 record for this FM to add meeting notes.',
            approveHire: 'Navigate to the Hire Request record to review and approve.',
            requestCapex:'Submit a capex request via the Finance team process.',
            weeklyBoard: 'The weekly board update will pull from the latest schedule data.',
            pageOnCall:  'Use the Rippling on-call paging system to reach the FM.',
            reschedule:  'Open the OneOnOne record and update the Meeting Date.'
        };
        const navActions = {
            addNote:     { type: 'standard__objectPage', attributes: { objectApiName: 'OneOnOne__c', actionName: 'list' } },
            approveHire: { type: 'standard__objectPage', attributes: { objectApiName: 'Hire_Request__c', actionName: 'list' } }
        };
        if (navActions[action]) {
            this[NavigationMixin.Navigate](navActions[action]);
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Action',
                message: messages[action] || 'Opening action...',
                variant: 'info'
            }));
        }
    }

    handleOpenPrepDoc() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'OneOnOne__c', actionName: 'list' }
        });
    }
}