import { LightningElement, wire, track } from 'lwc';
import getCurrentSnapshot from '@salesforce/apex/CapacityForecastService.getCurrentSnapshot';

export default class CapacityVsDemand extends LightningElement {
    @track snapshot;

    @wire(getCurrentSnapshot)
    onSnapshot({ data, error }) {
        if (data) {
            // Deep copy: wire result is frozen, can't mutate directly
            const copy = JSON.parse(JSON.stringify(data));
            copy.serviceLines = (copy.serviceLines || []).map(sl => {
                const width = Math.min(sl.utilizationPct || 0, 150);
                return {
                    ...sl,
                    barStyle: 'width: ' + width + '%;',
                    statusClass: 'cap-bar cap-bar-' + (sl.status || 'gray')
                };
            });
            this.snapshot = copy;
        } else if (error) {
            console.error('CapacityVsDemand wire error', error);
            this.snapshot = null;
        }
    }
}