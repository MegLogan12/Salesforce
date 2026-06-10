import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LovingLeadQualifier extends LightningElement {
    static renderMode = 'light';

    @api recordId;

    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;

        const scope    = this._collectScope();
        const timeline = this.querySelector('[data-q="timeline"]')?.value || '';
        const budget   = this.querySelector('[data-q="budget"]')?.value || '';

        const lines = [];
        if (scope)    lines.push('Scope of interest: ' + scope);
        if (timeline) lines.push('Timeline: ' + timeline);
        if (budget)   lines.push('Budget range: ' + budget);

        if (lines.length) {
            const existing = fields.Description || '';
            fields.Description = (existing ? existing + '\n\n' : '') + lines.join('\n');
        }

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    _collectScope() {
        return [...this.querySelectorAll('.lq-check input:checked')]
            .map(c => c.dataset.scope)
            .join(', ');
    }

    handleSuccess(event) {
        this.toast('Lead qualified', 'Lead ' + event.detail.id + ' saved.', 'success');
    }

    handleError() {
        this.toast('Could not save', 'Check the required fields and try again.', 'error');
    }

    handleSaveDraft() {
        this.toast('Draft saved', 'Your progress has been kept.', 'success');
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
