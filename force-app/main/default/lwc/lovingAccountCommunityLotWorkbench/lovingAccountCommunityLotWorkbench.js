import { LightningElement, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import FIRST_NAME from '@salesforce/schema/User.FirstName';
import LAST_NAME from '@salesforce/schema/User.LastName';
import getWorkbenchData from '@salesforce/apex/AccountCommunityLotWorkbenchController.getWorkbenchData';

let DB = { builders: [], divisions: [], communities: [], lots: [] };

const COMM_STAGES = ['Site Assessment','Contract Executed','HOA Setup','Active Selling','Fully Sold','Closed Out'];
const INLINE_CSS  = `<style>
*{box-sizing:border-box;margin:0;padding:0}
body,div{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;font-size:13px;color:#16325c}
.tc{display:none}.tc.on{display:block}
.hier-strip{background:#16325c;color:#fff;padding:6px 20px;display:flex;align-items:center;gap:8px;font-size:11px;flex-wrap:wrap}
.hier-link{color:rgba(255,255,255,.85);cursor:pointer;padding:2px 8px;border-radius:3px}.hier-link:hover{background:rgba(255,255,255,.15)}
.hier-link.cur{background:rgba(255,255,255,.2);color:#fff;font-weight:500}.hier-sep{color:rgba(255,255,255,.4)}
.hier-label{color:rgba(255,255,255,.5);text-transform:uppercase;letter-spacing:.4px;font-weight:500;font-size:9px}
.rec-header{background:#fff;padding:14px 20px 0;border-bottom:1px solid #e5e5e5}
.rec-top-row{display:flex;align-items:center;gap:12px;padding-bottom:12px}
.rec-icon{width:38px;height:38px;border-radius:6px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:15px;font-weight:700;flex-shrink:0}
.rec-title-block{flex:1;min-width:0}
.rec-breadcrumb{font-size:11px;color:#54698d;margin-bottom:2px}.rec-breadcrumb a{color:#0070d2;cursor:pointer}
.rec-title{font-size:18px;font-weight:500;color:#16325c;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.rec-actions{display:flex;gap:6px;flex-wrap:wrap}
.highlights{background:#fafaf9;border-bottom:1px solid #e5e5e5;padding:12px 20px;display:grid;grid-template-columns:repeat(6,1fr);gap:14px}
.hl-label{font-size:10px;color:#54698d;text-transform:uppercase;letter-spacing:.4px;font-weight:500;margin-bottom:3px}
.hl-value{font-size:13px;font-weight:500;color:#16325c;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.hl-value.green{color:#2e844a}.hl-value.amber{color:#ba7517}
.stage-path{display:flex;background:#f4f6f9;border-bottom:1px solid #e5e5e5;overflow-x:auto}
.stage-step{flex:1;min-width:90px;padding:9px 8px 9px 20px;font-size:10px;font-weight:500;color:#54698d;cursor:pointer;text-align:center;clip-path:polygon(0 0,calc(100% - 10px) 0,100% 50%,calc(100% - 10px) 100%,0 100%,10px 50%);margin-right:1px}
.stage-step:first-child{clip-path:polygon(0 0,calc(100% - 10px) 0,100% 50%,calc(100% - 10px) 100%,0 100%);padding-left:14px}
.stage-step.done{background:#e8f5e9;color:#2e7d32}.stage-step.current{background:#534ab7;color:#fff}.stage-step.future{background:#f4f6f9;color:#c8cdd6}
.subtabs{background:#fff;padding:0 20px;height:38px;display:flex;align-items:center;border-bottom:1px solid #e5e5e5;overflow-x:auto}
.subtab{padding:9px 16px;font-size:12px;color:#181818;cursor:pointer;border-bottom:3px solid transparent;height:38px;display:flex;align-items:center;gap:6px;white-space:nowrap}
.subtab.on{color:#0070d2;border-bottom-color:#0070d2;font-weight:500}.subtab:hover:not(.on){background:#f4f6f9}
.sub-tc{display:none}.sub-tc.on{display:block}
.sf-btn{background:#fff;border:1px solid #d8dde6;border-radius:4px;padding:5px 12px;font-size:12px;color:#16325c;cursor:pointer;white-space:nowrap}
.sf-btn:hover{background:#f4f6f9}.sf-btn.primary{background:#0070d2;border-color:#0070d2;color:#fff}
.sf-body{padding:14px 20px}
.opp-layout{display:grid;grid-template-columns:1fr 340px;gap:0;border-top:1px solid #e5e5e5;background:#fff}
.opp-main{padding:16px 20px;border-right:1px solid #e5e5e5;min-width:0}
.opp-rail{min-width:0;background:#fff}
.sec-header{display:flex;align-items:center;gap:8px;padding:10px 0 8px;border-bottom:1px solid #e5e5e5;margin-bottom:12px;cursor:pointer;user-select:none}
.sec-toggle{font-size:11px;color:#54698d;width:16px;text-align:center;transition:transform .2s;display:inline-block}
.sec-toggle.open{transform:rotate(90deg)}.sec-title{font-size:13px;font-weight:600;color:#16325c}
.sec-body{display:grid;grid-template-columns:1fr 1fr;gap:10px 28px;margin-bottom:20px}
.sec-body.hidden{display:none!important}
.opp-field{display:flex;flex-direction:column;padding:4px 0;border-bottom:1px solid #f4f6f9}
.opp-label{font-size:10px;color:#54698d;text-transform:uppercase;letter-spacing:.4px;font-weight:500;margin-bottom:2px}
.opp-value{font-size:12px;color:#16325c;min-height:18px;line-height:1.4}.opp-value a{color:#0070d2;cursor:pointer}
.editable{cursor:pointer;border-bottom:1px dashed transparent;transition:border-color .15s}
.editable:hover{border-bottom-color:#0070d2;color:#0070d2}
.edit-input,.edit-select{width:100%;font-size:12px;padding:2px 6px;border:1px solid #0070d2;border-radius:3px;outline:none;color:#16325c;background:#fff}
.act-panel{display:flex;flex-direction:column;min-height:400px}
.act-actions{display:flex;gap:1px;border-bottom:1px solid #e5e5e5;background:#f4f6f9}
.act-btn{flex:1;padding:9px 6px;font-size:11px;font-weight:500;color:#0070d2;background:#fff;border:none;border-right:1px solid #e5e5e5;cursor:pointer;text-align:center;display:flex;flex-direction:column;align-items:center;gap:3px}
.act-btn:last-child{border-right:none}.act-btn:hover{background:#f4f6f9}.act-btn-icon{font-size:14px}
.act-feed{padding:0 14px;flex:1}
.act-section-hdr{font-size:10px;font-weight:600;color:#54698d;text-transform:uppercase;letter-spacing:.5px;padding:12px 0 6px;border-bottom:1px solid #e5e5e5;margin-bottom:2px}
.act-item{display:flex;gap:10px;padding:10px 0;border-bottom:1px solid #f4f6f9;cursor:pointer}
.act-item:last-child{border-bottom:none}
.act-dot-col{display:flex;flex-direction:column;align-items:center;padding-top:2px;width:14px;flex-shrink:0}
.act-dot{width:10px;height:10px;border-radius:50%;flex-shrink:0}
.act-dot.task{background:#534ab7}.act-dot.call{background:#0070d2}.act-dot.event{background:#04844b}.act-dot.past{background:#d8dde6}.act-dot.overdue{background:#c23934}
.act-connector{width:1px;background:#e5e5e5;flex:1;margin-top:3px}
.act-body{flex:1;min-width:0}.act-title{font-size:12px;font-weight:500;color:#16325c;line-height:1.3}
.act-sub{font-size:11px;color:#54698d;margin-top:2px}.act-date{font-size:10px;color:#54698d;white-space:nowrap;padding-top:2px}
.act-overdue{color:#c23934;font-weight:500}
.act-refresh{padding:8px 14px;text-align:center;font-size:11px;color:#0070d2;cursor:pointer;border-top:1px solid #e5e5e5}
.layout{display:grid;grid-template-columns:1fr 300px;gap:14px}
.layout-main{min-width:0}.layout-rail{min-width:0}
.card{background:#fff;border:1px solid #d8dde6;border-radius:6px;overflow:hidden;margin-bottom:14px;box-shadow:0 1px 0 rgba(0,0,0,.04)}
.card.last{margin-bottom:0}.card.info{border-left:4px solid #0070d2}
.ch{padding:10px 14px;border-bottom:1px solid #e5e5e5;display:flex;align-items:center;gap:8px;background:#fafaf9}
.ch h3{font-size:13px;font-weight:500;color:#16325c;flex:1}
.ci{width:20px;height:20px;border-radius:3px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:10px;font-weight:700;flex-shrink:0}
.ch-link{font-size:11px;color:#0070d2;cursor:pointer}.fields-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px 24px;padding:12px 14px}
.field-row{display:flex;flex-direction:column}
.field-label{font-size:10px;color:#54698d;text-transform:uppercase;letter-spacing:.4px;font-weight:500;margin-bottom:3px}
.field-value{font-size:12px;color:#16325c;min-height:18px}.field-value a{color:#0070d2;cursor:pointer}
.tbl{width:100%;border-collapse:collapse;font-size:11px}
.tbl th{text-align:left;font-size:10px;font-weight:500;color:#54698d;padding:8px 12px;border-bottom:1px solid #e5e5e5;text-transform:uppercase;letter-spacing:.4px;background:#fafaf9;white-space:nowrap}
.tbl td{padding:8px 12px;border-bottom:1px solid #f0f0f0;vertical-align:middle}.tbl tr:last-child td{border-bottom:none}
.tbl tr:hover td{background:#f4f6f9}.tbl th.num,.tbl td.num{text-align:right}
.nl{color:#0070d2;font-weight:500;cursor:pointer}
.chip{display:inline-flex;font-size:10px;padding:2px 7px;border-radius:4px;align-items:center;gap:3px;white-space:nowrap}
.cg{background:#e8f5e9;color:#2e7d32}.cr{background:#fce8e8;color:#991b1b}.ca{background:#fef3c7;color:#92400e}
.cb2{background:#e3f0fb;color:#0c447c}.cp{background:#ede9fe;color:#5b21b6}.cgr{background:#f4f6f9;color:#54698d}
.pipeline-badge{display:inline-flex;align-items:center;padding:3px 9px;border-radius:12px;font-size:10px;font-weight:500;gap:4px}
.pb-90{background:#f4f6f9;color:#54698d;border:1px solid #d8dde6}.pb-60{background:#e3f0fb;color:#0c447c;border:1px solid #b5d4f4}
.pb-31{background:#fef3c7;color:#92400e;border:1px solid #f9c725}.pb-30{background:#fce8e8;color:#991b1b;border:1px solid #f09595}
.pb-takeoff{background:#ede9fe;color:#5b21b6;border:1px solid #c5bef7}.pb-clear{background:#e8f5e9;color:#2e7d32;border:1px solid #a5d6a7}
.pb-sched{background:#e3f0fb;color:#0070d2;border:1px solid #b5d4f4}.pb-active{background:#534ab7;color:#fff;border:1px solid #534ab7}
.pb-closed{background:#f4f6f9;color:#54698d;border:1px solid #d8dde6}
.list-toolbar{background:#fff;padding:10px 20px;border-bottom:1px solid #e5e5e5;display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.filter-chip{background:#f4f6f9;border:1px solid #d8dde6;border-radius:12px;padding:3px 10px;font-size:11px;color:#16325c;cursor:pointer;user-select:none}
.filter-chip.on{background:#534ab7;color:#fff;border-color:#534ab7}
.list-search{background:#fff;border:1px solid #d8dde6;border-radius:4px;padding:5px 10px;font-size:12px;color:#16325c;flex:1;max-width:280px}
.list-select{background:#fff;border:1px solid #d8dde6;border-radius:4px;padding:5px 10px;font-size:12px;color:#16325c}
.refresh-row{display:flex;align-items:center;gap:8px;padding:7px 20px;background:#fafaf9;border-bottom:1px solid #e5e5e5;font-size:11px;color:#54698d}
.refresh-btn{background:#fff;border:1px solid #d8dde6;border-radius:4px;padding:3px 10px;font-size:11px;color:#0070d2;cursor:pointer}
.lot-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(56px,1fr));gap:8px;padding:14px}
.lot-tile{padding:10px 4px;text-align:center;border-radius:5px;border:2px solid;font-size:11px;font-weight:500;cursor:pointer}
.lot-tile.in-prog{background:#ede9fe;border-color:#c5bef7;color:#534ab7}.lot-tile.scheduled{background:#e3f0fb;border-color:#b5d4f4;color:#0c447c}
.lot-tile.pending{background:#fef3c7;border-color:#f9c725;color:#92400e}.lot-tile.available{background:#f4f6f9;border-color:#e5e5e5;color:#54698d}
.lot-tile.closed{background:#e8f5e9;border-color:#a5d6a7;color:#54698d;opacity:.55}.lot-tile:hover{opacity:.8}
.legend{display:flex;gap:12px;flex-wrap:wrap;padding:8px 14px;border-top:1px solid #f0f0f0;font-size:10px;color:#54698d}
.legend-item{display:flex;align-items:center;gap:5px}.legend-sw{width:12px;height:12px;border-radius:2px;border:2px solid}
.hier-tree{padding:8px 14px}
.hier-node{display:flex;align-items:center;gap:8px;padding:5px 0;font-size:12px;border-bottom:1px solid #f4f6f9;cursor:pointer}
.hier-bullet{width:8px;height:8px;border-radius:50%;flex-shrink:0}
.hier-node.lvl0 .hier-bullet{background:#16325c}.hier-node.lvl1 .hier-bullet{background:#0070d2;margin-left:14px}
.hier-node.lvl2 .hier-bullet{background:#534ab7;margin-left:28px}.hier-node.lvl3 .hier-bullet{background:#04844b;margin-left:42px}
.hier-node a{color:#0070d2}.hier-meta{font-size:10px;color:#54698d;margin-left:auto;white-space:nowrap}
.related-mini{padding:8px 14px;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #f0f0f0;cursor:pointer}
.related-mini:last-child{border-bottom:none}.related-mini:hover{background:#f4f6f9}
.rm-count{background:#f4f6f9;color:#54698d;font-size:10px;padding:1px 7px;border-radius:8px;font-weight:500}
.rm-count.has{background:#e3f0fb;color:#0070d2}
.status-bar{display:flex;gap:0;overflow-x:auto;padding:4px 0}
.sb-step{flex:1;min-width:70px;text-align:center;font-size:10px;padding:6px 4px;border-top:3px solid #d8dde6;color:#54698d}
.sb-step.done{border-color:#04844b;color:#2e844a;font-weight:500}.sb-step.cur{border-color:#534ab7;color:#534ab7;font-weight:600}
.live-pill{display:inline-flex;align-items:center;gap:4px;background:#e8f5e9;color:#2e7d32;border:1px solid #a5d6a7;border-radius:10px;font-size:10px;font-weight:600;padding:2px 8px}
.live-dot{width:6px;height:6px;border-radius:50%;background:#2e7d32;animation:lpulse 1.8s infinite}
@keyframes lpulse{0%,100%{opacity:1}50%{opacity:.3}}
</style>`;

export default class LovingAccountCommunityLotWorkbench extends LightningElement {
    @track currentView      = 'communities';
    @track currentCommunityId = null;
    @track currentLotId     = null;
    @track detailTabVisible = false;
    @track detailTabLabel   = '';
    @track navTimestamp     = '';
    @track toastMsg         = '';
    @track toastVisible     = false;

    filters = {
        lots:  { bucket: 'all', builder: 'all', fm: 'all', search: '' },
        comms: { stage:  'all', builder: 'all', fm: 'all', search: '' },
    };

    _initialized    = false;
    _autoRefreshTmr = null;
    _toastTmr       = null;
    _loading        = true;
    _loadError      = null;

    @wire(getRecord, { recordId: userId, fields: [FIRST_NAME, LAST_NAME] })
    currentUser;

    get userInitials() {
        const first = (getFieldValue(this.currentUser?.data, FIRST_NAME) || '')[0] || '';
        const last  = (getFieldValue(this.currentUser?.data, LAST_NAME)  || '')[0] || '';
        return (first + last).toUpperCase() || '--';
    }
    get builderCount()   { return DB.builders.length; }
    get communityCount() { return DB.communities.length; }
    get lotCount()       { return DB.lots.length.toLocaleString(); }

    get tabAccCls()  { return 'sf-tab' + (this.currentView === 'accounts'   ? ' on' : ''); }
    get tabComCls()  { return 'sf-tab' + (this.currentView === 'communities' ? ' on' : ''); }
    get tabLotCls()  { return 'sf-tab' + (this.currentView === 'lots'        ? ' on' : ''); }
    get toastCls()   { return 'toast'  + (this.toastVisible ? ' show' : ''); }

    get content() { return this.template.querySelector('[data-id="main-content"]'); }

    connectedCallback() {
        this._loadData();
        this._autoRefreshTmr = setInterval(() => this.doRefresh(this.currentView), 30000);
    }
    disconnectedCallback() {
        if (this._autoRefreshTmr) clearInterval(this._autoRefreshTmr);
    }
    renderedCallback() {
        if (!this._initialized && !this._loading) {
            this._initialized = true;
            this.renderView();
            this.stampTs();
        }
    }

    _loadData() {
        this._loading = true;
        getWorkbenchData()
            .then(data => {
                this._enrichAndStore(data);
                this._loading = false;
                if (!this._initialized) {
                    this._initialized = true;
                    this.renderView();
                    this.stampTs();
                } else {
                    this.renderView();
                    this.stampTs();
                }
            })
            .catch(err => {
                this._loadError = err && err.body ? err.body.message : String(err);
                this._loading = false;
                const el = this.content;
                if (el) el.innerHTML = `<div style="padding:20px;color:#c23934">Error loading data: ${this._loadError}</div>`;
            });
    }

    _enrichAndStore(data) {
        DB.builders   = data.builders   || [];
        DB.divisions  = data.divisions  || [];
        DB.communities = (data.communities || []).map(c => ({ ...c, totalLots: 0, activeLots: c.activeLots || 0, closedLots: c.closedLots || 0 }));
        DB.lots = data.lots || [];
        // Build community map and enrich lots with FM; compute totalLots from child records
        const commMap = {};
        DB.communities.forEach(c => { commMap[c.id] = c; });
        DB.lots.forEach(l => {
            const c = commMap[l.communityId];
            if (c) {
                if (!l.fm) l.fm = c.fm;
                c.totalLots = (c.totalLots || 0) + 1;
                if (l.bucket === 'active')  c.activeLots = (c.activeLots || 0) + 1;
                if (l.bucket === 'closed')  c.closedLots = (c.closedLots || 0) + 1;
            }
        });
    }

    // ── Navigation ──────────────────────────────
    navigate(view, id) {
        this.currentView = view;
        if (view === 'community-detail') {
            this.currentCommunityId = id;
            this.detailTabVisible   = true;
            const c = DB.communities.find(x => x.id === id);
            this.detailTabLabel = c ? c.name : 'Community';
        } else if (view === 'lot-detail') {
            this.currentLotId     = id;
            this.detailTabVisible = true;
            const l = DB.lots.find(x => x.id === id);
            this.detailTabLabel = l ? l.lotId : 'Lot';
        } else {
            this.detailTabVisible = false;
        }
        this.renderView();
        this.stampTs();
    }

    renderView() {
        const el = this.content;
        if (!el) return;
        const v = this.currentView;
        if (v === 'accounts')          el.innerHTML = this.buildAccountsHtml();
        if (v === 'communities')       el.innerHTML = this.buildCommunitiesHtml();
        if (v === 'community-detail')  el.innerHTML = this.buildCommunityDetailHtml(this.currentCommunityId);
        if (v === 'lots')              el.innerHTML = this.buildLotsHtml();
        if (v === 'lot-detail')        el.innerHTML = this.buildLotDetailHtml(this.currentLotId);
    }

    doRefresh(view) {
        if (view === this.currentView) {
            getWorkbenchData()
                .then(data => { this._enrichAndStore(data); this.renderView(); this.stampTs(); this.showToast('Refreshed'); })
                .catch(() => { this.renderView(); this.stampTs(); this.showToast('Refreshed'); });
        }
    }

    stampTs() {
        this.navTimestamp = 'Updated ' + new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', second: '2-digit', hour12: true });
    }

    showToast(msg) {
        this.toastMsg     = msg;
        this.toastVisible = true;
        if (this._toastTmr) clearTimeout(this._toastTmr);
        this._toastTmr = setTimeout(() => { this.toastVisible = false; }, 2200);
    }

    // ── Event delegation ────────────────────────
    handleClick(e) {
        const actionEl = e.target.closest('[data-action]');
        if (actionEl) {
            e.stopPropagation();
            const a = actionEl.dataset.action;
            if (a === 'navigate')       this.navigate(actionEl.dataset.view, actionEl.dataset.id);
            if (a === 'setLotFilter')   this.setLotFilter(actionEl.dataset.key, actionEl.dataset.val, actionEl);
            if (a === 'setCommFilter')  this.setCommFilter(actionEl.dataset.key, actionEl.dataset.val, actionEl);
            if (a === 'doRefresh')      this.doRefresh(actionEl.dataset.view || this.currentView);
            if (a === 'subTab')         this.subTabAction(actionEl.dataset.prefix, actionEl.dataset.tab, actionEl);
            if (a === 'toggleSection')  this.toggleSection(actionEl);
            if (a === 'showToast')      this.showToast(actionEl.dataset.msg || 'Done');
            return;
        }
        const editable = e.target.closest('.editable');
        if (editable && !editable.querySelector('input,select')) this.activateEdit(editable);
    }

    handleInput(e) {
        const id = e.target.id || e.target.dataset.filterId;
        if (id === 'comm-search')        { this.filters.comms.search  = e.target.value; this.renderView(); }
        if (id === 'lot-search')         { this.filters.lots.search   = e.target.value; this.renderView(); }
        if (id === 'acct-search')        { this.renderView(); }
    }

    handleChange(e) {
        const id = e.target.id || e.target.dataset.filterId;
        if (id === 'comm-builder-filter'){ this.filters.comms.builder = e.target.value; this.renderView(); }
        if (id === 'comm-fm-filter')     { this.filters.comms.fm      = e.target.value; this.renderView(); }
        if (id === 'lot-builder-filter') { this.filters.lots.builder  = e.target.value; this.renderView(); }
        if (id === 'lot-fm-filter')      { this.filters.lots.fm       = e.target.value; this.renderView(); }
        if (id === 'acct-type-filter')   { this.renderView(); }
    }

    setLotFilter(key, val, chipEl) {
        this.filters.lots[key] = val;
        chipEl.closest('.list-toolbar')?.querySelectorAll('[data-action="setLotFilter"][data-key="'+key+'"]')
            .forEach(c => c.classList.toggle('on', c.dataset.val === val));
        this.renderView();
    }

    setCommFilter(key, val, chipEl) {
        this.filters.comms[key] = val;
        chipEl.closest('.list-toolbar')?.querySelectorAll('[data-action="setCommFilter"][data-key="'+key+'"]')
            .forEach(c => c.classList.toggle('on', c.dataset.val === val));
        this.renderView();
    }

    subTabAction(prefix, tab, el) {
        const root = el.closest('[data-subtab-root]') || this.content;
        root.querySelectorAll('[id^="'+prefix+'-"].sub-tc').forEach(t => t.classList.remove('on'));
        root.querySelectorAll('.subtab').forEach(t => t.classList.remove('on'));
        const target = root.querySelector('#'+prefix+'-'+tab);
        if (target) target.classList.add('on');
        el.classList.add('on');
    }

    toggleSection(headerEl) {
        const body   = headerEl.nextElementSibling;
        const arrow  = headerEl.querySelector('.sec-toggle');
        if (body)  body.classList.toggle('hidden');
        if (arrow) arrow.classList.toggle('open');
    }

    activateEdit(el) {
        const rt  = el.dataset.rt;
        const rid = el.dataset.rid;
        const fld = el.dataset.field;
        const typ = el.dataset.type  || 'text';
        const opts= el.dataset.opts  ? el.dataset.opts.split('|') : null;
        if (!fld) return;

        const rec = rt === 'community' ? DB.communities.find(c => c.id === rid)
                  : rt === 'lot'       ? DB.lots.find(l => l.id === rid)
                  : null;
        if (!rec) return;

        let input;
        if (typ === 'select' && opts) {
            input = document.createElement('select');
            input.className = 'edit-select';
            opts.forEach(o => {
                const op = document.createElement('option');
                op.value = o; op.textContent = o;
                if (String(rec[fld]) === o) op.selected = true;
                input.appendChild(op);
            });
        } else {
            input = document.createElement('input');
            input.className = 'edit-input';
            input.type = typ;
            input.value = rec[fld] != null ? String(rec[fld]) : '';
        }

        const save = () => {
            rec[fld] = input.value;
            el.innerHTML = this.renderEditableValue(rec, fld, typ, opts);
            this.showToast(fld + ' saved');
        };
        input.addEventListener('blur',    save);
        input.addEventListener('keydown', ev => { if (ev.key === 'Enter') { ev.preventDefault(); save(); } if (ev.key === 'Escape') { el.innerHTML = this.renderEditableValue(rec, fld, typ, opts); } });

        el.innerHTML = '';
        el.appendChild(input);
        input.focus();
    }

    renderEditableValue(rec, fld, typ, opts) {
        const v = rec[fld];
        if (fld === 'aqua')  return v ? '<span class="chip cg">Yes</span>' : '<span class="chip cgr">No</span>';
        if (fld === 'stage') return this.stageChip(v);
        if (fld === 'lotStatus') return this.statusChip(v);
        if (fld === 'bucket')    return this.pipelineBadge(v);
        return v != null ? String(v) : '<span style="color:#c8cdd6">—</span>';
    }

    // ── HTML helpers ─────────────────────────────
    getDivision(id) { return DB.divisions.find(d => d.id === id); }
    getBuilder(id)  { return DB.builders.find(b => b.id === id); }
    fmtDate(s) {
        if (!s || s === '—') return '—';
        const d = new Date(s + 'T12:00:00');
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }
    fmtMoney(n) { return n ? '$' + Number(n).toLocaleString() : '—'; }
    pipelineBadge(b) {
        const M = { '90+':['pb-90','90+ Days'],'60+':['pb-60','60+ Days'],'31':['pb-31','31 Days'],'30':['pb-30','30 Days'],'takeoff':['pb-takeoff','Takeoff Scheduled'],'clear':['pb-clear','Clear for Schedule'],'scheduled':['pb-sched','Scheduled'],'active':['pb-active','Active Today'],'closed':['pb-closed','Closed'] };
        const [cls,label] = M[b] || ['pb-90',b];
        return `<span class="pipeline-badge ${cls}">${label}</span>`;
    }
    eighty11Chip(v) {
        if (v === 'Cleared')    return `<span class="chip cg">${v}</span>`;
        if (v === 'Filed')      return `<span class="chip cb2">${v}</span>`;
        if (v === 'Not Filed')  return `<span class="chip cr">${v}</span>`;
        return `<span class="chip cgr">${v || '—'}</span>`;
    }
    statusChip(v) {
        if (!v || v==='—')           return `<span class="chip cgr">—</span>`;
        if (v==='In Production')     return `<span class="chip cb2">${v}</span>`;
        if (v==='Installed')         return `<span class="chip cg">${v}</span>`;
        if (v==='Under Construction')return `<span class="chip ca">${v}</span>`;
        return `<span class="chip cgr">${v}</span>`;
    }
    stageChip(s) {
        if (s==='Active Selling') return `<span class="chip cg">${s}</span>`;
        if (s==='Fully Sold')     return `<span class="chip cb2">${s}</span>`;
        if (s==='Closed Out')     return `<span class="chip cgr">${s}</span>`;
        return `<span class="chip ca">${s}</span>`;
    }
    editAttr(rt, rid, field, type, opts) {
        const optsStr = opts ? ` data-opts="${opts.join('|')}"` : '';
        return `class="opp-value editable" data-rt="${rt}" data-rid="${rid}" data-field="${field}" data-type="${type || 'text'}"${optsStr}`;
    }
    actItem(dotCls, icon, title, sub, dateStr, overdue=false) {
        return `<div class="act-item"><div class="act-dot-col"><div class="act-dot ${dotCls}"></div><div class="act-connector"></div></div><div class="act-body"><div class="act-title">${icon} ${title}</div><div class="act-sub${overdue?' act-overdue':''}">${sub}</div></div><div class="act-date${overdue?' act-overdue':''}">${dateStr}</div></div>`;
    }
    refreshRow(view, hint) {
        return `<div class="refresh-row"><button class="refresh-btn" data-action="doRefresh" data-view="${view}">↻ Refresh</button><span style="font-size:11px;color:#54698d">${this.navTimestamp}</span><span style="margin-left:auto;font-size:10px;color:#b0b7c3">${hint}</span></div>`;
    }

    // ── ACCOUNTS VIEW ────────────────────────────
    buildAccountsHtml() {
        let rows = '';
        DB.builders.forEach(b => {
            const divs = DB.divisions.filter(d => d.builderId === b.id);
            const total = divs.reduce((s,d) => s + DB.communities.filter(c=>c.divisionId===d.id).reduce((ss,c)=>ss+c.totalLots,0),0);
            rows += `<div style="display:flex;align-items:center;padding:10px 14px;border-bottom:1px solid #e5e5e5;background:#fff;cursor:pointer" data-action="navigate" data-view="accounts">
              <div style="width:8px;height:8px;border-radius:50%;background:#16325c;margin-right:10px;flex-shrink:0"></div>
              <div style="flex:1"><div style="font-weight:600">${b.name}</div><div style="font-size:10px;color:#54698d">${b.type} · ${b.hq}</div></div>
              <span style="font-size:10px;color:#54698d">${divs.length} divisions · ${total.toLocaleString()} lots</span></div>`;
            divs.forEach(d => {
                const comms = DB.communities.filter(c => c.divisionId === d.id);
                rows += `<div style="display:flex;align-items:center;padding:7px 14px;border-bottom:1px solid #f4f6f9;background:#fafaf9">
                  <div style="width:8px;height:8px;border-radius:50%;background:#0070d2;margin-left:14px;margin-right:10px;flex-shrink:0"></div>
                  <div style="flex:1"><span class="nl">${d.name}</span><div style="font-size:10px;color:#54698d">${d.contact} · ${d.phone} · $${d.stdSodRate}/sf</div></div>
                  <span style="font-size:10px;color:#54698d">${comms.length} communities</span></div>`;
                comms.forEach(c => {
                    rows += `<div style="display:flex;align-items:center;padding:6px 14px;border-bottom:1px solid #f4f6f9;background:#fff;cursor:pointer" data-action="navigate" data-view="community-detail" data-id="${c.id}">
                      <div style="width:8px;height:8px;border-radius:50%;background:#534ab7;margin-left:28px;margin-right:10px;flex-shrink:0"></div>
                      <span class="nl">${c.name}</span>
                      <span style="margin-left:auto;display:flex;gap:8px;align-items:center">${this.stageChip(c.stage)} <span style="font-size:10px;color:#54698d">${c.totalLots} lots</span></span></div>`;
                });
            });
        });
        return INLINE_CSS + `
        <div class="rec-header"><div class="rec-top-row">
          <div class="rec-icon" style="background:#16325c">🏢</div>
          <div class="rec-title-block"><div class="rec-breadcrumb">Accounts</div><div class="rec-title">Builder Account Hierarchy</div></div>
          <div class="rec-actions"><button class="sf-btn primary">+ New Account</button></div>
        </div></div>
        ${this.refreshRow('accounts','Syncs from Salesforce Account hierarchy')}
        <div class="sf-body"><div class="card last">${rows}</div></div>`;
    }

    // ── COMMUNITIES LIST ─────────────────────────
    buildCommunitiesHtml() {
        const { stage, builder, fm, search } = this.filters.comms;
        const rows = DB.communities.filter(c => {
            const div = this.getDivision(c.divisionId);
            if (stage !== 'all' && c.stage !== stage) return false;
            if (builder !== 'all' && div?.builderId !== builder) return false;
            if (fm !== 'all' && c.fm !== fm) return false;
            if (search && !c.name.toLowerCase().includes(search.toLowerCase())) return false;
            return true;
        });
        const chips = ['all','Active Selling','Fully Sold','Closed Out'];
        const chipHtml = chips.map(s => `<span class="filter-chip${this.filters.comms.stage===s?' on':''}" data-action="setCommFilter" data-key="stage" data-val="${s}">${s==='all'?'All':s}</span>`).join('');

        let tbody = '';
        rows.forEach(c => {
            const div = this.getDivision(c.divisionId);
            const bld = this.getBuilder(div?.builderId);
            tbody += `<tr style="cursor:pointer" data-action="navigate" data-view="community-detail" data-id="${c.id}">
              <td><a class="nl">${c.name}</a></td>
              <td>${bld?.name||''} / ${div?.name||''}</td><td>${c.fm}</td>
              <td class="num">${c.totalLots}</td><td class="num">${c.activeLots}</td><td class="num">${c.closedLots}</td>
              <td>${this.stageChip(c.stage)}</td>
              <td>${c.aqua?'<span class="chip cg">Yes</span>':'<span class="chip cgr">No</span>'}</td>
              <td class="num">${this.fmtMoney(c.stdPkg)}</td><td>${c.phases}</td>
            </tr>`;
        });
        return INLINE_CSS + `
        <div class="rec-header"><div class="rec-top-row">
          <div class="rec-icon" style="background:#0070d2">🏘</div>
          <div class="rec-title-block"><div class="rec-breadcrumb">Communities</div>
            <div class="rec-title">All Communities <span class="chip cgr" style="margin-left:6px">${rows.length} of ${DB.communities.length} shown</span></div></div>
          <div class="rec-actions"><button class="sf-btn">Export</button><button class="sf-btn primary">+ New Community</button></div>
        </div></div>
        <div class="list-toolbar">
          <span style="font-size:11px;color:#54698d;font-weight:500;text-transform:uppercase;letter-spacing:.4px">Stage:</span>
          ${chipHtml}
          <span style="margin-left:auto"></span>
          <select class="list-select" id="comm-builder-filter">
            <option value="all"${this.filters.comms.builder==='all'?' selected':''}>All builders</option>
            ${DB.builders.map(b=>`<option value="${b.id}"${this.filters.comms.builder===b.id?' selected':''}>${b.name}</option>`).join('')}
          </select>
          <select class="list-select" id="comm-fm-filter">
            <option value="all"${this.filters.comms.fm==='all'?' selected':''}>All FMs</option>
            ${[...new Set(DB.communities.map(c=>c.fm).filter(Boolean))].sort().map(f=>`<option value="${f}"${this.filters.comms.fm===f?' selected':''}>${f}</option>`).join('')}
          </select>
          <input class="list-search" id="comm-search" placeholder="Search communities…" value="${this.filters.comms.search||''}">
        </div>
        ${this.refreshRow('communities','Pipeline_Bucket__c recalculated nightly')}
        <div class="sf-body"><div class="card last">
          <table class="tbl"><thead><tr>
            <th>Community</th><th>Builder / Division</th><th>FM</th>
            <th class="num">Total</th><th class="num">Active</th><th class="num">Closed</th>
            <th>Stage</th><th>Aqua</th><th class="num">Std Pkg $</th><th>Phases</th>
          </tr></thead><tbody>${tbody||'<tr><td colspan="10" style="text-align:center;padding:24px;color:#54698d">No communities match filters</td></tr>'}</tbody></table>
          <div style="padding:10px 14px;background:#fafaf9;border-top:1px solid #e5e5e5;font-size:11px;color:#54698d">${rows.length} of ${DB.communities.length} communities shown</div>
        </div></div>`;
    }

    // ── COMMUNITY DETAIL ─────────────────────────
    buildCommunityDetailHtml(id) {
        const c   = DB.communities.find(x => x.id === id);
        if (!c) return '<div style="padding:40px;color:#54698d">Community not found.</div>';
        const div = this.getDivision(c.divisionId);
        const bld = this.getBuilder(div?.builderId);
        const lots = DB.lots.filter(l => l.communityId === id);

        // Stage path
        const stageIdx = COMM_STAGES.indexOf(c.stage);
        const stagePath = COMM_STAGES.map((s,i) => {
            const cls = i < stageIdx ? 'done' : i === stageIdx ? 'current' : 'future';
            return `<div class="stage-step ${cls}" data-action="showToast" data-msg="Stage: ${s}"><div style="font-size:10px;font-weight:500">${s}</div><div style="font-size:9px;margin-top:1px">${i<stageIdx?'✓':i===stageIdx?'▶':''}</div></div>`;
        }).join('');

        // Activity feed
        const activeLots   = lots.filter(l => l.bucket === 'active');
        const schedLots    = lots.filter(l => l.bucket === 'scheduled');
        const clearLots    = lots.filter(l => l.bucket === 'clear');
        const takeoffLots  = lots.filter(l => l.bucket === 'takeoff');
        const overdueLots  = lots.filter(l => l.bucket === '30' && l.eighty11 === 'Not Filed');
        const thirtyLots   = lots.filter(l => l.bucket === '30' && l.eighty11 !== 'Not Filed');
        const closedLots   = lots.filter(l => l.bucket === 'closed');

        let upcoming = '';
        overdueLots.forEach( l => { upcoming += this.actItem('overdue','🚧',`811 not filed — ${l.lotId}`,`Required before Clear for Schedule · ${l.fm}`,'Overdue',true); });
        activeLots.forEach(  l => { upcoming += this.actItem('task','🏗',`Install active — ${l.lotId}`,`${l.crew||l.fm} · ${l.address}`,'Today'); });
        schedLots.forEach(   l => { upcoming += this.actItem('event','📅',`Scheduled — ${l.lotId}`,`${l.crew||'Crew TBD'} · ${l.address}`,this.fmtDate(l.reqInstall).replace(', 2026','')); });
        clearLots.forEach(   l => { upcoming += this.actItem('call','✅',`Clear for Schedule — ${l.lotId}`,`Assign crew · ${l.fm}`,this.fmtDate(l.reqInstall).replace(', 2026','')); });
        takeoffLots.forEach( l => { upcoming += this.actItem('task','📏',`Takeoff upcoming — ${l.lotId}`,`${l.takeoff} · ${l.fm}`,this.fmtDate(l.reqInstall).replace(', 2026','')); });
        thirtyLots.forEach(  l => { upcoming += this.actItem('task','⏰',`30-day window — ${l.lotId}`,`811 ${l.eighty11} · Takeoff needed · ${l.fm}`,this.fmtDate(l.reqInstall).replace(', 2026','')); });
        if (!upcoming) upcoming = `<div style="padding:12px 0;font-size:11px;color:#54698d">No upcoming items.</div>`;

        let past = '';
        closedLots.forEach(l => { past += this.actItem('past','🏡',`Lot closed — HO owned · ${l.lotId}`,`All WOs approved`,this.fmtDate(l.reqInstall).replace(', 2026','').replace(', 2025','')); });
        past += this.actItem('past','📋',`Community setup complete`,`Pricebook: ${div?.pricebook||'—'}`,this.fmtDate(c.startDate).replace(', 202','\'2'));
        past += this.actItem('past','🤝',`Contract executed`,`${bld?.name} / ${div?.name}`,this.fmtDate(c.startDate).replace(', 202','\'2'));
        if (!past) past = `<div style="padding:12px 0;font-size:11px;color:#54698d">No past activity.</div>`;

        // Bucket summary
        const buckets = ['active','scheduled','clear','takeoff','30','31','60+','90+','closed'];
        let bucketRows = '';
        buckets.forEach(b => {
            const cnt = lots.filter(l=>l.bucket===b).length;
            if (!cnt) return;
            bucketRows += `<div style="display:flex;justify-content:space-between;align-items:center;padding:5px 0;border-bottom:1px solid #f4f6f9">${this.pipelineBadge(b)} <span class="rm-count has">${cnt}</span></div>`;
        });

        // Field sections
        const FM_OPTS = [...new Set(DB.communities.map(c=>c.fm).filter(Boolean))].sort();
        const SP_OPTS = ['Average','Exact','Flexible'];
        const buildFieldRow = (label, display, rt, rid, field, type, opts) => {
            const editAttrs = field ? `class="opp-value editable" data-rt="${rt}" data-rid="${rid}" data-field="${field}" data-type="${type||'text'}"${opts?` data-opts="${opts.join('|')}"`:''} ` : 'class="opp-value"';
            return `<div class="opp-field"><div class="opp-label">${label}</div><div ${editAttrs}>${display}</div></div>`;
        };
        const sections = [
            { title:'Community Information', open:true, fields:[
                buildFieldRow('Community Name', c.name,                   'community', id, 'name',      'text'),
                buildFieldRow('Stage',          this.stageChip(c.stage),  'community', id, 'stage',     'select', COMM_STAGES),
                buildFieldRow('Division',       `<a class="nl" data-action="navigate" data-view="accounts">${div?.name}</a>`, null,null,null),
                buildFieldRow('Builder',        `<a class="nl">${bld?.name}</a>`,  null,null,null),
                buildFieldRow('Field Manager',  c.fm,                     'community', id, 'fm',        'select', FM_OPTS),
                buildFieldRow('Phases',         String(c.phases),         'community', id, 'phases',    'text'),
                buildFieldRow('Total Lots',     String(c.totalLots),      'community', id, 'totalLots', 'text'),
                buildFieldRow('Address',        c.address,                'community', id, 'address',   'text'),
                buildFieldRow('Start Date',     this.fmtDate(c.startDate),'community', id, 'startDate', 'date'),
                buildFieldRow('Projected Close',this.fmtDate(c.closeDate),'community', id, 'closeDate', 'date'),
                buildFieldRow('Aqua Customer',  c.aqua?'<span class="chip cg">Yes</span>':'<span class="chip cgr">No</span>', 'community', id, 'aqua','select',['true','false']),
                buildFieldRow('Lot Size (avg)', c.lotSize,                'community', id, 'lotSize',   'text'),
            ]},
            { title:'Pricing & Standards', open:true, fields:[
                buildFieldRow('Package Code',   c.pkg,                    'community', id, 'pkg',       'text'),
                buildFieldRow('Spec Type',      `<span class="chip cgr">${c.specType}</span>`, 'community', id, 'specType','select',SP_OPTS),
                buildFieldRow('Std Package $',  this.fmtMoney(c.stdPkg), 'community', id, 'stdPkg',    'text'),
                buildFieldRow('Aqua Add-on $',  this.fmtMoney(c.aquaAddon),'community',id,'aquaAddon', 'text'),
                buildFieldRow('Sod Rate',       `$${c.sodRate}/sf`,       'community', id, 'sodRate',   'text'),
                buildFieldRow('Goal Hours',     `${c.goalHrs} hrs`,       'community', id, 'goalHrs',   'text'),
                buildFieldRow('Pricebook',      div?.pricebook||'—',      null,null,null),
                buildFieldRow('Division Contact',`${div?.contact} · ${div?.phone}`,null,null,null),
            ]},
            { title:'Lot Pipeline Summary', open:false, custom: `<div style="grid-column:1/-1">${bucketRows||'<div style="color:#54698d;font-size:11px;padding:8px 0">No lot data in this session.</div>'}</div>` },
        ];

        let leftHtml = '';
        sections.forEach(sec => {
            leftHtml += `<div><div class="sec-header" data-action="toggleSection"><span class="sec-toggle${sec.open?' open':''}">▶</span><span class="sec-title">${sec.title}</span></div>`;
            if (sec.custom) {
                leftHtml += `<div class="sec-body${sec.open?'':' hidden'}" style="grid-template-columns:1fr">${sec.custom}</div>`;
            } else {
                leftHtml += `<div class="sec-body${sec.open?'':' hidden'}">${sec.fields.join('')}</div>`;
            }
            leftHtml += '</div>';
        });

        // Lot grid
        const tileMap = { active:'in-prog', scheduled:'scheduled', clear:'pending', takeoff:'pending', '30':'pending', '31':'available', '60+':'available', '90+':'available', closed:'closed' };
        const lotTiles = lots.map(l => `<div class="lot-tile ${tileMap[l.bucket]||'available'}" data-action="navigate" data-view="lot-detail" data-id="${l.id}" title="${l.lotId} — ${l.lotStatus}"><div>${l.num}</div><div style="font-size:9px;margin-top:2px;opacity:.7">${l.eighty11==='Cleared'?'✓':l.eighty11==='Filed'?'⏳':''}</div></div>`).join('');
        const lotGridHtml = `<div class="ch"><div class="ci" style="background:#534ab7">🏠</div><h3>Lot Grid — ${c.name}</h3><span class="ch-link" style="margin-left:auto" data-action="navigate" data-view="lots">View full list →</span></div><div class="lot-grid">${lotTiles}</div><div class="legend"><div class="legend-item"><div class="legend-sw" style="background:#ede9fe;border-color:#c5bef7"></div>Active</div><div class="legend-item"><div class="legend-sw" style="background:#e3f0fb;border-color:#b5d4f4"></div>Scheduled</div><div class="legend-item"><div class="legend-sw" style="background:#fef3c7;border-color:#f9c725"></div>Pending/Clear</div><div class="legend-item"><div class="legend-sw" style="background:#f4f6f9;border-color:#e5e5e5"></div>Pipeline</div><div class="legend-item"><div class="legend-sw" style="background:#e8f5e9;border-color:#a5d6a7;opacity:.55"></div>Closed</div></div>`;

        return INLINE_CSS + `
        <div style="background:#16325c;color:#fff;padding:6px 20px;display:flex;align-items:center;gap:8px;font-size:11px;flex-wrap:wrap">
          <span style="color:rgba(255,255,255,.5);text-transform:uppercase;font-size:9px;font-weight:500;letter-spacing:.4px">Hierarchy:</span>
          <span style="color:rgba(255,255,255,.85);cursor:pointer;padding:2px 8px;border-radius:3px" data-action="navigate" data-view="accounts">${bld?.name}</span>›
          <span style="color:rgba(255,255,255,.85);cursor:pointer;padding:2px 8px;border-radius:3px" data-action="navigate" data-view="accounts">${div?.name}</span>›
          <span style="background:rgba(255,255,255,.2);color:#fff;font-weight:500;padding:2px 8px;border-radius:3px">${c.name}</span>
        </div>
        <div class="rec-header"><div class="rec-top-row">
          <div class="rec-icon" style="background:#0070d2">🏘</div>
          <div class="rec-title-block">
            <div class="rec-breadcrumb"><a data-action="navigate" data-view="communities">Communities</a> › ${div?.name}</div>
            <div class="rec-title">${c.name} ${this.stageChip(c.stage)}</div>
          </div>
          <div class="rec-actions">
            <button class="sf-btn">Edit</button>
            <button class="sf-btn" data-action="navigate" data-view="lots">View Lots</button>
            <button class="sf-btn primary">+ New Lot</button>
          </div>
        </div></div>
        <div class="stage-path">${stagePath}</div>
        <div class="highlights">
          <div><div class="hl-label">Stage</div><div class="hl-value">${this.stageChip(c.stage)}</div></div>
          <div><div class="hl-label">Close Date</div><div class="hl-value amber">${this.fmtDate(c.closeDate)}</div></div>
          <div><div class="hl-label">Field Manager</div><div class="hl-value">${c.fm}</div></div>
          <div><div class="hl-label">Std Package</div><div class="hl-value">${this.fmtMoney(c.stdPkg)}</div></div>
          <div><div class="hl-label">Total Lots</div><div class="hl-value">${c.totalLots} <span style="font-size:10px;color:#54698d">(${c.activeLots} active)</span></div></div>
          <div><div class="hl-label">Aqua Customer</div><div class="hl-value${c.aqua?' green':''}">${c.aqua?'Yes — $'+c.aquaAddon+'/lot':'No'}</div></div>
        </div>
        <div class="subtabs" data-subtab-root>
          <div class="subtab on" data-action="subTab" data-prefix="cd" data-tab="info">Details</div>
          <div class="subtab" data-action="subTab" data-prefix="cd" data-tab="lots">Lots <span class="rm-count has" style="margin-left:4px">${lots.length}</span></div>
          <div class="subtab" data-action="subTab" data-prefix="cd" data-tab="related">Related</div>
        </div>
        ${this.refreshRow('community-detail','Activity updates on refresh')}
        <div id="cd-info" class="sub-tc on">
          <div class="opp-layout">
            <div class="opp-main">${leftHtml}</div>
            <div class="opp-rail"><div class="act-panel">
              <div class="act-actions">
                <button class="act-btn" data-action="showToast" data-msg="Task added"><div class="act-btn-icon">✏️</div>New Task</button>
                <button class="act-btn" data-action="showToast" data-msg="Call logged"><div class="act-btn-icon">📞</div>Log a Call</button>
                <button class="act-btn" data-action="showToast" data-msg="Event created"><div class="act-btn-icon">📅</div>New Event</button>
                <button class="act-btn" data-action="showToast" data-msg="Email drafted"><div class="act-btn-icon">✉️</div>Email</button>
              </div>
              <div class="act-feed">
                <div class="act-section-hdr">Upcoming &amp; Overdue</div>${upcoming}
                <div class="act-section-hdr">Past Activity</div>${past}
              </div>
              <div class="act-refresh" data-action="doRefresh" data-view="community-detail">↻ Refresh Activity &nbsp;·&nbsp; <span class="live-pill" style="font-size:9px"><span class="live-dot"></span>LIVE</span></div>
            </div></div>
          </div>
        </div>
        <div id="cd-lots" class="sub-tc"><div class="card" style="margin:14px 20px">${lotGridHtml}</div></div>
        <div id="cd-related" class="sub-tc"><div class="sf-body"><div class="card last">
          <div class="ch"><div class="ci" style="background:#16325c">🔗</div><h3>Related Records</h3></div>
          <div class="related-mini" data-action="navigate" data-view="lots"><div style="font-size:12px">🏠 Lots</div><div class="rm-count has">${c.totalLots}</div></div>
          <div class="related-mini"><div style="font-size:12px">📋 Work Orders</div><div class="rm-count has">—</div></div>
          <div class="related-mini"><div style="font-size:12px">💧 Aqua Tickets</div><div class="rm-count ${c.aqua?'has':''}">${c.aqua?'—':'0'}</div></div>
          <div class="related-mini"><div style="font-size:12px">📷 Photos</div><div class="rm-count">—</div></div>
        </div></div></div>`;
    }

    // ── LOTS LIST ────────────────────────────────
    buildLotsHtml() {
        const { bucket, builder, fm, search } = this.filters.lots;
        const filtered = DB.lots.filter(l => {
            const c   = DB.communities.find(x => x.id === l.communityId);
            const div = this.getDivision(c?.divisionId);
            if (bucket  !== 'all' && l.bucket !== bucket) return false;
            if (builder !== 'all' && div?.builderId !== builder) return false;
            if (fm      !== 'all' && l.fm !== fm) return false;
            if (search && ![l.lotId, l.address, l.po, c?.name||''].join(' ').toLowerCase().includes(search.toLowerCase())) return false;
            return true;
        });

        const buckets = ['all','90+','60+','31','30','takeoff','clear','scheduled','active','closed'];
        const bucketLabels = { all:'All','90+':'90+ Days','60+':'60+ Days','31':'31 Days','30':'30 Days',takeoff:'Takeoff Scheduled',clear:'Clear for Schedule',scheduled:'Scheduled',active:'Active Today',closed:'Closed' };
        const chips = buckets.map(b => `<span class="filter-chip${this.filters.lots.bucket===b?' on':''}" data-action="setLotFilter" data-key="bucket" data-val="${b}">${bucketLabels[b]}</span>`).join('');

        let tbody = '';
        filtered.forEach(l => {
            const c   = DB.communities.find(x => x.id === l.communityId);
            const div = this.getDivision(c?.divisionId);
            const bld = this.getBuilder(div?.builderId);
            const tk  = l.takeoff === 'Locked' ? '<span class="chip cg">Locked</span>' : l.takeoff === 'Not Started' ? '<span class="chip cgr">Not Started</span>' : `<span class="chip cp">${l.takeoff}</span>`;
            const aq  = l.aqua === 'Auto' ? '<span class="chip cb2">Auto</span>' : l.aqua === 'Installed' ? '<span class="chip cg">Installed</span>' : `<span class="chip cgr">${l.aqua}</span>`;
            const bg  = l.bucket === 'active' ? 'background:#f5f3ff' : l.bucket === 'closed' ? 'opacity:.65' : '';
            tbody += `<tr style="${bg};cursor:pointer" data-action="navigate" data-view="lot-detail" data-id="${l.id}">
              <td><a class="nl">${l.lotId}</a></td>
              <td><a class="nl" data-action="navigate" data-view="community-detail" data-id="${c?.id}">${c?.name}</a></td>
              <td>${bld?.name} / ${div?.name}</td><td>${l.fm}</td><td>${l.address}</td>
              <td>${this.fmtDate(l.reqInstall)}</td>
              <td>${this.pipelineBadge(l.bucket)}</td>
              <td>${this.statusChip(l.lotStatus)}</td>
              <td>${this.eighty11Chip(l.eighty11)}</td>
              <td>${tk}</td><td>${aq}</td>
              <td>${l.po}</td><td class="num">${this.fmtMoney(l.poAmt)}</td>
              <td><span class="chip cgr">${l.specType}</span></td>
            </tr>`;
        });

        return INLINE_CSS + `
        <div class="rec-header"><div class="rec-top-row">
          <div class="rec-icon" style="background:#534ab7">🏠</div>
          <div class="rec-title-block"><div class="rec-breadcrumb">Lots</div>
            <div class="rec-title">All Lots <span class="chip cgr" style="margin-left:6px">${filtered.length} shown · ${DB.lots.length} total</span></div></div>
          <div class="rec-actions"><button class="sf-btn">Export</button><button class="sf-btn primary">+ New Lot</button></div>
        </div></div>
        <div class="list-toolbar">
          <span style="font-size:11px;color:#54698d;font-weight:500;text-transform:uppercase;letter-spacing:.4px">Pipeline:</span>
          ${chips}
          <span style="margin-left:auto"></span>
          <select class="list-select" id="lot-builder-filter">
            <option value="all"${this.filters.lots.builder==='all'?' selected':''}>All builders</option>
            ${DB.builders.map(b=>`<option value="${b.id}"${this.filters.lots.builder===b.id?' selected':''}>${b.name}</option>`).join('')}
          </select>
          <select class="list-select" id="lot-fm-filter">
            <option value="all"${this.filters.lots.fm==='all'?' selected':''}>All FMs</option>
            ${[...new Set(DB.lots.map(l=>l.fm).filter(Boolean))].sort().map(f=>`<option value="${f}"${this.filters.lots.fm===f?' selected':''}>${f}</option>`).join('')}
          </select>
          <input class="list-search" id="lot-search" placeholder="Search lots, PO, address…" value="${this.filters.lots.search||''}">
        </div>
        ${this.refreshRow('lots','811 status syncs from NC811 API nightly')}
        <div class="sf-body"><div class="card last">
          <table class="tbl"><thead><tr>
            <th>Lot #</th><th>Community</th><th>Builder / Division</th><th>FM</th>
            <th>Address</th><th>Req. Install</th><th>Pipeline</th><th>Status</th>
            <th>811</th><th>Takeoff</th><th>Aqua</th><th>PO #</th><th class="num">PO $</th><th>Spec</th>
          </tr></thead><tbody>${tbody||'<tr><td colspan="14" style="text-align:center;padding:24px;color:#54698d">No lots match filters</td></tr>'}</tbody></table>
          <div style="padding:10px 14px;background:#fafaf9;border-top:1px solid #e5e5e5;font-size:11px;color:#54698d">${filtered.length} of ${DB.lots.length} lots shown · Pipeline_Bucket__c recalculated nightly</div>
        </div></div>`;
    }

    // ── LOT DETAIL ───────────────────────────────
    buildLotDetailHtml(id) {
        const l = DB.lots.find(x => x.id === id);
        if (!l) return '<div style="padding:40px;color:#54698d">Lot not found.</div>';
        const c   = DB.communities.find(x => x.id === l.communityId);
        const div = this.getDivision(c?.divisionId);
        const bld = this.getBuilder(div?.builderId);

        const buildRow = (label, display, rt, rid, field, type, opts) => {
            const editAttrs = field ? `class="field-value editable" data-rt="${rt}" data-rid="${rid}" data-field="${field}" data-type="${type||'text'}"${opts?` data-opts="${opts.join('|')}"`:''} ` : 'class="field-value"';
            return `<div class="field-row"><div class="field-label">${label}</div><div ${editAttrs}>${display}</div></div>`;
        };

        const FM_OPTS = [...new Set(DB.communities.map(c=>c.fm).filter(Boolean))].sort();
        const STATUS_OPTS = ['Open','Under Construction','In Production','Installed','Closed (HO Owned)'];
        const PHASE_OPTS  = ['Phase 1','Phase 2','Phase 3','Phase 4'];

        const pipelineSteps = [
            {label:'90+ Days',done:true},{label:'60+ Days',done:true},
            {label:'31 Days',done:['30','takeoff','clear','scheduled','active','closed'].includes(l.bucket)},
            {label:'30 Days',done:['takeoff','clear','scheduled','active','closed'].includes(l.bucket)},
            {label:'Takeoff',done:['clear','scheduled','active','closed'].includes(l.bucket)},
            {label:'Clear',done:['scheduled','active','closed'].includes(l.bucket)},
            {label:'Scheduled',done:['active','closed'].includes(l.bucket)},
            {label:'Closed',done:l.bucket==='closed'},
        ];
        const curPipeIdx = pipelineSteps.findIndex(s=>!s.done);
        const pipelineBar = pipelineSteps.map((s,i) => {
            const isCur = i===curPipeIdx;
            const st = s.done?'border-color:#04844b;color:#2e7d32;background:#f9fff9':isCur?'border-color:#534ab7;color:#534ab7;font-weight:700;background:#f5f3ff':'border-color:#d8dde6;color:#c8cdd6';
            return `<div style="text-align:center;flex:1;min-width:70px;padding:7px 4px;border-top:3px solid;${st}"><div style="font-size:9px;font-weight:600">${s.label}</div><div style="font-size:9px;margin-top:3px">${s.done?'✓':isCur?'→':''}</div></div>`;
        }).join('');

        const eighty11Steps = ['Not Filed','Filed','Pending Locate','Marked','Cleared'];
        const curE11 = eighty11Steps.indexOf(l.eighty11);
        const e11Bar = eighty11Steps.map((s,i)=>`<div class="sb-step${i<curE11?' done':i===curE11?' cur':''}">${s}</div>`).join('');

        return INLINE_CSS + `
        <div style="background:#16325c;color:#fff;padding:6px 20px;display:flex;align-items:center;gap:8px;font-size:11px;flex-wrap:wrap">
          <span style="color:rgba(255,255,255,.5);text-transform:uppercase;font-size:9px;font-weight:500;letter-spacing:.4px">Hierarchy:</span>
          <span style="color:rgba(255,255,255,.85);cursor:pointer;padding:2px 8px;border-radius:3px" data-action="navigate" data-view="accounts">${bld?.name}</span>›
          <span style="color:rgba(255,255,255,.85);cursor:pointer;padding:2px 8px;border-radius:3px" data-action="navigate" data-view="accounts">${div?.name}</span>›
          <span style="color:rgba(255,255,255,.85);cursor:pointer;padding:2px 8px;border-radius:3px" data-action="navigate" data-view="community-detail" data-id="${c?.id}">${c?.name}</span>›
          <span style="background:rgba(255,255,255,.2);color:#fff;font-weight:500;padding:2px 8px;border-radius:3px">${l.lotId}</span>
        </div>
        <div class="rec-header"><div class="rec-top-row">
          <div class="rec-icon" style="background:#534ab7">🏠</div>
          <div class="rec-title-block">
            <div class="rec-breadcrumb"><a data-action="navigate" data-view="lots">Lots</a> › <a data-action="navigate" data-view="community-detail" data-id="${c?.id}">${c?.name}</a></div>
            <div class="rec-title">Lot ${l.num} — ${c?.name} ${this.statusChip(l.lotStatus)}</div>
          </div>
          <div class="rec-actions">
            <button class="sf-btn">Edit</button>
            <button class="sf-btn" data-action="navigate" data-view="community-detail" data-id="${c?.id}">View Community</button>
            <button class="sf-btn primary">+ New Work Order</button>
          </div>
        </div></div>
        <div class="highlights">
          <div><div class="hl-label">Pipeline Bucket</div><div class="hl-value">${this.pipelineBadge(l.bucket)}</div></div>
          <div><div class="hl-label">Lot Status</div><div class="hl-value">${this.statusChip(l.lotStatus)}</div></div>
          <div><div class="hl-label">Community</div><div class="hl-value"><a class="nl" data-action="navigate" data-view="community-detail" data-id="${c?.id}">${c?.name}</a></div></div>
          <div><div class="hl-label">Division</div><div class="hl-value">${div?.name}</div></div>
          <div><div class="hl-label">FM</div><div class="hl-value">${l.fm}</div></div>
          <div><div class="hl-label">Req. Install</div><div class="hl-value amber">${this.fmtDate(l.reqInstall)}</div></div>
        </div>
        <div class="subtabs" data-subtab-root>
          <div class="subtab on"   data-action="subTab" data-prefix="ld" data-tab="details">Details</div>
          <div class="subtab"      data-action="subTab" data-prefix="ld" data-tab="pipeline">Pipeline &amp; Tasks</div>
          <div class="subtab"      data-action="subTab" data-prefix="ld" data-tab="workorders">Work Orders <span class="rm-count ${l.woCount?'has':''}" style="margin-left:4px">${l.woCount||0}</span></div>
          <div class="subtab"      data-action="subTab" data-prefix="ld" data-tab="aqua">Aqua</div>
        </div>
        ${this.refreshRow('lot-detail','Syncs with FSL Mobile in real time')}
        <div id="ld-details" class="sub-tc on"><div class="sf-body"><div class="layout"><div class="layout-main">
          <div class="card info">
            <div class="ch"><div class="ci" style="background:#0070d2">📋</div><h3>Lot Information</h3></div>
            <div class="fields-grid">
              ${buildRow('Lot Record ID', l.lotId, null,null,null)}
              ${buildRow('Lot Number', l.num, 'lot', id, 'num','text')}
              ${buildRow('Community', `<a class="nl" data-action="navigate" data-view="community-detail" data-id="${c?.id}">${c?.name}</a>`,null,null,null)}
              ${buildRow('Division', `<a class="nl">${div?.name}</a>`,null,null,null)}
              ${buildRow('Phase', l.phase,'lot',id,'phase','select',PHASE_OPTS)}
              ${buildRow('Address', l.address,'lot',id,'address','text')}
              ${buildRow('GPS', l.gps,'lot',id,'gps','text')}
              ${buildRow('Lot Status', this.statusChip(l.lotStatus),'lot',id,'lotStatus','select',STATUS_OPTS)}
              ${buildRow('Spec Type', `<span class="chip cgr">${l.specType}</span>`,'lot',id,'specType','select',['Average','Exact','Flexible'])}
              ${buildRow('PO Number', l.po,'lot',id,'po','text')}
              ${buildRow('Requested Install', this.fmtDate(l.reqInstall),'lot',id,'reqInstall','date')}
              ${buildRow('Crew', l.crew||'<span style="color:#c8cdd6">Unassigned</span>','lot',id,'crew','text')}
            </div>
          </div>
          <div class="card last">
            <div class="ch"><div class="ci" style="background:#534ab7">📐</div><h3>Property Details</h3></div>
            <div class="fields-grid">
              ${buildRow('Sod Sq Footage', `${l.sodSf?.toLocaleString()} sf`,'lot',id,'sodSf','text')}
              ${buildRow('Goal Hours', `${l.goalHrs} hrs`,'lot',id,'goalHrs','text')}
              ${buildRow('PO Amount', this.fmtMoney(l.poAmt),'lot',id,'poAmt','text')}
              ${buildRow('Aqua', l.aqua,'lot',id,'aqua','select',['Auto','Installed','N/A','Not Started'])}
              ${buildRow('811 Status', this.eighty11Chip(l.eighty11),'lot',id,'eighty11','select',['Not Filed','Filed','Pending Locate','Marked','Cleared'])}
              ${buildRow('Takeoff', l.takeoff,'lot',id,'takeoff','text')}
            </div>
          </div>
        </div>
        <div class="layout-rail">
          <div class="card">
            <div class="ch"><div class="ci" style="background:#534ab7">🌳</div><h3>Hierarchy</h3></div>
            <div class="hier-tree">
              <div class="hier-node lvl0" data-action="navigate" data-view="accounts"><div class="hier-bullet"></div><a>${bld?.name}</a></div>
              <div class="hier-node lvl1" data-action="navigate" data-view="accounts"><div class="hier-bullet"></div><a>${div?.name}</a></div>
              <div class="hier-node lvl2" data-action="navigate" data-view="community-detail" data-id="${c?.id}"><div class="hier-bullet"></div><a>${c?.name}</a></div>
              <div class="hier-node lvl3"><div class="hier-bullet"></div><a style="font-weight:600;color:#16325c">Lot ${l.num}</a></div>
            </div>
          </div>
          <div class="card last">
            <div class="ch"><div class="ci" style="background:#16325c">🔗</div><h3>Related</h3></div>
            <div class="related-mini"><div style="font-size:12px">📋 Work Orders</div><div class="rm-count ${l.woCount?'has':''}">${l.woCount||0}</div></div>
            <div class="related-mini"><div style="font-size:12px">📷 Photos</div><div class="rm-count ${l.photoCount?'has':''}">${l.photoCount||0}</div></div>
            <div class="related-mini"><div style="font-size:12px">💧 Aqua Ticket</div><div class="rm-count ${l.aqua!=='N/A'?'has':''}">${l.aqua==='N/A'?'0':'1'}</div></div>
            <div class="related-mini"><div style="font-size:12px">🚧 811 Task</div><div class="rm-count has">1</div></div>
          </div>
        </div></div></div></div>
        <div id="ld-pipeline" class="sub-tc"><div class="sf-body">
          <div class="card"><div class="ch"><div class="ci" style="background:#0070d2">📍</div><h3>Pipeline Path</h3></div>
            <div style="display:flex;overflow-x:auto">${pipelineBar}</div></div>
          <div class="card last"><div class="ch"><div class="ci" style="background:#04844b">🚧</div><h3>811 Utility Marking</h3>${this.eighty11Chip(l.eighty11)}</div>
            <div class="status-bar">${e11Bar}</div>
            <div style="padding:8px 14px;font-size:11px;color:#54698d">811 must be Cleared before advancing to Clear for Schedule</div>
          </div>
        </div></div>
        <div id="ld-workorders" class="sub-tc"><div class="sf-body"><div class="card last">
          <div class="ch"><div class="ci" style="background:#0070d2">📋</div><h3>Work Orders — Lot ${l.num}</h3><button class="sf-btn primary" style="margin-left:auto">+ New WO</button></div>
          ${l.woCount ? `<table class="tbl"><thead><tr><th>WO #</th><th>Type</th><th>FM</th><th>Crew</th><th>Status</th><th>Scheduled</th><th class="num">Amount</th></tr></thead><tbody>
            <tr><td class="nl">WO-2026-${1000+parseInt(l.num)||999}</td><td><span style="background:#ede9fe;color:#534ab7;padding:3px 9px;border-radius:12px;font-size:11px">Install</span></td><td>${l.fm}</td><td>${l.crew||'—'}</td><td><span class="chip cg">Approved</span></td><td>${this.fmtDate(l.reqInstall)}</td><td class="num">${this.fmtMoney(l.poAmt)}</td></tr>
          </tbody></table>` : '<div style="padding:20px;color:#54698d;font-size:12px">No work orders yet.</div>'}
        </div></div></div>
        <div id="ld-aqua" class="sub-tc"><div class="sf-body">
          ${c?.aqua ? `<div class="card last"><div class="ch"><div class="ci" style="background:#0a8aa6">💧</div><h3>Aqua Install — Lot ${l.num}</h3>${l.aqua==='Installed'?'<span class="chip cg" style="margin-left:auto">Installed</span>':'<span class="chip ca" style="margin-left:auto">Pending</span>'}</div>
            <div class="fields-grid">
              <div class="field-row"><div class="field-label">Aqua Customer</div><div class="field-value"><span class="chip cg">Yes</span></div></div>
              <div class="field-row"><div class="field-label">Add-on $</div><div class="field-value">${this.fmtMoney(c?.aquaAddon)}</div></div>
              <div class="field-row"><div class="field-label">Status</div><div class="field-value">${l.aqua==='Installed'?'<span class="chip cg">Installed</span>':'<span class="chip ca">Pending</span>'}</div></div>
              <div class="field-row"><div class="field-label">Trigger</div><div class="field-value">Auto (Community.Aqua_Customer__c)</div></div>
            </div></div>` : `<div style="padding:20px 0;font-size:12px;color:#54698d">Aqua is not configured for ${c?.name}.</div>`}
        </div></div>`;
    }
}
