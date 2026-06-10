import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQueue from '@salesforce/apex/NightLoadingQueueController.getQueue';
import markLoaded from '@salesforce/apex/NightLoadingQueueController.markLoaded';
import releaseTruck from '@salesforce/apex/NightLoadingQueueController.releaseTruck';
import regenerate from '@salesforce/apex/NightLoadingQueueController.regenerate';

export default class NightLoadingQueue extends LightningElement {
    @track selectedDate = new Date().toISOString().substring(0, 10);
    @track queue = [];
    @track isLoading = false;
    @track isRegenerating = false;

    connectedCallback() {
        this.loadQueue();
    }

    loadQueue() {
        this.isLoading = true;
        getQueue({ loadDate: this.selectedDate })
            .then(data => {
                this.queue = data.map(t => this.enrichTicket(t));
            })
            .catch(err => this.showError(err))
            .finally(() => { this.isLoading = false; });
    }

    enrichTicket(t) {
        const pct = t.totalLines > 0 ? Math.round((t.loadedLines / t.totalLines) * 100) : 0;
        const allLoaded = t.totalLines > 0 && t.loadedLines === t.totalLines;
        return {
            ...t,
            progressPct: pct,
            progressVariant: allLoaded ? 'circular' : 'base',
            releaseVariant: allLoaded ? 'brand' : 'neutral',
            releaseDisabled: !allLoaded || t.status === 'Released',
            lines: (t.lines || []).map(l => ({
                ...l,
                loadedClass: l.loaded ? 'slds-text-color_success slds-text-title_caps' : ''
            }))
        };
    }

    handleDateChange(evt) {
        this.selectedDate = evt.detail.value;
        this.loadQueue();
    }

    handleMarkLoaded(evt) {
        const lineId = evt.currentTarget.dataset.lineId;
        const ticketId = evt.currentTarget.dataset.ticketId;
        const loaded = evt.detail.checked;

        markLoaded({ lineId, loaded })
            .then(() => {
                this.queue = this.queue.map(t => {
                    if (t.ticketId !== ticketId) return t;
                    const lines = t.lines.map(l => l.lineId === lineId ? { ...l, loaded } : l);
                    const loadedCount = lines.filter(l => l.loaded).length;
                    return this.enrichTicket({ ...t, lines, loadedLines: loadedCount });
                });
            })
            .catch(err => this.showError(err));
    }

    handleRelease(evt) {
        const ticketId = evt.currentTarget.dataset.ticketId;
        releaseTruck({ ticketId })
            .then(() => {
                this.queue = this.queue.map(t =>
                    t.ticketId === ticketId
                        ? this.enrichTicket({ ...t, status: 'Released' })
                        : t
                );
                this.showSuccess('Truck released.');
            })
            .catch(err => this.showError(err));
    }

    handleRegenerate() {
        this.isRegenerating = true;
        regenerate({ loadDate: this.selectedDate })
            .then(() => {
                this.showSuccess('Loading tickets regenerated.');
                this.loadQueue();
            })
            .catch(err => this.showError(err))
            .finally(() => { this.isRegenerating = false; });
    }

    showSuccess(msg) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: msg, variant: 'success' }));
    }

    showError(err) {
        const msg = (err && err.body && err.body.message) ? err.body.message : String(err);
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
    }
}
