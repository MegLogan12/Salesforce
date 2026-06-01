import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class OdlOppNextAction extends NavigationMixin(LightningElement) {
    @api nextActionText = '';
    @api nextActionButton = '';
    @api recordId;
    @api woReady = false;

    get bannerClass() {
        if (this.woReady) return 'next-action-banner banner-wo-ready';
        if (this.nextActionText && this.nextActionText.toLowerCase().startsWith('overdue')) return 'next-action-banner banner-urgent';
        if (this.nextActionText && this.nextActionText.toLowerCase().startsWith('due today')) return 'next-action-banner banner-today';
        return 'next-action-banner banner-default';
    }

    get buttonClass() {
        return this.woReady ? 'btn-action btn-wo-ready' : 'btn-action';
    }

    get actionIcon() {
        if (this.woReady) return '✓';
        if (this.nextActionButton === 'Call' || this.nextActionButton === 'Log Call') return '📞';
        if (this.nextActionButton === 'Schedule') return '📅';
        if (this.nextActionButton === 'Send Quote') return '📄';
        if (this.nextActionButton === 'New Task' || this.nextActionButton === 'Log Activity') return '✎';
        return '→';
    }

    handleAction() {
        if (!this.recordId) return;
        const taskActions = ['New Task', 'Log Activity', 'Log Call', 'Schedule', 'Confirm'];
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
