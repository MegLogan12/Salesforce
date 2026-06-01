import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMobileContext from '@salesforce/apex/ForemanMobileController.getMobileContext';
import updateVehicleChecklistItem from '@salesforce/apex/ForemanMobileController.updateVehicleChecklistItem';
import setLoadingCheck from '@salesforce/apex/ForemanMobileController.setLoadingCheck';
import beginDrive from '@salesforce/apex/ForemanMobileController.beginDrive';
import confirmArrival from '@salesforce/apex/ForemanMobileController.confirmArrival';
import startJob from '@salesforce/apex/ForemanMobileController.startJob';
import updateChecklistItem from '@salesforce/apex/ForemanMobileController.updateChecklistItem';
import createIssue from '@salesforce/apex/ForemanMobileController.createIssue';
import saveCloseoutDetails from '@salesforce/apex/ForemanMobileController.saveCloseoutDetails';
import closeoutJob from '@salesforce/apex/ForemanMobileController.closeoutJob';
import uploadJobsitePhoto from '@salesforce/apex/ForemanMobileController.uploadJobsitePhoto';

const STORAGE_KEY = 'loving-foreman-lang';

const LABELS = {
    en: {
        appTitle: 'LOVING Field App',
        appSub: 'Foreman mobile execution',
        refresh: 'Refresh',
        myDay: 'My Day',
        schedule: 'Schedule',
        map: 'Map',
        activeJob: 'Active Job',
        more: 'More',
        syncReady: 'Salesforce + Rippling synced',
        clockedIn: 'Clocked in',
        clockedOut: 'Clocked out',
        syncUnknown: 'Clock sync not available',
        todayAtGlance: 'Today at a glance',
        crewToday: 'Crew today',
        activeWorkOrder: 'Active work order',
        startDrive: 'Start drive',
        driveStarted: 'Drive started',
        openAppleMaps: 'Open Apple Maps',
        openGoogleMaps: 'Open Google Maps',
        confirmArrival: 'Confirm arrival and start job',
        startJob: 'Start job',
        vehicleChecklist: 'Vehicle checklist',
        loadedChecklist: 'Loaded checklist',
        scopePulled: 'Scope pulled from work order line items',
        markLoaded: 'Mark loaded checklist complete',
        markNotLoaded: 'Mark loaded checklist pending',
        beforePhotos: 'Before photos',
        closeoutPhotos: 'Closeout photos',
        workScope: 'Work scope',
        workChecklists: 'Work order checklists',
        noChecklist: 'No checklist is attached to this work order yet.',
        flagIssue: 'Flag issue',
        submitIssue: 'Submit issue',
        issueType: 'Issue type',
        severity: 'Severity',
        summary: 'Summary',
        notes: 'Notes',
        closeout: 'Closeout',
        installedSod: 'Installed sod sqft',
        closeoutNotes: 'Closeout notes',
        saveCloseout: 'Save closeout details',
        submitCloseout: 'Submit to closeout',
        syncStatus: 'Sync status',
        readyToStart: 'Ready to start',
        todaySchedule: "Today's schedule",
        appointment: 'Appointment',
        ripplingStatus: 'Rippling status',
        online: 'Online',
        offline: 'Offline',
        issuePhoto: 'Issue photo',
        actionRequired: 'Action required',
        language: 'Language',
        openIssues: 'Open issues',
        noIssues: 'No open issues on this work order.',
        noJob: 'No active work order assigned.',
        noJobSub: 'Refresh after Dispatch updates the schedule.',
        openJob: 'Open job',
        lineItems: 'line items',
        goalHours: 'Goal hours',
        address: 'Address',
        type: 'Type',
        status: 'Status',
        lot: 'Lot',
        community: 'Community',
        builder: 'Builder',
        truck: 'Truck / device',
        yes: 'Complete',
        no: 'Pending'
    },
    es: {
        appTitle: 'LOVING Field App',
        appSub: 'Ejecucion movil del capataz',
        refresh: 'Actualizar',
        myDay: 'Mi Dia',
        schedule: 'Horario',
        map: 'Mapa',
        activeJob: 'Trabajo activo',
        more: 'Mas',
        syncReady: 'Salesforce + Rippling sincronizados',
        clockedIn: 'Reloj iniciado',
        clockedOut: 'Reloj cerrado',
        syncUnknown: 'Sin estado de reloj',
        todayAtGlance: 'Resumen de hoy',
        crewToday: 'Cuadrilla de hoy',
        activeWorkOrder: 'Orden activa',
        startDrive: 'Empezar traslado',
        driveStarted: 'Traslado iniciado',
        openAppleMaps: 'Abrir Apple Maps',
        openGoogleMaps: 'Abrir Google Maps',
        confirmArrival: 'Confirmar llegada y empezar',
        startJob: 'Empezar trabajo',
        vehicleChecklist: 'Lista del vehiculo',
        loadedChecklist: 'Lista de carga',
        scopePulled: 'Alcance jalado de lineas de trabajo',
        markLoaded: 'Marcar carga completa',
        markNotLoaded: 'Marcar carga pendiente',
        beforePhotos: 'Fotos antes',
        closeoutPhotos: 'Fotos de cierre',
        workScope: 'Alcance de trabajo',
        workChecklists: 'Checklists del trabajo',
        noChecklist: 'No hay checklist adjunta a esta orden.',
        flagIssue: 'Reportar problema',
        submitIssue: 'Enviar problema',
        issueType: 'Tipo',
        severity: 'Severidad',
        summary: 'Resumen',
        notes: 'Notas',
        closeout: 'Cierre',
        installedSod: 'Pies de sod instalados',
        closeoutNotes: 'Notas de cierre',
        saveCloseout: 'Guardar cierre',
        submitCloseout: 'Enviar a cierre',
        syncStatus: 'Estado de sync',
        readyToStart: 'Listo para salir',
        todaySchedule: 'Horario de hoy',
        appointment: 'Cita',
        ripplingStatus: 'Estado de Rippling',
        online: 'En linea',
        offline: 'Sin linea',
        issuePhoto: 'Foto del problema',
        actionRequired: 'Accion requerida',
        language: 'Idioma',
        openIssues: 'Problemas abiertos',
        noIssues: 'No hay problemas abiertos en esta orden.',
        noJob: 'No hay orden activa asignada.',
        noJobSub: 'Actualiza despues de cambios de despacho.',
        openJob: 'Abrir trabajo',
        lineItems: 'lineas',
        goalHours: 'Horas meta',
        address: 'Direccion',
        type: 'Tipo',
        status: 'Estado',
        lot: 'Lote',
        community: 'Comunidad',
        builder: 'Builder',
        truck: 'Camion / dispositivo',
        yes: 'Completo',
        no: 'Pendiente'
    }
};

export default class LovingForemanMobile extends LightningElement {
    @api recordId;

    context;
    loading = true;
    busy = false;
    isOnline = true;
    activeTab = 'myDay';
    lang = 'en';
    issueDraft = {
        issueType: 'Other',
        severity: 'Medium',
        summary: '',
        notes: ''
    };
    closeoutDraft = {
        installedSodSqft: '',
        closeoutNotes: ''
    };

    connectedCallback() {
        this.isOnline = typeof navigator === 'undefined' ? true : navigator.onLine;
        window.addEventListener('online', this.handleConnectivityChange);
        window.addEventListener('offline', this.handleConnectivityChange);
        this.loadLanguage();
        this.loadContext();
    }

    disconnectedCallback() {
        window.removeEventListener('online', this.handleConnectivityChange);
        window.removeEventListener('offline', this.handleConnectivityChange);
    }

    get t() {
        return LABELS[this.lang] || LABELS.en;
    }

    get hasJob() {
        return !!this.currentJob?.id;
    }

    get currentJob() {
        return this.context?.activeJob;
    }

    get scheduleRows() {
        return (this.context?.schedule || []).map((row) => ({
            ...row,
            timeLabel: this.formatDateTime(row.scheduledStart),
            rowClass: row.isActive ? 'job-card active' : 'job-card'
        }));
    }

    get schedulePreviewRows() {
        return this.scheduleRows.slice(0, 3);
    }

    get vehicleItems() {
        return (this.context?.vehicleChecklist?.items || []).map((item) => ({
            ...item,
            rowClass: item.complete ? 'check-row done' : 'check-row',
            statusLabel: item.complete ? this.t.yes : this.t.no
        }));
    }

    get lineItems() {
        return (this.context?.lineItems || []).map((item) => ({
            ...item,
            quantityLabel: item.quantity ? `${item.quantity}` : '',
            goalLabel: item.goalMinutes ? `${item.goalMinutes} min` : ''
        }));
    }

    get checklistGroups() {
        return (this.context?.workOrderChecklists || []).map((group) => ({
            ...group,
            progressLabel: `${group.completedCount}/${group.requiredCount || group.items.length}`
        }));
    }

    get beforeSlots() {
        return this.context?.photoSummary?.beforeSlots || [];
    }

    get closeoutSlots() {
        return this.context?.photoSummary?.closeoutSlots || [];
    }

    get openIssues() {
        return this.context?.openIssues || [];
    }

    get hasIssues() {
        return this.openIssues.length > 0;
    }

    get hasChecklists() {
        return this.checklistGroups.length > 0;
    }

    get hasLineItems() {
        return this.lineItems.length > 0;
    }

    get loadedChecklistComplete() {
        return this.context?.loadedChecklist?.complete;
    }

    get loadingChecklistLabel() {
        return this.loadedChecklistComplete ? this.t.markNotLoaded : this.t.markLoaded;
    }

    get clockTone() {
        if (this.context?.clockStatus?.clockedIn) {
            return 'clock in';
        }
        return 'clock out';
    }

    get clockLabel() {
        if (!this.context?.clockStatus) {
            return this.t.syncUnknown;
        }
        return this.context.clockStatus.clockedIn ? this.t.clockedIn : this.t.clockedOut;
    }

    get clockSubLabel() {
        const status = this.context?.clockStatus;
        if (!status?.lastSync) {
            return this.t.syncUnknown;
        }
        return `${this.t.syncReady} · ${this.formatDateTime(status.lastSync)}`;
    }

    get beginDriveDisabled() {
        return this.busy || !this.context?.canBeginDrive;
    }

    get submitCloseoutDisabled() {
        return this.busy || !this.context?.canSubmitCloseout;
    }

    get beginDriveReason() {
        return this.context?.beginDriveReason;
    }

    get startJobReason() {
        if ((this.context?.photoSummary?.beforeCount || 0) < 4) {
            return '4 before photos are required before starting the job.';
        }
        if (this.currentJob?.latitude && this.currentJob?.longitude && !navigator.geolocation) {
            return 'Device location is required to confirm arrival.';
        }
        return '';
    }

    get startJobDisabled() {
        return this.busy || !!this.startJobReason;
    }

    get closeoutGates() {
        return this.context?.closeoutGates || [];
    }

    get currentAddress() {
        const parts = [this.currentJob?.address, this.currentJob?.cityStateZip].filter(Boolean);
        return parts.join(', ');
    }

    get goalHoursLabel() {
        const goal = this.currentJob?.goalHours;
        return goal || goal === 0 ? `${goal}` : '--';
    }

    get beforeCountLabel() {
        return `${this.context?.photoSummary?.beforeCount || 0}/4`;
    }

    get afterCountLabel() {
        return `${this.context?.photoSummary?.afterCount || 0}/4`;
    }

    get isMyDay() {
        return this.activeTab === 'myDay';
    }

    get isSchedule() {
        return this.activeTab === 'schedule';
    }

    get isMap() {
        return this.activeTab === 'map';
    }

    get isActiveJob() {
        return this.activeTab === 'activeJob';
    }

    get isMore() {
        return this.activeTab === 'more';
    }

    get issueTypeOptions() {
        return [
            'Site Blocked',
            'Material Missing',
            'Material Damaged',
            'Sod Quality Issue',
            'Customer or Builder Blocker',
            'Weather Delay',
            'Access Issue',
            'Safety Issue',
            'Scope Mismatch',
            'Need FM Review',
            'Cannot Complete Line Item'
        ];
    }

    get severityOptions() {
        return ['Low', 'Medium', 'High', 'Critical'];
    }

    get issueDisabled() {
        return this.busy || !this.issueDraft.summary?.trim();
    }

    get syncStatusLabel() {
        return this.isOnline ? this.t.online : this.t.offline;
    }

    get myDayTabClass() {
        return this.tabClassFor('myDay');
    }

    get scheduleTabClass() {
        return this.tabClassFor('schedule');
    }

    get mapTabClass() {
        return this.tabClassFor('map');
    }

    get activeJobTabClass() {
        return this.tabClassFor('activeJob');
    }

    get moreTabClass() {
        return this.tabClassFor('more');
    }

    async loadContext() {
        this.loading = true;
        try {
            this.context = await getMobileContext({ workOrderId: this.recordId });
            this.closeoutDraft.installedSodSqft = this.currentJob?.installedSodSqft || '';
            this.closeoutDraft.closeoutNotes = this.currentJob?.closeoutNotes || '';
        } catch (error) {
            this.toast('Load failed', this.reduceError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    loadLanguage() {
        try {
            const saved = window.localStorage.getItem(STORAGE_KEY);
            if (saved && LABELS[saved]) {
                this.lang = saved;
            }
        } catch (e) {
            // Ignore storage errors.
        }
    }

    saveLanguage() {
        try {
            window.localStorage.setItem(STORAGE_KEY, this.lang);
        } catch (e) {
            // Ignore storage errors.
        }
    }

    handleRefresh() {
        this.loadContext();
    }

    handleTabChange(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleLanguageToggle() {
        this.lang = this.lang === 'en' ? 'es' : 'en';
        this.saveLanguage();
    }

    handleConnectivityChange = () => {
        this.isOnline = navigator.onLine;
    };

    async handleVehicleToggle(event) {
        const item = this.vehicleItems.find((row) => row.key === event.currentTarget.dataset.key);
        if (!item) {
            return;
        }
        await this.runMutation(async () => {
            await updateVehicleChecklistItem({
                workOrderId: this.currentJob.id,
                itemKey: item.key,
                complete: !item.complete,
                truckNumber: this.context?.vehicleChecklist?.truckNumber || '',
                notes: this.context?.vehicleChecklist?.notes || ''
            });
            await this.loadContext();
        }, 'Vehicle checklist updated');
    }

    async handleLoadingToggle() {
        await this.runMutation(async () => {
            await setLoadingCheck({
                workOrderId: this.currentJob.id,
                complete: !this.loadedChecklistComplete
            });
            await this.loadContext();
        }, 'Loaded checklist updated');
    }

    async handleChecklistChange(event) {
        const checklistItemId = event.currentTarget.dataset.id;
        const status = event.target.value;
        await this.runMutation(async () => {
            await updateChecklistItem({
                checklistItemId,
                status,
                notes: null
            });
            await this.loadContext();
        }, 'Checklist item updated');
    }

    async handleBeginDrive() {
        await this.runMutation(async () => {
            await beginDrive({ workOrderId: this.currentJob.id });
            await this.loadContext();
        }, 'Drive started');
    }

    async handleStartJob() {
        await this.runMutation(async () => {
            if (this.currentJob?.latitude && this.currentJob?.longitude) {
                const coords = await this.requestLocation();
                await confirmArrival({
                    workOrderId: this.currentJob.id,
                    lat: coords.latitude,
                    lng: coords.longitude
                });
            } else {
                await startJob({ workOrderId: this.currentJob.id });
            }
            await this.loadContext();
        }, 'Job started');
    }

    handleIssueInput(event) {
        const field = event.target.dataset.field;
        this.issueDraft = {
            ...this.issueDraft,
            [field]: event.target.value
        };
    }

    async handleSubmitIssue() {
        await this.runMutation(async () => {
            await createIssue({
                workOrderId: this.currentJob.id,
                issueType: this.issueDraft.issueType,
                severity: this.issueDraft.severity,
                summary: this.issueDraft.summary,
                notes: this.issueDraft.notes
            });
            this.issueDraft = {
                issueType: 'Other',
                severity: 'Medium',
                summary: '',
                notes: ''
            };
            await this.loadContext();
        }, 'Issue submitted');
    }

    handleCloseoutInput(event) {
        const field = event.target.dataset.field;
        this.closeoutDraft = {
            ...this.closeoutDraft,
            [field]: event.target.value
        };
    }

    async handleSaveCloseout() {
        await this.runMutation(async () => {
            await saveCloseoutDetails({
                workOrderId: this.currentJob.id,
                installedSodSqft: this.closeoutDraft.installedSodSqft ? Number(this.closeoutDraft.installedSodSqft) : null,
                closeoutNotes: this.closeoutDraft.closeoutNotes
            });
            await this.loadContext();
        }, 'Closeout details saved');
    }

    async handleSubmitCloseout() {
        await this.runMutation(async () => {
            await closeoutJob({ workOrderId: this.currentJob.id });
            await this.loadContext();
        }, 'Closeout submitted');
    }

    async handlePhotoUpload(event) {
        const file = event.target.files?.[0];
        const category = event.target.dataset.category;
        if (!file || !category) {
            return;
        }
        await this.runMutation(async () => {
            const base64Body = await this.readFileAsBase64(file);
            await uploadJobsitePhoto({
                workOrderId: this.currentJob.id,
                fileName: file.name,
                base64Body,
                contentType: file.type,
                photoCategory: category
            });
            await this.loadContext();
            event.target.value = null;
        }, 'Photo uploaded');
    }

    handleOpenMaps(event) {
        const provider = event.currentTarget.dataset.provider;
        const lat = this.currentJob?.latitude;
        const lng = this.currentJob?.longitude;
        const address = encodeURIComponent(this.currentAddress || this.currentJob?.lotName || '');
        const coordQuery = lat && lng ? `${lat},${lng}` : address;

        let url = `https://www.google.com/maps/search/?api=1&query=${coordQuery}`;
        if (provider === 'apple') {
            url = `https://maps.apple.com/?q=${coordQuery}`;
        }
        window.open(url, '_blank');
    }

    tabClassFor(tabName) {
        return this.activeTab === tabName ? 'tab-btn active' : 'tab-btn';
    }

    async runMutation(work, successMessage) {
        this.busy = true;
        try {
            await work();
            if (successMessage) {
                this.toast(successMessage, '', 'success');
            }
        } catch (error) {
            this.toast('Action failed', this.reduceError(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    requestLocation() {
        return new Promise((resolve, reject) => {
            if (!navigator.geolocation) {
                reject(new Error('Device location is not available.'));
                return;
            }
            navigator.geolocation.getCurrentPosition(
                (position) => resolve(position.coords),
                (error) => reject(new Error(error.message || 'Unable to read device location.')),
                { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
            );
        });
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = reader.result || '';
                const base64 = String(result).split(',')[1];
                resolve(base64);
            };
            reader.onerror = () => reject(new Error('Unable to read file.'));
            reader.readAsDataURL(file);
        });
    }

    formatDateTime(value) {
        if (!value) {
            return '--';
        }
        return new Intl.DateTimeFormat(undefined, {
            month: 'short',
            day: 'numeric',
            hour: 'numeric',
            minute: '2-digit'
        }).format(new Date(value));
    }

    reduceError(error) {
        return error?.body?.message || error?.message || 'Unknown error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}