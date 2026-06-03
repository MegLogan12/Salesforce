import { LightningElement, track, wire, api } from 'lwc';
import getQueue from '@salesforce/apex/LawnCareQueueController.getQueue';

// Status badge colour mapping
const STATUS_CLASSES = {
    'New':                'slds-badge slds-badge_lightest',
    'Ready to Schedule':  'slds-badge slds-theme_shade',
    'Scheduled':          'slds-badge slds-theme_shade',
    'In Progress':        'slds-badge slds-theme_warning',
    'On Hold':            'slds-badge slds-theme_warning',
    'Cannot Complete':    'slds-badge slds-theme_error',
    'Completed':          'slds-badge slds-theme_success',
    'Cancelled':          'slds-badge slds-badge_lightest'
};

export default class LawnCareQueue extends LightningElement {
    /** Future week navigation (0 = current week; positive = weeks ahead). */
    @api weekOffset = 0;

    @track view;
    @track isLoading = true;
    @track error;

    @wire(getQueue)
    wiredData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.view  = this._enrichRows(data);
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : String(error);
            this.view  = undefined;
        }
    }

    // ── Derived getters ──────────────────────────────────────────────────────

    get hasRows() {
        return this.view && this.view.rows && this.view.rows.length > 0;
    }

    get unassignedChipClass() {
        return (this.view && this.view.unassigned > 0)
            ? 'slds-badge slds-theme_warning slds-m-right_x-small'
            : 'slds-badge slds-badge_lightest slds-m-right_x-small';
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    _enrichRows(data) {
        const rows = (data.rows || []).map(r => ({
            ...r,
            crewDisplay:           r.isUnassigned ? 'Unassigned' : (r.crewName || 'Unknown Crew'),
            crewClass:             r.isUnassigned
                ? 'slds-badge slds-theme_warning'
                : 'slds-text-body_small',
            statusBadgeClass:      STATUS_CLASSES[r.status] || 'slds-badge slds-badge_lightest',
            scheduledDateFormatted: r.scheduledDate
                ? new Date(r.scheduledDate).toLocaleDateString('en-US', {
                    month: 'short', day: 'numeric', year: 'numeric'
                  })
                : null
        }));
        return { ...data, rows };
    }
}
