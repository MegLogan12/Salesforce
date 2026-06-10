import { LightningElement, track, api } from 'lwc';
import sendMessage from '@salesforce/apex/McLovinChatController.sendMessage';

const DEFAULT_PLACEHOLDER = 'Paste an email, PO, scope, or notes...';

const QUICK_ACTIONS = {
    po: {
        autoSend: false,
        placeholder: 'Paste the PO text or describe it here, then hit Send...'
    },
    scope: {
        autoSend: true,
        message: 'I need to process a scope of work intake. What information do I need to provide and what happens with it in Salesforce?'
    },
    account: {
        autoSend: true,
        message: 'I need to create a new account. Walk me through what information is required and what type of account I should create.'
    },
    homeowner: {
        autoSend: true,
        message: 'I have a homeowner intake to process. What information do I need to collect from them and how do I enter it correctly?'
    },
    find: {
        autoSend: false,
        placeholder: 'Describe the job you\'re looking for (homeowner name, address, WO number, or any details)...'
    },
    missing: {
        autoSend: true,
        message: 'What information is most commonly missing or filled in wrong on work orders and intake records? What should I always double-check before moving a record forward?'
    }
};

let nextId = 0;

export default class McLovinEmployeeAgentWorkspace extends LightningElement {
    @api contextKey;
    @api pageTitle;
    @track messages = [];
    @track inputText = '';
    @track inputPlaceholder = DEFAULT_PLACEHOLDER;
    @track isLoading = false;
    @track isCollapsed = false;

    get isEmpty() {
        return this.messages.length === 0 && !this.isLoading;
    }

    get sendDisabled() {
        return this.isLoading || !this.inputText.trim();
    }

    get panelBodyClass() {
        return this.isCollapsed ? 'body hidden' : 'body';
    }

    get inputWrapClass() {
        return this.isCollapsed ? 'input-wrap hidden' : 'input-wrap';
    }

    handleInput(evt) {
        this.inputText = evt.target.value;
    }

    handleKeyDown(evt) {
        if (evt.key === 'Enter' && !evt.shiftKey) {
            evt.preventDefault();
            this.handleSend();
        }
    }

    handleQuickAction(evt) {
        const type = evt.currentTarget.dataset.type;
        const action = QUICK_ACTIONS[type];
        if (!action) return;

        if (action.autoSend) {
            this.inputText = action.message;
            this.handleSend();
        } else {
            this.inputPlaceholder = action.placeholder;
            const box = this.template.querySelector('.input-box');
            if (box) box.focus();
        }
    }

    handleClose() {
        this.isCollapsed = !this.isCollapsed;
    }

    handleClear() {
        this.messages = [];
        this.inputText = '';
        this.inputPlaceholder = DEFAULT_PLACEHOLDER;
    }

    async handleSend() {
        const text = this.inputText.trim();
        if (!text || this.isLoading) return;

        this.inputText = '';
        this.inputPlaceholder = DEFAULT_PLACEHOLDER;
        this.addMessage('user', text);
        this.isLoading = true;

        try {
            const history = this.messages
                .slice(-20)
                .map(m => ({ role: m.isUser ? 'user' : 'assistant', content: m.content }));

            const result = await sendMessage({ historyJson: JSON.stringify(history) });

            if (result.success) {
                this.addMessage('assistant', result.reply);
            } else {
                this.addMessage('assistant', 'Something went wrong on my end. ' + (result.errorMessage || 'Try again in a moment.'));
            }
        } catch (err) {
            const msg = (err.body && err.body.message) ? err.body.message : (err.message || 'Unknown error');
            this.addMessage('assistant', 'Could not reach the server. ' + msg);
        } finally {
            this.isLoading = false;
            this.scrollToBottom();
        }
    }

    addMessage(role, content) {
        const isUser = role === 'user';
        this.messages = [...this.messages, {
            id: ++nextId,
            content,
            isUser,
            rowCls: 'msg-row ' + (isUser ? 'user-row' : 'bot-row'),
            bubbleCls: isUser ? 'bubble-user' : 'bubble-bot'
        }];
        this.scrollToBottom();
    }

    scrollToBottom() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const el = this.template.querySelector('[data-id="chatbody"]');
            if (el) el.scrollTop = el.scrollHeight;
        }, 50);
    }
}
