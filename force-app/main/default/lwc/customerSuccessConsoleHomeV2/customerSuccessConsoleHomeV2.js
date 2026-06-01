import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getHome from '@salesforce/apex/CustomerCareController.getHome';

export default class CustomerSuccessConsoleHomeV2 extends NavigationMixin(LightningElement) {
    static shellStyleId = 'loving-customer-success-shell-style';
    activeTab = 'home';
    homeData;
    loadError;

    @wire(getHome)
    wiredHome({ data, error }) {
        if (data) {
            this.homeData = data;
            this.loadError = undefined;
        } else if (error) {
            this.homeData = null;
            this.loadError = this.extractErrorMessage(error);
            // eslint-disable-next-line no-console
            console.error('CustomerCareController.getHome error:', error);
        }
    }

    get hasLoadError() {
        return !!this.loadError;
    }

    extractErrorMessage(error) {
        if (!error) {
            return 'Customer Success data could not be loaded.';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        return 'Customer Success data could not be loaded.';
    }

    renderedCallback() {
        this.ensureShellStyle();
    }

    disconnectedCallback() {
        this.removeShellStyle();
    }

    get tabs() {
        return [
            { id: 'home', label: 'Home', badge: null },
            { id: 'omni', label: 'Omni Inbox', badge: this.inboxCount },
            { id: 'cases', label: 'Cases', badge: this.newRequestCount },
            { id: 'builder360', label: 'Builder 360', badge: null },
            { id: 'sitevisits', label: 'Site Visits', badge: this.siteVisitCount },
            { id: 'epo', label: 'EPO / PO Changes', badge: this.pendingEpoCount },
            { id: 'warranty', label: 'Warranty', badge: this.warrantyCount },
            { id: 'sameday', label: 'Same-Day', badge: this.urgentCount },
            { id: 'closeout', label: 'Closeout Queue', badge: this.closeoutCount },
            { id: 'knowledge', label: 'Knowledge + Playbooks', badge: null },
            { id: 'reports', label: 'Reports', badge: null },
            { id: 'approvals', label: 'Approvals', badge: null },
            { id: 'quotes', label: 'Quotes + Quote Builder', badge: this.quoteCount },
            { id: 'agentforce', label: 'Agentforce', badge: null }
        ].map((tab) => ({
            ...tab,
            cls: `tab${this.activeTab === tab.id ? ' on' : ''}`,
            href: this.tabHref(tab.id)
        }));
    }

    get stats() {
        return this.homeData?.todayStats || {};
    }

    get newRequestCount() {
        return this.stats.newRequests || 0;
    }

    get pendingEpoCount() {
        return this.stats.pendingEpos || 0;
    }

    get siteVisitCount() {
        return this.stats.siteVisitsScheduled || 0;
    }

    get warrantyCount() {
        return this.stats.openWarranty || 0;
    }

    get closeoutCount() {
        return this.homeData?.closeoutTotal || 0;
    }

    get quoteCount() {
        return this.homeData?.quotes?.length || 0;
    }

    get urgentCount() {
        return this.homeData?.urgentQueue?.length || 0;
    }

    get inboxCount() {
        return this.homeData?.inboxPreview?.length || 0;
    }

    get summaryTitle() {
        return 'Customer Success';
    }

    get summarySubtitle() {
        return `${this.newRequestCount} new requests · ${this.pendingEpoCount} pending EPO / PO changes · ${this.siteVisitCount} site visits · ${this.closeoutCount} in closeout`;
    }

    get todayLabel() {
        return new Intl.DateTimeFormat('en-US', {
            weekday: 'long',
            month: 'short',
            day: 'numeric'
        }).format(new Date());
    }

    get teamMembers() {
        const members = this.homeData?.teamOnDuty || [];
        return members.filter((member) => member && member.name && member.name !== 'Customer Care Team');
    }

    get hasTeamMembers() {
        return this.teamMembers.length > 0;
    }

    get teamTitle() {
        return `${this.teamMembers.length} team members on duty`;
    }

    get teamSubtitle() {
        return this.teamMembers.map((member) => member.name).join(' · ');
    }

    get coverageTitle() {
        return 'Active Customer Success coverage';
    }

    get coverageSubtitle() {
        return `${this.urgentCount} urgent items · ${this.pendingEpoCount} PO / EPO changes · ${this.siteVisitCount} site visits · ${this.quoteCount} quotes in the active queue.`;
    }

    ensureShellStyle() {
        if (typeof window === 'undefined' || typeof document === 'undefined') {
            return;
        }
        if (!window.location.pathname.includes('/lightning/n/Customer_Success_Console')) {
            return;
        }
        if (document.getElementById(CustomerSuccessConsoleHomeV2.shellStyleId)) {
            return;
        }
        const style = document.createElement('style');
        style.id = CustomerSuccessConsoleHomeV2.shellStyleId;
        style.textContent = `
            .flexipageHeader,
            app-flexipage-header {
                display: none !important;
            }
        `;
        document.head.appendChild(style);
    }

    removeShellStyle() {
        if (typeof document === 'undefined') {
            return;
        }
        document.getElementById(CustomerSuccessConsoleHomeV2.shellStyleId)?.remove();
    }

    get casesHomeUrl() {
        return '/lightning/o/Case/home';
    }

    get accountsHomeUrl() {
        return '/lightning/o/Account/home';
    }

    get purchaseOrdersHomeUrl() {
        return '/lightning/n/LOVING_PO_Pipeline';
    }

    get serviceAppointmentsHomeUrl() {
        return '/lightning/o/ServiceAppointment/home';
    }

    get quotesHomeUrl() {
        return '/lightning/o/Quote__c/home';
    }

    get workOrderPipelineUrl() {
        return '/lightning/n/Work_Order_Pipeline';
    }

    get agentforceUrl() {
        return '/lightning/n/mcLOVIN_Employee_Agent';
    }

    get summaryKpis() {
        return [
            { key: 'requests', value: this.newRequestCount, label: 'New Requests', cls: 'kpi orange' },
            { key: 'urgent', value: this.urgentCount, label: 'Urgent Queue', cls: 'kpi red' },
            { key: 'epo', value: this.pendingEpoCount, label: 'PO / EPO Changes', cls: 'kpi orange' },
            { key: 'visits', value: this.siteVisitCount, label: 'Site Visits', cls: 'kpi blue' },
            { key: 'warranty', value: this.warrantyCount, label: 'Open Warranty', cls: 'kpi purple' },
            { key: 'closeout', value: this.closeoutCount, label: 'Closeout Queue', cls: 'kpi green' }
        ];
    }

    get urgentSectionTitle() {
        return `${this.urgentCount} urgent items requiring action`;
    }

    get inboxTitle() {
        return `${this.inboxCount} live inbox items`;
    }

    get siteVisitSectionTitle() {
        return `${this.siteVisitCount} site visits scheduled today`;
    }

    get epoSectionTitle() {
        return `${this.pendingEpoCount} pending PO / EPO changes`;
    }

    get closeoutSectionTitle() {
        return `${this.closeoutCount} closeout items awaiting review`;
    }

    get quotesSectionTitle() {
        return `${this.quoteCount} active quotes in Customer Success`;
    }

    get liveSummaryTitle() {
        return `Live summary for ${this.todayLabel}`;
    }

    get liveSummaryRows() {
        return [
            { label: 'New requests', value: this.newRequestCount },
            { label: 'Urgent queue', value: this.urgentCount },
            { label: 'Pending EPO / PO', value: this.pendingEpoCount },
            { label: 'Site visits', value: this.siteVisitCount },
            { label: 'Open warranty', value: this.warrantyCount },
            { label: 'Closeout queue', value: this.closeoutCount }
        ];
    }

    get urgentQueueRows() {
        return (this.homeData?.urgentQueue || []).map((row) => ({
            ...row,
            statusClass: this.chipClassFromTone(row.statusTone)
        }));
    }

    get hasUrgentQueue() {
        return this.urgentQueueRows.length > 0;
    }

    get inboxRows() {
        return (this.homeData?.inboxPreview || []).map((row) => ({
            ...row,
            rowClass: `queue-row${row.rowClass ? ` ${row.rowClass}` : ''}`,
            avatarStyle: this.avatarStyle(row.avatarBg)
        }));
    }

    get hasInbox() {
        return this.inboxRows.length > 0;
    }

    get siteVisitRows() {
        return (this.homeData?.siteVisitsToday || []).map((row) => ({
            ...row,
            chipClass: this.chipClassFromTone(row.chipTone)
        }));
    }

    get hasSiteVisits() {
        return this.siteVisitRows.length > 0;
    }

    get pendingEpoRows() {
        return (this.homeData?.pendingEpos || []).map((row) => ({
            ...row,
            dayClass: this.dayClass(row.dayClass),
            actionBtnClass: this.actionButtonClass(row.actionTone)
        }));
    }

    get hasPendingEpos() {
        return this.pendingEpoRows.length > 0;
    }

    get quoteRows() {
        return (this.homeData?.quotes || []).map((row) => ({
            ...row,
            statusClass: this.chipClassFromTone(row.chipTone)
        }));
    }

    get hasQuotes() {
        return this.quoteRows.length > 0;
    }

    get closeoutOwnerRows() {
        return this.homeData?.closeoutByOwner || [];
    }

    get hasCloseoutByOwner() {
        return this.closeoutOwnerRows.length > 0;
    }

    get recentActivityRows() {
        return (this.homeData?.recentActivity || []).map((row) => ({
            ...row,
            avatarStyle: this.avatarStyle(row.avatarBg)
        }));
    }

    get hasRecentActivity() {
        return this.recentActivityRows.length > 0;
    }

    tabHref(tabId) {
        switch (tabId) {
            case 'home':
                return '/lightning/n/Customer_Success_Console';
            case 'omni':
            case 'cases':
                return this.casesHomeUrl;
            case 'builder360':
                return this.accountsHomeUrl;
            case 'sitevisits':
                return this.serviceAppointmentsHomeUrl;
            case 'epo':
                return '/lightning/n/LOVING_PO_Pipeline';
            case 'warranty':
            case 'sameday':
            case 'closeout':
            case 'approvals':
                return this.workOrderPipelineUrl;
            case 'knowledge':
                return '/lightning/o/Knowledge__kav/home';
            case 'reports':
                return '/lightning/o/Report/home';
            case 'quotes':
                return this.quotesHomeUrl;
            case 'agentforce':
                return this.agentforceUrl;
            default:
                return '/lightning/n/Customer_Success_Console';
        }
    }

    handleRefresh() {
        window.location.reload();
    }

    chipClassFromTone(tone) {
        return `chip ${tone || 'gray'}`;
    }

    avatarStyle(bg) {
        return bg ? `background:${bg};` : '';
    }

    actionButtonClass(tone) {
        if (tone === 'danger') return 'btn red small';
        if (tone === 'warning') return 'btn primary small';
        if (tone === 'success') return 'btn green small';
        return 'btn small';
    }

    dayClass(dayClass) {
        if (dayClass === 'red') return 'day-chip red-text';
        if (dayClass === 'amber') return 'day-chip orange-text';
        if (dayClass === 'green') return 'day-chip green-text';
        return 'day-chip';
    }

    openRecord(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    navigateToObject(objectApiName, actionName = 'home') {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName,
                actionName
            }
        });
    }

    navigateToNavItem(apiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName
            }
        });
    }

    openNewCase() {
        this.navigateToObject('Case', 'new');
    }

    openCases() {
        this.navigateToObject('Case', 'home');
    }

    openAccounts() {
        this.navigateToObject('Account', 'home');
    }

    openQuotes() {
        this.navigateToObject('Quote__c', 'home');
    }

    openServiceAppointments() {
        this.navigateToObject('ServiceAppointment', 'home');
    }

    openBuilderPoPipeline() {
        this.navigateToNavItem('LOVING_PO_Pipeline');
    }

    openWorkOrderPipeline() {
        this.navigateToNavItem('Work_Order_Pipeline');
    }

    openReports() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Report',
                actionName: 'home'
            }
        });
    }

    openKnowledge() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Knowledge__kav',
                actionName: 'home'
            }
        });
    }

    openAgentforce() {
        this.navigateToNavItem('mcLOVIN_Employee_Agent');
    }
}