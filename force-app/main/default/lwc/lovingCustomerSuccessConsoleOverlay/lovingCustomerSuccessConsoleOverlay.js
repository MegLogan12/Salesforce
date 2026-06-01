import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConsoleData from '@salesforce/apex/LovingCustomerSuccessConsoleController.getConsoleData';

const TAB_DEFS = [
    { id: 'home', label: 'Home', title: 'Customer Success Home', subtitle: 'Daily control tower for routed work, urgent cases, builder changes, site visits, closeout, and approvals.', initials: 'CS', tone: 'orange', metric: 'newToday', action: 'newCase', emptyTitle: 'No active home records.', emptyBody: 'New Case is available for intake.' },
    { id: 'omni', label: 'Omni Inbox', title: 'Omni Inbox', subtitle: 'Routed AgentWork and PendingServiceRouting, with Case fallback when Omni has no rows.', initials: 'OM', tone: 'orange', metric: 'omniWork', action: 'disabledOmni', emptyTitle: 'No routed Omni work.', emptyBody: 'The console will fall back to open Cases when routed work is empty.' },
    { id: 'cases', label: 'Cases', title: 'Cases', subtitle: 'Case is the Customer Success source of truth for intake and issue management.', initials: 'CA', tone: 'blue', metric: 'openCases', action: 'newCase', emptyTitle: 'No open Cases found.', emptyBody: 'Create a Case to start Customer Success work.' },
    { id: 'builder360', label: 'Builder 360', title: 'Builder 360', subtitle: 'Builder account hierarchy, contacts, cases, field follow-up, and quote context.', initials: 'B3', tone: 'green', metric: null, action: 'newCase', emptyTitle: 'No builder accounts returned.', emptyBody: 'Account records will appear here when available.' },
    { id: 'siteVisits', label: 'Site Visits', title: 'Site Visits', subtitle: 'ServiceAppointment and WorkOrder context for field follow-up related to Cases.', initials: 'SV', tone: 'blue', metric: 'siteVisits', action: 'newServiceAppointment', emptyTitle: 'No site visits returned.', emptyBody: 'Create a Service Appointment if field follow-up is required.' },
    { id: 'epo', label: 'EPO / PO Changes', title: 'EPO / PO Changes', subtitle: 'Builder-requested additions or changes to original PO scope, price, material, duration, or approval.', initials: 'EPO', tone: 'orange', metric: null, action: 'disabledEpo', emptyTitle: 'No EPO / PO Change Cases returned.', emptyBody: 'Use Case Type or Subject to identify EPO / PO Change work.' },
    { id: 'warranty', label: 'Warranty', title: 'Warranty', subtitle: 'Case-first warranty review with WorkOrder or ServiceAppointment follow-up where needed.', initials: 'WA', tone: 'blue', metric: 'openWarranty', action: 'newCase', emptyTitle: 'No warranty Cases returned.', emptyBody: 'Create a Case and classify warranty details before field follow-up.' },
    { id: 'sameDay', label: 'Same-Day', title: 'Same-Day', subtitle: 'High-priority Case queue for urgent response and same-day field coordination.', initials: 'SD', tone: 'red', metric: 'sameDay', action: 'newCase', emptyTitle: 'No same-day urgent Cases.', emptyBody: 'High-priority open Cases will appear here.' },
    { id: 'closeout', label: 'Closeout Queue', title: 'Closeout Queue', subtitle: 'Completed field work needing Customer Success validation, communication, or invoice readiness.', initials: 'CO', tone: 'green', metric: null, action: 'disabledCloseout', emptyTitle: 'No closeout Work Orders returned.', emptyBody: 'Closeout remains read-only in this phase.' },
    { id: 'knowledge', label: 'Knowledge + Playbooks', title: 'Knowledge + Playbooks', subtitle: 'KnowledgeArticleVersion, Macro, and QuickText support for daily Customer Success work.', initials: 'KB', tone: 'purple', metric: 'knowledge', action: 'disabledKnowledge', emptyTitle: 'No published Knowledge articles returned.', emptyBody: 'Knowledge setup may be needed, or articles may not be published.' },
    { id: 'reports', label: 'Reports', title: 'Reports', subtitle: 'Customer Success reporting plus build audit and source map evidence.', initials: 'RP', tone: 'blue', metric: null, action: 'disabledReports', emptyTitle: 'No reports returned.', emptyBody: 'Create Salesforce reports and dashboards for operational reporting.' },
    { id: 'approvals', label: 'Approvals', title: 'Approvals', subtitle: 'Review, validate, approve, reject, return, or escalate Customer Success work.', initials: 'AP', tone: 'orange', metric: 'approvals', action: 'disabledApproval', emptyTitle: 'No approval work items returned.', emptyBody: 'Approval buttons stay disabled until an approved action or flow exists.' },
    { id: 'quotes', label: 'Quotes + Quote Builder', title: 'Quotes + Quote Builder', subtitle: 'Final tab for standard Quote, QuoteLineItem, PricebookEntry, validation, and builder send readiness.', initials: 'QB', tone: 'purple', metric: 'quotes', action: 'newQuote', emptyTitle: 'No Quotes returned.', emptyBody: 'Create a standard Quote when pricing work is ready.' }
];

const KPI_DEFS = [
    { key: 'omniWork', label: 'Routed work', tone: 'orange' },
    { key: 'openCases', label: 'Open Cases', tone: 'blue' },
    { key: 'urgentCases', label: 'Urgent Cases', tone: 'red' },
    { key: 'siteVisits', label: 'Site Visits', tone: 'blue' },
    { key: 'approvals', label: 'Approvals', tone: 'orange' },
    { key: 'quotes', label: 'Quotes', tone: 'purple' }
];

export default class LovingCustomerSuccessConsoleOverlay extends NavigationMixin(LightningElement) {
    @track currentTab = 'home';
    @track data;
    wiredResult;
    error;

    @wire(getConsoleData)
    wiredConsole(result) {
        this.wiredResult = result;
        if (result.data) {
            this.data = this.decoratePayload(result.data);
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.data = undefined;
        }
    }

    get isLoading() {
        return !this.data && !this.error;
    }

    get hasError() {
        return Boolean(this.error);
    }

    get errorMessage() {
        return this.error?.body?.message || this.error?.message || 'Customer Success console data could not load.';
    }

    get metrics() {
        return this.data?.metrics || {};
    }

    get tabs() {
        return TAB_DEFS.map((tab) => {
            const count = tab.metric ? this.metrics[tab.metric] : null;
            return {
                ...tab,
                count,
                className: tab.id === this.currentTab ? 'tab-button active' : 'tab-button'
            };
        });
    }

    get activeConfig() {
        return TAB_DEFS.find((tab) => tab.id === this.currentTab) || TAB_DEFS[0];
    }

    get activeTitle() {
        return this.activeConfig.title;
    }

    get activeSubtitle() {
        return this.activeConfig.subtitle;
    }

    get activeInitials() {
        return this.activeConfig.initials;
    }

    get activeIconClass() {
        return `mini-icon ${this.activeConfig.tone}`;
    }

    get activeCardClass() {
        return `card ${this.activeConfig.tone}`;
    }

    get activeRecords() {
        const rows = this.data?.recordsByTab?.[this.currentTab] || [];
        return rows.map((row, index) => ({
            ...row,
            rowKey: row.id || `${this.currentTab}-${index}`,
            name: row.name || row.title || 'Record',
            title: row.title || row.detail || 'No summary',
            statusLabel: row.status || row.priority || 'Open',
            detail: row.detail || row.accountName || row.contactName || '-',
            chipClass: `chip ${row.tone || 'blue'}`,
            noRecord: !row.id
        }));
    }

    get hasActiveRecords() {
        return this.activeRecords.length > 0;
    }

    get activeEmptyTitle() {
        return this.activeConfig.emptyTitle;
    }

    get activeEmptyBody() {
        return this.activeConfig.emptyBody;
    }

    get activePrimaryLabel() {
        switch (this.activeConfig.action) {
            case 'newCase':
                return '+ New Case';
            case 'newServiceAppointment':
                return '+ Create SA';
            case 'newQuote':
                return '+ New Quote';
            case 'disabledApproval':
                return 'Approve Selected';
            case 'disabledOmni':
                return 'Accept next';
            default:
                return 'Setup needed';
        }
    }

    get activePrimaryVariant() {
        return this.activePrimaryDisabled ? 'neutral' : 'brand';
    }

    get activePrimaryDisabled() {
        return this.activeConfig.action && this.activeConfig.action.startsWith('disabled');
    }

    get activePrimaryTitle() {
        if (!this.activePrimaryDisabled) {
            return this.activePrimaryLabel;
        }
        return 'Disabled until an approved Salesforce action or flow exists.';
    }

    get kpis() {
        return KPI_DEFS.map((kpi) => ({
            label: kpi.label,
            value: this.metrics[kpi.key] || 0,
            className: `kpi ${kpi.tone}`
        }));
    }

    get features() {
        return this.data?.features || [];
    }

    get sourceMap() {
        return this.data?.sourceMap || [];
    }

    get buttonMatrixPreview() {
        return (this.data?.buttonMatrix || []).slice(0, 8).map((button) => ({
            ...button,
            label: button.enabled ? 'Enabled' : 'Disabled',
            className: button.enabled ? 'chip green' : 'chip gray'
        }));
    }

    get toolRows() {
        return this.features.slice(0, 8);
    }

    get agentforceMessage() {
        const feature = this.features.find((row) => row.feature === 'Agentforce Assist');
        return feature?.uiBehaviorIfMissing || 'Setup-needed state until approved Agentforce actions exist.';
    }

    get slaRows() {
        const entitlements = this.features.find((row) => row.feature === 'Entitlements');
        const milestones = this.features.find((row) => row.feature === 'Case Milestones');
        return [
            { label: 'Entitlements', value: entitlements?.enabledLabel || 'Check setup' },
            { label: 'Case Milestones', value: milestones?.enabledLabel || 'Check setup' },
            { label: 'SLA source', value: 'Case header and right rail' }
        ];
    }

    get isHome() {
        return this.currentTab === 'home';
    }

    get isReports() {
        return this.currentTab === 'reports';
    }

    get isApprovals() {
        return this.currentTab === 'approvals';
    }

    get isQuotes() {
        return this.currentTab === 'quotes';
    }

    decoratePayload(payload) {
        const copy = JSON.parse(JSON.stringify(payload));
        copy.features = (copy.features || []).map((feature) => ({
            ...feature,
            enabledLabel: feature.enabled ? 'Yes' : 'No',
            availableLabel: feature.objectAvailable ? 'Yes' : 'No',
            enabledClass: feature.enabled ? 'chip green' : 'chip gray',
            availableClass: feature.objectAvailable ? 'chip green' : 'chip amber'
        }));
        copy.sourceMap = (copy.sourceMap || []).map((row) => ({
            ...row,
            existsLabel: row.exists ? 'Yes' : 'No',
            lovingLabel: row.lovingFieldNeeded ? 'Yes' : 'No',
            existsClass: row.exists ? 'chip green' : 'chip amber'
        }));
        return copy;
    }

    switchTab(event) {
        this.currentTab = event.currentTarget.dataset.id;
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    refresh() {
        refreshApex(this.wiredResult);
    }

    handlePrimaryAction() {
        if (this.activePrimaryDisabled) {
            this.showToast('Setup needed', this.activePrimaryTitle, 'warning');
            return;
        }
        if (this.activeConfig.action === 'newServiceAppointment') {
            this.navigateNew('ServiceAppointment');
            return;
        }
        if (this.activeConfig.action === 'newQuote') {
            this.newQuote();
            return;
        }
        this.newCase();
    }

    newCase() {
        this.navigateNew('Case');
    }

    newQuote() {
        this.navigateNew('Quote');
    }

    navigateNew(objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName,
                actionName: 'new'
            }
        });
    }

    openRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            this.showToast('No record to open', 'This row is a setup-needed state, not a Salesforce record.', 'info');
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

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}