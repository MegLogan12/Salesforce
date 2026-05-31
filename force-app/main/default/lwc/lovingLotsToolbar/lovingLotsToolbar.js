import { LightningElement, api } from 'lwc';

export default class LovingLotsToolbar extends LightningElement {
    @api filters = [];
    @api builderOptions = [];
    @api fmOptions = [];
    @api builderFilter = 'all';
    @api fmFilter = 'all';
    @api searchTerm = '';

    setPipeline(event) {
        this.dispatchEvent(new CustomEvent('pipelinechange', { detail: event.currentTarget.dataset.value }));
    }

    handleBuilderFilter(event) {
        this.dispatchEvent(new CustomEvent('builderchange', { detail: event.target.value }));
    }

    handleFmFilter(event) {
        this.dispatchEvent(new CustomEvent('fmchange', { detail: event.target.value }));
    }

    handleSearch(event) {
        this.dispatchEvent(new CustomEvent('search', { detail: event.target.value }));
    }
}