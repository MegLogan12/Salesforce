import { LightningElement, api, wire } from 'lwc';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { getFieldValue } from 'lightning/uiRecordApi';

export default class ParentNationalContacts extends LightningElement {
    @api recordId;
    _contacts;

    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'Contacts',
        fields: ['Contact.Id', 'Contact.Name', 'Contact.Title', 'Contact.Email', 'Contact.Phone']
    })
    wiredContacts({ error, data }) {
        if (data) { this._contacts = data.records; }
        else if (error) { this._contacts = []; }
    }

    get contacts() {
        if (!this._contacts) return [];
        return this._contacts.map(r => {
            const name = r.fields.Name ? r.fields.Name.value : '';
            const title = r.fields.Title ? r.fields.Title.value : '';
            const email = r.fields.Email ? r.fields.Email.value : '';
            const phone = r.fields.Phone ? r.fields.Phone.value : '';
            const nameParts = (name || '').trim().split(' ');
            const first = nameParts[0] || '';
            const last = nameParts[nameParts.length - 1] || '';
            const initials = (first[0] || '') + (last[0] || '');
            return {
                id: r.id,
                name: name || '—',
                title: title || '',
                email: email || '',
                phone: phone || '',
                initials: initials.toUpperCase(),
                emailHref: email ? `mailto:${email}` : '#',
                phoneHref: phone ? `tel:${phone}` : '#'
            };
        });
    }

    get hasContacts() { return this.contacts.length > 0; }
    get isLoaded() { return this._contacts !== undefined; }
}