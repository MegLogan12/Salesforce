import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTodayDispatch from '@salesforce/apex/DispatchMapController.getTodayDispatch';

const STATUS_CLASSES = {
    Scheduled:  'tc-status status-scheduled',
    Dispatched: 'tc-status status-dispatched',
    'In Progress': 'tc-status status-inprogress',
    Completed:  'tc-status status-completed',
};

export default class LovingDispatchMap extends LightningElement {
    @track trucks = [];
    @track mapMarkers = [];
    @track error;
    @track isLoading = true;

    wiredResult;

    mapCenter = {
        location: { Latitude: 35.13, Longitude: -80.82 }
    };

    todayLabel = new Date().toLocaleDateString('en-US', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
    });

    get activeCount() { return this.trucks.length; }
    get hasTrucks()   { return this.trucks.length > 0; }

    @wire(getTodayDispatch)
    wiredDispatch(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            const rows = result.data.filter(t => t.unitName && !t.unitName.startsWith('UAT'));

            this.trucks = rows.map(t => ({
                ...t,
                driverName:  t.driverName  || 'Unassigned',
                statusClass: STATUS_CLASSES[t.status] || 'tc-status status-other',
            }));

            this.mapMarkers = rows
                .filter(t => t.lat != null && t.lng != null)
                .map(t => ({
                    location:    { Latitude: t.lat, Longitude: t.lng },
                    title:       `${t.unitName} — ${t.driverName || 'Unassigned'}`,
                    description: `${t.subject || ''}\n${t.street || ''}, ${t.city || ''}\n${t.schedTime || ''} • ${t.status || ''}`,
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