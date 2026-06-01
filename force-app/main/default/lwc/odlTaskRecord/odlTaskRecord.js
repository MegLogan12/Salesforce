import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import TASK_STATUS   from '@salesforce/schema/Task.Status';
import TASK_SUBJECT  from '@salesforce/schema/Task.Subject';
import getAdjacentTaskIds from '@salesforce/apex/ODL_TaskController.getAdjacentTaskIds';

const FIELDS = [TASK_STATUS, TASK_SUBJECT];

export default class OdlTaskRecord extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isSaving = false;

    _adjacentIds = { prevId: null, nextId: null };

    // ── Display fields shown in the record form ───────────────────────────────
    fields = [
        'Task.Subject',
        'Task.WhoId',
        'Task.WhatId',
        'Task.OwnerId',
        'Task.ActivityDate',
        'Task.Status',
        'Task.Priority',
        'Task.Type',
        'Task.Description'
    ];

    // ── Wire: current task status ─────────────────────────────────────────────
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    task;

    // ── Wire: adjacent task IDs ───────────────────────────────────────────────
    @wire(getAdjacentTaskIds, { currentTaskId: '$recordId' })
    wiredAdjacent({ data }) {
        if (data) {
            this._adjacentIds = data;
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────

    get isCompleted() {
        return getFieldValue(this.task.data, TASK_STATUS) === 'Completed';
    }

    get completeLabel() {
        return this.isSaving ? 'Saving…' : '✓ Mark Complete';
    }

    get hasPrev() {
        return Boolean(this._adjacentIds && this._adjacentIds.prevId);
    }

    get hasNext() {
        return Boolean(this._adjacentIds && this._adjacentIds.nextId);
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    handleReturn() {
        this[NavigationMixin.Navigate]({
            type:       'standard__navItemPage',
            attributes: { apiName: 'Outdoor_Living_Tasks' }
        });
    }

    handlePrev() {
        if (this._adjacentIds.prevId) {
            this[NavigationMixin.Navigate]({
                type:       'standard__recordPage',
                attributes: { recordId: this._adjacentIds.prevId, actionName: 'view' }
            });
        }
    }

    handleNext() {
        if (this._adjacentIds.nextId) {
            this[NavigationMixin.Navigate]({
                type:       'standard__recordPage',
                attributes: { recordId: this._adjacentIds.nextId, actionName: 'view' }
            });
        }
    }

    async handleMarkComplete() {
        this.isSaving = true;
        try {
            await updateRecord({
                fields: { Id: this.recordId, Status: 'Completed' }
            });
            this.dispatchEvent(new ShowToastEvent({
                title:   'Task completed',
                message: 'The task has been marked as completed.',
                variant: 'success'
            }));
        } catch (err) {
            const msg = err?.body?.message || 'Could not update task.';
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
        } finally {
            this.isSaving = false;
        }
    }
}
