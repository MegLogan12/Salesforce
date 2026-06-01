import { LightningElement, track } from 'lwc';
import createLead from '@salesforce/apex/BackyardDesignController.createLead';
import updateLead from '@salesforce/apex/BackyardDesignController.updateLead';
import convertLeadAndCreateOpportunity from '@salesforce/apex/BackyardDesignController.convertLeadAndCreateOpportunity';
import updateOpportunity from '@salesforce/apex/BackyardDesignController.updateOpportunity';
import markFormSubmitted from '@salesforce/apex/BackyardDesignController.markFormSubmitted';
import updateOpportunityWithFeatures from '@salesforce/apex/BackyardDesignController.updateOpportunityWithFeatures';
import uploadBackyardPhoto from '@salesforce/apex/BackyardDesignController.uploadBackyardPhoto';
import validateCouponCode from '@salesforce/apex/BackyardDesignController.validateCouponCode';

const FEATURES = [
  { id: 'grilling-island', name: 'Grilling Island', cost: 4500, selected: false },
  { id: 'outdoor-fireplace', name: 'Outdoor Fireplace', cost: 4800, selected: false },
  { id: 'paver-patio', name: 'Paver Patio', cost: 2500, selected: false },
  { id: 'fire-pit', name: 'Fire Pit', cost: 1000, selected: false },
  { id: 'sitting-wall', name: 'Sitting Wall', cost: 1500, selected: false },
  { id: 'landscape-enhancements', name: 'Landscape Enhancements', cost: 2000, selected: false },
  { id: 'low-voltage-lighting', name: 'Low Voltage Lighting', cost: 1500, selected: false },
  { id: 'irrigation-upgrades', name: 'Irrigation Upgrades', cost: 500, selected: false },
];

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

export default class startMyDesignForm extends LightningElement {
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
    description: '',
    additionalDetails: '',
  };

  @track features = FEATURES;
  @track isLoading = false;
  @track errorMessage = '';
  @track showSuccess = false;
  @track uploadedFileName = null;
  @track uploadedFileBase64 = null;
  @track leadId = null;
  @track opportunityId = null;
  @track contentDocumentId = null;
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

  get isGrillingIslandSelected() {
    const feature = this.features.find(f => f.id === 'grilling-island');
    return feature ? feature.selected : false;
  }

  get grillingIslandPriceText() {
    if (this.couponValid && this.leadSource === 'Lennar Voucher') {
      return 'FREE with Lennar Voucher';
    }
    return 'Prices starting as low as $4,500';
  }

  timelineOptions = TIMELINE_OPTIONS;
  budgetOptions = BUDGET_OPTIONS;

  @track showAdditionalTextarea = false;

  connectedCallback() {
    // Notify parent iframe that form has loaded (for loading overlay in Squarespace)
    setTimeout(() => {
      if (window.parent !== window) {
        window.parent.postMessage({ type: 'formLoaded' }, '*');
      }
      this.scrollToTop();
    }, 100);
  }

  renderedCallback() {
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

  get isStep3() {
    return this.activeStep === 3;
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

  get step3NumberClass() {
    return this.activeStep === 3 ? 'step-number active' : 'step-number';
  }

  get step3LabelClass() {
    return this.activeStep === 3 ? 'step-label active' : 'step-label';
  }

  get estimateTotal() {
    return this.features
      .filter((f) => f.selected)
      .reduce((sum, f) => sum + f.cost, 0)
      .toLocaleString();
  }

  get monthlyEstimate() {
    const total = this.features.filter((f) => f.selected).reduce((sum, f) => sum + f.cost, 0);
    // Formula: Total / 40 months
    return Math.round(total / 40).toLocaleString();
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
      // Reset Grilling Island to original cost and deselect
      this._resetGrillingIsland();
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
      if (this.couponValid) {
        this._applyLennarVoucherToGrillingIsland();
      }
    } catch (error) {
      console.error('Coupon validation error:', error);
      this.couponInvalid = true;
    } finally {
      this.couponValidating = false;
    }
  }

  /**
   * Set Grilling Island to free and auto-select when Lennar Voucher is valid
   */
  _applyLennarVoucherToGrillingIsland() {
    this.features = this.features.map(f => {
      if (f.id === 'grilling-island') {
        return { ...f, cost: 0, selected: true };
      }
      return f;
    });
  }

  /**
   * Reset Grilling Island to original cost and deselect
   */
  _resetGrillingIsland() {
    this.features = this.features.map(f => {
      if (f.id === 'grilling-island') {
        return { ...f, cost: 4500, selected: false };
      }
      return f;
    });
  }

  /**
   * Handle select/combobox changes (native select element)
   */
  handleSelectChange(event) {
    const field = event.target.dataset.field;
    this.formData[field] = event.target.value;
  }

  /**
   * Handle feature toggle - updated for new HTML structure
   */
  handleFeatureToggle(event) {
    const featureId = event.target.dataset.featureId;
    const minCost = parseInt(event.target.dataset.min, 10);
    const maxCost = parseInt(event.target.dataset.max, 10);
    const isChecked = event.target.checked;
    
    // Map HTML data-feature-id (camelCase) to FEATURES array IDs (kebab-case)
    const idMapping = {
      'grillingIsland': 'grilling-island',
      'outdoorFireplace': 'outdoor-fireplace',
      'paverPatio': 'paver-patio',
      'firePit': 'fire-pit',
      'sittingWall': 'sitting-wall',
      'landscapeEnhancements': 'landscape-enhancements',
      'lighting': 'low-voltage-lighting',
      'irrigation': 'irrigation-upgrades'
    };
    
    // Get the full feature ID (check mapping first, then use as-is)
    const fullFeatureId = idMapping[featureId] || featureId;
    
    // Update features array
    const feature = this.features.find((f) => f.id === fullFeatureId);
    
    if (feature) {
      feature.selected = isChecked;
      this.features = [...this.features];
    }
  }

  /**
   * Toggle additional textarea visibility
   */
  toggleAdditionalTextarea(event) {
    this.showAdditionalTextarea = event.target.checked;
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
    if (!this.formData.timeline || !this.formData.budget || !this.formData.description?.trim()) {
      this.errorMessage = 'Please fill in all required fields.';
      return false;
    }
    return true;
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
   * Submit Step 2 - Convert Lead & Create Opportunity
   */
  async submitStep2() {
    if (!this.validateStep2()) {
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      const opportunityData = {
        timeline: this.formData.timeline,
        budget: this.formData.budget,
        description: this.formData.description,
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

      // Upload image if provided (only if not already uploaded)
      if (this.uploadedFileBase64 && this.uploadedFileName && !this.photoUploaded) {
        this.contentDocumentId = await uploadBackyardPhoto({
          opportunityId: this.opportunityId,
          fileName: this.uploadedFileName,
          base64Data: this.uploadedFileBase64,
        });
        this.photoUploaded = true;
      }

      this.activeStep = 3;
      this.scrollToTop();
    } catch (error) {
      this.errorMessage = `Error in submission: ${error.body?.message || error.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Submit Step 3 - Update Opportunity with Selected Features
   */
  async submitStep3() {
    this.isLoading = true;
    this.errorMessage = '';

    try {
      const selectedFeatures = this.features.filter((f) => f.selected);
      const selectedFeatureNames = selectedFeatures.map((f) => f.name).join(', ');
      const selectedFeaturesList = selectedFeatures.map((f) => f.name);

      const featureData = {
        selectedFeatures: selectedFeatureNames,
        selectedFeaturesList: selectedFeaturesList,
        estimateTotal: this.estimateTotal,
        monthlyEstimate: this.monthlyEstimate,
        additionalDetails: this.formData.additionalDetails,
      };

      await updateOpportunityWithFeatures({
        opportunityId: this.opportunityId,
        featureData,
      });

      // Mark form as submitted
      await markFormSubmitted({ opportunityId: this.opportunityId });

      this.showSuccess = true;
      this.scrollToTop();
    } catch (error) {
      this.errorMessage = `Error updating opportunity: ${error.body?.message || error.message}`;
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