import { LightningElement, track, api } from 'lwc';
import ASSETS from '@salesforce/resourceUrl/askMclovin';
import sendMessage from '@salesforce/apex/McLovinChatController.sendMessage';

const WITTY = [
    'Need a hand?',
    'I do smart answers, not scavenger hunts.',
    'Got answers, ideas, and the occasional save-your-day moment.',
    "Stuck? Let's figure it out."
];

const CHIP_PROMPTS = {
    po:        'I need to process a Purchase Order. What information do I need and how do I enter it in Salesforce? Keep it brief.',
    scope:     'Walk me through a scope of work intake quickly. What do I need to provide?',
    account:   'I need to create a new account. What type should it be and what information is required?',
    homeowner: 'I have a homeowner intake to process. What do I need to collect from them?',
    find:      'Help me find an existing job or work order. What is the best way to search?',
    missing:   'What information is most commonly missing on work orders that causes problems later? Be specific and brief.'
};

export default class AskMclovin extends LightningElement {
    headUrl = ASSETS + '/head.png';
    fullUrl  = ASSETS + '/full.png';
    peekUrl  = ASSETS + '/peek.png';

    @track state      = 'open';
    @track pos        = { x: null, y: null };
    @track nudgeText  = '';
    @track nudgeOn    = false;
    @track peekOn     = false;
    @track peekBubbleOn = false;
    @track isThinking = false;

    _history   = [];
    _drag      = null;
    _idleTimer = null;
    _nudgeTimer = null;
    _moveH     = null;
    _upH       = null;
    _dragMoved = false;

    get isBadge() { return this.state === 'badge'; }
    get isOpen()  { return this.state === 'open'; }
    get mcClass() { return 'mc'; }
    get mcStyle() {
        if (this.pos.x === null) return 'left:auto;right:34px;top:auto;bottom:34px;';
        return `left:${this.pos.x}px;top:${this.pos.y}px;right:auto;bottom:auto;`;
    }
    get nudgeClass()      { return 'bubble nudge pe' + (this.nudgeOn ? ' show' : ''); }
    get nudgeStyle()      { return this._nudgeStyle || ''; }
    get peekClass()       { return 'peek' + (this.peekOn ? ' in' : ''); }
    get peekBubbleClass() { return 'bubble' + (this.peekBubbleOn ? ' show' : ''); }

    connectedCallback() {
        this._moveH = (e) => this.onDragMove(e);
        this._upH   = () => this.onDragEnd();
        window.addEventListener('mousemove', this._moveH);
        window.addEventListener('touchmove', this._moveH, { passive: false });
        window.addEventListener('mouseup',   this._upH);
        window.addEventListener('touchend',  this._upH);
        // Show full-body intro, then shrink to badge after 6 seconds
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.state = 'badge';
            this.scheduleIdle();
        }, 6000);
    }

    disconnectedCallback() {
        window.removeEventListener('mousemove', this._moveH);
        window.removeEventListener('touchmove', this._moveH);
        window.removeEventListener('mouseup',   this._upH);
        window.removeEventListener('touchend',  this._upH);
        clearTimeout(this._idleTimer);
        clearTimeout(this._nudgeTimer);
    }

    /* ---- public API ---- */
    @api open()       { this.state = 'open';  this.nudgeOn = false; }
    @api minimize()   { this.state = 'badge'; this.scheduleIdle(); }
    @api peek()       { this.doPeek(); }
    @api say(text)    { this.showNudge(text, true); }

    /* ---- interactions ---- */
    onBadgeClick() { if (!this._dragMoved) this.open(); }

    onChip(e) {
        const q = e.currentTarget.dataset.q;
        const prompt = CHIP_PROMPTS[q];
        if (prompt) this.callAI(prompt);
    }

    onSend() {
        const inp = this.template.querySelector('.askbar input');
        if (inp && inp.value.trim()) {
            this.callAI(inp.value.trim());
            inp.value = '';
        }
    }

    onAskKey(e) { if (e.key === 'Enter') this.onSend(); }

    /* ---- AI call ---- */
    async callAI(text) {
        if (this.isThinking) return;
        this.isThinking = true;
        this.showNudge('Thinking...', false);

        this._history.push({ role: 'user', content: text });
        // Keep last 10 turns to stay within token limits
        const recent = this._history.slice(-10);

        try {
            const result = await sendMessage({ historyJson: JSON.stringify(recent) });
            if (result.success) {
                const reply = result.reply;
                this._history.push({ role: 'assistant', content: reply });
                // Show in nudge bubble — truncate to 280 chars for the small bubble
                const display = reply.length > 280 ? reply.slice(0, 277) + '...' : reply;
                this.showNudge(display, true);
            } else {
                this.showNudge('Ran into an issue. ' + (result.errorMessage || 'Try again.'), true);
            }
        } catch (err) {
            const msg = (err.body && err.body.message) ? err.body.message : 'Check your connection.';
            this.showNudge('Could not reach the server. ' + msg, true);
        } finally {
            this.isThinking = false;
        }
    }

    /* ---- nudge bubble ---- */
    showNudge(text, sticky) {
        this.nudgeText = text;
        const mc = this.template.querySelector('.mc');
        if (mc) {
            const b = mc.getBoundingClientRect();
            this._nudgeStyle = `left:${Math.max(12, b.left - 230)}px;top:${b.top - 6}px;max-width:220px;`;
        }
        this.nudgeOn = true;
        clearTimeout(this._nudgeTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._nudgeTimer = setTimeout(() => { this.nudgeOn = false; }, sticky ? 7000 : 3200);
    }

    /* ---- idle: occasional nudge or peek when minimized ---- */
    scheduleIdle() {
        clearTimeout(this._idleTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._idleTimer = setTimeout(() => {
            if (this.state === 'badge') {
                if (Math.random() < 0.5) this.doPeek();
                else this.showNudge(WITTY[Math.floor(Math.random() * WITTY.length)]);
            }
            this.scheduleIdle();
        }, 7000 + Math.random() * 6000);
    }

    doPeek() {
        this.peekOn = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.peekBubbleOn = true; }, 420);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.peekBubbleOn = false; this.peekOn = false; }, 4200);
    }

    /* ---- drag ---- */
    onDragStart(e) {
        const p = e.touches ? e.touches[0] : e;
        const mc = this.template.querySelector('.mc');
        const b  = mc.getBoundingClientRect();
        this._drag     = { baseX: b.left, baseY: b.top, startX: p.clientX, startY: p.clientY };
        this._dragMoved = false;
        e.preventDefault();
    }
    onDragMove(e) {
        if (!this._drag) return;
        const p  = e.touches ? e.touches[0] : e;
        const dx = p.clientX - this._drag.startX;
        const dy = p.clientY - this._drag.startY;
        if (Math.abs(dx) + Math.abs(dy) > 4) this._dragMoved = true;
        this.pos = {
            x: Math.max(8, Math.min(window.innerWidth  - 90, this._drag.baseX + dx)),
            y: Math.max(8, Math.min(window.innerHeight - 90, this._drag.baseY + dy))
        };
        if (this.state === 'open') this.nudgeOn = false;
    }
    onDragEnd() {
        this._drag = null;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._dragMoved = false; }, 30);
    }
}
