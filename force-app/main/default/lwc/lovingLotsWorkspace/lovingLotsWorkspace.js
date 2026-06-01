import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLotsWorkspace from '@salesforce/apex/LovingLotWorkspaceController.getLotsWorkspace';

export default class LovingLotsWorkspace extends NavigationMixin(LightningElement) {
    rows = [];
    columns = [];
    objectLabel = 'Lot';
    objectPluralLabel = 'Lots';
    accountCount = 0;
    communityCount = 0;
    lotCount = 0;
    activeLotCount = 0;
    pipelineOptions = [{ label: 'All', value: 'All' }];
    builderOptions = [];
    fmOptions = [];
    pipelineFilter = 'All';
    builderFilter = 'all';
    fmFilter = 'all';
    searchTerm = '';
    errorMsg = '';

    @wire(getLotsWorkspace)
    wiredWorkspace({ data, error }) {
        if (data) {
            this.objectLabel = data.objectLabel || 'Lot';
            this.objectPluralLabel = data.objectPluralLabel || 'Lots';
            this.accountCount = data.accountCount || 0;
            this.communityCount = data.communityCount || 0;
            this.lotCount = data.lotCount || 0;
            this.activeLotCount = data.activeLotCount || 0;
            this.columns = data.columns || [];
            this.pipelineOptions = data.pipelineOptions?.length ? data.pipelineOptions : [{ label: 'All', value: 'All' }];
            this.builderOptions = data.builderOptions || [];
            this.fmOptions = data.fmOptions || [];
            this.rows = (data.rows || []).map((row) => ({
                ...row,
                pipelineClassName: `chip ${row.pipelineClass || 'cgr'}`,
                lotStatusClassName: `chip ${row.lotStatusClass || 'cgr'}`,
                eight11ClassName: `chip ${row.eight11Class || 'cgr'}`,
                takeoffClassName: `chip ${row.takeoffClass || 'cgr'}`,
                aquaClassName: `chip ${row.aquaClass || 'cgr'}`,
                cells: this.buildCells(row)
            }));
            this.errorMsg = '';
        } else if (error) {
            this.errorMsg = error?.body?.message || error?.message || 'Could not load lots.';
        }
    }

    get isLoading() {
        return !this.rows.length && !this.errorMsg;
    }

    get pipelineFilters() {
        return this.pipelineOptions.map((option) => ({
            label: option.label,
            value: option.value,
            className: `pill ${this.pipelineFilter === option.value ? 'on' : ''}`
        }));
    }

    get filteredRows() {
        const needle = (this.searchTerm || '').trim().toLowerCase();
        return this.rows.filter((row) => {
            if (this.pipelineFilter !== 'All' && row.pipelineBucket !== this.pipelineFilter) return false;
            if (this.builderFilter !== 'all' && row.builderDivisionName !== this.builderFilter) return false;
            if (this.fmFilter !== 'all' && row.fmName !== this.fmFilter) return false;
            if (!needle) return true;
            return [
                row.lotLabel,
                row.lotNumber,
                row.communityName,
                row.builderDivisionName,
                row.fmName,
                row.address,
                row.poNumber,
                row.specType
            ].some((value) => (value || '').toLowerCase().includes(needle));
        });
    }

    setPipeline(event) {
        this.pipelineFilter = event.detail;
    }

    handleBuilderFilter(event) {
        this.builderFilter = event.detail;
    }

    handleFmFilter(event) {
        this.fmFilter = event.detail;
    }

    handleSearch(event) {
        this.searchTerm = event.detail;
    }

    openLot(event) {
        const recordId = event.detail;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: 'Lot__c', actionName: 'view' }
        });
    }

    handleNewLot() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Lot__c', actionName: 'new' }
        });
    }

    buildCells(row) {
        return (this.columns || []).map((column) => {
            const value = row[column.key] || '-';
            const isLink = column.type === 'link';
            const isChip = column.type === 'chip';
            const classValue = column.classKey ? row[column.classKey] : 'cgr';
            return {
                key: column.key,
                value,
                isLink,
                isChip,
                isText: !isLink && !isChip,
                cellClass: column.numeric ? 'num' : '',
                chipClass: `chip ${classValue || 'cgr'}`
            };
        });
    }

    exportCsv() {
        const header = (this.columns || []).map((column) => column.label);
        const rows = this.filteredRows.map((row) => (this.columns || []).map((column) => row[column.key]));
        const csv = [header, ...rows].map((line) => line.map((cell) => `"${String(cell || '').replaceAll('"', '""')}"`).join(',')).join('\n');
        const link = document.createElement('a');
        link.href = `data:text/csv;charset=utf-8,${encodeURIComponent(csv)}`;
        link.download = 'loving-lots.csv';
        link.click();
    }
}