import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class OdlOppEngagementHealth extends NavigationMixin(LightningElement) {
    @api engagement;
    @api opportunityId;

    get hasState() {
        return Boolean(this.engagement?.state) && this.engagement.state !== 'N/A';
    }

    get isClosed() {
        return this.engagement?.state === 'N/A';
    }

    get stateLabelText() {
        return this.engagement?.stateLabel ?? '';
    }

    get cardClass() {
        const base = 'engagement-card';
        const modifier = this.engagement?.stateClass ?? 'engagement-active';
        return `${base} ${modifier}`;
    }

    get stateBadgeClass() {
        const base = 'engagement-badge';
        const modifier = this.engagement?.stateClass ?? 'engagement-active';
        return `${base} ${modifier}`;
    }

    get daysSinceDisplay() {
        if (this.engagement?.daysSinceResponse == null) return '—';
        return String(this.engagement.daysSinceResponse);
    }

    get outreachDisplay() {
        return String(this.engagement?.outreachAttemptsSince ?? 0);
    }

    get lastResponseDate() {
        return this.engagement?.lastResponseDate ?? null;
    }

    get callToAction() {
        return this.engagement?.callToAction ?? null;
    }

    handleMoveToNurture() {
        this.dispatchEvent(new CustomEvent('movenurture', { bubbles: true, composed: true }));
    }

    handleMarkLost() {
        this.dispatchEvent(new CustomEvent('marklost', {
            bubbles: true,
            composed: true,
            detail: { lossReason: 'No Decision / Non-Responsive' }
        }));
    }
}
