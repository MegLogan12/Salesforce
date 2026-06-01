import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import NAME from '@salesforce/schema/Lot__c.Name';
import LOT_NUMBER from '@salesforce/schema/Lot__c.Lot_Number__c';
import STATUS from '@salesforce/schema/Lot__c.Status__c';
import STREET_ADDRESS from '@salesforce/schema/Lot__c.Street_Address__c';
import REQUESTED_INSTALL_DATE from '@salesforce/schema/Lot__c.Requested_Install_Date__c';
import INSTALL_DATE from '@salesforce/schema/Lot__c.Install_Date__c';
import PLANT_PACKAGE from '@salesforce/schema/Lot__c.Plant_Package__c';
import PACKAGE_NOTES from '@salesforce/schema/Lot__c.Package_Override_Notes__c';

const FIELDS = [
    NAME,
    LOT_NUMBER,
    STATUS,
    STREET_ADDRESS,
    REQUESTED_INSTALL_DATE,
    INSTALL_DATE,
    PLANT_PACKAGE,
    PACKAGE_NOTES
];

const STATUS_ORDER = ['Available', 'Pending', 'Scheduled', 'In Production', 'Complete', 'Closed'];

export default class LotLifecycleTimeline extends LightningElement {
    @api recordId;
    record;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = data;
            this.error = undefined;
        } else if (error) {
            this.record = undefined;
            this.error = (error.body && error.body.message) ? error.body.message : 'Unable to load lot timeline.';
        }
    }

    get isLoaded() {
        return !!this.record;
    }

    get hasError() {
        return !!this.error;
    }

    get name() {
        return getFieldValue(this.record, NAME) || 'Lot';
    }

    get lotNumber() {
        return getFieldValue(this.record, LOT_NUMBER) || null;
    }

    get statusValue() {
        return getFieldValue(this.record, STATUS) || '';
    }

    get statusLabel() {
        return this.statusValue || 'Not Set';
    }

    get address() {
        return getFieldValue(this.record, STREET_ADDRESS) || '';
    }

    get hasAddress() {
        return !!this.address;
    }

    get requestedInstallDisplay() {
        return this.formatDate(getFieldValue(this.record, REQUESTED_INSTALL_DATE));
    }

    get installDateDisplay() {
        return this.formatDate(getFieldValue(this.record, INSTALL_DATE));
    }

    get plantPackage() {
        return getFieldValue(this.record, PLANT_PACKAGE) || '';
    }

    get hasPlantPackage() {
        return !!this.plantPackage;
    }

    get notes() {
        return getFieldValue(this.record, PACKAGE_NOTES) || '';
    }

    get hasNotes() {
        return !!this.notes;
    }

    get statusSteps() {
        const normalizedStatus = this.statusValue.toLowerCase();
        let currentIndex = STATUS_ORDER.findIndex((label) => normalizedStatus.includes(label.toLowerCase()));
        if (currentIndex === -1) {
            currentIndex = 0;
        }

        return STATUS_ORDER.map((label, index) => {
            let cssClass = 'step';
            if (index < currentIndex) {
                cssClass = 'step done';
            } else if (index === currentIndex) {
                cssClass = 'step current';
            }
            return {
                label,
                cssClass
            };
        });
    }

    get statusChipClass() {
        const normalizedStatus = this.statusValue.toLowerCase();
        if (normalizedStatus.includes('complete')) return 'chip status-complete';
        if (normalizedStatus.includes('closed')) return 'chip status-closed';
        if (normalizedStatus.includes('production')) return 'chip status-production';
        if (normalizedStatus.includes('schedul')) return 'chip status-scheduled';
        if (normalizedStatus.includes('pend')) return 'chip status-pending';
        return 'chip status-default';
    }

    formatDate(value) {
        if (!value) {
            return 'Not yet recorded';
        }
        return new Date(value).toLocaleDateString(undefined, {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }
}