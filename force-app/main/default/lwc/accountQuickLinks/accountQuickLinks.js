import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import BMG_PRICING from '@salesforce/schema/Account.BMG_Pricing_Link__c';
import CONTRACT from '@salesforce/schema/Account.Contract_Link__c';
import DRIVE from '@salesforce/schema/Account.Drive_Folder_Link__c';
import LOT_LAYOUT from '@salesforce/schema/Account.Lot_Layout_Link__c';
import COI from '@salesforce/schema/Account.Insurance_COI_Link__c';
import WEBSITE from '@salesforce/schema/Account.Website';

const FIELDS = [BMG_PRICING, CONTRACT, DRIVE, LOT_LAYOUT, COI, WEBSITE];

// 6 dot-tile links; dot colors come from the mockup palette.
const LINK_CONFIG = [
    { key: 'bmg',      label: 'BMG Pricing',       sub: 'Attached documents', color: '#0070d2' },
    { key: 'contract', label: 'Contract Document', sub: 'ContentDocument',    color: '#2e844a' },
    { key: 'portal',   label: 'Builder Portal',    sub: 'External link',      color: '#534ab7' },
    { key: 'drive',    label: 'Shared Drive Folder', sub: 'Folder',           color: '#e65100' },
    { key: 'lot',      label: 'Lot Layout Link',   sub: 'External link',      color: '#0070d2' },
    { key: 'coi',      label: 'Insurance COI',     sub: 'Attachment',         color: '#2e844a' }
];

export default class AccountQuickLinks extends LightningElement {
    @api recordId;
    account;
    isEditing = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount({ data }) {
        if (data) this.account = data;
    }

    get editButtonLabel() {
        return this.isEditing ? 'Close Editor' : 'Edit Links';
    }

    handleToggleEdit() {
        this.isEditing = !this.isEditing;
    }

    handleCancel() {
        this.isEditing = false;
    }

    async handleSuccess() {
        this.isEditing = false;
        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Quick links updated',
                message: 'The account links were saved successfully.',
                variant: 'success'
            })
        );
    }

    handleError(event) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Unable to save links',
                message: event.detail?.message || 'Review the highlighted fields and try again.',
                variant: 'error'
            })
        );
    }

    get links() {
        if (!this.account) {
            return LINK_CONFIG.map(c => ({ ...c, url: '', hasUrl: false, sub: 'Not set', arrow: '+' }));
        }
        const urls = {
            bmg: getFieldValue(this.account, BMG_PRICING),
            contract: getFieldValue(this.account, CONTRACT),
            portal: getFieldValue(this.account, WEBSITE),
            drive: getFieldValue(this.account, DRIVE),
            lot: getFieldValue(this.account, LOT_LAYOUT),
            coi: getFieldValue(this.account, COI)
        };
        return LINK_CONFIG.map(c => {
            const url = urls[c.key];
            const has = !!url;
            return {
                ...c,
                url: url || '',
                hasUrl: has,
                sub: has ? c.sub : 'Not set',
                arrow: has ? '\u2197' : '+',
                dotStyle: `background:${c.color}`,
                arrowCls: has ? 'ql-arrow' : 'ql-arrow muted'
            };
        });
    }
}