import { api, LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import startDraft from '@salesforce/apex/McLovinEmployeeAgentController.startDraft';
import analyzeRequest from '@salesforce/apex/McLovinEmployeeAgentController.analyzeRequest';
import saveRequest from '@salesforce/apex/McLovinEmployeeAgentController.saveRequest';

const PAGE_CONTEXT_BY_API = {
    HomePage: 'HOME',
    Unified_App_Home_Page: 'ODL_HOME',
    Unified_App_Home: 'ODL_HOME',
    Customer_Success_Console: 'CUSTOMER_CARE',
    Customer_Success_Service_Console: 'CUSTOMER_CARE',
    Aqua_Service_Home_Page: 'AQUA',
    Aqua_Service_Home: 'AQUA',
    Scheduling_Console_Home: 'SCHEDULING',
    Scheduling_Console: 'SCHEDULING',
    Forecasting_Home_Page: 'FORECASTING',
    Forecasting_Home: 'FORECASTING',
    Seller_Home: 'SELLER_HOME'
};

const RECORD_CONTEXT_BY_OBJECT = {
    WorkOrder: 'WORKORDER_RECORD',
    Case: 'CASE_RECORD',
    Opportunity: 'OPPORTUNITY_RECORD',
    Account: 'ACCOUNT_RECORD',
    Community__c: 'COMMUNITY_RECORD',
    Lot__c: 'LOT_RECORD'
};

const QUICK_START_TEMPLATES = {
    uploadPo: {
        label: 'Upload PO',
        sourceType: 'Document',
        prompt: 'Purchase Order Upload\nRouting Lane: Builder PO\nPO Number:\nBuilder:\nCommunity:\nLot:\nAddress:\nScope of Work:\nWhat should happen next:\n'
    },
    uploadNewAccount: {
        label: 'Upload New Account',
        sourceType: 'Document',
        prompt: 'New Account Intake\nRouting Lane: New Account\nAccount Name:\nRecord Type:\nPrimary Contact:\nEmail:\nPhone:\nAddress:\nReason for create:\nOwnership note:\n'
    },
    uploadScope: {
        label: 'Upload Scope of Work',
        sourceType: 'Document',
        prompt: 'Scope of Work\nRouting Lane: Scope Review\nBuilder / Homeowner:\nCommunity:\nLot:\nAddress:\nWork Order Id (if existing):\nScope Lines:\n'
    },
    uploadHomeowner: {
        label: 'Upload Homeowner Intake',
        sourceType: 'Document',
        prompt: 'Homeowner Intake\nRouting Lane: Homeowner\nHousehold / Last Name:\nStreet Address:\nCity State Zip:\nPrimary Contact:\nEmail:\nPhone:\nRequest:\n'
    },
    uploadSpreadsheet: {
        label: 'Upload Spreadsheet',
        sourceType: 'Spreadsheet',
        prompt: 'Spreadsheet Batch Intake\nRouting Lane: Spreadsheet\nPaste notes here or upload the workbook. mcLOVIN will sort rows, match existing records, and flag what still needs a human call.\n'
    },
    customerCareCase: {
        label: 'Open Customer Care Case',
        sourceType: 'Document',
        prompt: 'Customer Care Case Intake\nRouting Lane: Customer Care Closeout\nCase Type: Customer Care\nCustomer / Builder:\nContact:\nEmail:\nPhone:\nAddress:\nIssue Summary:\nProof Attached:\n'
    },
    warrantyCase: {
        label: 'Open Warranty Case',
        sourceType: 'Document',
        prompt: 'Warranty Case Intake\nRouting Lane: Warranty\nCase Type: Warranty\nCustomer / Builder:\nContact:\nEmail:\nPhone:\nAddress:\nCoverage Issue:\nProof Attached:\n'
    },
    scheduleRequest: {
        label: 'Request Scheduling / Reschedule',
        sourceType: 'Document',
        prompt: 'Scheduling Request\nRouting Lane: Scheduling\nRequest Type: Reschedule\nWork Order / Service Appointment:\nCommunity:\nLot / Address:\nReason:\nRequested Date:\nApproval Note:\n'
    },
    aquaRepair: {
        label: 'Dispatch Aqua Repair',
        sourceType: 'Document',
        prompt: 'Aqua Repair Intake\nRouting Lane: Aqua Repair\nIssue Type:\nProperty / Community:\nAddress:\nCustomer / Builder:\nProof Attached:\nWhat failed:\nUrgency:\n'
    }
};

const KNOWLEDGE_SECTIONS = [
    { key: 'approvals', label: 'Approvals' },
    { key: 'ownership', label: 'Ownership' },
    { key: 'queues', label: 'Queue Logic' },
    { key: 'requiredFields', label: 'Required Fields' },
    { key: 'failurePoints', label: 'Failure Points' },
    { key: 'doNotDo', label: 'What Not To Do' }
];

const CONTEXT_CONFIGS = {
    HOME: {
        label: 'Home',
        purpose: 'General LOVING employee landing page for intake, routing, and figuring out where the work should actually start.',
        doNow: 'Upload a PO, upload a new account, open a customer care case, or jump to the right console before you create junk in the wrong place.',
        caution: 'Do not guess the record path from Home. Pick the real workflow first so ownership, approvals, and reporting land correctly.',
        prompts: ['Upload PO', 'Upload new account', 'Create builder account', 'Create homeowner account', 'Create work order', 'Find the right page for this task', 'What fields are required?', 'Why is this blocked?'],
        actions: [
            { label: 'Upload PO', type: 'seed', templateKey: 'uploadPo' },
            { label: 'Upload New Account', type: 'seed', templateKey: 'uploadNewAccount' },
            { label: 'Open Customer Care Case', type: 'seed', templateKey: 'customerCareCase' },
            { label: 'Go To Scheduling Console', type: 'navTab', apiName: 'Scheduling_Console' },
            { label: 'Create Work Order', type: 'objectNew', objectApiName: 'WorkOrder' }
        ],
        approvals: [
            'If the request changes margin, routing, or field execution, expect an approval or owner review before pretending it is ready.',
            'Do not push builder or homeowner intake forward until the account path is settled.'
        ],
        ownership: [
            'Home is triage, not final ownership. mcLOVIN should push work into the right console or record path.',
            'Builder intake belongs on the real builder account path, not under The Loving Group.'
        ],
        queues: [
            'Customer care closeout issues route to the customer care lane.',
            'Scheduling changes route to Scheduling_Queue, not to random comments on the job.'
        ],
        requiredFields: [
            'PO / builder package: builder account, community, lot, PO number, scope.',
            'Homeowner intake: household name, property address, contact details, request summary.'
        ],
        failurePoints: [
            'Starting on the wrong page and creating duplicates.',
            'Skipping community or lot on builder work so reporting splits later.'
        ],
        doNotDo: [
            'Do not create a builder account under The Loving Group by default.',
            'Do not open a generic record just because it is the first thing you can click.'
        ]
    },
    SELLER_HOME: {
        label: 'Seller Home',
        purpose: 'Sales-side launch point for builder, homeowner, opportunity, and intake work.',
        doNow: 'Upload a PO, upload a new account packet, create or open the right opportunity path, or route the job into field operations.',
        caution: 'Sales pages are where duplicate accounts and wrong opportunity paths get born. Slow down before save, not after.',
        prompts: ['Upload a PO', 'Upload a new account', 'Create opportunity', 'Search account', 'Explain builder workflow', 'Where do I go for field operations?'],
        actions: [
            { label: 'Upload PO', type: 'seed', templateKey: 'uploadPo' },
            { label: 'Upload New Account', type: 'seed', templateKey: 'uploadNewAccount' },
            { label: 'New Opportunity', type: 'objectNew', objectApiName: 'Opportunity' },
            { label: 'Create Community', type: 'objectNew', objectApiName: 'Community__c' },
            { label: 'Go To Scheduling Console', type: 'navTab', apiName: 'Scheduling_Console' }
        ],
        approvals: [
            'Builder account creation and opportunity routing should be confirmed before downstream work starts.',
            'Do not move to execution until the sales path is on the right account.'
        ],
        ownership: [
            'Sales owns intake clarity here.',
            'Field operations takes over only after the opportunity / work-order path is clean.'
        ],
        queues: [
            'Customer care issues belong in customer care, not buried in sales notes.',
            'Scheduling requests belong in the scheduling lane once the job is real.'
        ],
        requiredFields: [
            'Builder work: builder account, community, lot, opportunity path, PO if present.',
            'Homeowner work: household, property address, contact, request type.'
        ],
        failurePoints: [
            'Creating duplicate builder accounts.',
            'Creating opportunities without the community / lot context that later operations needs.'
        ],
        doNotDo: [
            'Do not use The Loving Group as the builder target account.',
            'Do not create a new homeowner path when the household already exists.'
        ]
    },
    UNIFIED: {
        label: 'Unified App',
        purpose: 'Executive and cross-functional operating page for routing work into the right LOVING system, not for freelancing a random process.',
        doNow: 'Launch the correct intake, create the right record, or jump to customer care, aqua, or scheduling without bouncing through the wrong app.',
        caution: 'This page looks broad on purpose. That does not make it a safe place to improvise ownership or skip the real downstream workflow.',
        prompts: ['Where do I start?', 'Upload a PO', 'Upload a new account', 'Create a new opportunity', 'Open customer care', 'Take me to scheduling', 'Show me common tasks'],
        actions: [
            { label: 'Upload PO', type: 'seed', templateKey: 'uploadPo' },
            { label: 'Upload New Account', type: 'seed', templateKey: 'uploadNewAccount' },
            { label: 'New Opportunity', type: 'objectNew', objectApiName: 'Opportunity' },
            { label: 'Open Customer Care Case', type: 'seed', templateKey: 'customerCareCase' },
            { label: 'Take Me To Scheduling', type: 'navTab', apiName: 'Scheduling_Console' },
            { label: 'Create Community And Lot', type: 'chain', steps: [
                { type: 'objectNew', objectApiName: 'Community__c' },
                { type: 'objectNew', objectApiName: 'Lot__c' }
            ] }
        ],
        approvals: [
            'Work that affects field execution, budget, or builder/homeowner routing needs the right owner before it moves.',
            'If the job is not ready for downstream teams, say so now instead of hiding it in a partial record.'
        ],
        ownership: [
            'Unified is orchestration. It should point to the correct owner, not absorb every task itself.',
            'Builder, customer care, aqua, and scheduling all have distinct follow-through owners.'
        ],
        queues: [
            'Customer care routing stays in customer care lanes.',
            'Scheduling changes should end up in Scheduling_Queue.'
        ],
        requiredFields: [
            'Pick the real path first: PO, account, opportunity, case, work order, or schedule.',
            'Gather builder/community/lot or household/property context before save.'
        ],
        failurePoints: [
            'Cross-functional pages create false confidence. People think they are done because the wrapper page loaded.',
            'Wrong path selection here causes reporting drift later.'
        ],
        doNotDo: [
            'Do not use Unified as a trash can for half-known requests.',
            'Do not route field work without knowing which job, which property, and which owner actually owns the next step.'
        ]
    },
    CUSTOMER_CARE: {
        label: 'Customer Care',
        purpose: 'Customer care and warranty operating page for issue triage, closeout review, warranty routing, and customer-facing follow-through.',
        doNow: 'Open a warranty or customer care case, verify queue/owner, review required proof, and keep the issue on the right lane.',
        caution: 'Customer care falls apart when issue type, queue, and proof are sloppy. That is how jobs disappear into the wrong hands.',
        prompts: ['Open a warranty case', 'Open a same-day escalation', 'Create a closeout review', 'Find a customer account', 'Explain case routing', 'What queue should this go to?', 'What approvals apply here?'],
        actions: [
            { label: 'Open Warranty Case', type: 'seed', templateKey: 'warrantyCase' },
            { label: 'Open Customer Care Case', type: 'seed', templateKey: 'customerCareCase' },
            { label: 'Request Scheduling / Reschedule', type: 'seed', templateKey: 'scheduleRequest' },
            { label: 'New Case', type: 'objectNew', objectApiName: 'Case', defaultFieldValues: { Origin: 'Web' } },
            { label: 'Find Customer Account', type: 'navTab', apiName: 'Outdoor_Living_Accounts' }
        ],
        approvals: [
            'Closeout reviews and warranty determinations need the right lane before they get treated as completed.',
            'Do not promise schedule changes from customer care without the scheduling lane picking them up.'
        ],
        ownership: [
            'Customer care owns issue intake quality and the customer-facing handoff.',
            'Warranty-specific issues should be kept on the warranty lane.'
        ],
        queues: [
            'Warranty queue: Warranty.',
            'Customer care closeout lane exists as Customer_Care_Closeout.',
            'Scheduling-related requests should route to Scheduling_Queue.'
        ],
        requiredFields: [
            'Customer, contact method, property/address, issue summary, and proof.',
            'Warranty cases need coverage context, not just “customer is mad.”'
        ],
        failurePoints: [
            'Opening a generic case with no route or proof.',
            'Dropping a scheduling problem into customer care without flagging Scheduling_Queue.'
        ],
        doNotDo: [
            'Do not dump warranty, closeout, and scheduling issues into one generic lane.',
            'Do not close the issue just because a note exists.'
        ]
    },
    AQUA: {
        label: 'Aqua Service',
        purpose: 'Aqua repair, check, and pickup operating page for field-ready service work and proof-driven follow-through.',
        doNow: 'Dispatch aqua repair, open aqua check or pickup, confirm proof, and route the request into the right aqua workflow.',
        caution: 'Aqua work is easy to mislabel. If issue type and proof are wrong, the next team wastes time and inventory.',
        prompts: ['Create Aqua repair ticket', 'Open Aqua check', 'Open Aqua pickup', 'What proof is required?', 'What closes an Aqua job?', 'Who owns the next step?'],
        actions: [
            { label: 'Dispatch Aqua Repair', type: 'seed', templateKey: 'aquaRepair' },
            { label: 'Open Aqua Check Work Order', type: 'objectNew', objectApiName: 'WorkOrder' },
            { label: 'Open Aqua Pickup Work Order', type: 'objectNew', objectApiName: 'WorkOrder' },
            { label: 'Open Customer Care Case', type: 'seed', templateKey: 'customerCareCase' },
            { label: 'Go To Scheduling Console', type: 'navTab', apiName: 'Scheduling_Console' }
        ],
        approvals: [
            'Aqua exceptions need the correct issue type and proof before anyone treats them as ready.',
            'Do not call it closed until the proof path says it is closed.'
        ],
        ownership: [
            'Aqua lane owns the repair/check/pickup workflow.',
            'If it becomes a scheduling problem, hand it to scheduling instead of parking it here.'
        ],
        queues: [
            'Aqua queue evidence in production is limited. Aqua_Closeout_Approval exists, but repair dispatch should still be reviewed before auto-routing.'
        ],
        requiredFields: [
            'Issue type, property context, customer/builder, proof, urgency.',
            'If it is a pickup or check, say that explicitly.'
        ],
        failurePoints: [
            'Wrong aqua workflow chosen.',
            'No proof attached, so the next person has to guess.'
        ],
        doNotDo: [
            'Do not fake an aqua repair with a generic work order and no issue context.',
            'Do not mark aqua work closed without proof.'
        ]
    },
    SCHEDULING: {
        label: 'Scheduling Console',
        purpose: 'Dispatcher-facing scheduling board for live FSL work, crew coverage, blocked jobs, and reschedule handling.',
        doNow: 'Find available crew, explain the blocker, request a reschedule, or verify what is still missing before dispatch.',
        caution: 'If the job is blocked here, the board is not being dramatic. Something real is missing and dispatch will only get uglier if you ignore it.',
        prompts: ['Reschedule this job', 'Find available crew', 'Explain why this job is blocked', 'Check territory coverage', 'What resource is missing?', 'What must happen before dispatch?'],
        actions: [
            { label: 'Request Scheduling / Reschedule', type: 'seed', templateKey: 'scheduleRequest' },
            { label: 'Open Work Order', type: 'navTab', apiName: 'Scheduling_Console' },
            { label: 'Dispatch Aqua Repair', type: 'seed', templateKey: 'aquaRepair' },
            { label: 'Create Work Order', type: 'objectNew', objectApiName: 'WorkOrder' },
            { label: 'Open Customer Care Case', type: 'seed', templateKey: 'customerCareCase' }
        ],
        approvals: [
            'Reschedules need the right reason and owner before they count as real.',
            'Dispatch should not move blocked work just to make the board look cleaner.'
        ],
        ownership: [
            'Scheduling owns the board, crew fit, and dispatch move.',
            'Upstream teams still own fixing missing prerequisites.'
        ],
        queues: [
            'Scheduling queue: Scheduling_Queue.',
            'Customer issues stay in customer care; scheduling should not become the complaint inbox.'
        ],
        requiredFields: [
            'Work order or service appointment context, territory, crew/resource fit, reschedule reason.',
            'If the job is blocked, identify the missing dependency before trying to move it.'
        ],
        failurePoints: [
            'No crew or territory fit.',
            'Job ready status is fake because upstream data is incomplete.',
            'Reschedule requested with no reason or no owner.'
        ],
        doNotDo: [
            'Do not dispatch around a blocker just because the date looks urgent.',
            'Do not hide an ownership problem by changing the schedule.'
        ]
    },
    FORECASTING: {
        label: 'Forecasting',
        purpose: 'Forecast review page for seeing what demand is real, what inputs are missing, and why rollups are lying.',
        doNow: 'Explain the forecast view, find missing data, open the related opportunity path, or call out what is blocking rollup.',
        caution: 'Forecasting pages are only as real as the underlying sales and ops data. If the numbers are off, the page is not the only suspect.',
        prompts: ['Explain forecast view', 'Why is this forecast wrong?', 'Show missing data', 'What is blocking forecast rollup?', 'Open related opportunity', 'Show required inputs'],
        actions: [
            { label: 'Upload Spreadsheet', type: 'seed', templateKey: 'uploadSpreadsheet' },
            { label: 'Upload New Account', type: 'seed', templateKey: 'uploadNewAccount' },
            { label: 'New Opportunity', type: 'objectNew', objectApiName: 'Opportunity' },
            { label: 'Go To ODL Home', type: 'navTab', apiName: 'Outdoor_Living_Home' }
        ],
        approvals: [
            'Forecast adjustments should follow the owning pipeline or scheduling process, not ad hoc edits.',
            'If the forecast is wrong because the source record is wrong, fix the source.'
        ],
        ownership: [
            'Forecasting summarizes. It does not own the originating sales, ops, or scheduling data.',
            'The owner of the missing source data still owns the fix.'
        ],
        queues: [
            'There is no magic forecast queue. Fix the source workflow that feeds the rollup.'
        ],
        requiredFields: [
            'Opportunity, work order, or schedule inputs must be complete upstream.',
            'Missing builder/community/lot or stage data will make the forecast look dumber than it is.'
        ],
        failurePoints: [
            'Null or missing source data.',
            'Trying to explain a rollup problem without checking the underlying records.'
        ],
        doNotDo: [
            'Do not patch the dashboard story and ignore the underlying record problem.',
            'Do not treat forecast variance as a page-only defect.'
        ]
    },
    WORKORDER_RECORD: {
        label: 'Work Order Record',
        purpose: 'Live work-order context for execution, scope, and readiness.',
        doNow: 'Review the job, add parsed scope items, open scheduling, or route service issues correctly.',
        caution: 'A work order with weak source data turns into field confusion fast.',
        prompts: ['Create work order', 'Request Scheduling/Reschedule', 'What fields are required?', 'What can break here?'],
        actions: [
            { label: 'Request Scheduling / Reschedule', type: 'seed', templateKey: 'scheduleRequest' },
            { label: 'Upload Scope Of Work', type: 'seed', templateKey: 'uploadScope' },
            { label: 'Go To Scheduling Console', type: 'navTab', apiName: 'Scheduling_Console' }
        ],
        approvals: ['Readiness and routing still matter before dispatch.'],
        ownership: ['Field execution owns the job once the work order path is real.'],
        queues: ['Scheduling changes still belong to Scheduling_Queue.'],
        requiredFields: ['Clear scope, property context, and routing.'],
        failurePoints: ['Weak scope or wrong property context.'],
        doNotDo: ['Do not pretend the work order is ready if the upstream path is broken.']
    },
    CASE_RECORD: {
        label: 'Case Record',
        purpose: 'Service issue context for routing, ownership, and proof.',
        doNow: 'Check queue, proof, and whether this belongs in warranty, customer care, or scheduling.',
        caution: 'Cases go stale when the route is wrong.',
        prompts: ['What queue should this go to?', 'Why is this blocked?', 'Open a warranty case', 'Open a customer care case'],
        actions: [
            { label: 'Open Warranty Case', type: 'seed', templateKey: 'warrantyCase' },
            { label: 'Open Customer Care Case', type: 'seed', templateKey: 'customerCareCase' },
            { label: 'Request Scheduling / Reschedule', type: 'seed', templateKey: 'scheduleRequest' }
        ],
        approvals: ['Queue and owner must be correct before closeout or reschedule moves.'],
        ownership: ['Customer care owns the service issue lane unless it moves to scheduling or field execution.'],
        queues: ['Warranty and Scheduling queues exist in production.'],
        requiredFields: ['Issue summary, proof, customer context, route.'],
        failurePoints: ['Wrong route and no proof.'],
        doNotDo: ['Do not leave a case in a generic lane with no next owner.']
    },
    DEFAULT: {
        label: 'mcLOVIN',
        purpose: 'General LOVING operating assistant.',
        doNow: 'Upload intake, ask what fields are missing, or jump to the right workflow.',
        caution: 'If the path is unclear, fix the path before save.',
        prompts: ['Upload PO', 'Upload new account', 'Open customer care case', 'Create work order', 'What fields are required?'],
        actions: [
            { label: 'Upload PO', type: 'seed', templateKey: 'uploadPo' },
            { label: 'Upload New Account', type: 'seed', templateKey: 'uploadNewAccount' },
            { label: 'Create Work Order', type: 'objectNew', objectApiName: 'WorkOrder' }
        ],
        approvals: ['High-risk routing still needs the right owner.'],
        ownership: ['mcLOVIN should direct you to the right lane, not hide the lane.'],
        queues: ['Scheduling and Warranty queues exist when the route is real.'],
        requiredFields: ['Enough business context to know what should be created.'],
        failurePoints: ['Generic intake with no route.'],
        doNotDo: ['Do not save ambiguous junk.']
    }
};

export default class McLovinEmployeeAgentWorkspace extends NavigationMixin(LightningElement) {
    @api pageTitle = "mcLOVIN'";
    @api contextKey;

    @track sourceType = 'Text';
    @track intakeText = '';
    @track requestId;
    @track analysis;
    @track overrides = {};
    @track saveResult;
    @track isBusy = false;
    @track currentPageReference;

    sourceTypeOptions = [
        { label: 'Text', value: 'Text' },
        { label: 'Email', value: 'Email' },
        { label: 'Document', value: 'Document' },
        { label: 'Spreadsheet', value: 'Spreadsheet' }
    ];

    quickStarts = Object.values(QUICK_START_TEMPLATES).slice(0, 5);

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        this.currentPageReference = pageRef;
    }

    connectedCallback() {
        this.ensureDraft();
    }

    get resolvedContextKey() {
        if (this.contextKey && CONTEXT_CONFIGS[this.contextKey]) {
            return this.contextKey;
        }
        const pageRef = this.currentPageReference;
        const apiName = pageRef?.attributes?.apiName || pageRef?.attributes?.name;
        if (apiName && PAGE_CONTEXT_BY_API[apiName]) {
            return PAGE_CONTEXT_BY_API[apiName];
        }
        const objectApiName = pageRef?.attributes?.objectApiName;
        if (objectApiName && RECORD_CONTEXT_BY_OBJECT[objectApiName]) {
            return RECORD_CONTEXT_BY_OBJECT[objectApiName];
        }
        return 'DEFAULT';
    }

    get contextConfig() {
        return CONTEXT_CONFIGS[this.resolvedContextKey] || CONTEXT_CONFIGS.DEFAULT;
    }

    get contextLabel() {
        return this.contextConfig.label;
    }

    get contextPurpose() {
        return this.contextConfig.purpose;
    }

    get contextDoNow() {
        return this.contextConfig.doNow;
    }

    get contextCaution() {
        return this.contextConfig.caution;
    }

    get contextPromptRows() {
        return (this.contextConfig.prompts || []).map((label) => ({ label }));
    }

    get contextActionRows() {
        return this.contextConfig.actions || [];
    }

    get knowledgeRows() {
        return KNOWLEDGE_SECTIONS.map((section) => ({
            key: section.key,
            label: section.label,
            values: this.contextConfig[section.key] || []
        }));
    }

    get detectedContextLabel() {
        const pageRef = this.currentPageReference;
        const recordBits = [];
        if (pageRef?.attributes?.objectApiName) {
            recordBits.push(pageRef.attributes.objectApiName);
        }
        if (pageRef?.attributes?.recordId) {
            recordBits.push(pageRef.attributes.recordId);
        }
        return recordBits.join(' · ');
    }

    async ensureDraft() {
        if (this.requestId) return;
        try {
            this.requestId = await startDraft({ sourceType: this.sourceType, intakeText: this.intakeText });
        } catch (error) {
            this.showError(error);
        }
    }

    handleSourceTypeChange(event) {
        this.sourceType = event.detail.value;
    }

    handleQuickStart(event) {
        const templateKey = Object.keys(QUICK_START_TEMPLATES).find((key) => QUICK_START_TEMPLATES[key].label === event.target.label);
        this.applyQuickStart(templateKey);
    }

    handleContextAction(event) {
        const actionLabel = event.target.label;
        const action = (this.contextActionRows || []).find((row) => row.label === actionLabel);
        if (!action) return;
        this.executeAction(action);
    }

    handlePromptAction(event) {
        const label = event.target.label;
        this.intakeText = `${label}\nPage Context: ${this.contextLabel}\nWhat is this page for?\nWhat can I do here right now?\nWhat can break here?\n`;
        this.sourceType = 'Text';
        this.analysis = null;
        this.saveResult = null;
        this.toast(`mcLOVIN' queued the ${label.toLowerCase()} prompt.`, 'info');
    }

    applyQuickStart(templateKey) {
        const template = QUICK_START_TEMPLATES[templateKey];
        if (!template) return;
        this.sourceType = template.sourceType || this.sourceType;
        this.intakeText = `${template.prompt}\nPage Context: ${this.contextLabel}\n`;
        this.analysis = null;
        this.saveResult = null;
        this.toast(`mcLOVIN' lined up ${template.label.toLowerCase()}.`, 'success');
    }

    executeAction(action) {
        if (!action) return;
        if (action.type === 'seed') {
            this.applyQuickStart(action.templateKey);
            return;
        }
        if (action.type === 'navTab') {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: action.apiName
                }
            });
            return;
        }
        if (action.type === 'objectNew') {
            const state = {};
            if (action.defaultFieldValues) {
                state.defaultFieldValues = encodeDefaultFieldValues(action.defaultFieldValues);
            }
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: action.objectApiName,
                    actionName: 'new'
                },
                state
            });
            return;
        }
        if (action.type === 'chain') {
            // Run the first step immediately and leave the second one visible in the prompt.
            const firstStep = action.steps?.[0];
            const secondStep = action.steps?.[1];
            if (secondStep?.objectApiName) {
                this.intakeText = `Create Community and Lot\nPage Context: ${this.contextLabel}\nStep 1: Create the Community.\nStep 2: Create the Lot and tie it to the new Community.\n`;
                this.sourceType = 'Text';
            }
            this.executeAction(firstStep);
        }
    }

    handleTextChange(event) {
        this.intakeText = event.target.value;
    }

    handleOverrideChange(event) {
        this.overrides = {
            ...this.overrides,
            [event.target.dataset.key]: event.target.value
        };
    }

    async handleAnalyze() {
        this.isBusy = true;
        this.saveResult = null;
        try {
            await this.ensureDraft();
            const contextWrappedText = this.buildContextWrappedText();
            const result = await analyzeRequest({
                requestId: this.requestId,
                sourceType: this.sourceType,
                intakeText: contextWrappedText
            });
            this.analysis = result;
            this.overrides = this.seedOverrides(result);
            this.toast('mcLOVIN\' analyzed the intake.', 'success');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isBusy = false;
        }
    }

    buildContextWrappedText() {
        const parts = [
            `Page Context: ${this.contextLabel}`,
            `Page Purpose: ${this.contextPurpose}`,
            `Immediate Safe Action: ${this.contextDoNow}`
        ];
        if (this.currentPageReference?.attributes?.recordId) {
            parts.push(`Record Id: ${this.currentPageReference.attributes.recordId}`);
        }
        if (this.currentPageReference?.attributes?.objectApiName) {
            parts.push(`Object Api Name: ${this.currentPageReference.attributes.objectApiName}`);
        }
        if (this.intakeText) {
            parts.push(this.intakeText);
        }
        return parts.join('\n');
    }

    async handleSave() {
        if (!this.analysis) return;
        if (!window.confirm('Save the proposed Salesforce records now?')) {
            return;
        }
        this.isBusy = true;
        try {
            const result = await saveRequest({
                requestId: this.requestId,
                overridesJson: JSON.stringify(this.overrides),
                confirmed: true
            });
            this.saveResult = {
                ...result,
                primaryRecordUrl: result.primaryRecordId ? `/lightning/r/${result.primaryRecordId}/view` : null
            };
            this.toast('Records saved.', 'success');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isBusy = false;
        }
    }

    async handleUploadFinished() {
        this.toast('Files uploaded. Re-analyze to pull the latest document text.', 'success');
    }

    seedOverrides(result) {
        const seeded = {};
        (result.missingFields || []).forEach((field) => {
            seeded[field.apiName] = field.value || '';
        });
        if (result?.extractedData?.workOrderId) {
            seeded.workOrderId = result.extractedData.workOrderId;
        }
        return seeded;
    }

    get extractedRows() {
        if (!this.analysis || !this.analysis.extractedData) return [];
        return Object.entries(this.analysis.extractedData)
            .filter(([, value]) => value !== null && value !== '' && value !== undefined && value !== this.analysis.combinedPreview)
            .map(([key, value]) => ({
                key,
                keyLabel: key,
                value: typeof value === 'object' ? JSON.stringify(value) : value
            }));
    }

    get candidateRows() {
        if (!this.analysis || !this.analysis.candidates) return [];
        return this.analysis.candidates.map((row) => ({
            ...row,
            url: `/lightning/r/${row.recordId}/view`
        }));
    }

    get missingFieldRows() {
        if (!this.analysis || !this.analysis.missingFields) return [];
        return this.analysis.missingFields.map((row) => ({
            ...row,
            value: this.overrides[row.apiName] || ''
        }));
    }

    get parsedScopeItems() {
        return this.analysis?.extractedData?.parsedScopeItems || [];
    }

    get hasParsedScopeItems() {
        return this.parsedScopeItems.length > 0;
    }

    get workOrderIdValue() {
        return this.overrides.workOrderId || this.analysis?.extractedData?.workOrderId || '';
    }

    get quickQuestionRows() {
        return [
            'Upload a PO and tie it to the right builder account, community, lot, and opportunity path.',
            'Upload a new account packet and decide whether to match or create the Account, Contact, Lead, Opportunity, or Case.',
            'Upload a scope of work and turn the description into parsed Work Order items.',
            'Upload a spreadsheet and sort row-by-row exceptions instead of dumping bad data into Salesforce.',
            'Ask what fields are still missing before save, and mcLOVIN will tell you straight.'
        ];
    }

    toast(message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'mcLOVIN\'',
            message,
            variant
        }));
    }

    showError(error) {
        const message = error?.body?.message || error?.message || 'Unknown error';
        this.dispatchEvent(new ShowToastEvent({
            title: 'mcLOVIN\' Error',
            message,
            variant: 'error'
        }));
    }
}