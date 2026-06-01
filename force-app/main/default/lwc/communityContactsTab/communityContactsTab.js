import { LightningElement, api, wire } from 'lwc';
import getCommunityContacts from '@salesforce/apex/CommunityRecordController.getCommunityContacts';

export default class CommunityContactsTab extends LightningElement {
    @api recordId;
    cards = [];

    @wire(getCommunityContacts, { communityId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.cards = data.map(c => ({
                ...c,
                emailHref: c.email ? 'mailto:' + c.email : null
            }));
        } else if (error) {
            this.cards = [];
        }
    }

    get hasCards() { return this.cards && this.cards.length > 0; }
}