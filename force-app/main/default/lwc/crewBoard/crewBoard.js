import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTomorrowsCrews from '@salesforce/apex/CrewAssignController.getTomorrowsCrews';
import assignRig from '@salesforce/apex/CrewAssignController.assignRig';

export default class CrewBoard extends LightningElement {
    @api division;
    @track crews = [];
    error;
    isLoading = true;

    // Store wired result for refreshApex
    _wiredCrews;
    // Map of crewId -> { truck, vehicle } for pending input values
    _inputs = {};

    @wire(getTomorrowsCrews, { division: '$division' })
    wiredCrews(result) {
        this._wiredCrews = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.crews = data.map(c => ({
                ...c,
                isAssigned: !!(c.truckNumber && c.vehicle),
                inputTruck: '',
                inputVehicle: '',
                isSaving: false
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message ?? error?.message ?? 'An error occurred loading crews.';
            this.crews = [];
        }
    }

    get crewCount() {
        return this.crews.length;
    }

    get assignedCount() {
        return this.crews.filter(c => c.isAssigned).length;
    }

    get unassignedCount() {
        return this.crews.filter(c => !c.isAssigned).length;
    }

    get unassignedBadgeClass() {
        return this.unassignedCount > 0
            ? 'slds-badge slds-badge_error'
            : 'slds-badge';
    }

    get hasCrews() {
        return this.crews.length > 0;
    }

    handleTruckChange(event) {
        const crewId = event.target.dataset.crewId;
        if (!this._inputs[crewId]) this._inputs[crewId] = {};
        this._inputs[crewId].truck = event.target.value;
    }

    handleVehicleChange(event) {
        const crewId = event.target.dataset.crewId;
        if (!this._inputs[crewId]) this._inputs[crewId] = {};
        this._inputs[crewId].vehicle = event.target.value;
    }

    async handleAssign(event) {
        const crewId = event.target.dataset.crewId;
        const inputs = this._inputs[crewId] ?? {};
        const truckNumber = inputs.truck ?? '';
        const vehicle = inputs.vehicle ?? '';

        // Mark crew as saving
        this.crews = this.crews.map(c =>
            c.id === crewId ? { ...c, isSaving: true } : c
        );

        try {
            await assignRig({ crewId, truckNumber, vehicle });
            // Clear pending inputs for this crew
            this._inputs[crewId] = {};
            await refreshApex(this._wiredCrews);
        } catch (err) {
            this.error = err?.body?.message ?? err?.message ?? 'Failed to assign rig.';
            // Un-mark saving state on failure
            this.crews = this.crews.map(c =>
                c.id === crewId ? { ...c, isSaving: false } : c
            );
        }
    }
}
