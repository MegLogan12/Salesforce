import { LightningElement, api, track } from 'lwc';

const SESSION_KEY = 'mclovin-launch-prompt-dismissed';

export default class McLovinLaunchPrompt extends LightningElement {
    @api headline = "Hey, do you need help?";
    @api message = "mcLOVIN' can review a document, email, text, or spreadsheet, tie it to the right Salesforce records, ask for missing required fields, and save when you confirm.";
    @api autoOpen;
    @api contextKey;

    @track showPrompt = false;
    @track showWorkspace = false;

    connectedCallback() {
        if (this.autoOpen !== true && this.autoOpen !== 'true') {
            return;
        }
        try {
            this.showPrompt = window.sessionStorage.getItem(SESSION_KEY) !== '1';
        } catch (e) {
            this.showPrompt = true;
        }
    }

    get showLauncherButton() {
        return !this.showPrompt && !this.showWorkspace;
    }

    handleOpenWorkspace() {
        this.showPrompt = false;
        this.showWorkspace = true;
        this.persistDismissal();
    }

    handleDismissPrompt() {
        this.showPrompt = false;
        this.persistDismissal();
    }

    handleMinimizeWorkspace() {
        this.showWorkspace = false;
    }

    persistDismissal() {
        try {
            window.sessionStorage.setItem(SESSION_KEY, '1');
        } catch (e) {
            // Ignore sessionStorage failures and keep the launcher usable.
        }
    }
}