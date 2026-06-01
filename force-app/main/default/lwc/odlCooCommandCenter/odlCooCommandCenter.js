import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getPipelineByLob from '@salesforce/apex/LovingCooController.getPipelineByLob';
import getActivityRisks from '@salesforce/apex/LovingCooController.getActivityRisks';

export default class OdlCooCommandCenter extends NavigationMixin(LightningElement) {
    wiredPipelineResult;
    wiredRiskResult;
    pipeline = [];
    risks = [];
    errorMessage = '';

    @wire(getPipelineByLob)
    wiredPipeline(value) {
        this.wiredPipelineResult = value;
        if (value.data) {
            this.pipeline = value.data;
            this.errorMessage = '';
        } else if (value.error) {
            this.pipeline = [];
            this.errorMessage = (value.error.body && value.error.body.message) ? value.error.body.message : 'Unable to load pipeline data.';
        }
    }

    @wire(getActivityRisks)
    wiredRisks(value) {
        this.wiredRiskResult = value;
        if (value.data) {
            this.risks = value.data;
        } else if (value.error) {
            this.risks = [];
            if (!this.errorMessage) {
                this.errorMessage = (value.error.body && value.error.body.message) ? value.error.body.message : 'Unable to load activity risks.';
            }
        }
    }

    get hasError() { return !!this.errorMessage; }

    get pipelineRows() {
        return (this.pipeline || []).map((row) => ({
            ...row,
            pipelineDisplay: this.formatCurrency(row.pipeline),
            weightedDisplay: this.formatCurrency(row.weighted)
        }));
    }

    get riskRows() {
        return this.risks || [];
    }

    get pipelineDisplay() {
        return this.formatCurrency((this.pipeline || []).reduce((sum, row) => sum + (row.pipeline || 0), 0));
    }

    get umbPipelineDisplay() {
        return this.formatCurrency(this.findPipeline('UMB'));
    }

    get designBuildPipelineDisplay() {
        return this.formatCurrency(this.findPipeline('Custom Build'));
    }

    get lawnPipelineDisplay() {
        return this.formatCurrency(this.findPipeline('Lawn Care'));
    }

    get followUpsDue() {
        return (this.pipeline || []).reduce((sum, row) => sum + (row.followUpsDue || 0), 0);
    }

    get atRiskCount() {
        return (this.pipeline || []).reduce((sum, row) => sum + (row.atRisk || 0), 0);
    }

    findPipeline(label) {
        const row = (this.pipeline || []).find((item) => item.lob === label);
        return row ? row.pipeline : 0;
    }

    formatCurrency(value) {
        const amount = Number(value || 0);
        if (amount >= 1000000) {
            return `$${(amount / 1000000).toFixed(2)}M`;
        }
        if (amount >= 1000) {
            return `$${Math.round(amount / 1000)}K`;
        }
        return `$${Math.round(amount)}`;
    }

    handleRefresh() {
        if (this.wiredPipelineResult) {
            refreshApex(this.wiredPipelineResult);
        }
        if (this.wiredRiskResult) {
            refreshApex(this.wiredRiskResult);
        }
    }

    handleOpenReports() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Report',
                actionName: 'home'
            }
        });
    }
}