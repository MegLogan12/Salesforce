import { LightningElement, api } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LovingSiteVisitChecklist extends LightningElement {
    static renderMode = 'light';

    @api recordId;

    handleSave() {
        const root = this;

        const opportunityName = root.querySelector('[placeholder="e.g. Rivera Backyard"]')?.value?.trim() || '';
        const visitDate       = root.querySelector('input[type="date"]')?.value || '';
        const accessNotes     = root.querySelector('[placeholder="Gate code, side entry..."]')?.value?.trim() || '';
        const soil            = root.querySelector('select:nth-of-type(1)')?.value || '';
        const slope           = root.querySelector('select:nth-of-type(2)')?.value || '';
        const drainage        = root.querySelector('select:nth-of-type(3)')?.value || '';
        const scopeSummary    = root.querySelector('textarea')?.value?.trim() || '';

        const checkedItems = [...root.querySelectorAll('.lov-check input[type="checkbox"]:checked')]
            .map(cb => cb.closest('label').textContent.trim());

        const lines = [];
        if (accessNotes)            lines.push('Access: ' + accessNotes);
        if (soil)                   lines.push('Soil: ' + soil);
        if (slope)                  lines.push('Slope: ' + slope);
        if (drainage)               lines.push('Drainage: ' + drainage);
        if (checkedItems.length)    lines.push('Checklist: ' + checkedItems.join(', '));
        if (scopeSummary)           lines.push('Scope: ' + scopeSummary);

        const fields = {
            Subject:      { value: 'Site Visit' + (opportunityName ? ' — ' + opportunityName : '') },
            Type:         { value: 'Site Visit' },
            Description:  { value: lines.join('\n') || '' },
            Status:       { value: 'Completed' },
        };
        if (visitDate) fields.ActivityDate = { value: visitDate };
        if (this.recordId) fields.WhatId = { value: this.recordId };

        createRecord({ apiName: 'Task', fields })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Site visit saved',
                    message: 'Activity logged' + (opportunityName ? ' for ' + opportunityName : '') + '.',
                    variant: 'success'
                }));
                this._clearForm();
            })
            .catch(err => {
                const msg = err?.body?.message || 'Could not save the site visit activity.';
                this.dispatchEvent(new ShowToastEvent({ title: 'Save failed', message: msg, variant: 'error' }));
            });
    }

    _clearForm() {
        this.querySelectorAll('input[type="text"], input[type="date"], textarea').forEach(el => { el.value = ''; });
        this.querySelectorAll('select').forEach(el => { el.selectedIndex = 0; });
        this.querySelectorAll('input[type="checkbox"]').forEach(cb => { cb.checked = false; });
    }
}
