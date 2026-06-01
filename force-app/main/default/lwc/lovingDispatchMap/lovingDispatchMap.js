import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTodayDispatch from '@salesforce/apex/DispatchMapController.getTodayDispatch';

const STATUS_CLASSES = {
    Active:   'tc-status status-dispatched',
    Delayed:  'tc-status status-inprogress',
    Offline:  'tc-status status-other',
    Unknown:  'tc-status status-other',
};

const TERRITORY_COORDS = {
    'Charlotte Metro':  { lat: 35.2271, lon: -80.8431, label: 'Charlotte Metro' },
    'Charlotte - North':{ lat: 35.3271, lon: -80.7431, label: 'Charlotte North' },
    'Triad':            { lat: 36.0726, lon: -79.7920, label: 'Triad' },
    'Triangle':         { lat: 35.7796, lon: -78.6382, label: 'Triangle' },
    'Greenville':       { lat: 34.8526, lon: -82.3940, label: 'Greenville' },
    'Upstate SC':       { lat: 34.9496, lon: -81.9319, label: 'Upstate SC' },
    'Columbia':         { lat: 34.0007, lon: -81.0348, label: 'Columbia' },
    'Midlands SC':      { lat: 34.0007, lon: -81.0348, label: 'Midlands SC' },
    'Asheville':        { lat: 35.5951, lon: -82.5515, label: 'Asheville' },
    'Western NC':       { lat: 35.5951, lon: -82.5515, label: 'Western NC' },
};
const DEFAULT_TERRITORY = 'Charlotte Metro';

const REFRESH_INTERVAL_MS = 60000;

export default class LovingDispatchMap extends LightningElement {
    @api territory;
    @track trucks     = [];
    @track mapMarkers = [];
    @track error;
    @track isLoading  = true;

    wiredResult;
    _refreshTimer;

    get _coords() {
        const key = this.territory && TERRITORY_COORDS[this.territory]
            ? this.territory
            : DEFAULT_TERRITORY;
        return TERRITORY_COORDS[key];
    }

    get territoryLabel() {
        return this._coords.label;
    }

    get mapCenter() {
        return { location: { Latitude: this._coords.lat, Longitude: this._coords.lon } };
    }

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
