import { LightningElement, track } from 'lwc';
import createLead from '@salesforce/apex/ConsultationController.createLead';
import updateLead from '@salesforce/apex/ConsultationController.updateLead';
import convertLeadAndCreateOpportunity from '@salesforce/apex/ConsultationController.convertLeadAndCreateOpportunity';
import updateOpportunity from '@salesforce/apex/ConsultationController.updateOpportunity';
import markFormSubmitted from '@salesforce/apex/ConsultationController.markFormSubmitted';
import uploadBackyardPhoto from '@salesforce/apex/ConsultationController.uploadBackyardPhoto';
import validateCouponCode from '@salesforce/apex/ConsultationController.validateCouponCode';

const TIMELINE_OPTIONS = [
  { label: 'Select', value: '' },
  { label: 'ASAP (0-2 months)', value: 'ASAP' },
  { label: 'This Quarter (3-4 months)', value: 'This Quarter' },
  { label: 'This Year', value: 'This Year' },
  { label: 'Flexible/TBD', value: 'Flexible/TBD' },
];

const BUDGET_OPTIONS = [
  { label: 'Select', value: '' },
  { label: 'Under $5,000', value: 'Under 5K' },
  { label: '$5,000 - $10,000', value: '5K-10K' },
  { label: '$10,000 - $20,000', value: '10K-20K' },
  { label: '$20,000 - $50,000', value: '20K-50K' },
  { label: 'Over $50,000', value: 'Over 50K' },
];

export default class ScheduleAVisitForm extends LightningElement {
  @track activeStep = 1;
  @track formData = {
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    street: '',
    city: '',
    state: '',
    zip: '',
    timeline: '',
    budget: '',
    desiredOutcome: '',
  };

  @track selectedDates = [];
  @track currentSelectedDate = '';
  @track currentSelectedTime = '';

  @track isLoading = false;
  @track errorMessage = '';
  @track showSuccess = false;
  @track leadId = null;
  @track opportunityId = null;
  @track uploadedFileName = '';
  @track uploadedFileBase64 = null;
  @track photoUploaded = false;
  @track smsConsent = false;

  // Lead Source / Coupon
  @track leadSource = '';
  @track couponCode = '';
  @track couponValid = false;
  @track couponInvalid = false;
  @track couponValidating = false;

  get showCouponField() {
    return this.leadSource === 'Lennar Voucher';
  }

  timelineOptions = TIMELINE_OPTIONS;
  budgetOptions = BUDGET_OPTIONS;

  connectedCallback() {
    // Set minimum date to today
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    this.minDate = `${yyyy}-${mm}-${dd}`;

    // Notify parent iframe that form has loaded (for loading overlay in Squarespace)
    setTimeout(() => {
      if (window.parent !== window) {
        window.parent.postMessage({ type: 'formLoaded' }, '*');
      }
      this.scrollToTop();
    }, 100);
  }

  renderedCallback() {
    // Set the min attribute on the date input after render
    const dateInput = this.template.querySelector('.date-picker-input');
    if (dateInput && this.minDate) {
      dateInput.setAttribute('min', this.minDate);
    }
    
    // Send height to parent after each render
    this.sendHeightToParent();
  }

  /**
   * Send the current height of the form to the parent iframe
   */
  sendHeightToParent() {
    if (window.parent !== window) {
      // Use document.body.scrollHeight for accurate iframe content measurement
      const height = document.body.scrollHeight;
      if (height && height > 0) {
        window.parent.postMessage({ type: 'setHeight', height: height }, '*');
      }
    }
  }

  get showForm() {
    return !this.showSuccess;
  }

  get isStep1() {
    return this.activeStep === 1;
  }

  get isStep2() {
    return this.activeStep === 2;
  }

  // Dynamic CSS classes for step indicator
  get step1NumberClass() {
    return this.activeStep === 1 ? 'step-number active' : 'step-number';
  }

  get step1LabelClass() {
    return this.activeStep === 1 ? 'step-label active' : 'step-label';
  }

  get step2NumberClass() {
    return this.activeStep === 2 ? 'step-number active' : 'step-number';
  }

  get step2LabelClass() {
    return this.activeStep === 2 ? 'step-label active' : 'step-label';
  }

  // Date picker getters
  get hasSelectedDates() {
    return this.selectedDates.length > 0;
  }

  get isMaxDatesReached() {
    return this.selectedDates.length >= 3;
  }

  get addDateButtonLabel() {
    return this.isMaxDatesReached ? 'Max 3' : 'Add';
  }

  get addDateButtonClass() {
    return this.isMaxDatesReached ? 'add-date-btn disabled' : 'add-date-btn';
  }

  /**
   * Handle input field changes
   */
  handleInputChange(event) {
    const field = event.target.dataset.field;
    this.formData[field] = event.target.value;
  }

  /**
   * Handle SMS consent checkbox change
   */
  handleSmsConsentChange(event) {
    this.smsConsent = event.target.checked;
  }

  /**
   * Handle lead source dropdown change
   */
  handleLeadSourceChange(event) {
    this.leadSource = event.target.value;
    if (this.leadSource !== 'Lennar Voucher') {
      this.couponCode = '';
      this.couponValid = false;
      this.couponInvalid = false;
      this.couponValidating = false;
    }
  }

  /**
   * Handle coupon code input change
   */
  handleCouponCodeChange(event) {
    this.couponCode = event.target.value;
    this.couponValid = false;
    this.couponInvalid = false;
    if (this.couponCode && this.couponCode.trim().length >= 4) {
      this._validateCouponCode();
    }
  }

  /**
   * Validate coupon code via Apex
   */
  async _validateCouponCode() {
    this.couponValidating = true;
    this.couponValid = false;
    this.couponInvalid = false;
    try {
      const result = await validateCouponCode({ code: this.couponCode.trim() });
      this.couponValid = !!result;
      this.couponInvalid = !result;
    } catch (error) {
      console.error('Coupon validation error:', error);
      this.couponInvalid = true;
    } finally {
      this.couponValidating = false;
    }
  }

  /**
   * Handle select/combobox changes (native select element)
   */
  handleSelectChange(event) {
    const field = event.target.dataset.field;
    this.formData[field] = event.target.value;
  }

  /**
   * Handle date picker change
   */
  handleDatePickerChange(event) {
    const value = event.target.value;
    
    if (!value) {
      this.currentSelectedDate = '';
      return;
    }

    // Only check if date is not in the past
    const selectedDate = new Date(value + 'T00:00:00');
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (selectedDate < today) {
      this.errorMessage = 'Please select today or a future date.';
      event.target.value = '';
      this.currentSelectedDate = '';
      return;
    }

    this.currentSelectedDate = value;
    this.errorMessage = '';
  }

  /**
   * Handle time picker change
   */
  handleTimePickerChange(event) {
    this.currentSelectedTime = event.target.value;
  }

  /**
   * Handle Add Date button click
   */
  handleAddDate() {
    if (!this.currentSelectedDate || !this.currentSelectedTime || this.isMaxDatesReached) {
      if (!this.currentSelectedDate || !this.currentSelectedTime) {
        this.errorMessage = 'Please select both a date and time.';
      }
      return;
    }

    // Create unique key for this date/time combo
    const dateTimeKey = `${this.currentSelectedDate}_${this.currentSelectedTime}`;

    // Check if date/time already added
    const alreadyAdded = this.selectedDates.some(d => d.dateTimeKey === dateTimeKey);
    if (alreadyAdded) {
      this.errorMessage = 'This date/time is already selected.';
      return;
    }

    // Format date for display (e.g., "Wed, Jan 21")
    const dateObj = new Date(this.currentSelectedDate + 'T00:00:00');
    const dateOptions = { weekday: 'short', month: 'short', day: 'numeric' };
    const displayDate = dateObj.toLocaleDateString('en-US', dateOptions);

    // Format time for display (e.g., "2:30 PM")
    const [hours, minutes] = this.currentSelectedTime.split(':');
    const hour = parseInt(hours, 10);
    const ampm = hour >= 12 ? 'PM' : 'AM';
    const displayHour = hour % 12 || 12;
    const displayTime = `${displayHour}:${minutes} ${ampm}`;

    // Combined display (e.g., "Wed, Jan 21 @ 2:30 PM")
    const displayDateTime = `${displayDate} @ ${displayTime}`;

    // Add to selected dates
    this.selectedDates = [
      ...this.selectedDates,
      {
        id: Date.now().toString(),
        date: this.currentSelectedDate,
        time: this.currentSelectedTime,
        dateTimeKey: dateTimeKey,
        displayDateTime: displayDateTime
      }
    ];

    // Clear the inputs
    this.currentSelectedDate = '';
    this.currentSelectedTime = '';
    const dateInput = this.template.querySelector('.date-picker-input');
    if (dateInput) {
      dateInput.value = '';
    }
    const timeInput = this.template.querySelector('.time-picker-input');
    if (timeInput) {
      timeInput.value = '';
    }

    this.errorMessage = '';
  }

  /**
   * Handle remove date pill
   */
  handleRemoveDate(event) {
    const dateId = event.target.dataset.dateId;
    this.selectedDates = this.selectedDates.filter(d => d.id !== dateId);
  }

  /**
   * Handle file click - trigger hidden file input
   */
  handleFileClick() {
    const fileInput = this.template.querySelector('.hidden-file-input');
    if (fileInput) {
      fileInput.click();
    }
  }

  /**
   * Handle file selection from hidden input
   */
  handleFileSelect(event) {
    const file = event.target.files[0];
    if (file) {
      this.uploadedFileName = file.name;
      
      // Read file as Base64
      const reader = new FileReader();
      reader.onload = () => {
        // Remove the data URL prefix (e.g., "data:image/jpeg;base64,")
        const base64 = reader.result.split(',')[1];
        this.uploadedFileBase64 = base64;
      };
      reader.readAsDataURL(file);
    }
  }

  /**
   * Validate Step 1 required fields
   */
  validateStep1() {
    const requiredFields = ['firstName', 'lastName', 'email', 'phone', 'street', 'city', 'state', 'zip'];
    const missingFields = requiredFields.filter((field) => !this.formData[field]?.trim());
    if (missingFields.length > 0) {
      this.errorMessage = `Please fill in all required fields: ${missingFields.join(', ')}`;
      return false;
    }
    if (!this.leadSource) {
      this.errorMessage = 'Please select how you heard about us.';
      return false;
    }
    if (this.leadSource === 'Lennar Voucher' && !this.couponValid) {
      this.errorMessage = 'Please enter and validate your Lennar voucher code.';
      return false;
    }
    return true;
  }

  /**
   * Validate Step 2 required fields
   */
  validateStep2() {
    if (!this.formData.timeline || !this.formData.budget || !this.formData.desiredOutcome?.trim()) {
      this.errorMessage = 'Please fill in all required fields.';
      return false;
    }

    // Validate at least one consultation date is provided
    if (this.selectedDates.length === 0) {
      this.errorMessage = 'Please select at least one preferred consultation date.';
      return false;
    }

    return true;
  }

  /**
   * Submit Step 1 - Create or Update Lead
   */
  async submitStep1() {
    if (!this.validateStep1()) {
      return;
    }

    // If Lead was already converted (Opportunity exists), just move to next step
    // Can't update a converted Lead
    if (this.opportunityId) {
      this.activeStep = 2;
      this.scrollToTop();
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      const phoneWithCountryCode = this.formData.phone.startsWith('+1') ? this.formData.phone : '+1' + this.formData.phone;
      const leadData = {
        FirstName: this.formData.firstName,
        LastName: this.formData.lastName,
        Email: this.formData.email,
        Phone: phoneWithCountryCode,
        Street: this.formData.street,
        City: this.formData.city,
        State: this.formData.state,
        PostalCode: this.formData.zip,
        SMSConsent: this.smsConsent ? 'true' : 'false',
        LeadSource: this.leadSource || '',
        CouponCode: this.couponCode || '',
      };

      // If Lead already exists, update it; otherwise create new
      if (this.leadId) {
        await updateLead({ leadId: this.leadId, leadData });
      } else {
        this.leadId = await createLead({ leadData });
      }
      
      this.activeStep = 2;
      this.scrollToTop();
    } catch (error) {
      this.errorMessage = `Error saving lead: ${error.body?.message || error.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Scroll to top of the page and update height (for iframe embedding)
   */
  scrollToTop() {
    // Scroll within the component
    window.scrollTo(0, 0);
    
    // Send message to parent iframe to scroll to top
    if (window.parent !== window) {
      window.parent.postMessage({ type: 'scrollToTop' }, '*');
    }
    
    // Update height after delays to allow DOM to fully render
    setTimeout(() => this.sendHeightToParent(), 150);
    setTimeout(() => this.sendHeightToParent(), 400);
  }

  /**
   * Submit Step 2 - Convert Lead & Create Opportunity with consultation dates
   */
  async submitStep2() {
    if (!this.validateStep2()) {
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      // Convert local date/time to UTC ISO string for Apex
      // This ensures timezone is handled correctly regardless of user's browser timezone
      const consultationDates = this.selectedDates.map(d => {
        // Create a local Date object from the date and time picker values
        // d.date is 'YYYY-MM-DD', d.time is 'HH:mm'
        const localDateTime = new Date(`${d.date}T${d.time}:00`);
        // toISOString() converts to UTC and returns format: 2026-02-02T18:30:00.000Z
        return {
          utcDateTime: localDateTime.toISOString()
        };
      });

      const opportunityData = {
        timeline: this.formData.timeline,
        budget: this.formData.budget,
        desiredOutcome: this.formData.desiredOutcome,
        consultationDates: consultationDates,
        couponCode: this.couponCode || '',
      };

      // If Opportunity already exists (user went back/forth), update it instead of converting again
      if (this.opportunityId) {
        await updateOpportunity({
          opportunityId: this.opportunityId,
          opportunityData,
        });
      } else {
        // First time - convert lead and create opportunity
        this.opportunityId = await convertLeadAndCreateOpportunity({
          leadId: this.leadId,
          opportunityData,
        });
      }

      // Upload backyard photo if provided (only if not already uploaded)
      if (this.uploadedFileBase64 && this.uploadedFileName && !this.photoUploaded) {
        try {
          await uploadBackyardPhoto({
            opportunityId: this.opportunityId,
            fileName: this.uploadedFileName,
            base64Data: this.uploadedFileBase64,
          });
          this.photoUploaded = true;
        } catch (uploadError) {
          // Log but don't fail the submission if photo upload fails
          console.error('Photo upload failed:', uploadError);
        }
      }

      // Mark form as submitted
      await markFormSubmitted({ opportunityId: this.opportunityId });

      this.showSuccess = true;
      this.scrollToTop();
    } catch (error) {
      this.errorMessage = `Error in submission: ${error.body?.message || error.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Navigate to previous step
   */
  goBack() {
    if (this.activeStep > 1) {
      this.activeStep--;
      this.errorMessage = '';
      this.scrollToTop();
    }
  }

  /**
   * Clear error message
   */
  clearError() {
    this.errorMessage = '';
  }
}