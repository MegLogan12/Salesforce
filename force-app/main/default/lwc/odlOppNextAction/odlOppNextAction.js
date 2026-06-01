import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class OdlOppNextAction extends NavigationMixin(LightningElement) {
    @api nextActionText = '';
    @api nextActionButton = '';
    @api recordId;
    @api woReady = false;
    @api engagementState = '';

    get hasButton() {
        return Boolean(this.nextActionButton);
    }

    get isGoingDark() {
        return this.engagementState === 'Going Dark';
    }

    get isSlowing() {
        return this.engagementState === 'Slowing';
    }

    get bannerClass() {
        if (this.isGoingDark) return 'next-action-banner banner-urgent';
        if (this.isSlowing) return 'next-action-banner banner-today';
        if (this.woReady) return 'next-action-banner banner-wo-ready';
        return 'next-action-banner banner-default';
    }

    get buttonClass() {
        if (this.woReady) return 'btn-action btn-wo-ready';
        if (this.isGoingDark) return 'btn-action btn-urgent';
        return 'btn-action';
    }

    get actionIcon() {
        if (this.woReady || this.nextActionButton === 'Release') return '✓';
        if (this.nextActionButton === 'Call' || this.nextActionButton === 'Follow Up') return '📞';
        if (this.nextActionButton === 'Schedule') return '📅';
        if (this.nextActionButton === 'Send' || this.nextActionButton === 'Request') return '📄';
        if (this.nextActionButton === 'Mark Signed') return '✎';
        if (this.nextActionButton === 'Advance') return '▶';
        return '→';
    }

    handleAction() {
        if (!this.recordId) return;
        const taskActions = ['Schedule', 'Mark Signed', 'Request', 'Follow Up'];
        if (taskActions.includes(this.nextActionButton)) {
            this[NavigationMixin.Navigate]({
                type: 'standard__quickAction',
                attributes: { apiName: 'Global.NewTask' },
                state: { recordId: this.recordId }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: this.recordId, actionName: 'view' }
            });
        }
    }
}
