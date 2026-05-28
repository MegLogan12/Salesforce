import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import homeownerStyles from '@salesforce/resourceUrl/homeownerStyles';
import getTaskDashboard from '@salesforce/apex/ODL_TaskController.getTaskDashboard';

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export default class OdlTasks extends LightningElement {
    @track allTasks = [];
    @track overdueTasks = [];
    @track todayTasks = [];
    @track upcomingTasks = [];
    @track activeView = 'today';
    @track searchTerm = '';
    overdueCount = 0;
    todayCount = 0;
    upcomingCount = 0;
    voicemailCount = 0;
    completedTodayCount = 0;

    connectedCallback() {
        loadStyle(this, homeownerStyles).catch(() => {});
    }

    @wire(getTaskDashboard)
    wiredData({ error, data }) {
        if (data) {
            const mapTask = t => ({
                ...t,
                whatName: t.What ? t.What.Name : '—',
                dueDateFormatted: t.ActivityDate ? new Date(t.ActivityDate + 'T12:00:00').toLocaleDateString('en-US', {month:'short', day:'numeric'}) : '—',
                statusChipClass: t.Status === 'Completed' ? 'chip cg' : 'chip ca'
            });
            this.overdueTasks = (data.overdueTasks || []).map(mapTask);
            this.todayTasks = (data.todayTasks || []).map(mapTask);
            this.upcomingTasks = (data.upcomingTasks || []).map(mapTask);
            this.overdueCount = data.overdueCount || 0;
            this.todayCount = data.todayCount || 0;
            this.upcomingCount = this.upcomingTasks.length;
            const allMapped = [...this.overdueTasks, ...this.todayTasks, ...this.upcomingTasks];
            this.voicemailCount = allMapped.filter(t => t.Subject && t.Subject.toLowerCase().includes('voicemail')).length;
            this.completedTodayCount = (data.completedTodayTasks || []).length;
        }
    }

    get visibleTasks() {
        let base = this.activeView === 'overdue' ? this.overdueTasks : this.activeView === 'upcoming' ? this.upcomingTasks : this.todayTasks;
        if (this.searchTerm) {
            const t = this.searchTerm.toLowerCase();
            base = base.filter(task => (task.Subject || '').toLowerCase().includes(t));
        }
        return base;
    }

    get allChipClass() { return this.activeView === 'today' ? 'filter-chip on' : 'filter-chip'; }
    get overdueChipClass() { return this.activeView === 'overdue' ? 'filter-chip on' : 'filter-chip'; }
    get upcomingChipClass() { return this.activeView === 'upcoming' ? 'filter-chip on' : 'filter-chip'; }
    get umbChipClass() { return this.activeView === 'UMB' ? 'filter-chip on' : 'filter-chip'; }
    get cbChipClass() { return this.activeView === 'Custom Build' ? 'filter-chip on' : 'filter-chip'; }
    get lcChipClass() { return this.activeView === 'Lawn Care' ? 'filter-chip on' : 'filter-chip'; }

    showAll() { this.activeView = 'today'; }
    showVoicemail() { this.activeView = 'voicemail'; }
    showOverdue() { this.activeView = 'overdue'; }
    showUpcoming() { this.activeView = 'upcoming'; }
    filterUmb() { this.activeView = 'UMB'; }
    filterCb() { this.activeView = 'Custom Build'; }
    filterLc() { this.activeView = 'Lawn Care'; }
    handleSearch(e) { this.searchTerm = e.target.value; }

    get calendarDays() {
        const today = new Date();
        const startOfWeek = new Date(today);
        startOfWeek.setDate(today.getDate() - today.getDay());
        const all = [...this.overdueTasks, ...this.todayTasks, ...this.upcomingTasks];
        return Array.from({ length: 7 }, (_, i) => {
            const d = new Date(startOfWeek);
            d.setDate(startOfWeek.getDate() + i);
            const dateStr = d.toISOString().split('T')[0];
            const dayTasks = all.filter(t => t.ActivityDate === dateStr);
            return {
                label: d.toLocaleDateString('en-US', { weekday: 'short', day: 'numeric' }),
                dayName: DAY_NAMES[d.getDay()],
                count: dayTasks.length,
                events: dayTasks.slice(0, 3).map(t => ({ label: t.Subject, cssClass: 'event' }))
            };
        });
    }

    get noTasks() { return this.visibleTasks.length === 0; }
}
