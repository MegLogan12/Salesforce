import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getPipelineSummary from '@salesforce/apex/SchedulingConsoleController.getPipelineSummary';

export default class WorkOrderPipelineKanban extends NavigationMixin(LightningElement) {
    @track _wiredResult;
    @track _columns = [];
    @track _error = null;
    @track isLoading = true;
    @track searchTerm = '';

    @wire(getPipelineSummary, { division: null })
    wiredPipeline(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this._columns = result.data.filter(col => col.count > 0 || ['Ready to Schedule','30 Days'].includes(col.bucket));
            this._error = null;
        } else if (result.error) {
            this._error = result.error && result.error.body ? result.error.body.message : 'Failed to load pipeline data.';
        }
    }

    get columns() {
        const term = (this.searchTerm || '').toLowerCase().trim();
        if (!term) return this._columns;
        return this._columns.map(col => {
            const filtered = (col.lots || []).filter(
                l => (l.name || '').toLowerCase().includes(term)
                  || (l.fmName || '').toLowerCase().includes(term)
            );
            return { ...col, lots: filtered, count: filtered.length };
        }).filter(col => col.count > 0);
    }
    get hasColumns(){ return this._columns.length > 0; }
    get hasError()  { return !!this._error; }
    get errorMsg()  { return this._error; }
    get todayLabel() {
        return new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
    }
    get totalLots() {
        return this._columns.reduce((sum, c) => sum + (c.count || 0), 0);
    }
    get filteredTotal() {
        return this.columns.reduce((sum, c) => sum + (c.count || 0), 0);
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => { this.isLoading = false; });
    }

    handleNavigateLot(event) {
        const lotId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: lotId, actionName: 'view' }
        });
    }
}
