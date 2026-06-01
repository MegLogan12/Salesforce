import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Work_Order__c cross-object fields (Lot address fields already in production)
import WO_LOT_NAME        from '@salesforce/schema/Work_Order__c.Lot__r.Name';
import WO_LOT_STREET      from '@salesforce/schema/Work_Order__c.Lot__r.Street_Address__c';
import WO_LOT_CITY        from '@salesforce/schema/Work_Order__c.Lot__r.City__c';
import WO_LOT_STATE       from '@salesforce/schema/Work_Order__c.Lot__r.State__c';
import WO_LOT_LAT         from '@salesforce/schema/Work_Order__c.Lot__r.Lot_Latitude__c';
import WO_COMMUNITY_NAME  from '@salesforce/schema/Work_Order__c.Community__r.Name';

const WO_FIELDS = [
    WO_LOT_NAME, WO_LOT_STREET, WO_LOT_CITY, WO_LOT_STATE,
    WO_LOT_LAT, WO_COMMUNITY_NAME
];

export default class LovingRouteButton extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api labelOverride = 'Navigate to Job Site';

    @track _record;
    @track _error;

    get cardLabel() {
        return this.labelOverride || 'Navigate to Job Site';
    }

    get isLoading() {
        return !this._record && !this._error;
    }

    // Wire only for Work_Order__c pages.
    // ServiceAppointment support requires LOVING_Work_Order__c to be deployed first;
    // add SA targets after Phase 5 deploy confirms that field is live.
    @wire(getRecord, { recordId: '$recordId', fields: WO_FIELDS })
    wiredWO({ data, error }) {
        if (data)  { this._record = data; this._error = null; }
        if (error) { this._error = error; this._record = null; }
    }

    // ── Field accessors ──────────────────────────────────────────────────────

    get lotName() {
        return this._record ? getFieldValue(this._record, WO_LOT_NAME) : null;
    }

    get street() {
        return this._record ? getFieldValue(this._record, WO_LOT_STREET) : null;
    }

    get city() {
        return this._record ? getFieldValue(this._record, WO_LOT_CITY) : null;
    }

    get state() {
        return this._record ? getFieldValue(this._record, WO_LOT_STATE) : null;
    }

    get latitude() {
        return this._record ? getFieldValue(this._record, WO_LOT_LAT) : null;
    }

    get communityName() {
        return this._record ? getFieldValue(this._record, WO_COMMUNITY_NAME) : null;
    }

    // ── Destination string ───────────────────────────────────────────────────

    get destination() {
        // Prefer street address when available
        if (this.street && this.city && this.state) {
            return [this.street, this.city, this.state].join(', ');
        }
        // Fall back to lot + community name (Google Maps / Waze text search works reliably)
        const parts = [];
        if (this.lotName)       parts.push(this.lotName);
        if (this.communityName) parts.push(this.communityName);
        if (this.city)          parts.push(this.city);
        if (this.state)         parts.push(this.state);
        return parts.length ? parts.join(', ') : null;
    }

    get hasDestination() {
        return !!this.destination;
    }

    get destinationLabel() {
        return this.destination;
    }

    get hasCoordinates() {
        return !!this.latitude;
    }

    get latLngLabel() {
        return this.latitude ? `GPS: ${this.latitude}` : '';
    }

    // ── Deep link URLs ───────────────────────────────────────────────────────

    get googleMapsUrl() {
        if (!this.destination) return '#';
        return `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(this.destination)}`;
    }

    get wazeUrl() {
        if (!this.destination) return '#';
        return `https://waze.com/ul?q=${encodeURIComponent(this.destination)}&navigate=yes`;
    }

    get appleMapsUrl() {
        if (!this.destination) return '#';
        return `https://maps.apple.com/?daddr=${encodeURIComponent(this.destination)}&dirflg=d`;
    }
}