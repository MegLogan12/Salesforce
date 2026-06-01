import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getHomeData       from '@salesforce/apex/AquaConsoleController.getHomeData';
import getTodayInstalls  from '@salesforce/apex/AquaConsoleController.getTodayInstalls';
import getInstallScope   from '@salesforce/apex/AquaConsoleController.getInstallScope';
import getTechRoutes     from '@salesforce/apex/AquaConsoleController.getTechRoutes';
import getSameDayQueue   from '@salesforce/apex/AquaConsoleController.getSameDayQueue';
import getInventoryData  from '@salesforce/apex/AquaConsoleController.getInventoryData';
import getCommunityData  from '@salesforce/apex/AquaConsoleController.getCommunityData';
import getWateringData   from '@salesforce/apex/AquaConsoleController.getWateringData';
import getCloseoutQueue  from '@salesforce/apex/AquaConsoleController.getCloseoutQueue';
import getPickupData              from '@salesforce/apex/AquaConsoleController.getPickupData';
import getPickupReconciliation    from '@salesforce/apex/AquaConsoleController.getPickupReconciliation';
import applyRunTimePct   from '@salesforce/apex/AquaConsoleController.applyRunTimePct';
import updateWateringSchedule from '@salesforce/apex/AquaConsoleController.updateWateringSchedule';
import approveCloseout   from '@salesforce/apex/AquaConsoleController.approveCloseout';
import returnNfi         from '@salesforce/apex/AquaConsoleController.returnNfi';
import resolveTicket     from '@salesforce/apex/AquaConsoleController.resolveTicket';
import createSameDayRepair from '@salesforce/apex/AquaConsoleController.createSameDayRepair';
import bulkRetrieveEndOfSeason from '@salesforce/apex/AquaConsoleController.bulkRetrieveEndOfSeason';
import reassignPickup    from '@salesforce/apex/AquaConsoleController.reassignPickup';
import reoptimizeRoutes  from '@salesforce/apex/AquaConsoleController.reoptimizeRoutes';
import addShopStop       from '@salesforce/apex/AquaConsoleController.addShopStop';

// Tab definitions — frozen from CLAUDE.md
const TABS = [
    { id: 'home',       label: '🏠 Home',                    hasBadge: false,  urgentWhenPositive: false },
    { id: 'installs',   label: '💧 Installs Today',           hasBadge: true,   urgentWhenPositive: false },
    { id: 'routes',     label: '🗺 Field Routes',             hasBadge: true,   urgentWhenPositive: false },
    { id: 'sameday',    label: '🚨 Same-Day',                 hasBadge: true,   urgentWhenPositive: true  },
    { id: 'inventory',  label: '📦 Inventory',                hasBadge: false,  urgentWhenPositive: false },
    { id: 'assign',     label: '👤 FM Assignments',           hasBadge: false,  urgentWhenPositive: false },
    { id: 'water',      label: '🌡 Watering Schedule',        hasBadge: false,  urgentWhenPositive: false },
    { id: 'closeout',   label: '✓ Closeout Queue',            hasBadge: true,   urgentWhenPositive: false },
    { id: 'pickup',     label: '📅 End-of-Season Pickup',     hasBadge: false,  urgentWhenPositive: false }
];

export default class LovingAquaConsole extends NavigationMixin(LightningElement) {

    @api pageTitle = 'Aqua Service Console';
    @track activeTab = 'home';

    // ── Wired results ───────────────────────────────────────────────────
    _wiredHome;
    _homeData    = null;
    _homeError   = null;

    _wiredInstalls;
    _installs    = null;
    _wiredScope;
    _scope       = null;

    _wiredRoutes;
    _techRoutes  = null;

    _wiredSameDay;
    _sameDayQueue = null;

    _wiredInv;
    _invData     = null;

    _wiredComm;
    _commData    = null;

    _wiredWater;
    _waterData   = null;

    _wiredCloseout;
    _closeoutQueue = null;

    _wiredPickup;
    _pickupData  = null;

    _wiredRecon;
    _reconData   = null;
    @track _selectedPickupId = null;

    // ── Watering adjustment state ────────────────────────────────────────
    @track _newRunTimePct = 70;
    @track _selectedWaterScheduleType = 'Seasonal Monthly';
    @track _selectedWaterScheduleKey = null;
    @track _selectedWaterFrequency = '';
    @track _selectedWaterDurationMin = null;
    @track _actionInFlight = false;

    // ── Filter state ────────────────────────────────────────────────────
    @track _installFilter = 'All';
    @track _closeoutFilter = 'All';

    // ─────────────────────────────────────────────────────────────────────
    // WIRE ADAPTERS
    // ─────────────────────────────────────────────────────────────────────

    @wire(getHomeData)
    wiredHome(result) {
        this._wiredHome = result;
        const { data, error } = result;
        if (data)  { this._homeData  = data;  this._homeError = null; }
        else if (error) { this._homeError = this._errMsg(error); }
    }

    @wire(getTodayInstalls)
    wiredInstalls(result) {
        this._wiredInstalls = result;
        const { data, error } = result;
        if (data)  this._installs = data;
        else if (error) this._installs = [];
    }

    @wire(getInstallScope)
    wiredScope(result) {
        this._wiredScope = result;
        const { data } = result;
        if (data) this._scope = data;
    }

    @wire(getTechRoutes)
    wiredRoutes(result) {
        this._wiredRoutes = result;
        const { data } = result;
        if (data) this._techRoutes = data;
    }

    @wire(getSameDayQueue)
    wiredSameDay(result) {
        this._wiredSameDay = result;
        const { data } = result;
        if (data) this._sameDayQueue = data;
    }

    @wire(getInventoryData)
    wiredInv(result) {
        this._wiredInv = result;
        const { data } = result;
        if (data) this._invData = data;
    }

    @wire(getCommunityData)
    wiredComm(result) {
        this._wiredComm = result;
        const { data } = result;
        if (data) this._commData = data;
    }

    @wire(getWateringData)
    wiredWater(result) {
        this._wiredWater = result;
        const { data } = result;
        if (data) {
            this._waterData = data;
            this._selectedWaterScheduleType = data.currentScheduleType || 'Seasonal Monthly';
            this._selectedWaterScheduleKey = data.currentScheduleKey || null;
            this._syncWaterSelectionFromData();
        }
    }

    @wire(getCloseoutQueue)
    wiredCloseout(result) {
        this._wiredCloseout = result;
        const { data } = result;
        if (data) this._closeoutQueue = data;
    }

    @wire(getPickupData)
    wiredPickup(result) {
        this._wiredPickup = result;
        const { data } = result;
        if (data) this._pickupData = data;
    }

    @wire(getPickupReconciliation, { pickupTicketId: '$_selectedPickupId' })
    wiredRecon(result) {
        this._wiredRecon = result;
        const { data } = result;
        if (data) this._reconData = data;
    }

    // ─────────────────────────────────────────────────────────────────────
    // LIFECYCLE — live GPS sync polling
    // ─────────────────────────────────────────────────────────────────────

    _refreshTimer;

    connectedCallback() {
        // Refresh GPS-dependent wires every 60 s so the map panel stays in
        // sync with the 3-minute WexGpsSyncScheduler backend chain.
        this._refreshTimer = setInterval(() => {
            if (this._wiredRoutes) refreshApex(this._wiredRoutes);
            if (this._wiredHome)   refreshApex(this._wiredHome);
            if (this._wiredSameDay) refreshApex(this._wiredSameDay);
        }, 60000);
    }

    disconnectedCallback() {
        if (this._refreshTimer) {
            clearInterval(this._refreshTimer);
            this._refreshTimer = null;
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // TAB MANAGEMENT
    // ─────────────────────────────────────────────────────────────────────

    handleTabClick(evt) {
        evt.preventDefault();
        evt.stopPropagation();
        this.activeTab = evt.currentTarget.dataset.tab;
    }

    get tabs() {
        const d = this._homeData || {};
        const badges = {
            installs: d.kpiInstallsToday || 0,
            routes:   d.kpiChecksToday   || 0,
            sameday:  d.kpiSameDay        || 0,
            closeout: d.kpiAwaitingCloseout || 0
        };
        return TABS.map(t => {
            const isActive  = t.id === this.activeTab;
            const badgeVal  = t.hasBadge ? (badges[t.id] || 0) : 0;
            const isUrgent  = t.urgentWhenPositive && badgeVal > 0;
            let css = 'sf-tab';
            if (isActive) css += ' on';
            if (isUrgent) css += ' urgent';
            const badgeLabel = t.id === 'routes'
                ? (badgeVal + ' communities')
                : String(badgeVal);
            return {
                ...t,
                css,
                badgeVal,
                badgeLabel,
                showBadge: t.hasBadge
            };
        });
    }

    // Tab visibility booleans
    get showHomeTab()      { return this.activeTab === 'home'; }
    get showInstallsTab()  { return this.activeTab === 'installs'; }
    get showRoutesTab()    { return this.activeTab === 'routes'; }
    get showSameDayTab()   { return this.activeTab === 'sameday'; }
    get showInventoryTab() { return this.activeTab === 'inventory'; }
    get showAssignTab()    { return this.activeTab === 'assign'; }
    get showWaterTab()     { return this.activeTab === 'water'; }
    get showCloseoutTab()  { return this.activeTab === 'closeout'; }
    get showPickupTab()    { return this.activeTab === 'pickup'; }

    // ─────────────────────────────────────────────────────────────────────
    // HOME TAB GETTERS
    // ─────────────────────────────────────────────────────────────────────

    get homeData()     { return this._homeData || {}; }
    get homeLoading()  { return this._homeData == null && this._homeError == null; }
    get homeError()    { return this._homeError; }
    get teamMembers()  { return (this._homeData && this._homeData.teamMembers) ? this._homeData.teamMembers : []; }
    get installsToday() { return (this._homeData && this._homeData.installsToday) ? this._homeData.installsToday : []; }
    get sameDayRepairs(){ return (this._homeData && this._homeData.sameDayRepairs) ? this._homeData.sameDayRepairs : []; }
    get techStatus()   { return (this._homeData && this._homeData.techStatus) ? this._homeData.techStatus : []; }
    get inventoryAlerts(){ return (this._homeData && this._homeData.inventoryAlerts) ? this._homeData.inventoryAlerts : []; }
    get tamperFlags()  { return (this._homeData && this._homeData.tamperFlags) ? this._homeData.tamperFlags : []; }
    get activityFeed() { return (this._homeData && this._homeData.activity) ? this._homeData.activity : []; }
    get hasTechStatus()    { return this.techStatus.length > 0; }
    get hasInvAlerts()     { return this.inventoryAlerts.length > 0; }
    get hasTamperFlags()   { return this.tamperFlags.length > 0; }
    get hasActivity()      { return this.activityFeed.length > 0; }

    get sameDayCardTitle() {
        const n = (this._homeData && this._homeData.kpiSameDay) ? this._homeData.kpiSameDay : 0;
        return 'Same-Day Repairs · ' + n;
    }

    get homeTitle() {
        return 'Aqua Service';
    }

    get homeSubtitle() {
        return 'Field manager schedule coverage and community watering operations';
    }

    get wateringRailTitle() {
        const m = (this._homeData && this._homeData.wateringCurrentMonthLabel) ? this._homeData.wateringCurrentMonthLabel : '';
        return m ? `Watering Schedule · ${m}` : 'Watering Schedule';
    }

    get teamLeadTitle() {
        const fmName = (this._homeData && this._homeData.fmName) ? this._homeData.fmName : '';
        return fmName ? `Lead field manager · ${fmName}` : '0 field managers assigned';
    }

    get routesSubtitle() {
        const fmName = (this._homeData && this._homeData.fmName) ? this._homeData.fmName : '';
        return fmName ? `Field manager route lead · ${fmName}` : '0 field managers assigned to active routes';
    }

    get inventorySubtitle() {
        const synced = (this._invData && this._invData.lastSynced) ? this._invData.lastSynced : '';
        return synced ? `Last synced ${synced}` : '0 inventory sync timestamps recorded';
    }

    get assignmentsSubtitle() {
        return 'Live community ownership, service days, and field-manager coverage';
    }

    get wateringSubtitle() {
        return 'Community-by-community watering coverage first, then live schedule controls';
    }

    get closeoutSubtitle() {
        const count = (this._homeData && this._homeData.kpiAwaitingCloseout) ? this._homeData.kpiAwaitingCloseout : 0;
        return `${count} tickets awaiting closeout`;
    }

    // ─────────────────────────────────────────────────────────────────────
    // INSTALLS TODAY TAB
    // ─────────────────────────────────────────────────────────────────────

    get installsLoading() { return this._installs == null; }

    get filteredInstalls() {
        const all = this._installs || [];
        if (this._installFilter === 'All') return all;
        return all.filter(r => r.statusLabel === this._installFilter);
    }

    get installFilterChips() {
        return ['All','In Progress','Scheduled','Completed'].map(f => ({
            label: f,
            css: 'filter-chip' + (this._installFilter === f ? ' on' : '')
        }));
    }

    get scopeRows() { return this._scope || []; }
    get totalScopeRow() {
        return this._scope ? this._scope.find(r => r.isTotal) : null;
    }
    get standardScopeRows() {
        return this._scope ? this._scope.filter(r => !r.isTotal) : [];
    }

    handleInstallFilterClick(evt) {
        this._installFilter = evt.currentTarget.dataset.label;
    }

    // ─────────────────────────────────────────────────────────────────────
    // CHECK ROUTES TAB
    // ─────────────────────────────────────────────────────────────────────

    get routesLoading() { return this._techRoutes == null; }
    get techRoutes()    { return this._techRoutes || []; }

    // Compute SVG triangle points for each tech pin
    get techRouteMap() {
        return (this._techRoutes || []).map((t, idx) => {
            const x = t.svgX != null ? Number(t.svgX) : 340;
            const y = t.svgY != null ? Number(t.svgY) : 140;
            const pts = (x - 8) + ',' + (y + 16) + ' ' + x + ',' + y + ' ' + (x + 8) + ',' + (y + 16);
            return {
                ...t,
                svgPoints: pts,
                labelX: x + 12,
                labelY: y + 4
            };
        });
    }

    get techRoutesWithStops() {
        return (this._techRoutes || []).map(t => ({
            ...t,
            stops: (t.stops || []).map(s => ({
                ...s,
                stopNumClass: s.isComplete ? 'stop-num complete' : s.isCurrent ? 'stop-num current' : 'stop-num upcoming',
                stopNumLabel: s.isComplete ? '✓' : s.isCurrent ? '●' : String(s.stopNum || '')
            }))
        }));
    }

    // ─────────────────────────────────────────────────────────────────────
    // SAME-DAY TAB
    // ─────────────────────────────────────────────────────────────────────

    get sameDayLoading() { return this._sameDayQueue == null; }
    get sameDayQueue()   { return this._sameDayQueue || []; }
    get hasSameDayTickets() { return this.sameDayQueue.length > 0; }

    // ─────────────────────────────────────────────────────────────────────
    // INVENTORY TAB
    // ─────────────────────────────────────────────────────────────────────

    get invLoading() { return this._invData == null; }
    get invData()    { return this._invData || {}; }

    get invPartRows() {
        return ((this._invData && this._invData.partRows) ? this._invData.partRows : []).map(r => ({
            ...r,
            shopStyle:   'width:' + (r.shopPct   || 0).toFixed(1) + '%',
            vanStyle:    'width:' + (r.vanPct    || 0).toFixed(1) + '%',
            onsiteStyle: 'width:' + (r.onsitePct || 0).toFixed(1) + '%',
            rowBg: r.isBelowThreshold ? 'background:#fffbeb' : ''
        }));
    }

    get invVanRows() {
        return (this._invData && this._invData.vanRows) ? this._invData.vanRows : [];
    }

    get invLogRows() {
        return (this._invData && this._invData.logRows) ? this._invData.logRows : [];
    }

    get vanPartHeaders() {
        const rows = this.invVanRows;
        if (!rows || rows.length === 0) return [];
        const first = rows[0];
        return first.partCounts ? first.partCounts.map(p => p.itemType) : [];
    }

    // ─────────────────────────────────────────────────────────────────────
    // COMMUNITY ASSIGNMENTS TAB
    // ─────────────────────────────────────────────────────────────────────

    get commLoading() { return this._commData == null; }
    get commData()    { return this._commData || {}; }
    get communityRows()   { return (this._commData && this._commData.communityRows) ? this._commData.communityRows : []; }
    get techCapacityRows(){ return (this._commData && this._commData.techCapacityRows) ? this._commData.techCapacityRows : []; }
    get techOptions()     { return (this._commData && this._commData.techOptions) ? this._commData.techOptions : []; }

    // ─────────────────────────────────────────────────────────────────────
    // WATERING SCHEDULE TAB
    // ─────────────────────────────────────────────────────────────────────

    get waterLoading() { return this._waterData == null; }
    get waterData()    { return this._waterData || {}; }
    get waterMonths()  { return (this._waterData && this._waterData.months) ? this._waterData.months : []; }
    get waterHistory() { return (this._waterData && this._waterData.history) ? this._waterData.history : []; }
    get waterPrograms() { return (this._waterData && this._waterData.programs) ? this._waterData.programs : []; }
    get waterScheduleTypeOptions() { return (this._waterData && this._waterData.scheduleTypeOptions) ? this._waterData.scheduleTypeOptions : []; }
    get waterFrequencyOptions() { return (this._waterData && this._waterData.frequencyOptions) ? this._waterData.frequencyOptions : []; }
    get waterAffectedLots() { return (this._waterData && this._waterData.affectedLots) ? this._waterData.affectedLots : 0; }
    get selectedWaterProgram() {
        return this.waterPrograms.find((program) => program.scheduleKey === this._selectedWaterScheduleKey) || null;
    }
    get waterPeriodOptions() {
        return this.waterPrograms
            .filter((program) => program.scheduleType === this._selectedWaterScheduleType)
            .map((program) => ({ label: program.periodLabel, value: program.scheduleKey }));
    }
    get waterCurrentPct()   {
        const program = this.selectedWaterProgram;
        return program && program.runTimePct != null
            ? program.runTimePct
            : ((this._waterData && this._waterData.currentMonthPct) ? this._waterData.currentMonthPct : 0);
    }
    get waterCurrentPctLabel() { return this.waterCurrentPct + '%'; }
    get waterCurrentPeriodLabel() {
        const program = this.selectedWaterProgram;
        return program ? program.periodLabel : ((this._waterData && this._waterData.currentMonthName) ? this._waterData.currentMonthName : 'Current Period');
    }
    get waterAdjustTitle() {
        const program = this.selectedWaterProgram;
        return program ? ('Adjust watering schedule — ' + program.periodLabel) : 'Adjust watering schedule';
    }
    get waterServiceDayNote() {
        return (this._waterData && this._waterData.serviceDayNote)
            ? this._waterData.serviceDayNote
            : '0 Aqua communities are tagged with service days in the current schedule scope.';
    }

    get isOffSeason() {
        const months = this.waterMonths;
        const cur = months.find(m => m.isCurrent);
        return cur ? cur.isOff : false;
    }

    get offSeasonResumeMonth() {
        const first = this.waterMonths.find(m => !m.isOff);
        return first ? first.monthName : '';
    }

    get sodSliderStyle() {
        const pct = this._newRunTimePct || 0;
        // Brown (dry) at 0 % → amber at 40 % → green (healthy) at 100 %
        return 'width:100%;margin:10px 0;accent-color:#04844b;'
            + 'background:linear-gradient(to right,'
            + '#7c4a1e 0%,'
            + '#fe9339 ' + (pct * 0.4).toFixed(1) + '%,'
            + '#04844b ' + pct.toFixed(1) + '%,'
            + '#e0e0e0 ' + pct.toFixed(1) + '%,'
            + '#e0e0e0 100%);'
            + 'border-radius:4px;height:6px;appearance:none;cursor:pointer;';
    }
    get waterWarnLabel() {
        return '⚠ This will update ' + this.waterAffectedLots + ' active check tickets for ' +
            ((this._waterData && this._waterData.currentMonthName) ? this._waterData.currentMonthName : 'this month');
    }
    get newRunTimePct()   { return this._newRunTimePct; }
    get newRunTimePctLabel() { return this._newRunTimePct + '%'; }

    get waterGridTitle() {
        const yr = (this._waterData && this._waterData.year) ? this._waterData.year : '';
        return yr ? `Schedule Controls · ${yr}` : 'Schedule Controls';
    }
    get waterCoverageTitle() {
        return `Community watering coverage — ${this.waterCurrentPeriodLabel}`;
    }
    get communityWateringRows() {
        const scheduledPct = this.waterCurrentPct;
        return this.communityRows.map((row) => ({
            ...row,
            scheduledPctLabel: `${scheduledPct}%`,
            serviceDaysLabel: row.serviceDays || 'No service days set',
            activeLotsLabel: row.activeLots != null ? row.activeLots : 0,
            fieldManagerLabel: row.primaryTechName || '—',
            scheduleTypeLabel: this._selectedWaterScheduleType || 'Seasonal Monthly',
            runDurationLabel: this._selectedWaterDurationMin != null ? `${this._selectedWaterDurationMin} min` : '—',
            frequencyLabel: this._selectedWaterFrequency || '—'
        }));
    }

    handleRangeChange(evt) {
        this._newRunTimePct = Number(evt.target.value);
    }

    handleWaterScheduleTypeChange(evt) {
        this._selectedWaterScheduleType = evt.target.value;
        const options = this.waterPeriodOptions;
        this._selectedWaterScheduleKey = options.length ? options[0].value : null;
        this._syncWaterSelectionFromData();
    }

    handleWaterPeriodChange(evt) {
        this._selectedWaterScheduleKey = evt.target.value;
        this._syncWaterSelectionFromData();
    }

    handleWaterFrequencyChange(evt) {
        this._selectedWaterFrequency = evt.target.value;
    }

    handleWaterDurationChange(evt) {
        const value = evt.target.value;
        this._selectedWaterDurationMin = value === '' ? null : Number(value);
    }

    handleApplyRunTime() {
        if (this._actionInFlight) return;
        this._actionInFlight = true;
        const program = this.selectedWaterProgram;
        if (!program) {
            this._actionInFlight = false;
            this._toast('Not available', 'Select a watering schedule first.', 'info');
            return;
        }
        updateWateringSchedule({
            scheduleType: this._selectedWaterScheduleType,
            monthName: program.monthName,
            weekNumber: program.weekNumber,
            runFrequency: this._selectedWaterFrequency,
            runDurationMin: this._selectedWaterDurationMin,
            runTimePct: this._newRunTimePct
        })
            .then(() => {
                this._actionInFlight = false;
                this._toast('Schedule updated', 'The selected watering schedule was updated.', 'success');
                return refreshApex(this._wiredWater);
            })
            .catch(e => {
                this._actionInFlight = false;
                this._toast('Error', this._errMsg(e), 'error');
            });
    }

    _syncWaterSelectionFromData() {
        const program = this.selectedWaterProgram
            || this.waterPrograms.find((row) => row.scheduleType === this._selectedWaterScheduleType)
            || null;
        if (program) {
            this._selectedWaterScheduleKey = program.scheduleKey;
            this._newRunTimePct = program.runTimePct != null ? Number(program.runTimePct) : 0;
            this._selectedWaterFrequency = program.runFrequency || '';
            this._selectedWaterDurationMin = program.runDurationMin != null ? Number(program.runDurationMin) : null;
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // CLOSEOUT QUEUE TAB
    // ─────────────────────────────────────────────────────────────────────

    get closeoutLoading() { return this._closeoutQueue == null; }

    get closeoutFilterChips() {
        return ['All','Pending Photos','Pending Notes','Pending Inventory','Pending Approval'].map(f => ({
            label: f,
            css: 'filter-chip' + (this._closeoutFilter === f ? ' on' : '')
        }));
    }

    get filteredCloseout() {
        return this._closeoutQueue || [];
    }

    get closeoutQueueTitle() {
        const n = (this._closeoutQueue) ? this._closeoutQueue.length : 0;
        return 'Closeout Queue — ' + n + ' pending';
    }

    get closeoutWithChecks() {
        return (this._closeoutQueue || []).map(t => ({
            ...t,
            deviceClass:    t.isDeviceInstalled   ? 'ok' : 'nok',
            deviceIcon:     t.isDeviceInstalled   ? '✓' : '✗',
            timerClass:     t.isTimerTested        ? 'ok' : 'nok',
            timerIcon:      t.isTimerTested        ? '✓' : '✗',
            coverageClass:  t.isCoverageVerified   ? 'ok' : 'nok',
            coverageIcon:   t.isCoverageVerified   ? '✓' : '✗',
            photosClass:    t.isPhotosUploaded     ? 'ok' : 'nok',
            photosIcon:     t.isPhotosUploaded     ? '✓' : '✗',
            notesClass:     t.isCloseoutNotes      ? 'ok' : 'nok',
            notesIcon:      t.isCloseoutNotes      ? '✓' : '✗',
            inventoryClass: t.isInventoryRecorded  ? 'ok' : 'nok',
            inventoryIcon:  t.isInventoryRecorded  ? '✓' : '✗',
            approveBtnCss:  t.isCloseoutReady      ? 'sf-btn success' : 'sf-btn success',
            approveDisabled: !t.isCloseoutReady
        }));
    }

    handleCloseoutFilterClick(evt) {
        this._closeoutFilter = evt.currentTarget.dataset.label;
    }

    handleApproveCloseout(evt) {
        const id   = evt.currentTarget.dataset.id;
        const type = evt.currentTarget.dataset.type;
        if (this._actionInFlight) return;
        this._actionInFlight = true;
        approveCloseout({ ticketId: id, ticketType: type })
            .then(() => {
                this._actionInFlight = false;
                this._toast('Closeout approved', 'Ticket closed successfully.', 'success');
                return refreshApex(this._wiredCloseout);
            })
            .catch(e => {
                this._actionInFlight = false;
                this._toast('Error', this._errMsg(e), 'error');
            });
    }

    handleReturnNfi(evt) {
        const id   = evt.currentTarget.dataset.id;
        const type = evt.currentTarget.dataset.type;
        if (this._actionInFlight) return;
        this._actionInFlight = true;
        returnNfi({ ticketId: id, ticketType: type })
            .then(() => {
                this._actionInFlight = false;
                this._toast('Returned as NFI', 'Ticket returned to field owner.', 'warning');
                return refreshApex(this._wiredCloseout);
            })
            .catch(e => {
                this._actionInFlight = false;
                this._toast('Error', this._errMsg(e), 'error');
            });
    }

    // ─────────────────────────────────────────────────────────────────────
    // PICKUP TAB
    // ─────────────────────────────────────────────────────────────────────

    get pickupLoading() { return this._pickupData == null; }
    get pickupData()    { return this._pickupData || {}; }
    get pickupRows()    { return (this._pickupData && this._pickupData.pickupRows) ? this._pickupData.pickupRows : []; }

    get seasonTitle() {
        const d = this._pickupData || {};
        return (d.seasonYear || '') + ' Aqua Season — Day ' + (d.seasonDay || 0) + ' of ' + (d.seasonTotal || 0);
    }

    get pickupQueueTitle() {
        const n = this.pickupRows.length;
        return 'Pending pickup queue (' + n + ' lots — Home Closed flow)';
    }

    get retrieveDisabled() {
        const d = this._pickupData || {};
        return (d.seasonDaysUntilRetrieve || 0) > 0;
    }

    get retrieveSubLabel() {
        const d = this._pickupData || {};
        const days = d.seasonDaysUntilRetrieve || 0;
        return days > 0
            ? 'Currently disabled — ' + days + ' days until season end'
            : 'Season active — use with authorization';
    }

    get reconciliationData()  { return this._reconData || {}; }
    get reconciliationRows()  { return (this._reconData && this._reconData.rows) ? this._reconData.rows : []; }
    get reconciliationClean() { return this._reconData ? this._reconData.isClean : true; }
    get hasVarianceFlagRow()  { return this._reconData ? !this._reconData.isClean : false; }

    get varianceRows() {
        return this.reconciliationRows.filter(r => r.hasMissing);
    }

    get varianceData() {
        const d = this._reconData || {};
        return {
            cmName:        d.cmName        || 'Community Manager',
            estimatedBill: d.estimatedBill != null ? Number(d.estimatedBill).toFixed(2) : '0.00'
        };
    }

    get selectedPickupLot() {
        const row = (this.pickupRows || []).find(r => r.id === this._selectedPickupId);
        return row ? row.lotCommunity : 'Select a ticket';
    }

    handleSelectPickup(evt) {
        this._selectedPickupId = evt.currentTarget.dataset.id;
    }

    // ─────────────────────────────────────────────────────────────────────
    // ACTIONS
    // ─────────────────────────────────────────────────────────────────────

    handleMarkResolved(evt) {
        const id = evt.currentTarget.dataset.id;
        if (this._actionInFlight) return;
        this._actionInFlight = true;
        resolveTicket({ ticketId: id })
            .then(() => {
                this._actionInFlight = false;
                this._toast('Resolved', 'Ticket marked as resolved.', 'success');
                return Promise.all([
                    refreshApex(this._wiredSameDay),
                    refreshApex(this._wiredHome)
                ]);
            })
            .catch(e => {
                this._actionInFlight = false;
                this._toast('Error', this._errMsg(e), 'error');
            });
    }

    handleNavToRecord(evt) {
        const recordId = evt.currentTarget.dataset.id;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    handleNavToTab(evt) {
        evt.preventDefault();
        evt.stopPropagation();
        const tab = evt.currentTarget.dataset.target;
        if (tab) this.activeTab = tab;
    }

    handleRetrieveAll() {
        bulkRetrieveEndOfSeason()
            .then(() => {
                this._toast('Retrieve All Complete', 'Pickup tickets created for all active lots.', 'success');
                return refreshApex(this._wiredPickup);
            })
            .catch(err => {
                this._toast('Retrieve Failed', err.body ? err.body.message : String(err), 'error');
            });
    }

    handleNewAquaTicket() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Aqua_Install_Ticket__c', actionName: 'new' }
        });
    }

    handleManageTeam() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Employee__c', actionName: 'list' }
        });
    }

    handleNewInstallTicket() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Aqua_Install_Ticket__c', actionName: 'new' }
        });
    }

    handleNewCheckTicket() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Aqua_Check_Ticket__c', actionName: 'new' }
        });
    }

    handleNewSameDayRepair() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Aqua_Check_Ticket__c', actionName: 'new' }
        });
    }

    handleReoptimizeRoutes() {
        reoptimizeRoutes()
            .then(() => {
                this._toast('Re-Optimization Requested', 'Route optimization submitted. Refresh routes in a moment.', 'success');
                return refreshApex(this._wiredRoutes);
            })
            .catch(err => {
                this._toast('Re-Optimization Failed', err.body ? err.body.message : String(err), 'error');
            });
    }

    handleCallContact(evt) {
        const id = evt.currentTarget.dataset.id;
        const ticket = (this._sameDayQueue || []).find(t => t.id === id);
        if (ticket && ticket.contactPhone) {
            window.open('tel:' + ticket.contactPhone);
        } else {
            this._toast('Contact', 'Open the ticket record to view contact details.', 'info');
        }
    }

    handleViewTechLocation() {
        this.activeTab = 'routes';
    }

    handleCreateInvAdjustment() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Aqua_Inventory_Adjustment__c', actionName: 'new' }
        });
    }

    handleExport() {
        const rows = this.invPartRows || [];
        if (!rows.length) {
            this._toast('Export', '0 inventory records are available to export.', 'info');
            return;
        }
        const headers = ['Item', 'Total Qty', 'Shop Qty', 'Van Qty', 'On-Site Qty', 'Below Threshold'];
        const csv = [
            headers.join(','),
            ...rows.map((row) => ([
                row.itemName,
                row.totalQty,
                row.shopQty,
                row.vanQty,
                row.onsiteQty,
                row.isBelowThreshold ? 'Yes' : 'No'
            ]).map((value) => this._csvValue(value)).join(','))
        ].join('\n');
        const link = document.createElement('a');
        link.href = `data:text/csv;charset=utf-8,${encodeURIComponent(csv)}`;
        link.download = `aqua-inventory-${new Date().toISOString().slice(0, 10)}.csv`;
        link.click();
    }

    handleApproveAllEligible() {
        const eligible = (this._closeoutQueue || []).filter(t => t.isCloseoutReady);
        if (eligible.length === 0) {
            this._toast('None eligible', '0 tickets currently meet every closeout requirement.', 'warning');
            return;
        }
        if (this._actionInFlight) return;
        this._actionInFlight = true;
        const promises = eligible.map(t => approveCloseout({ ticketId: t.id, ticketType: t.ticketType }));
        Promise.all(promises)
            .then(() => {
                this._actionInFlight = false;
                this._toast('Approved', eligible.length + ' closeout tickets approved.', 'success');
                return refreshApex(this._wiredCloseout);
            })
            .catch(e => {
                this._actionInFlight = false;
                this._toast('Error', this._errMsg(e), 'error');
            });
    }

    // ─────────────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────────────

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _errMsg(err) {
        if (typeof err === 'string') return err;
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'Unexpected error.';
    }

    _csvValue(value) {
        const text = value == null ? '' : String(value);
        return `"${text.replace(/"/g, '""')}"`;
    }
}