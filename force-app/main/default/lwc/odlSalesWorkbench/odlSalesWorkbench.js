import { LightningElement, wire } from 'lwc';
import getPageData from '@salesforce/apex/ODLSetupMatrixController.getPageData';

export default class OdlSalesWorkbench extends LightningElement {
    pageData = { objectRows: [], pageRows: [], picklistRows: [] };

    @wire(getPageData)
    wiredPageData({ data }) {
        if (data) {
            this.pageData = data;
        }
    }
}