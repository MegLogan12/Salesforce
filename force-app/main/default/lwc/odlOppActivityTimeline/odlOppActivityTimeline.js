import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class OdlOppActivityTimeline extends NavigationMixin(LightningElement) {
    @api interactions = [];
    @api lastAction = '';
    @api lastActionDate = '';
    @api recordId;

    get hasInteractions() {
        return Array.isArray(this.interactions) && this.interactions.length > 0;
    }

    handleLogCall() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.LogACall' },
            state: { recordId: this.recordId || '' }
        });
    }

    handleNewActivity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.NewTask' },
            state: { recordId: this.recordId || '' }
        });
    }
}
