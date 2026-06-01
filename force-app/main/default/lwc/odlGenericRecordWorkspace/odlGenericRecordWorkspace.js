import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/ODLVisibleWorkspaceController.getPageData';

const NEW_TASK_ACTION = 'Global.NewTask';

export default class OdlGenericRecordWorkspace extends NavigationMixin(LightningElement) {
    @api recordId;

    pageData;
    error;

    @wire(getPageData, { recordId: '$recordId' })
    wiredPageData({ data, error }) {
        if (data) {
            this.pageData = {
                ...data,
                actions: (data.actions || []).map((item) => ({
                    ...item,
                    className: item.disabled ? 'cta cta-disabled' : (item.actionType === 'edit' ? 'cta' : 'cta cta-secondary')
                })),
                sections: (data.sections || []).map((section) => {
                    const fields = (section.fields || [])
                        .filter((item) => item && (item.value || item.url || item.subtext))
                        .map((item, index) => ({
                        ...item,
                        key: `${section.title}-field-${index}`
                    }));
                    const rows = (section.rows || []).map((row, index) => ({
                        ...row,
                        key: `${section.title}-row-${index}`
                    }));
                    return {
                        ...section,
                        fields,
                        rows,
                        hasFields: fields.length > 0,
                        hasRows: rows.length > 0,
                        isEmpty: fields.length === 0 && rows.length === 0
                    };
                }).filter((section) => section.hasFields || section.hasRows)
            };
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.pageData = undefined;
        }
    }

    get hasData() {
        return Boolean(this.pageData);
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        if (Array.isArray(this.error.body)) {
            return this.error.body.map((item) => item.message).join(', ');
        }
        return this.error.body ? this.error.body.message : this.error.message;
    }

    handleAction(event) {
        const actionType = event.currentTarget.dataset.action;
        const url = event.currentTarget.dataset.url;
        if (actionType === 'edit') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    actionName: 'edit'
                }
            });
            return;
        }
        if (actionType === 'newTask') {
            this[NavigationMixin.Navigate]({
                type: 'standard__quickAction',
                attributes: {
                    apiName: NEW_TASK_ACTION
                },
                state: {
                    recordId: this.recordId
                }
            });
            return;
        }
        if (actionType === 'openUrl' && url) {
            window.open(url, '_self');
        }
    }
}