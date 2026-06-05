import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/**
 * lovingLeadQualifier
 * A perchable LOVING question form bound to the Lead object.
 *
 * LIGHT DOM is required so Ask mcLOVIN' can read the data-mclovin-* attributes
 * on the card. Shadow DOM (the default) would hide them and he would never find
 * this form. Because light DOM styles are NOT scoped, all CSS selectors in
 * lovingLeadQualifier.css are namespaced under .loving-lead-qualifier so they
 * cannot leak into the rest of the console.
 */
export default class LovingLeadQualifier extends LightningElement {
  static renderMode = 'light';   // <-- the important line

  @api recordId;                 // optional: pass to edit an existing Lead

  // capture the landscape-specific answers until custom fields exist
  handleSubmit(event) {
    // example of injecting extra values into the save if you add custom fields:
    // const fields = event.detail.fields;
    // fields.Project_Interest__c = this.collectScope();
    // fields.Timeline__c = this.querySelector('[data-q="timeline"]').value;
    // fields.Budget_Range__c = this.querySelector('[data-q="budget"]').value;
    // event.preventDefault(); this.template.querySelector('lightning-record-edit-form').submit(fields);
  }

  collectScope() {
    return [...this.querySelectorAll('.lq-check input:checked')]
      .map((c) => c.dataset.scope)
      .join('; ');
  }

  handleSuccess(event) {
    this.toast('Lead qualified', 'Saved Lead ' + event.detail.id, 'success');
  }
  handleError() {
    this.toast('Could not save', 'Check the required fields and try again.', 'error');
  }
  handleSaveDraft() {
    this.toast('Draft saved', 'We kept your progress.', 'success');
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
