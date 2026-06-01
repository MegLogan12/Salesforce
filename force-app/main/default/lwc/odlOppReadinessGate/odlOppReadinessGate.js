import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class OdlOppReadinessGate extends NavigationMixin(LightningElement) {
    @api readiness;
    @api recordId;

    get hasReadiness() { return Boolean(this.readiness); }
    get releaseDisabled() { return !this.readiness?.woReady; }
    get releaseButtonTitle() {
        return this.readiness?.woReady
            ? 'Release Work Order'
            : 'Blocked until contract and deposit requirements are complete.';
    }
    get releaseButtonClass() {
        return this.readiness?.woReady ? 'btn-release btn-release-active' : 'btn-release';
    }

    get voucherGateClass() {
        return this.readiness?.voucherLinked ? 'gate-row gate-pass' : 'gate-row gate-neutral';
    }
    get quoteGateClass() {
        return this.readiness?.quoteAccepted ? 'gate-row gate-pass' : 'gate-row gate-fail';
    }
    get contractGateClass() {
        return this.readiness?.contractSigned ? 'gate-row gate-pass' : 'gate-row gate-fail';
    }
    get depositGateClass() {
        return this.readiness?.depositPaid ? 'gate-row gate-pass' : 'gate-row gate-fail';
    }

    get voucherCheck() { return this.readiness?.voucherLinked ? '✓' : '○'; }
    get quoteCheck() { return this.readiness?.quoteAccepted ? '✓' : '✗'; }
    get contractCheck() { return this.readiness?.contractSigned ? '✓' : '✗'; }
    get depositCheck() { return this.readiness?.depositPaid ? '✓' : '✗'; }

    get quoteStatusClass() {
        const s = this.readiness?.quoteStatus;
        if (s === 'Accepted') return 'chip chip-green';
        if (s === 'Sent') return 'chip chip-amber';
        if (s === 'Rejected') return 'chip chip-red';
        return 'chip chip-gray';
    }

    get contractStatusClass() {
        const s = this.readiness?.contractStatus;
        if (s === 'Signed') return 'chip chip-green';
        if (s === 'Sent') return 'chip chip-amber';
        return 'chip chip-gray';
    }

    handleReleaseWo() {
        if (!this.recordId || !this.readiness?.woReady) return;
        // Navigate to the Work Order creation/release flow
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'view' }
        });
    }
}
