import { LightningElement, api } from 'lwc';

export default class LovingLotTabs extends LightningElement {
    @api activeTab = 'details';
    @api workOrderCount = 0;
    @api photoCount = 0;

    get detailsTabClass() {
        return this.tabClass('details');
    }

    get pipelineTabClass() {
        return this.tabClass('pipeline');
    }

    get workOrdersTabClass() {
        return this.tabClass('workorders');
    }

    get photosTabClass() {
        return this.tabClass('photos');
    }

    get aquaTabClass() {
        return this.tabClass('aqua');
    }

    tabClass(tabName) {
        return `subtab ${this.activeTab === tabName ? 'on' : ''}`;
    }

    handleTab(event) {
        this.dispatchEvent(new CustomEvent('tabchange', { detail: event.currentTarget.dataset.tab }));
    }
}