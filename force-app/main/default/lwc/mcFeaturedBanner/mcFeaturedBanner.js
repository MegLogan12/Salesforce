import { LightningElement, api } from 'lwc';

export default class McFeaturedBanner extends LightningElement {
    @api headline = 'This Week';
    @api subhead = '';
    @api ctaLabel = '';
    @api ctaUrl = '';

    handleCtaClick() {
        if (this.ctaUrl) window.open(this.ctaUrl, '_blank');
    }
}