import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTodayDispatch from '@salesforce/apex/DispatchMapController.getTodayDispatch';

const STATUS_CLASSES = {
    Active:   'tc-status status-dispatched',
    Delayed:  'tc-status status-inprogress',
    Offline:  'tc-status status-other',
    Unknown:  'tc-status status-other',
};

const REFRESH_INTERVAL_MS = 60000; // 60 seconds

export default class LovingDispatchMap extends LightningElement {
    @track trucks     = [];
    @track mapMarkers = [];
    @track error;
    @track isLoading  = true;

    wiredResult;
    _refreshTimer;

    mapCenter = {
        location: { Latitude: 35.13, Longitude: -80.82 }
    };

    todayLabel = new Date().toLocaleDateString('en-US', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
    });

    get activeCount() { return this.trucks.length; }
    get hasTrucks()   { return this.trucks.length > 0; }

    connectedCallback() {
        this._refreshTimer = setInterval(() => {
            refreshApex(this.wiredResult);
        }, REFRESH_INTERVAL_MS);
    }

    disconnectedCallback() {
        if (this._refreshTimer) clearInterval(this._refreshTimer);
    }

    @wire(getTodayDispatch)
    wiredDispatch(result) {
        this.wiredResult = result;
        this.isLoading   = false;
        if (result.data) {
            this.trucks = result.data.map(t => ({
                ...t,
                driverName:  t.driverName  || 'Unassigned',
                statusClass: STATUS_CLASSES[t.status] || 'tc-status status-other',
                schedTime:   t.lastSeen    || '—',
            }));

            this.mapMarkers = this.trucks
                .filter(t => t.lat != null && t.lng != null)
                .map(t => ({
                    location:    { Latitude: t.lat, Longitude: t.lng },
                    title:       `${t.unitName} — ${t.driverName}`,
                    description: `${t.subject || ''}\n${t.street || ''}, ${t.city || ''}\nGPS: ${t.status} · Last seen ${t.lastSeen || '—'}`,
                }));

            this.error = undefined;
        } else if (result.error) {
            this.error = (result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Failed to load dispatch data.';
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => { this.isLoading = false; });
    }
}
