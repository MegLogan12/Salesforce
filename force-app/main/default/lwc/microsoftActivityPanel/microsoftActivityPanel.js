import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getLoggedEmails    from '@salesforce/apex/MicrosoftEmailService.getLoggedEmails';
import getCurrentUserUpn  from '@salesforce/apex/MicrosoftEmailService.getCurrentUserUpn';
import sendAndLog         from '@salesforce/apex/MicrosoftEmailService.sendAndLog';
import getMyEvents        from '@salesforce/apex/MicrosoftCalendarService.getMyEvents';
import createEvent        from '@salesforce/apex/MicrosoftCalendarService.createEvent';

export default class MicrosoftActivityPanel extends LightningElement {
    @api recordId;

    // ── Emails ────────────────────────────────────────────────────────────────
    @wire(getLoggedEmails, { recordId: '$recordId' })
    _emailsWire;

    get emails()        { return this._emailsWire?.data ?? []; }
    get hasEmails()     { return this.emails.length > 0; }
    get emailsLoading() { return !this._emailsWire?.data && !this._emailsWire?.error; }
    get emailError()    { return this._emailsWire?.error?.body?.message ?? null; }

    // ── Calendar ──────────────────────────────────────────────────────────────
    @track events        = [];
    @track calendarLoading = false;
    @track calendarError   = null;

    get hasEvents() { return this.events.length > 0; }

    // ── User UPN ──────────────────────────────────────────────────────────────
    @wire(getCurrentUserUpn)
    _upnWire;

    get currentUpn() { return this._upnWire?.data ?? null; }
    get noUpn()      { return this._upnWire?.data === '' || this._upnWire?.data === null; }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this._loadCalendar();
    }

    async _loadCalendar() {
        this.calendarLoading = true;
        this.calendarError   = null;
        try {
            this.events = await getMyEvents();
        } catch (e) {
            this.calendarError = e?.body?.message ?? 'Could not load calendar events.';
        } finally {
            this.calendarLoading = false;
        }
    }

    // ── Email modal state ─────────────────────────────────────────────────────
    @track emailModalOpen  = false;
    @track emailTo         = '';
    @track emailSubject    = '';
    @track emailBody       = '';
    @track emailSendError  = null;
    @track sendingEmail    = false;

    openEmailModal()  { this.emailModalOpen = true;  this.emailSendError = null; }
    closeEmailModal() { this.emailModalOpen = false; }

    onEmailTo(e)      { this.emailTo      = e.target.value; }
    onEmailSubject(e) { this.emailSubject = e.target.value; }
    onEmailBody(e)    { this.emailBody    = e.target.value; }

    async handleSendEmail() {
        if (!this.currentUpn) {
            this.emailSendError = 'Your Microsoft UPN is not set. Ask your admin to update your User record.';
            return;
        }
        const toList = this.emailTo.split(',').map(s => s.trim()).filter(Boolean);
        if (!toList.length || !this.emailSubject) {
            this.emailSendError = 'To and Subject are required.';
            return;
        }
        this.sendingEmail   = true;
        this.emailSendError = null;
        try {
            await sendAndLog({
                fromUpn:     this.currentUpn,
                toAddresses: toList,
                subject:     this.emailSubject,
                htmlBody:    this.emailBody,
                whatId:      this.recordId,
                whoId:       null
            });
            this.dispatchEvent(new ShowToastEvent({ title: 'Email sent', message: 'Logged in Salesforce and sent via Outlook.', variant: 'success' }));
            this.closeEmailModal();
            await refreshApex(this._emailsWire);
        } catch (e) {
            this.emailSendError = e?.body?.message ?? 'Failed to send email.';
        } finally {
            this.sendingEmail = false;
        }
    }

    // ── Meeting modal state ───────────────────────────────────────────────────
    @track calendarModalOpen  = false;
    @track meetingSubject     = '';
    @track meetingStart       = '';
    @track meetingEnd         = '';
    @track meetingLocation    = '';
    @track meetingAttendees   = '';
    @track meetingNotes       = '';
    @track meetingCreateError = null;
    @track creatingMeeting    = false;

    openCalendarModal()  { this.calendarModalOpen = true;  this.meetingCreateError = null; }
    closeCalendarModal() { this.calendarModalOpen = false; }

    onMeetingSubject(e)   { this.meetingSubject   = e.target.value; }
    onMeetingStart(e)     { this.meetingStart     = e.target.value; }
    onMeetingEnd(e)       { this.meetingEnd       = e.target.value; }
    onMeetingLocation(e)  { this.meetingLocation  = e.target.value; }
    onMeetingAttendees(e) { this.meetingAttendees = e.target.value; }
    onMeetingNotes(e)     { this.meetingNotes     = e.target.value; }

    async handleCreateMeeting() {
        if (!this.currentUpn) {
            this.meetingCreateError = 'Your Microsoft UPN is not set. Ask your admin to update your User record.';
            return;
        }
        if (!this.meetingSubject || !this.meetingStart || !this.meetingEnd) {
            this.meetingCreateError = 'Subject, Start, and End are required.';
            return;
        }
        const attendeeList = this.meetingAttendees.split(',').map(s => s.trim()).filter(Boolean);
        this.creatingMeeting    = true;
        this.meetingCreateError = null;
        try {
            // datetime-local returns "YYYY-MM-DDTHH:mm" — append :00 for Graph
            const startIso = this.meetingStart.length === 16 ? this.meetingStart + ':00' : this.meetingStart;
            const endIso   = this.meetingEnd.length   === 16 ? this.meetingEnd   + ':00' : this.meetingEnd;
            await createEvent({
                organizerUpn:  this.currentUpn,
                subject:       this.meetingSubject,
                startIso,
                endIso,
                location:      this.meetingLocation,
                body:          this.meetingNotes,
                attendeeEmails: attendeeList,
                whatId:        this.recordId
            });
            this.dispatchEvent(new ShowToastEvent({ title: 'Meeting created', message: 'Event created in Outlook and logged in Salesforce.', variant: 'success' }));
            this.closeCalendarModal();
            this._loadCalendar();
        } catch (e) {
            this.meetingCreateError = e?.body?.message ?? 'Failed to create meeting.';
        } finally {
            this.creatingMeeting = false;
        }
    }
}
