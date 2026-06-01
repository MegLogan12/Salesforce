import { LightningElement, api, wire } from 'lwc';
import getWorkOrder from '@salesforce/apex/ODLWorkOrderController.getWorkOrder';

export default class OdlWorkOrderPhotos extends LightningElement {
    @api recordId;
    photos;
    error;

    @wire(getWorkOrder, { recordId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.photos = data.photos;
            this.error = undefined;
        } else if (error) {
            this.error = this.reduceError(error);
            this.photos = undefined;
        }
    }

    // Counts are pulled from the maintained count fields on Work_Order__c.
    // These are capture counts against the minimum — never stock images.
    get tiles() {
        if (!this.photos) {
            return [];
        }
        const p = this.photos;
        return [
            this.tile('Takeoff', p.takeoffCount, p.takeoffMin, p.takeoffStatus, 'Minimum 1 required'),
            this.tile('Progress', p.progressCount, null, p.progressStatus, 'No minimum, encouraged daily'),
            this.tile('Closeout', p.closeoutCount, p.closeoutMin, p.closeoutStatus, 'Minimum 4 required to complete')
        ];
    }

    tile(name, count, min, status, requirement) {
        return {
            name,
            count: count === null || count === undefined ? '—' : count,
            requirement,
            status,
            statusClass: this.statusClass(status)
        };
    }

    statusClass(status) {
        if (status === 'Met') return 'pt-status met';
        if (status === 'Ongoing') return 'pt-status ongoing';
        return 'pt-status pending';
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        } else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return 'An unexpected error occurred.';
    }
}
