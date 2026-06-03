import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex }    from '@salesforce/apex';
import getLoadingQueue    from '@salesforce/apex/NightLoadingController.getLoadingQueue';
import markLoaded         from '@salesforce/apex/NightLoadingController.markLoaded';

export default class NightLoadingQueue extends LightningElement {

    view;
    error;
    isLoading = true;

    _wiredQueueResult;

    @wire(getLoadingQueue)
    wiredQueue(result) {
        this._wiredQueueResult = result;
        this.isLoading = false;
        const { data, error } = result;
        if (data) {
            // Stamp isSaving=false onto each row so the button can be toggled
            this.view  = {
                ...data,
                trucks: data.trucks.map(t => ({ ...t, isSaving: false }))
            };
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message ?? error?.message ?? 'Unable to load loading queue.';
            this.view  = undefined;
        }
    }

    // ── Computed getters ──────────────────────────────────────────────────────

    get hasTrucks() {
        return !this.isLoading && this.view && this.view.trucks && this.view.trucks.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.error && (!this.view || !this.view.trucks || this.view.trucks.length === 0);
    }

    get hasPending() {
        return this.view && this.view.pendingCount > 0;
    }

    // ── Mark Loaded handler ───────────────────────────────────────────────────

    handleMarkLoaded(event) {
        const ticketId = event.currentTarget.dataset.ticketId;

        // Optimistically disable the button for this row
        this.view = {
            ...this.view,
            trucks: this.view.trucks.map(t =>
                t.ticketId === ticketId ? { ...t, isSaving: true } : t
            )
        };

        markLoaded({ ticketId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Success',
                    message: 'Ticket marked as Loaded.',
                    variant: 'success'
                }));
                return refreshApex(this._wiredQueueResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Error',
                    message: error?.body?.message ?? error?.message ?? 'Failed to mark ticket as loaded.',
                    variant: 'error'
                }));
                // Re-enable the button on failure
                this.view = {
                    ...this.view,
                    trucks: this.view.trucks.map(t =>
                        t.ticketId === ticketId ? { ...t, isSaving: false } : t
                    )
                };
            });
    }
}
