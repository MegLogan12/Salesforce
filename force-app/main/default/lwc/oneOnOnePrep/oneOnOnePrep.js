import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPrepView from '@salesforce/apex/OneOnOnePrepController.getPrepView';
import createActionItem from '@salesforce/apex/OneOnOnePrepController.createActionItem';
import saveNotes from '@salesforce/apex/OneOnOnePrepController.saveNotes';
import markActionItemDone from '@salesforce/apex/OneOnOnePrepController.markActionItemDone';

export default class OneOnOnePrep extends LightningElement {
    @api recordId;
    @track view;
    @track newDescription = '';
    wiredView;

    @wire(getPrepView, { oneOnOneId: '$recordId' })
    onView(result) {
        this.wiredView = result;
        if (result.data) this.view = result.data;
    }

    handleNotes(event) {
        const value = event.target.value;
        clearTimeout(this._t);
        this._t = setTimeout(async () => {
            try {
                await saveNotes({ oneOnOneId: this.recordId, notes: value });
            } catch (e) { console.error(e); }
        }, 800);
    }

    handleDescription(event) {
        this.newDescription = event.target.value;
    }

    async addActionItem() {
        if (!this.newDescription) return;
        try {
            await createActionItem({
                oneOnOneId: this.recordId,
                ownerId: this.view?.openActionItems?.[0]?.Owner_User__c || null,
                description: this.newDescription,
                dueDate: null
            });
            this.newDescription = '';
            await refreshApex(this.wiredView);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Action item added',
                variant: 'success'
            }));
        } catch (e) {
            console.error(e);
        }
    }

    async markDone(event) {
        const aiId = event.target.dataset.id;
        try {
            await markActionItemDone({ actionItemId: aiId });
            await refreshApex(this.wiredView);
        } catch (e) { console.error(e); }
    }
}