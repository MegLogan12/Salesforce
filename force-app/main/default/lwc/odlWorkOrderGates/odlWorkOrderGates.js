import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWorkOrder from '@salesforce/apex/ODLWorkOrderController.getWorkOrder';
import completeJob from '@salesforce/apex/ODLWorkOrderController.completeJob';

export default class OdlWorkOrderGates extends LightningElement {
    @api recordId;
    @track view;
    error;
    completing = false;
    _wired;

    @wire(getWorkOrder, { recordId: '$recordId' })
    wired(result) {
        this._wired = result;
        if (result.data) {
            this.view = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = this.reduceError(result.error);
            this.view = undefined;
        }
    }

    get hasData() {
        return !!this.view;
    }

    get readinessLabel() {
        return this.view && this.view.readyToComplete ? 'Ready to complete' : 'Not ready to complete';
    }

    get readinessClass() {
        return this.view && this.view.readyToComplete
            ? 'gate-badge ready'
            : 'gate-badge notready';
    }

    get completeDisabled() {
        return this.completing || !this.view || !this.view.readyToComplete;
    }

    get completeReason() {
        if (!this.view) {
            return '';
        }
        return this.view.readyToComplete
            ? 'All required gates pass. The job can be completed.'
            : 'Blocked until all required gates pass: ' + (this.view.blocker || '');
    }

    get gates() {
        if (!this.view) {
            return [];
        }
        return this.view.gates.map((g) => ({
            ...g,
            iconName: this.gateIcon(g),
            iconVariant: this.gateIconVariant(g),
            statusText: this.gateStatus(g)
        }));
    }

    get steps() {
        if (!this.view) {
            return [];
        }
        return this.view.stepper.map((s) => ({
            ...s,
            cssClass: 'step ' + s.state
        }));
    }

    get hasScope() {
        return this.view && this.view.scope && this.view.scope.length > 0;
    }

    gateIcon(g) {
        if (g.passed) return 'utility:check';
        if (g.flag) return 'utility:info';
        return 'utility:dash';
    }

    gateIconVariant(g) {
        if (g.passed) return 'success';
        if (g.required) return 'warning';
        return '';
    }

    gateStatus(g) {
        if (g.passed) return 'Done';
        if (g.flag) return 'Not confirmed';
        return g.required ? 'Pending' : 'Optional';
    }

    handleComplete() {
        this.completing = true;
        completeJob({ recordId: this.recordId })
            .then((data) => {
                this.view = data;
                return refreshApex(this._wired);
            })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Work order completed',
                        message: 'All required gates passed and the job was marked complete.',
                        variant: 'success'
                    })
                );
            })
            .catch((e) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Cannot complete job',
                        message: this.reduceError(e),
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.completing = false;
            });
    }

    handleRefresh() {
        return refreshApex(this._wired);
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
