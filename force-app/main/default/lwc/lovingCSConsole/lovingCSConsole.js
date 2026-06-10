import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getConsoleData from '@salesforce/apex/LovingCSConsoleController.getConsoleData';
import verifyPO from '@salesforce/apex/LovingCSConsoleController.verifyPO';
import nfiPO from '@salesforce/apex/LovingCSConsoleController.nfiPO';
import approvePO from '@salesforce/apex/LovingCSConsoleController.approvePO';
import escalatePO from '@salesforce/apex/LovingCSConsoleController.escalatePO';
import createPO from '@salesforce/apex/LovingCSConsoleController.createPO';
import saveQuote from '@salesforce/apex/LovingCSConsoleController.saveQuote';
import approveQuote from '@salesforce/apex/LovingCSConsoleController.approveQuote';
import rejectQuote from '@salesforce/apex/LovingCSConsoleController.rejectQuote';
import sendQuote from '@salesforce/apex/LovingCSConsoleController.sendQuote';
import warrantyDetermine from '@salesforce/apex/LovingCSConsoleController.warrantyDetermine';
import caseAddNote from '@salesforce/apex/LovingCSConsoleController.caseAddNote';
import caseResolve from '@salesforce/apex/LovingCSConsoleController.caseResolve';
import caseClose from '@salesforce/apex/LovingCSConsoleController.caseClose';
import createCase from '@salesforce/apex/LovingCSConsoleController.createCase';
import onboardBuilder from '@salesforce/apex/LovingCSConsoleController.onboardBuilder';
import createCommunity from '@salesforce/apex/LovingCSConsoleController.createCommunity';
import sendEmailMsg from '@salesforce/apex/LovingCSConsoleController.sendEmailMsg';

const PO_STAGES = ['Pending CS Review', 'NFI', 'Verified', 'Mismatch Review', 'CS Approved', 'Work Order Created'];
const WO_STAGES = ['Pending Takeoff', 'Takeoff In Progress', 'Ready to Schedule', 'Scheduled', 'In Progress',
    'Pending Closeout', 'Need Further Info (NFI)', 'Pending Approval', 'Approved', 'FM QI Review',
    'Invoiced', 'Paid'];
const TABS = [
    { key: 'home', label: 'Home' }, { key: 'pipeline', label: 'Pipeline' },
    { key: 'po', label: 'PO Intake' }, { key: 'approvals', label: 'Approvals' },
    { key: 'cases', label: 'Cases' }, { key: 'quotes', label: 'Quote Builder' },
    { key: 'warranty', label: 'Warranty' }, { key: 'fj', label: 'Finished Jobs' },
    { key: 'takeoffs', label: 'Takeoffs' }, { key: 'invoices', label: 'Invoices' },
    { key: 'reports', label: 'Reports' }, { key: 'builders', label: 'Builders' },
    { key: 'communities', label: 'Communities' }, { key: 'zones', label: 'Zone Map' },
    { key: 'knowledge', label: 'Knowledge' }
];
const PO_PILL = { 'Pending CS Review': 'amber', NFI: 'red', Verified: 'aqua',
    'Mismatch Review': 'red', 'CS Approved': 'green', 'Work Order Created': 'gray' };
const KB = [
    { id: 'KB-01', cat: 'Warranty', catCss: 'slds-badge cs-badge-aqua', title: 'Warranty coverage windows',
      body: '90-day sod, 1-year tree, and workmanship terms by builder. Warranty WOs bill nothing (BR-032): no invoice or a $0 invoice. Whether warranty damage ever bills is open question Q-010, recommended No.' },
    { id: 'KB-02', cat: 'BMG', catCss: 'slds-badge cs-badge-orange', title: 'BMG pricing validation, step by step',
      body: 'Every PO validates against the community BMG package code before approval. Compare PO unit pricing to the catalog line by line; any gap is a Price Variance mismatch. Resolution paths: builder correction, or an EPO at BMG pricing. Never approve over an open mismatch.' },
    { id: 'KB-03', cat: 'PO process', catCss: 'slds-badge slds-badge_lightest', title: 'NFI returns done right',
      body: 'NFI means Not For Install: the PO is missing something we need. Name exactly what is missing, return it, and the count increments automatically. Three NFIs on one PO is a builder-relationship conversation, not a fourth return.' },
    { id: 'KB-04', cat: 'EPO', catCss: 'slds-badge cs-badge-purple', title: 'When to raise an EPO',
      body: 'Raise an EPO when verified field scope exceeds the PO. Price at catalog, draft in the Quote Builder, route through Approvals, and send. The auto-approve ceiling is an open Section 11 decision.' },
    { id: 'KB-05', cat: 'Builders', catCss: 'slds-badge slds-badge_lightest', title: 'DR Horton invoicing requirement',
      body: 'DR Horton invoices require the Cloudscape entry-complete flag true before invoice generation fires (BR step 22). If an invoice is stuck Pending Send, check that flag first before escalating to Finance.' },
    { id: 'KB-06', cat: 'Cases', catCss: 'slds-badge slds-badge_lightest', title: 'QI failure cases and the Close gate',
      body: 'QI scores 1 to 10 with a hard floor of 9. Any item below 9 fails, creates a case here, and blocks Close. The case cannot close until re-inspection passes with every item at 9 or above. CS coordinates the builder conversation; CS does not approve QI.' }
];

export default class LovingCSConsole extends LightningElement {
    @track curTab = 'home';
    @track query = '';
    @track poFilter = 'all';
    @track terrFilter = 'all';
    @track openCaseId = null;
    @track openKbId = null;
    @track toastMsg = '';
    @track _toastKind = '';
    @track modal = null;
    @track emailCtx = {};
    @track qbLines = [];
    @track qbKind = 'Customer Care';
    @track qbLot = '';
    @track qbFromPo = null;
    @track afLog = [{ id: 1, css: 'cs-af-msg', text: 'Morning. Ask about POs, quotes, zones, warranty, or cases. I read and route; I do not approve, schedule, or touch payments.' }];
    @track busy = false;

    _wire;
    _data;
    _qbSeq = 1;
    _afSeq = 2;

    @wire(getConsoleData)
    wired(r) {
        this._wire = r;
        if (r.data) { this._data = r.data; }
        if (r.error) { this.toast('Load failed: ' + this.errMsg(r.error), 'red'); }
    }

    get d() {
        return this._data || { canEdit: false, pos: [], wos: [], quotes: [], warranty: [], fjs: [],
            cases: [], invoices: [], takeoffs: [], communities: [], builders: [], zones: [],
            catalog: [], warrantyRate: [], qiTrend: [], takeoffTime: [] };
    }
    get canEdit() { return this.d.canEdit === true; }
    get readOnly() { return !this.canEdit; }

    refresh() { return refreshApex(this._wire); }

    errMsg(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Unexpected error';
    }
    toast(msg, kind) {
        this.toastMsg = msg;
        this._toastKind = kind || '';
        clearTimeout(this._tt);
        this._tt = setTimeout(() => { this.toastMsg = ''; }, 4600);
    }
    match(hay) {
        const g = (this.query || '').toLowerCase().trim();
        return !g || (hay || '').toLowerCase().indexOf(g) > -1;
    }
    money(n) {
        if (n === null || n === undefined) return '—';
        return '$' + Number(n).toLocaleString(undefined, { maximumFractionDigits: 0 });
    }
    badgeCss(color) {
        return color === 'gray' ? 'slds-badge slds-badge_lightest' : 'slds-badge cs-badge-' + color;
    }

    // ─── toast ──────────────────────────────────────────────────────────────
    get showToast() { return !!this.toastMsg; }
    get toastCss() {
        const k = this._toastKind;
        return 'slds-notify slds-notify_toast' +
            (k === 'green' ? ' slds-theme_success' : '') +
            (k === 'red' ? ' slds-theme_error' : '') +
            (k === 'amber' ? ' slds-theme_warning' : '');
    }
    get toastIcon() {
        const k = this._toastKind;
        if (k === 'green') return 'utility:success';
        if (k === 'red') return 'utility:error';
        if (k === 'amber') return 'utility:warning';
        return 'utility:info';
    }
    dismissToast() { this.toastMsg = ''; clearTimeout(this._tt); }

    // ─── nav ────────────────────────────────────────────────────────────────
    get tabs() {
        const counts = {
            pipeline: this.d.pos.length, po: this.poNeedingAction.length,
            approvals: this.approvalItems.length, cases: this.d.cases.length,
            quotes: this.d.quotes.length, warranty: this.d.warranty.length,
            fj: this.d.fjs.length, takeoffs: this.d.takeoffs.length,
            invoices: this.d.invoices.filter(i => i.status === 'Pending Send').length,
            builders: this.d.builders.length, communities: this.d.communities.length
        };
        return TABS.map(t => ({
            ...t,
            liCss: 'slds-tabs_default__item' + (this.curTab === t.key ? ' slds-is-active' : ''),
            count: counts[t.key] !== undefined ? String(counts[t.key]) : null
        }));
    }
    handleTab(e) { this.curTab = e.currentTarget.dataset.key; }
    handleSearch(e) { this.query = e.target.value; }

    get isHome() { return this.curTab === 'home'; }
    get isPipeline() { return this.curTab === 'pipeline'; }
    get isPo() { return this.curTab === 'po'; }
    get isApprovals() { return this.curTab === 'approvals'; }
    get isCases() { return this.curTab === 'cases'; }
    get isQuotes() { return this.curTab === 'quotes'; }
    get isWarranty() { return this.curTab === 'warranty'; }
    get isFj() { return this.curTab === 'fj'; }
    get isTakeoffs() { return this.curTab === 'takeoffs'; }
    get isInvoices() { return this.curTab === 'invoices'; }
    get isReports() { return this.curTab === 'reports'; }
    get isBuilders() { return this.curTab === 'builders'; }
    get isCommunities() { return this.curTab === 'communities'; }
    get isZones() { return this.curTab === 'zones'; }
    get isKnowledge() { return this.curTab === 'knowledge'; }

    // ─── home ───────────────────────────────────────────────────────────────
    get poNeedingAction() {
        return this.d.pos.filter(p => ['Pending CS Review', 'NFI', 'Mismatch Review'].includes(p.status));
    }
    get homeKpis() {
        const pend = this.poNeedingAction.length;
        const appr = this.approvalItems.length;
        const qv = this.d.quotes.reduce((s, q) => s + (q.amount || 0), 0);
        const wOpen = this.d.warranty.filter(w => w.determinationPending).length;
        return [
            { l: 'POs pending review', v: String(pend), css: 'v' + (pend > 2 ? ' amber' : ''), s: 'Verify, NFI, or route' },
            { l: 'Approvals waiting', v: String(appr), css: 'v' + (appr > 3 ? ' red' : ' amber'), s: 'POs, quotes, warranty' },
            { l: 'Open cases', v: String(this.d.cases.length), css: 'v', s: 'QI, claims, disputes' },
            { l: 'Open quote value', v: this.money(qv), css: 'v', s: 'CC + EPO' },
            { l: 'Pipeline POs', v: String(this.d.pos.length), css: 'v', s: 'All buckets' },
            { l: 'Warranty determinations', v: String(wOpen), css: 'v', s: 'Waiting on CS' },
            { l: 'Finished Jobs open', v: String(this.d.fjs.length), css: 'v amber', s: 'No client billing' },
            { l: 'Invoices pending send', v: String(this.d.invoices.filter(i => i.status === 'Pending Send').length), css: 'v', s: 'Read-only, GP% visible' }
        ];
    }
    get homePoStages() {
        const max = Math.max(this.d.pos.length, 1);
        return PO_STAGES.map(st => {
            const n = this.d.pos.filter(p => p.status === st).length;
            return { st, n, barStyle: 'width:' + Math.min(100, (n / max) * 200) + '%' };
        });
    }
    get homeWoStages() {
        const max = Math.max(this.d.wos.length, 1);
        return WO_STAGES.filter(st => this.d.wos.some(w => w.status === st)).slice(0, 6).map(st => {
            const n = this.d.wos.filter(w => w.status === st).length;
            return { st, n, barStyle: 'width:' + Math.min(100, (n / max) * 300) + '%' };
        });
    }

    // ─── pipeline board ─────────────────────────────────────────────────────
    get poLane() {
        return PO_STAGES.map(st => {
            const cards = this.d.pos
                .filter(p => p.status === st && this.match(p.name + p.poNumber + p.builder + p.community + p.lot))
                .map(p => ({
                    ...p,
                    amountLabel: this.money(p.amount),
                    chips: [
                        p.bucket ? { id: p.id + 'b', css: this.badgeCss('gray'), label: p.bucket } : null,
                        p.nfi > 0 ? { id: p.id + 'n', css: this.badgeCss('amber'), label: 'NFI ×' + p.nfi } : null,
                        p.mismatchType && p.status === 'Mismatch Review'
                            ? { id: p.id + 'm', css: this.badgeCss('red'), label: p.mismatchType } : null
                    ].filter(Boolean)
                }));
            const sum = cards.reduce((s, c) => s + (c.amount || 0), 0);
            return { st, count: cards.length, sum: sum ? this.money(sum) : '', cards, empty: cards.length === 0 };
        });
    }
    get woLane() {
        return WO_STAGES.map(st => {
            const cards = this.d.wos
                .filter(w => w.status === st && this.match(w.name + w.community + w.lot + w.woType))
                .slice(0, 30)
                .map(w => ({
                    ...w,
                    amountLabel: w.billableType === 'Warranty (No Charge)' || w.billableType === 'FJ Internal' ? 'No charge' : '',
                    typeChip: w.woType === 'Warranty' ? { css: this.badgeCss('aqua'), label: 'Warranty' }
                        : w.woType === 'Finish Job' ? { css: this.badgeCss('purple'), label: 'FJ' } : null,
                    subChip: w.subStatus ? { css: this.badgeCss('amber'), label: w.subStatus } : null,
                    fmLabel: w.fmBlocked ? 'FM blocked (G6)' : w.fm
                }));
            return { st, stLabel: st === 'Need Further Info (NFI)' ? 'NFI' : st,
                count: cards.length, cards, empty: cards.length === 0 };
        });
    }
    handleWoCard(e) {
        const id = e.currentTarget.dataset.id;
        const wo = this.d.wos.find(w => w.id === id);
        if (!wo) return;
        if (wo.woType === 'Warranty') { this.curTab = 'warranty'; this.toast(wo.name + ' opened in the Warranty queue.', 'green'); return; }
        if (wo.woType === 'Finish Job') { this.curTab = 'fj'; this.toast(wo.name + ' opened in Finished Jobs.', 'green'); return; }
        if (wo.status === 'FM QI Review') { this.curTab = 'cases'; this.toast(wo.name + ' carries the QI hold; the case is in your queue. WO detail lives in the scheduling console.', 'amber'); return; }
        if (wo.status === 'Invoiced' || wo.status === 'Paid') { this.curTab = 'invoices'; return; }
        this.toast(wo.name + ' (' + wo.status + '): Work Order detail lives in the scheduling console. CS is read-only on field execution.', 'amber');
    }
    handlePoCard(e) {
        this.query = '';
        this.curTab = 'po';
        const id = e.currentTarget.dataset.id;
        const po = this.d.pos.find(p => p.id === id);
        if (po) { this.query = po.poNumber; }
    }

    // ─── PO intake ──────────────────────────────────────────────────────────
    get poFilterChips() {
        const mk = (k, l, n) => ({ key: k, label: l, count: String(n),
            css: 'slds-button slds-button_neutral' + (this.poFilter === k ? ' slds-button_brand' : '') });
        return [
            mk('all', 'All', this.d.pos.length),
            mk('nfi', 'NFI', this.d.pos.filter(p => p.status === 'NFI').length),
            mk('mismatch', 'Mismatch', this.d.pos.filter(p => p.status === 'Mismatch Review').length),
            mk('pending', 'Pending review', this.d.pos.filter(p => p.status === 'Pending CS Review').length)
        ];
    }
    handlePoFilter(e) { this.poFilter = e.currentTarget.dataset.key; }
    get poRows() {
        return this.d.pos.filter(p => {
            if (this.poFilter === 'nfi' && p.status !== 'NFI') return false;
            if (this.poFilter === 'mismatch' && p.status !== 'Mismatch Review') return false;
            if (this.poFilter === 'pending' && p.status !== 'Pending CS Review') return false;
            return this.match(p.name + ' ' + p.poNumber + ' ' + p.builder + ' ' + p.community + ' ' + p.lot + ' ' + p.status);
        }).map(p => ({
            ...p,
            amountLabel: this.money(p.amount),
            pillCss: this.badgeCss(PO_PILL[p.status] || 'gray'),
            noFile: !p.hasFile,
            isMismatch: p.status === 'Mismatch Review',
            isNfi: p.status === 'NFI',
            mismatchLine: p.status === 'Mismatch Review'
                ? ((p.mismatchType ? p.mismatchType + ': ' : '') + (p.mismatchNotes || 'open mismatch')) : null,
            nfiLine: p.status === 'NFI' ? ((p.nfiReason || 'Returned NFI') + ' (NFI ×' + p.nfi + ')') : null
        }));
    }
    get poRowCount() { return String(this.poRows.length); }

    handleVerify(e) { this.act(verifyPO, { poId: e.currentTarget.dataset.id }, 'Verified against the community package. It now sits in Approvals.'); }
    handleNfi(e) {
        let reason = 'Returned by CS: missing information.';
        try {
            const typed = window.prompt('What is missing? (goes to NFI_Reason__c and the builder email)');
            if (typed === null) return;
            if (typed.trim()) reason = typed.trim();
        } catch (ignore) {
            // window.prompt unavailable under LWS — fall through with the default reason
        }
        this.act(nfiPO, { poId: e.currentTarget.dataset.id, reason }, 'Returned NFI. The count incremented.');
    }
    handleApprove(e) { this.act(approvePO, { poId: e.currentTarget.dataset.id }, 'CS Approved. CS_Approved__c is set; the WO builds once all gates are green.'); }
    handleEscalate(e) {
        this.act(escalatePO, { poId: e.currentTarget.dataset.id, context: 'Escalated from the CS Console PO queue.' },
            'Escalated with full context attached and no recipient — routing is your open Section 11 decision.');
    }
    handleEpoFromPo(e) {
        const id = e.currentTarget.dataset.id;
        const po = this.d.pos.find(p => p.id === id);
        if (!po || po.status !== 'Mismatch Review') { this.toast('EPO starts from a mismatch; none open here.', 'amber'); return; }
        this.qbKind = 'EPO';
        this.qbFromPo = id;
        this.qbLot = po.lot + ' · ' + po.community;
        this.qbLines = [];
        this.addQbLine();
        this.curTab = 'quotes';
        this.toast('Quote Builder opened as an EPO for ' + po.name + '. Add the variance lines at catalog pricing; saving resolves the mismatch.', 'green');
    }

    act(fn, params, okMsg) {
        if (this.busy) return;
        this.busy = true;
        fn(params)
            .then(() => { this.toast(okMsg, 'green'); return this.refresh(); })
            .catch(err => this.toast(this.errMsg(err), 'red'))
            .finally(() => { this.busy = false; });
    }

    // ─── approvals ──────────────────────────────────────────────────────────
    get approvalItems() {
        const items = [];
        this.d.pos.forEach(p => {
            if (p.status === 'Verified') {
                items.push({ key: 'po' + p.id, kind: 'PO approval', kindCss: this.badgeCss('aqua'), id: p.id, rec: p.name,
                    desc: p.builder + ' · ' + p.lot + ' · ' + this.money(p.amount) + ' · install ' + p.install,
                    actLabel: 'Approve', rejLabel: 'Return', act: 'approvePo', rej: 'nfiPo' });
            }
            if (p.status === 'Mismatch Review') {
                items.push({ key: 'mm' + p.id, kind: 'Mismatch resolution', kindCss: this.badgeCss('red'), id: p.id, rec: p.name,
                    desc: (p.mismatchType ? p.mismatchType + ': ' : '') + (p.mismatchNotes || 'open mismatch'),
                    actLabel: 'Create EPO', rejLabel: 'Escalate', act: 'epo', rej: 'escalate' });
            }
        });
        this.d.quotes.forEach(q => {
            if (q.status === 'Draft') {
                items.push({ key: 'q' + q.id, kind: 'Quote approval', kindCss: this.badgeCss('purple'), id: q.id, rec: q.name,
                    desc: q.kind + ' · ' + q.lot + ' · ' + this.money(q.amount) + (q.gp != null ? ' · GP ' + q.gp + '%' : ''),
                    actLabel: 'Approve', rejLabel: 'Reject', act: 'approveQuote', rej: 'rejectQuote' });
            }
        });
        this.d.warranty.forEach(w => {
            if (w.determinationPending) {
                items.push({ key: 'w' + w.id, kind: 'Warranty determination', kindCss: this.badgeCss('orange'), id: w.id, rec: w.name,
                    desc: w.lot + ' · ' + w.community + (w.reason ? ' · ' + w.reason : ''),
                    actLabel: 'Approve', rejLabel: 'Deny', act: 'wApprove', rej: 'wDeny' });
            }
        });
        return items;
    }
    get approvalRows() { return this.approvalItems.filter(i => this.match(i.kind + ' ' + i.rec + ' ' + i.desc)); }
    get approvalCount() { return String(this.approvalRows.length); }
    get noApprovals() { return this.approvalRows.length === 0; }
    handleApprovalAct(e) { this.routeApproval(e.currentTarget.dataset.act, e.currentTarget.dataset.id); }
    handleApprovalRej(e) { this.routeApproval(e.currentTarget.dataset.rej, e.currentTarget.dataset.id); }
    routeApproval(action, id) {
        const fake = { currentTarget: { dataset: { id } } };
        if (action === 'approvePo') this.handleApprove(fake);
        else if (action === 'nfiPo') this.handleNfi(fake);
        else if (action === 'epo') this.handleEpoFromPo(fake);
        else if (action === 'escalate') this.handleEscalate(fake);
        else if (action === 'approveQuote') this.act(approveQuote, { quoteId: id }, 'Quote approved. Send it from Quote Builder.');
        else if (action === 'rejectQuote') this.act(rejectQuote, { quoteId: id }, 'Quote rejected.');
        else if (action === 'wApprove') this.act(warrantyDetermine, { woId: id, covered: true, note: '' }, 'Determination: Approved. No client billing (BR-032).');
        else if (action === 'wDeny') this.act(warrantyDetermine, { woId: id, covered: false, note: '' }, 'Determination: Denied as warranty. Draft a Customer Care quote if the client wants the work billable.');
    }

    // ─── cases ──────────────────────────────────────────────────────────────
    get caseRows() {
        return this.d.cases
            .filter(c => this.match(c.name + ' ' + c.subject + ' ' + c.account + ' ' + c.lot))
            .map(c => ({
                ...c,
                liCss: 'slds-accordion__list-item' + (this.openCaseId === c.id ? ' slds-is-open' : ''),
                expanded: this.openCaseId === c.id,
                noteLines: (c.notes || '').split('\n').filter(Boolean).map((x, i) => ({ id: c.id + 'n' + i, text: x })),
                statusLabel: c.status + (c.subStatus ? ' · ' + c.subStatus : '')
            }));
    }
    handleToggleCase(e) {
        const id = e.currentTarget.dataset.id;
        this.openCaseId = this.openCaseId === id ? null : id;
    }
    handleCaseNote(e) {
        const id = e.currentTarget.dataset.id;
        const ta = this.template.querySelector('lightning-textarea[data-note="' + id + '"]');
        const v = ta ? ta.value.trim() : '';
        if (!v) { this.toast('Type the note first.', 'amber'); return; }
        this.act(caseAddNote, { woId: id, note: v }, 'Note added.');
    }
    handleCaseResolve(e) { this.act(caseResolve, { woId: e.currentTarget.dataset.id }, 'Resolved.'); }
    handleCaseClose(e) { this.act(caseClose, { woId: e.currentTarget.dataset.id }, 'Closed.'); }

    // ─── quote builder ──────────────────────────────────────────────────────
    get catalogOptions() { return this.d.catalog; }
    get qbKindCss() { return this.qbKind === 'EPO' ? 'slds-badge cs-badge-orange' : 'slds-badge cs-badge-purple'; }
    get qbLineRows() {
        return this.qbLines.map(l => ({ ...l, lineTotal: this.money(l.qty * l.price),
            options: this.d.catalog.map(c => ({ ...c, selected: c.id === l.catalogId })) }));
    }
    get qbTotals() {
        let rev = 0, cost = 0;
        this.qbLines.forEach(l => { rev += (l.qty || 0) * (l.price || 0); cost += (l.qty || 0) * (l.cost || 0); });
        const gp = rev > 0 ? Math.round(((rev - cost) / rev) * 100) : 0;
        return { rev: this.money(rev), cost: this.money(cost), gp,
            gpStyle: 'color:' + (gp >= 30 ? '#13854e' : '#b27508') };
    }
    addQbLine() {
        const first = this.d.catalog[0] || { id: null, name: '', price: 0, cost: 0 };
        this.qbLines = [...this.qbLines, { id: this._qbSeq++, catalogId: first.id,
            name: first.name, qty: 1, price: first.price, cost: first.cost }];
    }
    handleQbAdd() { this.addQbLine(); }
    handleQbRemove(e) {
        const id = Number(e.currentTarget.dataset.id);
        this.qbLines = this.qbLines.filter(l => l.id !== id);
    }
    handleQbItem(e) {
        const id = Number(e.currentTarget.dataset.id);
        const cat = this.d.catalog.find(c => c.id === e.target.value);
        this.qbLines = this.qbLines.map(l => l.id === id && cat
            ? { ...l, catalogId: cat.id, name: cat.name, price: cat.price, cost: cat.cost } : l);
    }
    handleQbQty(e) {
        const id = Number(e.currentTarget.dataset.id);
        const v = Math.max(0, Number(e.target.value) || 0);
        this.qbLines = this.qbLines.map(l => l.id === id ? { ...l, qty: v } : l);
    }
    handleQbPrice(e) {
        const id = Number(e.currentTarget.dataset.id);
        const v = Math.max(0, Number(e.target.value) || 0);
        this.qbLines = this.qbLines.map(l => l.id === id ? { ...l, price: v } : l);
    }
    handleQbKind(e) { this.qbKind = e.detail.value; }
    handleQbLot(e) { this.qbLot = e.detail.value; }
    handleQbStartEpo() {
        this.qbKind = 'EPO'; this.qbFromPo = null; this.qbLot = ''; this.qbLines = [];
        this.curTab = 'quotes';
        this.toast('Quote Builder switched to EPO. Pick the lot and add the variance lines at catalog pricing.', 'green');
    }
    handleQbSave() {
        if (!this.qbLines.length) { this.toast('Add at least one line before saving the quote.', 'amber'); return; }
        if (!this.qbLot.trim()) { this.toast('Pick the lot or client this quote belongs to.', 'amber'); return; }
        const payload = JSON.stringify({
            fromPoId: this.qbKind === 'EPO' ? this.qbFromPo : null,
            lotText: this.qbLot,
            lines: this.qbLines.map(l => ({ name: l.name, qty: l.qty, price: l.price, cost: l.cost, catalogId: l.catalogId }))
        });
        this.busy = true;
        saveQuote({ payload })
            .then(name => {
                const was = this.qbFromPo;
                this.qbLines = []; this.qbLot = ''; this.qbFromPo = null; this.qbKind = 'Customer Care';
                this.toast(name + ' saved and routed to Approvals.' + (was ? ' Mismatch marked resolved.' : ''), 'green');
                return this.refresh();
            })
            .catch(err => this.toast(this.errMsg(err), 'red'))
            .finally(() => { this.busy = false; });
    }
    get quoteRows() {
        return this.d.quotes.filter(q => this.match(q.name + ' ' + q.kind + ' ' + q.lot + ' ' + q.status))
            .map(q => ({ ...q,
                amountLabel: this.money(q.amount),
                gpLabel: q.gp == null ? '·' : q.gp + '%',
                daysLabel: q.days == null ? '·' : String(q.days),
                kindCss: this.badgeCss(q.kind === 'EPO' ? 'orange' : 'purple'),
                statusCss: this.badgeCss(q.status === 'Approved' ? 'green' : q.status === 'Draft' ? 'amber' : q.status === 'Rejected' ? 'red' : 'aqua'),
                statusLabel: q.status === 'Draft' ? 'Pending Approval' : q.status,
                canSend: q.status === 'Approved' }));
    }
    get quoteCount() { return String(this.d.quotes.length); }
    handleSendQuote(e) { this.act(sendQuote, { quoteId: e.currentTarget.dataset.id }, 'Sent. Days-open clock runs until acknowledged.'); }

    // ─── warranty + fj ──────────────────────────────────────────────────────
    get warrantyRows() {
        return this.d.warranty.filter(w => this.match(w.name + ' ' + w.lot + ' ' + w.community + ' ' + (w.reason || '')))
            .map(w => ({ ...w,
                fmLabel: w.fmBlocked ? null : w.fm,
                determination: w.determinationPending ? null : (w.coverage || 'Determined'),
                detCss: this.badgeCss('green') }));
    }
    get warrantyCount() { return String(this.warrantyRows.length); }
    handleWApprove(e) { this.act(warrantyDetermine, { woId: e.currentTarget.dataset.id, covered: true, note: '' }, 'Determination: Approved. No client billing (BR-032).'); }
    handleWDeny(e) { this.act(warrantyDetermine, { woId: e.currentTarget.dataset.id, covered: false, note: '' }, 'Determination: Denied as warranty.'); }
    get fjRows() {
        return this.d.fjs.filter(w => this.match(w.name + ' ' + w.lot + ' ' + w.community + ' ' + (w.reason || '')));
    }
    get fjCount() { return String(this.fjRows.length); }

    // ─── takeoffs / invoices ────────────────────────────────────────────────
    get takeoffRows() {
        return this.d.takeoffs.filter(t => this.match(t.name + ' ' + t.lot + ' ' + t.community + ' ' + t.status + ' ' + t.po))
            .map(t => ({ ...t,
                statusCss: this.badgeCss(t.status === 'Approved' ? 'green' : t.status === 'Returned' ? 'amber' : t.status === 'In Progress' ? 'gray' : 'aqua') }));
    }
    get takeoffCount() { return String(this.takeoffRows.length); }
    get invoiceRows() {
        return this.d.invoices.filter(i => this.match(i.name + ' ' + i.builder + ' ' + i.lot + ' ' + i.status + ' ' + i.wo))
            .map(i => ({ ...i,
                amountLabel: this.money(i.amount),
                gpLabel: i.gp == null ? '·' : Number(i.gp).toFixed(0) + '%',
                gpStyle: 'color:' + (i.gp >= 35 ? '#13854e' : i.gp > 0 ? '#b27508' : '#7d8696'),
                statusCss: this.badgeCss(i.status === 'Paid' ? 'green' : i.status === 'Sent' ? 'aqua' : 'amber'),
                typeCss: this.badgeCss(i.invType === 'Standard' ? 'gray' : 'aqua') }));
    }
    get invoiceCount() { return String(this.invoiceRows.length); }
    handleCloudscape(e) {
        const inv = this.d.invoices.find(i => i.id === e.currentTarget.dataset.id);
        if (!inv) return;
        this.toast(inv.name + ' is held because the Cloudscape entry-complete flag is false on ' + inv.wo
            + '. It will not send until the Cloudscape entry is completed (BR step 22). Route to the CSM owning the DR Horton entry, not to Finance.', 'amber');
    }

    // ─── reports ────────────────────────────────────────────────────────────
    get rptPoAging() {
        return [...this.d.pos]
            .map(p => ({ id: p.id, c1: p.poNumber, c2: p.builder, c3: p.received, c4: p.status }))
            .slice(0, 25);
    }
    get rptNfiRate() {
        const by = {};
        this.d.pos.forEach(p => {
            const b = p.builder || '—';
            by[b] = by[b] || { po: 0, nfi: 0 };
            by[b].po++; by[b].nfi += (p.nfi || 0);
        });
        return Object.keys(by).map(b => ({ id: b, c1: b, c2: String(by[b].po), c3: String(by[b].nfi),
            c4: Math.round((by[b].nfi / by[b].po) * 100) + '%' }));
    }
    get rptEpoTracker() {
        return this.d.quotes.filter(q => q.kind === 'EPO')
            .map(q => ({ id: q.id, c1: q.name, c2: q.lot, c3: this.money(q.amount),
                c4: (q.status === 'Draft' ? 'Pending Approval' : q.status) + (q.days != null ? ' · ' + q.days + 'd' : '') }));
    }
    get rptWarrantyRate() { return this.d.warrantyRate.map((r, i) => ({ id: 'wr' + i, ...r })); }
    get rptQiTrend() { return this.d.qiTrend.map((r, i) => ({ id: 'qi' + i, ...r })); }
    get rptTakeoffTime() { return this.d.takeoffTime.map((r, i) => ({ id: 'tk' + i, ...r })); }

    // ─── builders / communities / zones / knowledge ─────────────────────────
    get builderRows() { return this.d.builders.filter(b => this.match(b.name)); }
    get builderCount() { return String(this.builderRows.length); }
    handleBuilderComms(e) {
        this.query = e.currentTarget.dataset.name || '';
        this.curTab = 'communities';
    }
    get terrChips() {
        const terrs = ['all', ...new Set(this.d.communities.map(c => c.territory).filter(t => t && t !== '—'))];
        return terrs.slice(0, 8).map(t => ({ key: t, label: t === 'all' ? 'All territories' : t,
            css: 'slds-button slds-button_neutral' + (this.terrFilter === t ? ' slds-button_brand' : '') }));
    }
    handleTerrFilter(e) { this.terrFilter = e.currentTarget.dataset.key; }
    get communityRows() {
        return this.d.communities
            .filter(c => (this.terrFilter === 'all' || c.territory === this.terrFilter)
                && this.match(c.name + ' ' + c.division + ' ' + c.territory + ' ' + c.bmg))
            .slice(0, 150)
            .map(c => ({ ...c, lotsLabel: c.lots == null ? '·' : String(c.lots),
                fmLabel: c.fmBlocked ? null : (c.fm || '—') }));
    }
    get communityCount() { return String(this.communityRows.length); }
    get zoneRows() {
        return this.d.zones.map(z => ({ ...z,
            label: 'Zone ' + z.zone,
            fmLabel: z.blocked ? null : (z.fm || '—'),
            comms: z.communities || 'No active communities' }));
    }
    get kbRows() {
        return KB.filter(k => this.match(k.title + ' ' + k.cat + ' ' + k.body))
            .map(k => ({ ...k, liCss: 'slds-accordion__list-item' + (this.openKbId === k.id ? ' slds-is-open' : ''),
                expanded: this.openKbId === k.id }));
    }
    handleToggleKb(e) {
        const id = e.currentTarget.dataset.id;
        this.openKbId = this.openKbId === id ? null : id;
    }

    // ─── modals ─────────────────────────────────────────────────────────────
    get showNewPo() { return this.modal === 'newpo'; }
    get showNewCase() { return this.modal === 'newcase'; }
    get showNewComm() { return this.modal === 'newcomm'; }
    get showOnboard() { return this.modal === 'onboard'; }
    get showEmail() { return this.modal === 'email'; }
    get anyModal() { return this.modal !== null; }
    handleOpenNewPo() { this.modal = 'newpo'; }
    handleOpenNewCase() { this.modal = 'newcase'; }
    handleOpenNewComm() { this.modal = 'newcomm'; }
    handleOpenOnboard() { this.modal = 'onboard'; }
    handleCloseModal() { this.modal = null; }
    stopProp(e) { e.stopPropagation(); }

    val(sel) {
        const el = this.template.querySelector(sel);
        return el ? el.value : '';
    }
    handleCreatePo() {
        const payload = JSON.stringify({
            poNumber: this.val('[data-f="npNum"]').trim(),
            amount: Number(this.val('[data-f="npAmt"]')) || null,
            installDate: this.val('[data-f="npDate"]'),
            communityId: this.val('[data-f="npComm"]')
        });
        this.busy = true;
        createPO({ payload })
            .then(() => { this.modal = null; this.curTab = 'po';
                this.toast('PO created as Pending CS Review.', 'green'); return this.refresh(); })
            .catch(err => this.toast(this.errMsg(err), 'red'))
            .finally(() => { this.busy = false; });
    }
    handleCreateCase() {
        const payload = JSON.stringify({
            subject: this.val('[data-f="ncSubj"]').trim(),
            communityId: this.val('[data-f="ncComm"]') || null,
            lotText: this.val('[data-f="ncLot"]').trim(),
            origin: this.val('[data-f="ncOrigin"]'),
            note: this.val('[data-f="ncNote"]').trim()
        });
        this.busy = true;
        createCase({ payload })
            .then(() => { this.modal = null; this.curTab = 'cases';
                this.toast('Case created and assigned to you.', 'green'); return this.refresh(); })
            .catch(err => this.toast(this.errMsg(err), 'red'))
            .finally(() => { this.busy = false; });
    }
    handleOnboardBuilder() {
        const name = this.val('[data-f="nbName"]').trim();
        this.busy = true;
        onboardBuilder({ divisionName: name })
            .then(() => { this.modal = null; this.curTab = 'builders';
                this.toast(name + ' onboarded. Add its first community next.', 'green'); return this.refresh(); })
            .catch(err => this.toast(this.errMsg(err), 'red'))
            .finally(() => { this.busy = false; });
    }
    handleCreateCommunity() {
        const payload = JSON.stringify({
            name: this.val('[data-f="ncName"]').trim(),
            builderAccountId: this.val('[data-f="ncDiv"]') || null,
            territory: this.val('[data-f="ncTerr"]').trim(),
            bmg: this.val('[data-f="ncBmg"]').trim(),
            aqua: this.template.querySelector('[data-f="ncAqua"]')?.checked === true
        });
        this.busy = true;
        createCommunity({ payload })
            .then(() => { this.modal = null; this.curTab = 'communities';
                this.toast('Community created. FM assignment stays unassigned until Ops provides the zone name (G6).', 'green');
                return this.refresh(); })
            .catch(err => this.toast(this.errMsg(err), 'red'))
            .finally(() => { this.busy = false; });
    }

    // ─── email ───────────────────────────────────────────────────────────────
    get emailTemplates() {
        return [
            { key: '', label: 'No template' },
            { key: 'nfi', label: 'NFI notification' },
            { key: 'epo', label: 'EPO cover' },
            { key: 'warranty', label: 'Warranty determination' },
            { key: 'update', label: 'General update' }
        ];
    }
    get emailTemplateOptions() {
        return this.emailTemplates.map(t => ({ label: t.label, value: t.key }));
    }
    handleOpenEmail(e) {
        const id = e.currentTarget.dataset.id;
        const kind = e.currentTarget.dataset.kind;
        let lot = '', label = id;
        if (kind === 'po') {
            const p = this.d.pos.find(x => x.id === id);
            if (p) { lot = p.lot + ' · ' + p.community; label = p.name; }
        } else {
            const c = this.d.cases.find(x => x.id === id);
            if (c) { lot = c.lot; label = c.name; }
        }
        this.emailCtx = { recordId: id, lot, label };
        this.modal = 'email';
    }
    handleEmailTpl(e) {
        const k = e.detail.value;
        if (!k) return;
        const lot = this.emailCtx.lot || '';
        const id = this.emailCtx.label || '';
        const T = {
            nfi: { s: id + ' returned: information needed before install',
                b: 'Hi,\n\nWe reviewed ' + id + ' for ' + lot + ' and need the following before it can move to install: \n\nOnce resubmitted, review completes same day.\n\nThank you,\nLOVING Customer Success' },
            epo: { s: 'EPO for ' + lot + ': field-verified scope above the PO',
                b: 'Hi,\n\nField verification on ' + lot + ' found scope above the PO. The attached EPO is priced at your package rates.\n\nReply to acknowledge and we will keep your install date.\n\nThank you,\nLOVING Customer Success' },
            warranty: { s: 'Warranty determination for ' + lot,
                b: 'Hi,\n\nWe completed the warranty review for ' + lot + '. Determination: covered under warranty. The corrective visit is being scheduled at no charge.\n\nThank you,\nLOVING Customer Success' },
            update: { s: 'Update on ' + lot, b: 'Hi,\n\nQuick update on ' + lot + ': ' }
        }[k];
        if (!T) return;
        const sub = this.template.querySelector('[data-f="emSub"]');
        const body = this.template.querySelector('[data-f="emBody"]');
        if (sub) sub.value = T.s;
        if (body) body.value = T.b;
    }
    handleSendEmail() {
        const payload = JSON.stringify({
            toAddress: this.val('[data-f="emTo"]').trim(),
            subject: this.val('[data-f="emSub"]').trim(),
            body: this.val('[data-f="emBody"]').trim(),
            recordId: this.emailCtx.recordId
        });
        this.busy = true;
        sendEmailMsg({ payload })
            .then(() => { this.modal = null;
                this.toast('Email sent and logged to the record.', 'green'); return this.refresh(); })
            .catch(err => this.toast(this.errMsg(err), 'red'))
            .finally(() => { this.busy = false; });
    }

    // ─── modal combobox options ───────────────────────────────────────────────
    get communityOptions() {
        return this.d.communities.map(c => ({ label: c.name, value: c.id }));
    }
    get communityOptionsOptional() {
        return [{ label: '—', value: '' }, ...this.communityOptions];
    }
    get builderOptions() {
        return this.d.builders.map(b => ({ label: b.name, value: b.id }));
    }
    get originOptions() {
        return [
            { label: 'Builder call', value: 'Builder call' },
            { label: 'Email', value: 'Email' },
            { label: 'Portal', value: 'Portal' },
            { label: 'Other', value: 'Other' }
        ];
    }
    get quoteKindOptions() {
        return [
            { label: 'Customer Care', value: 'Customer Care' },
            { label: 'EPO', value: 'EPO' }
        ];
    }

    // ─── agentforce (read & route only) ─────────────────────────────────────
    get afChips() {
        return [
            { key: 'what needs my approval', label: 'What needs my approval' },
            { key: 'show the mismatch', label: 'Show the mismatch' },
            { key: 'zone status', label: 'Zone status' },
            { key: 'warranty', label: 'Warranty queue' }
        ];
    }
    handleAfChip(e) { this.afAsk(e.currentTarget.dataset.key); }
    handleAfKey(e) {
        if (e.key === 'Enter') { this.afAsk(e.target.value); e.target.value = ''; }
    }
    handleAfAsk() {
        const inp = this.template.querySelector('[data-f="afInput"]');
        if (inp && inp.value.trim()) { this.afAsk(inp.value.trim()); inp.value = ''; }
    }
    afAsk(q) {
        const l = q.toLowerCase();
        let a;
        const mm = this.d.pos.filter(p => p.status === 'Mismatch Review');
        if (l.includes('mismatch')) {
            a = mm.length
                ? mm[0].name + ': ' + (mm[0].mismatchType || 'mismatch') + '. ' + (mm[0].mismatchNotes || '') + ' Resolve with a builder correction or an EPO.'
                : 'No open mismatches right now.';
        } else if (l.includes('approval')) {
            a = this.approvalItems.length + ' item(s) waiting on you: '
                + this.approvalItems.slice(0, 3).map(i => i.kind + ' ' + i.rec).join('; ') + '.';
        } else if (l.includes('zone') || l.includes('fm')) {
            a = 'Zones 1, 3, and 4 are BLOCKED pending Ops per gate G6 — I will not guess names on blocked zones. '
                + this.d.zones.filter(z => !z.blocked && z.fm).map(z => 'Zone ' + z.zone + ': ' + z.fm).join('; ');
        } else if (l.includes('warrant')) {
            const open = this.d.warranty.filter(w => w.determinationPending);
            a = open.length + ' warranty determination(s) open. Warranty bills nothing per BR-032.';
        } else if (l.includes('po') || l.includes('review')) {
            a = this.poNeedingAction.length + ' POs need attention: '
                + this.d.pos.filter(p => p.status === 'Pending CS Review').length + ' pending review, '
                + this.d.pos.filter(p => p.status === 'NFI').length + ' NFI, '
                + mm.length + ' in mismatch.';
        } else {
            a = 'I read and route across this console: POs, pipeline, approvals, cases, quotes, warranty, FJ, zones. I do not approve, schedule, or touch payments.';
        }
        this.afLog = [...this.afLog,
            { id: this._afSeq++, css: 'cs-af-msg user', text: q },
            { id: this._afSeq++, css: 'cs-af-msg', text: a }].slice(-6);
    }

    get alerts() {
        const out = [];
        this.d.pos.filter(p => p.status === 'Mismatch Review').slice(0, 2).forEach(p =>
            out.push({ id: 'al' + p.id, css: 'cs-alert cs-alert-red', icon: 'utility:error', title: 'PO mismatch open',
                text: p.name + ' (' + p.lot + '): ' + (p.mismatchType || 'mismatch') + '. Resolve via correction or EPO.' }));
        this.d.pos.filter(p => p.status === 'NFI').slice(0, 1).forEach(p =>
            out.push({ id: 'al' + p.id, css: 'cs-alert cs-alert-amber', icon: 'utility:warning', title: 'NFI PO returned',
                text: p.name + ' returned (NFI ×' + p.nfi + ').' }));
        this.d.warranty.filter(w => w.determinationPending).slice(0, 1).forEach(w =>
            out.push({ id: 'al' + w.id, css: 'cs-alert cs-alert-aqua', icon: 'utility:info', title: 'Warranty determination waiting',
                text: w.name + ' · ' + w.lot + ' · ' + w.community }));
        return out;
    }
}
