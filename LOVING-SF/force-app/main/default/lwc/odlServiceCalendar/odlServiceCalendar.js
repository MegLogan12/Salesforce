import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getServiceCalendar from '@salesforce/apex/ODL_WorkController.getServiceCalendar';

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const EVENT_CLASSES = ['event', 'event blue', 'event green', 'event purple'];

export default class OdlServiceCalendar extends LightningElement {
    @track appointments = [];
    consultCount = 0;
    siteVisitCount = 0;
    installCount = 0;
    totalCount = 0;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getServiceCalendar)
    wiredData({ error, data }) {
        if (data) {
            this.appointments = data.map((a, i) => ({
                ...a,
                startFormatted: a.SchedStartTime ? new Date(a.SchedStartTime).toLocaleString('en-US', {month:'short', day:'numeric', hour:'numeric', minute:'2-digit'}) : '—',
                endFormatted: a.SchedEndTime ? new Date(a.SchedEndTime).toLocaleString('en-US', {hour:'numeric', minute:'2-digit'}) : '—'
            }));
            this.totalCount = data.length;
        }
    }

    get calendarDays() {
        const today = new Date();
        const startOfWeek = new Date(today);
        startOfWeek.setDate(today.getDate() - today.getDay());
        return Array.from({ length: 7 }, (_, i) => {
            const d = new Date(startOfWeek);
            d.setDate(startOfWeek.getDate() + i);
            const dayAppts = this.appointments.filter(a => {
                if (!a.SchedStartTime) return false;
                const apptDate = new Date(a.SchedStartTime);
                return apptDate.getDay() === d.getDay() && apptDate.getDate() === d.getDate();
            });
            return {
                dayName: DAY_NAMES[d.getDay()],
                count: dayAppts.length,
                events: dayAppts.slice(0, 3).map((a, idx) => ({
                    id: a.Id || idx,
                    label: a.Subject || a.AppointmentNumber || 'Appointment',
                    cssClass: EVENT_CLASSES[idx % EVENT_CLASSES.length]
                }))
            };
        });
    }

    get noAppts() { return this.appointments.length === 0; }
}
