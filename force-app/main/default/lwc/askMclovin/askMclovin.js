import { LightningElement, track, api } from 'lwc';
import ASSETS from '@salesforce/resourceUrl/askMclovin';
import sendMessage from '@salesforce/apex/McLovinChatController.sendMessage';

// Behavior config — tune timings, flags, and dialogue here without touching logic
const C = {
    timings: {
        entranceDelayMs:          600,
        entranceFadeMs:           350,
        walkSpeedPxPerSec:        240,
        runSpeedPxPerSec:         470,
        turnMs:                   320,
        idleBeforeWanderMinMs:  12000,
        idleBeforeWanderMaxMs:  22000,
        perchSettleMs:            450,
        peekIntervalMinMs:      30000,
        peekIntervalMaxMs:      60000,
        peekHoldMs:              4200,
        lineCooldownMs:          9000,
        maxLinesPerMinute:           4,
        quietWhileTypingMs:      4000,
        returnToPerchAfterIdleMs:8000,
        celebrateCooldownMs:   120000
    },
    flags: {
        walkInOnLoad:              true,
        wanderWhenIdle:            true,
        perchOnForms:              true,
        hangOnEdgeWhenNoPerch:     true,
        followOnRecordChange:      true,
        rememberLastPosition:      true,
        neverCoverFocusedField:    true,
        muteLinesWhileTyping:      true
    },
    perchTypes: {
        'sit-top':   { anchor: 'topRight',    offsetX: -28, offsetY:  -6 },
        'lean-left': { anchor: 'leftMid',     offsetX: -10, offsetY:   0 },
        'lean-right':{ anchor: 'rightMid',    offsetX:  10, offsetY:   0 },
        'lay-top':   { anchor: 'topCenter',   offsetX:   0, offsetY: -10 },
        'stand':     { anchor: 'bottomRight', offsetX:   0, offsetY:   0 },
        'hang-edge': { anchor: 'screenEdge',  offsetX:   0, offsetY:   0 }
    },
    dialogue: {
        entrance: [
            "Morning. Let's go close something.",
            "I'm up. Point me at the hard one.",
            "Back at it. What are we winning today?",
            "Reporting for duty. And snacks."
        ],
        idle: [
            "I do smart answers, not scavenger hunts.",
            "Got answers, ideas, and the occasional save your day moment.",
            "Stuck? Say the word.",
            "I'll be right here being charming."
        ],
        perch_generic: [
            "I'll hang out here while you work.",
            "Comfy. Holler if you need me.",
            "Take your time, I've got nowhere to be."
        ],
        context: {
            opportunity: [
                "Want the smart way to close this one?",
                "Tell me the objection and I'll hand you the line.",
                "Stage looks ready to move. Nudge it?"
            ],
            account: [
                "Want a quick read on this account before you call?",
                "I can pull the last three touches if you want."
            ],
            lead: [
                "Fresh lead. Want a fast qualifying question?",
                "I can draft the first outreach if you like."
            ],
            quote: [
                "Want me to sanity check this quote?",
                "Margins look tight. Want options?"
            ],
            task: [
                "Knock this out and I'll cheer.",
                "Want me to draft the follow up?"
            ],
            report: [
                "Want the one number that actually matters here?",
                "I can summarize this in a sentence."
            ]
        },
        minimized: [ "Need a hand?", "Tap me anytime.", "I'll be over here." ],
        peek:      [ "Psst... need help closing this?", "Psst... I do shortcuts too.", "Knock knock. It's your unfair advantage." ],
        drag_pickup: [ "Wheee.", "Where to, boss?" ],
        drag_drop:   [ "Good spot.", "Right here works.", "Cozy." ]
    }
};

// States
const S = { ENTER:'enter', BADGE:'badge', WELCOME:'welcome', PERCH:'perch', EDGE:'edge', DRAG:'drag' };

// Chip prompts wired to OpenAI
const CHIP_PROMPTS = {
    po:        'I need to process a Purchase Order. What information do I need and how do I enter it in Salesforce? Keep it brief.',
    scope:     'Walk me through a scope of work intake quickly. What do I need to provide?',
    account:   'I need to create a new account. What type should it be and what information is required?',
    homeowner: 'I have a homeowner intake to process. What do I need to collect from them?',
    find:      'Help me find an existing job or work order. What is the best way to search?',
    missing:   'What information is most commonly missing on work orders that causes problems later? Be specific and brief.'
};

// Pick a random item from an array, never the same as last
function pick(arr, last) {
    if (!arr || !arr.length) return '';
    const opts = arr.filter(l => l !== last);
    return opts[Math.floor(Math.random() * opts.length)] || arr[0];
}

export default class AskMclovin extends LightningElement {
    headUrl = ASSETS + '/head.png';
    fullUrl  = ASSETS + '/full.png';
    peekUrl  = ASSETS + '/peek.png';

    @track _state     = S.ENTER;
    @track pos        = { x: -160, y: 0 };   // off-screen left initially
    @track isWalking  = false;
    @track faceRight  = true;
    @track nudgeText  = '';
    @track nudgeOn    = false;
    @track isThinking = false;

    _history       = [];
    _drag          = null;
    _dragMoved     = false;
    _moveH         = null;
    _upH           = null;
    _peekTimer     = null;
    _idleTimer     = null;
    _nudgeTimer    = null;
    _walkTimer     = null;
    _lastLine      = '';
    _lineCount     = 0;
    _lineMinute    = 0;
    _typingTimer   = null;
    _typing        = false;
    _currentPerch  = null;
    _reducedMotion = false;
    _walkTrans     = '';

    /* ---- computed getters ---- */
    get isBadge()   { return this._state === S.BADGE; }
    get isOpen()    { return this._state === S.WELCOME; }
    get isPerch()   { return this._state === S.PERCH; }
    get isEdge()    { return this._state === S.EDGE; }
    get isEntering(){ return this._state === S.ENTER; }

    get mcStyle() {
        const trans = this._walkTrans ? `transition:${this._walkTrans};` : '';
        const flip  = this.faceRight  ? '' : 'transform:scaleX(-1);';
        if (this.pos.x === null) return `left:auto;right:34px;top:auto;bottom:34px;${trans}${flip}`;
        return `left:${this.pos.x}px;top:${this.pos.y}px;right:auto;bottom:auto;${trans}${flip}`;
    }
    get overlayClass() { return this.isWalking ? 'mc-overlay walking' : 'mc-overlay'; }
    get nudgeClass()   { return 'bubble nudge pe' + (this.nudgeOn ? ' show' : ''); }
    get nudgeStyle()   { return this._nudgeStyle || ''; }
    get peekClass()    { return 'peek' + (this._peekVis ? ' in' : ''); }
    get peekBubbleClass() { return 'bubble' + (this._peekBubble ? ' show' : ''); }

    /* ---- lifecycle ---- */
    connectedCallback() {
        this._reducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
        this._moveH = (e) => this._onDragMove(e);
        this._upH   = () => this._onDragEnd();
        window.addEventListener('mousemove',  this._moveH);
        window.addEventListener('touchmove',  this._moveH, { passive: false });
        window.addEventListener('mouseup',    this._upH);
        window.addEventListener('touchend',   this._upH);
        window.addEventListener('keydown',    (e) => { if (e.key === 'Escape') this.minimize(); });
        // Listen for typing to suppress lines
        window.addEventListener('keypress', () => this._onTyping());

        // Restore saved position
        if (C.flags.rememberLastPosition) {
            try {
                const saved = JSON.parse(localStorage.getItem('mclovin_pos') || 'null');
                if (saved) this._savedPos = saved;
            } catch (_) { /* ignore */ }
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this._runEntrance(), C.timings.entranceDelayMs);
    }

    disconnectedCallback() {
        window.removeEventListener('mousemove', this._moveH);
        window.removeEventListener('touchmove', this._moveH);
        window.removeEventListener('mouseup',   this._upH);
        window.removeEventListener('touchend',  this._upH);
        clearTimeout(this._peekTimer);
        clearTimeout(this._idleTimer);
        clearTimeout(this._nudgeTimer);
        clearTimeout(this._walkTimer);
    }

    /* ---- public API ---- */
    @api open()     { this._setState(S.WELCOME); this.nudgeOn = false; }
    @api minimize() { this._goToBadgeOrPerch(); }
    @api peek()     { this._doPeek(); }
    @api say(text)  { this._showBubble(text, true); }

    /* ---- entrance ---- */
    _runEntrance() {
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        const groundY = vh - 160;

        if (this._reducedMotion) {
            // Fade in directly, show welcome bubble, then settle
            this.pos = { x: vw - 160, y: groundY };
            this._setState(S.ENTER);
            this._showBubble(pick(C.dialogue.entrance, this._lastLine), true);
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._goToBadgeOrPerch(), 3000);
            return;
        }

        // Place off-screen left, at ground level
        this.pos     = { x: -160, y: groundY };
        this.faceRight = true;
        this._setState(S.ENTER);

        // Walk to resting spot
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const perch = this._findBestPerch();
            const targetX = perch ? this._perchX(perch) : Math.max(vw * 0.18, 100);
            this._walkTo(targetX, groundY, () => {
                // Arrived — show entrance line, then settle
                this.isWalking = false;
                this._walkTrans = '';
                this._showBubble(pick(C.dialogue.entrance, this._lastLine), true);
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    if (perch) this._perchOn(perch);
                    else       this._goToEdgeOrBadge();
                }, 3200);
            });
        }, C.timings.entranceFadeMs);
    }

    /* ---- walking ---- */
    _walkTo(targetX, targetY, onDone) {
        const dist     = Math.hypot(targetX - this.pos.x, targetY - this.pos.y);
        const duration = Math.round((dist / C.timings.walkSpeedPxPerSec) * 1000);
        this.faceRight  = targetX > this.pos.x;
        this.isWalking  = true;
        this._walkTrans = `left ${duration}ms cubic-bezier(0.22,0.1,0.3,1), top ${duration}ms cubic-bezier(0.22,0.1,0.3,1)`;

        // Trigger the CSS transition
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.pos = { x: targetX, y: targetY }; }, 30);
        clearTimeout(this._walkTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._walkTimer = setTimeout(onDone, duration + 60);
    }

    /* ---- perch system ---- */
    _findBestPerch() {
        if (!C.flags.perchOnForms) return null;
        const els = this.template?.querySelectorAll?.('[data-mclovin-perch]')
               || document.querySelectorAll('[data-mclovin-perch]');
        if (!els || !els.length) return null;
        let best = null, bestScore = -Infinity;
        els.forEach(el => {
            const r = el.getBoundingClientRect();
            if (r.width < 10 || r.height < 10) return;
            if (r.bottom < 0 || r.top > window.innerHeight) return;
            const priority  = parseInt(el.dataset.mclovinPriority || '0', 10);
            const centerDx  = Math.abs((r.left + r.width / 2) - window.innerWidth / 2);
            const score     = priority * 100 - centerDx;
            if (score > bestScore) { bestScore = score; best = el; }
        });
        return best;
    }

    _perchX(el) {
        const r    = el.getBoundingClientRect();
        const type = el.dataset.mclovinPerch || 'stand';
        const cfg  = C.perchTypes[type] || C.perchTypes['stand'];
        const anchor = cfg.anchor;
        let x = 0;
        if (anchor === 'topRight' || anchor === 'rightMid' || anchor === 'bottomRight') x = r.right + cfg.offsetX;
        else if (anchor === 'leftMid')   x = r.left + cfg.offsetX;
        else if (anchor === 'topCenter') x = r.left + r.width / 2 + cfg.offsetX;
        else                             x = r.right + cfg.offsetX;
        return Math.max(8, Math.min(window.innerWidth - 120, x));
    }

    _perchY(el) {
        const r    = el.getBoundingClientRect();
        const type = el.dataset.mclovinPerch || 'stand';
        const cfg  = C.perchTypes[type] || C.perchTypes['stand'];
        const anchor = cfg.anchor;
        let y = 0;
        if (anchor === 'topRight' || anchor === 'topCenter' || anchor === 'bottomRight') y = r.top + cfg.offsetY;
        else if (anchor === 'leftMid' || anchor === 'rightMid') y = r.top + r.height / 2 + cfg.offsetY;
        else y = r.top + cfg.offsetY;
        return Math.max(8, Math.min(window.innerHeight - 120, y));
    }

    _perchOn(el) {
        const ctx  = el.dataset.mclovinContext;
        const x    = this._perchX(el);
        const y    = this._perchY(el);
        this._currentPerch = el;
        if (this._reducedMotion) {
            this.pos = { x, y };
            this._setState(S.PERCH);
            this._sayContextLine(ctx);
            this._scheduleIdle();
        } else {
            this._walkTo(x, y, () => {
                this.isWalking = false;
                this._walkTrans = '';
                this._setState(S.PERCH);
                this._sayContextLine(ctx);
                this._scheduleIdle();
            });
        }
    }

    _sayContextLine(ctx) {
        let bank = (ctx && C.dialogue.context[ctx]) ? C.dialogue.context[ctx] : C.dialogue.perch_generic;
        const line = pick(bank, this._lastLine);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this._showBubble(line, false), C.timings.perchSettleMs);
    }

    /* ---- edge hang ---- */
    _goToEdgeOrBadge() {
        if (!C.flags.hangOnEdgeWhenNoPerch) {
            this._setState(S.BADGE);
            this._scheduleIdle();
            return;
        }
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        const targetX = vw - 90;
        const targetY = vh * 0.5;
        if (this._reducedMotion) {
            this.pos = { x: targetX, y: targetY };
            this._setState(S.EDGE);
            this._scheduleIdle();
        } else {
            this._walkTo(targetX, targetY, () => {
                this.isWalking = false;
                this._walkTrans = '';
                this._setState(S.EDGE);
                this._scheduleIdle();
            });
        }
    }

    _goToBadgeOrPerch() {
        clearTimeout(this._idleTimer);
        const perch = this._findBestPerch();
        if (perch) this._perchOn(perch);
        else {
            this._setState(S.BADGE);
            this._scheduleIdle();
        }
    }

    /* ---- idle scheduling ---- */
    _scheduleIdle() {
        clearTimeout(this._idleTimer);
        const delay = C.timings.idleBeforeWanderMinMs
            + Math.random() * (C.timings.idleBeforeWanderMaxMs - C.timings.idleBeforeWanderMinMs);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._idleTimer = setTimeout(() => {
            if (this._state === S.BADGE || this._state === S.PERCH || this._state === S.EDGE) {
                if (Math.random() < 0.4) this._doPeek();
                else this._showBubble(pick(C.dialogue.idle, this._lastLine), false);
            }
            this._scheduleIdle();
        }, delay);
    }

    /* ---- peek ---- */
    _doPeek() {
        if (this._peekVis) return;
        this._peekVis = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._peekBubble = true; }, 420);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this._peekBubble = false;
            this._peekVis    = false;
        }, C.timings.peekHoldMs);
    }

    /* ---- typing detection ---- */
    _onTyping() {
        this._typing = true;
        clearTimeout(this._typingTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._typingTimer = setTimeout(() => { this._typing = false; }, C.timings.quietWhileTypingMs);
    }

    /* ---- nudge bubble ---- */
    _showBubble(text, sticky) {
        if (!text) return;
        if (this._typing && C.flags.muteLinesWhileTyping && !sticky) return;
        this._lastLine = text;
        this.nudgeText = text;
        const mc = this.template.querySelector('.mc');
        if (mc) {
            const b = mc.getBoundingClientRect();
            this._nudgeStyle = `left:${Math.max(12, b.left - 240)}px;top:${Math.max(8, b.top - 10)}px;max-width:230px;`;
        }
        this.nudgeOn = true;
        clearTimeout(this._nudgeTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._nudgeTimer = setTimeout(() => { this.nudgeOn = false; }, sticky ? 7000 : 3500);
    }

    /* ---- state helper ---- */
    _setState(s) { this._state = s; }

    /* ---- interactions ---- */
    onBadgeClick() { if (!this._dragMoved) this.open(); }
    onPerchClick()  { this.open(); }
    onEdgeClick()   { this.open(); }

    onChip(e) {
        const prompt = CHIP_PROMPTS[e.currentTarget.dataset.q];
        if (prompt) this._callAI(prompt);
    }

    onSend() {
        const inp = this.template.querySelector('.askbar input');
        if (inp && inp.value.trim()) {
            this._callAI(inp.value.trim());
            inp.value = '';
        }
    }

    onAskKey(e) { if (e.key === 'Enter') this.onSend(); }

    /* ---- AI call ---- */
    async _callAI(text) {
        if (this.isThinking) return;
        this.isThinking = true;
        this._showBubble('Thinking...', false);
        this._history.push({ role: 'user', content: text });
        const recent = this._history.slice(-10);
        try {
            const result = await sendMessage({ historyJson: JSON.stringify(recent) });
            if (result.success) {
                this._history.push({ role: 'assistant', content: result.reply });
                const display = result.reply.length > 280 ? result.reply.slice(0, 277) + '...' : result.reply;
                this._showBubble(display, true);
            } else {
                this._showBubble('Ran into an issue. ' + (result.errorMessage || 'Try again.'), true);
            }
        } catch (err) {
            const msg = (err.body && err.body.message) ? err.body.message : 'Check your connection.';
            this._showBubble('Could not reach the server. ' + msg, true);
        } finally {
            this.isThinking = false;
        }
    }

    /* ---- drag ---- */
    onDragStart(e) {
        const p  = e.touches ? e.touches[0] : e;
        const mc = this.template.querySelector('.mc');
        const b  = mc.getBoundingClientRect();
        this._drag      = { baseX: b.left, baseY: b.top, startX: p.clientX, startY: p.clientY };
        this._dragMoved = false;
        this._walkTrans = '';
        this._setState(S.DRAG);
        this._showBubble(pick(C.dialogue.drag_pickup, this._lastLine), false);
        e.preventDefault();
    }
    _onDragMove(e) {
        if (!this._drag) return;
        const p  = e.touches ? e.touches[0] : e;
        const dx = p.clientX - this._drag.startX;
        const dy = p.clientY - this._drag.startY;
        if (Math.abs(dx) + Math.abs(dy) > 4) this._dragMoved = true;
        this.faceRight = dx >= 0;
        this.pos = {
            x: Math.max(8, Math.min(window.innerWidth - 100, this._drag.baseX + dx)),
            y: Math.max(8, Math.min(window.innerHeight - 100, this._drag.baseY + dy))
        };
    }
    _onDragEnd() {
        if (!this._drag) return;
        this._drag = null;

        if (C.flags.rememberLastPosition) {
            try { localStorage.setItem('mclovin_pos', JSON.stringify(this.pos)); } catch (_) { /* ignore */ }
        }

        this._showBubble(pick(C.dialogue.drag_drop, this._lastLine), false);
        // Snap to perch or edge
        const perch = this._findBestPerch();
        if (perch) this._perchOn(perch);
        else       this._goToEdgeOrBadge();

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._dragMoved = false; }, 30);
    }
}
