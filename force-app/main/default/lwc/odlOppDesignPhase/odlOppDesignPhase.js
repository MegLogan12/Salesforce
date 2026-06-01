import { LightningElement, api } from 'lwc';

export default class OdlOppDesignPhase extends LightningElement {
    @api pageData;

    get designFeeStatus() {
        return this.pageData?.designFeeStatus ?? 'Not Charged';
    }

    get designFeeDisplay() {
        const status = this.designFeeStatus;
        if (status === 'Paid') return '$179 — Paid';
        if (status === 'Waived') return 'Waived';
        if (status === 'Charged') return '$179 — Awaiting Payment';
        return 'Not charged';
    }

    get designFeeClass() {
        const status = this.designFeeStatus;
        if (status === 'Paid') return 'dps-value dps-value-green';
        if (status === 'Waived') return 'dps-value dps-value-blue';
        if (status === 'Charged') return 'dps-value dps-value-amber';
        return 'dps-value dps-value-gray';
    }

    get designFeePaidDate() {
        return this.pageData?.designFeePaidDate ?? null;
    }

    get showFeeNote() {
        return this.designFeeStatus === 'Waived';
    }

    get feeNote() {
        return 'Design fee waived for this customer.';
    }

    get designStatusLabel() {
        return this.pageData?.opportunityRecord?.Design_Status__c ?? null;
    }

    get designStatusClass() {
        const status = this.designStatusLabel;
        if (status === 'Approved') return 'design-badge design-badge-green';
        if (status === 'In Review') return 'design-badge design-badge-amber';
        if (status === 'Rejected') return 'design-badge design-badge-red';
        return 'design-badge design-badge-gray';
    }

    get designStatusChipClass() {
        return this.designStatusClass;
    }

    get designLink() {
        return this.pageData?.opportunityRecord?.Design_Link__c ?? null;
    }

    get noDesign() {
        return !this.designLink && (!this.designStatusLabel || this.designStatusLabel === 'Not Started');
    }
}
