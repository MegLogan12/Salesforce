import { LightningElement, api, wire } from 'lwc';
import getContactsForAccount from '@salesforce/apex/ParentAccountRollupController.getContactsForAccount';

const AVATAR_CYCLE = ['av av-b', 'av av-g', 'av av-p', 'av av-o'];

export default class ContactsCards extends LightningElement {
    @api recordId;
    rows;
    error;

    @wire(getContactsForAccount, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) { this.rows = data; this.error = undefined; }
        else if (error) this.error = error.body ? error.body.message : error.message;
    }

    get hasRows() { return this.rows && this.rows.length > 0; }
    get count() { return this.rows ? this.rows.length : 0; }

    get viewRows() {
        if (!this.rows) return [];
        return this.rows.map((r, idx) => ({
            ...r,
            avatarCls: AVATAR_CYCLE[idx % AVATAR_CYCLE.length],
            emailHref: r.email ? `mailto:${r.email}` : '',
            phoneHref: r.phone ? `tel:${r.phone}` : '',
            hasRole: !!r.roleTag
        }));
    }
}