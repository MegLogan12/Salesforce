import { LightningElement, track } from 'lwc';

const AGENTS = [
    {
        id: 1,
        name: 'Lead Qualifier',
        topic: 'Inbound lead',
        trigger: 'New Lead created',
        reads: 'Lead, Opportunity, Lead_Type__c',
        extComms: 'human review',
        actions: 'Read lead, score, route, log',
        status: 'Design'
    },
    {
        id: 2,
        name: 'PO Intake',
        topic: 'Builder PO',
        trigger: 'Builder PO received',
        reads: 'Builder_PO__c, price book, Community__c',
        extComms: 'internal only',
        actions: 'Parse PO, match price/qty, flag mismatch',
        status: 'Design'
    },
    {
        id: 3,
        name: 'Warranty Triage',
        topic: 'Care request',
        trigger: 'New Case created',
        reads: 'Case, Warranty_Record__c',
        extComms: 'human review',
        actions: 'Classify, draft response, route to queue',
        status: 'Design'
    },
    {
        id: 4,
        name: 'Scheduling',
        topic: 'Service appointment',
        trigger: 'WO Ready to Schedule',
        reads: 'ServiceAppointment, capacity',
        extComms: 'internal only',
        actions: 'Suggest slot, check capacity, propose',
        status: 'Design'
    }
];

const LOG_ENTRIES = [
    {
        id: 1,
        agentName: 'Lead Qualifier',
        action: 'Scored inbound lead — routed to Sales queue',
        timestamp: '2026-06-02 09:14 AM',
        status: 'logged'
    },
    {
        id: 2,
        agentName: 'PO Intake',
        action: 'Parsed Builder PO #1042 — price mismatch flagged',
        timestamp: '2026-06-02 10:31 AM',
        status: 'logged'
    },
    {
        id: 3,
        agentName: 'Warranty Triage',
        action: 'Classified Case #8819 — routed to Warranty queue',
        timestamp: '2026-06-02 01:05 PM',
        status: 'logged'
    }
];

const GUARDRAILS = [
    {
        id: 1,
        name: 'Human in the loop',
        description: 'No agent action is final without a human approval step for high-impact operations.',
        enforcement: 'Enforced',
        badgeClass: 'slds-badge slds-badge_success'
    },
    {
        id: 2,
        name: 'Full audit trail',
        description: 'Every agent action is logged with agent name, action taken, record ID, and timestamp.',
        enforcement: 'Enforced',
        badgeClass: 'slds-badge slds-badge_success'
    },
    {
        id: 3,
        name: 'Defined topic and actions',
        description: 'Agents operate only within their configured topic scope and permitted action list.',
        enforcement: 'Enforced',
        badgeClass: 'slds-badge slds-badge_success'
    },
    {
        id: 4,
        name: 'Bias review',
        description: 'Lead Qualifier scoring logic reviewed for demographic bias before go-live.',
        enforcement: 'Pending',
        badgeClass: 'slds-badge slds-badge_warning'
    }
];

export default class AgentforceConsole extends LightningElement {
    @track _expandedIds = new Set();

    get agents() {
        return AGENTS.map(agent => ({
            ...agent,
            isExpanded: this._expandedIds.has(agent.id),
            detailButtonLabel: this._expandedIds.has(agent.id) ? 'Collapse' : 'Details'
        }));
    }

    get logEntries() {
        return LOG_ENTRIES;
    }

    get guardrails() {
        return GUARDRAILS;
    }

    handleToggleDetail(event) {
        const agentId = Number(event.target.dataset.agentId);
        const updated = new Set(this._expandedIds);
        if (updated.has(agentId)) {
            updated.delete(agentId);
        } else {
            updated.add(agentId);
        }
        this._expandedIds = updated;
    }
}
