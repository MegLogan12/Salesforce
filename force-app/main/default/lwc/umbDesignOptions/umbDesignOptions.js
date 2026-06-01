import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDesignOptions from '@salesforce/apex/UMBDesignOptionController.getDesignOptions';
import selectDesignOption from '@salesforce/apex/UMBDesignOptionController.selectDesignOption';
import redesign from '@salesforce/apex/UMBRedesignService.redesign';
import toggleHeart from '@salesforce/apex/UMBRedesignService.toggleHeart';

const TIER_META = {
    Retreat:     { cls: 'house-card good',   tag: 'tag tag-green',  imgCls: 'house-img good-img' },
    Entertainer: { cls: 'house-card better', tag: 'tag tag-blue',   imgCls: 'house-img better-img' },
    Signature:   { cls: 'house-card best',   tag: 'tag tag-orange', imgCls: 'house-img best-img' }
};

export default class UmbDesignOptions extends LightningElement {
    @api recordId;
    @track options = [];
    isLoaded = false;
    loadError = null;
    busyId = null;
    _wired;

    @wire(getDesignOptions, { opportunityId: '$recordId' })
    wired(result) {
        this._wired = result;
        if (result.data) {
            this.loadError = null;
            this.options = result.data.map((o) => {
                const meta = TIER_META[o.Tier__c] || { cls: 'house-card', tag: 'tag', imgCls: 'house-img' };
                const elements = (o.Design_Elements__r || []).map((e) => ({
                    id: e.Id,
                    name: e.Product__r ? e.Product__r.Name : e.Name,
                    category: e.Category__c,
                    placement: e.Placement__c,
                    hearted: e.Is_Hearted__c,
                    heartIcon: e.Is_Hearted__c ? 'utility:favorite' : 'utility:favorite_alt',
                    heartVariant: e.Is_Hearted__c ? 'warning' : 'border',
                    heartTitle: e.Is_Hearted__c ? 'Hearted — kept on redesign' : 'Heart to keep this on redesign'
                }));
                return {
                    id: o.Id,
                    tier: o.Tier__c,
                    packageLabel: o.Package_Label__c,
                    priceFormatted: o.Price__c != null ? '$' + Number(o.Price__c).toLocaleString() : 'Pricing pending',
                    description: o.Description__c,
                    features: o.Features__c ? o.Features__c.split('\n').filter((f) => f.trim()) : [],
                    imageUrl: o.Rendered_Image_URL__c,
                    hasImage: !!o.Rendered_Image_URL__c,
                    isConcept: o.Is_Concept__c,
                    isSelected: o.Is_Selected__c,
                    elements,
                    hasElements: elements.length > 0,
                    cardClass: o.Is_Selected__c ? meta.cls + ' selected' : meta.cls,
                    tagClass: meta.tag,
                    imgClass: meta.imgCls,
                    busy: this.busyId === o.Id,
                    redesignLabel: this.busyId === o.Id ? 'Designing…' : 'Redesign',
                    selectLabel: o.Is_Selected__c ? 'Selected' : 'Select this design',
                    selectVariant: o.Is_Selected__c ? 'success' : 'brand'
                };
            });
            this.isLoaded = true;
        } else if (result.error) {
            this.options = [];
            this.loadError = this.msg(result.error);
            this.isLoaded = true;
        }
    }

    get hasOptions() { return !this.loadError && this.options.length > 0; }
    get noOptions() { return this.isLoaded && !this.loadError && this.options.length === 0; }
    get hasError() { return this.isLoaded && !!this.loadError; }

    handleSelect(event) {
        const designOptionId = event.currentTarget.dataset.id;
        selectDesignOption({ designOptionId, opportunityId: this.recordId })
            .then(() => {
                this.toast('Design Selected', 'Your selected design has been saved.', 'success');
                return refreshApex(this._wired);
            })
            .catch((err) => this.toast('Could not save selection', this.msg(err), 'error'));
    }

    handleHeart(event) {
        const elementId = event.currentTarget.dataset.id;
        const hearted = event.currentTarget.dataset.hearted === 'true';
        toggleHeart({ elementId, hearted: !hearted })
            .then(() => refreshApex(this._wired))
            .catch((err) => this.toast('Could not update', this.msg(err), 'error'));
    }

    handleRedesign(event) {
        const designOptionId = event.currentTarget.dataset.id;
        this.busyId = designOptionId;
        // reflect spinner immediately
        this.options = this.options.map((o) =>
            o.id === designOptionId ? { ...o, busy: true, redesignLabel: 'Designing…' } : o);
        redesign({ designOptionId })
            .then(() => {
                this.toast('Redesign started', 'New options are generating — this takes a few seconds.', 'success');
                // poll once after the async render completes
                return new Promise((res) => setTimeout(res, 12000));
            })
            .then(() => refreshApex(this._wired))
            .catch((err) => this.toast('Redesign failed', this.msg(err), 'error'))
            .finally(() => { this.busyId = null; });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    msg(err) { return err && err.body ? err.body.message : 'Unknown error'; }
}