import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import SCOPE_NOTES from '@salesforce/schema/Community__c.Scope_Notes__c';
import SOD_TYPE from '@salesforce/schema/Community__c.Sod_Type__c';
import SOD_SQFT from '@salesforce/schema/Community__c.Sod_Sqft__c';
import PINE_STRAW_OR_MULCH from '@salesforce/schema/Community__c.Pine_Straw_Or_Mulch__c';
// Pine_Straw_Coverage_Per_Bale__c and Avg_Sod_Roll_Coverage__c not in production — removed
import PLANT_TYPES from '@salesforce/schema/Community__c.Plant_Types__c';
import SHRUB_PACKAGE_DETAILS from '@salesforce/schema/Community__c.Shrub_Package_Details__c';
import STREET_TREE_SPECIES from '@salesforce/schema/Community__c.Street_Tree_Species__c';
import STREET_TREES_COUNT from '@salesforce/schema/Community__c.Street_Trees_Count__c';
import LOT_TREES_COUNT from '@salesforce/schema/Community__c.Lot_Trees_Count__c';

const FIELDS = [
    SCOPE_NOTES, SOD_TYPE, SOD_SQFT, PINE_STRAW_OR_MULCH,
    PLANT_TYPES, SHRUB_PACKAGE_DETAILS,
    STREET_TREE_SPECIES, STREET_TREES_COUNT, LOT_TREES_COUNT
];

export default class CommunityScope extends LightningElement {
    @api recordId;
    _record;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) { this._record = data; this.error = undefined; }
        else if (error) {
            this._record = undefined;
            this.error = (error.body && error.body.message) ? error.body.message : 'Unable to load scope data.';
        }
    }

    get isLoaded() { return this._record !== undefined; }
    get hasError() { return !!this.error; }
    get scopeNotes() { return getFieldValue(this._record, SCOPE_NOTES) || null; }
    get hasScopeNotes() { return !!getFieldValue(this._record, SCOPE_NOTES); }
    get sodType() { return getFieldValue(this._record, SOD_TYPE) || '—'; }
    get sodSqft() { const v = getFieldValue(this._record, SOD_SQFT); return v != null ? v.toLocaleString() : '—'; }
    get avgSodRollCoverage() { return '—'; } // field not in production
    get pineStrawOrMulch() { return getFieldValue(this._record, PINE_STRAW_OR_MULCH) || '—'; }
    get pineStrawCoverage() { return '—'; } // field not in production
    get plantTypes() { return getFieldValue(this._record, PLANT_TYPES) || null; }
    get hasPlantTypes() { return !!getFieldValue(this._record, PLANT_TYPES); }
    get shrubPackageDetails() { return getFieldValue(this._record, SHRUB_PACKAGE_DETAILS) || '—'; }
    get streetTreeSpecies() { return getFieldValue(this._record, STREET_TREE_SPECIES) || '—'; }
    get streetTreesCount() { const v = getFieldValue(this._record, STREET_TREES_COUNT); return v != null ? v : '—'; }
    get lotTreesCount() { const v = getFieldValue(this._record, LOT_TREES_COUNT); return v != null ? v : '—'; }
}