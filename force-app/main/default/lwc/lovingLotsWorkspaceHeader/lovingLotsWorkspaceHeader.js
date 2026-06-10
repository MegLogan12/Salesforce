import { LightningElement, api } from 'lwc';

export default class LovingLotsWorkspaceHeader extends LightningElement {
    @api objectLabel = 'Lot';
    @api objectPluralLabel = 'Lots';
    @api accountCount = 0;
    @api communityCount = 0;
    @api lotCount = 0;
    @api activeLotCount = 0;

    handleExport() {
        this.dispatchEvent(new CustomEvent('export'));
    }

    handleNewLot() {
        this.dispatchEvent(new CustomEvent('newlot'));
    }
}