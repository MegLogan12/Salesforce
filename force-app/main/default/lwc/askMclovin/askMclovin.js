import { LightningElement, track } from 'lwc';
import ASSETS from '@salesforce/resourceUrl/askMclovin';

// ── Dialogue ───────────────────────────────────────────────────────────────
const LINES = {
    opportunity: ["Want the smart way to close this one?", "Tell me the objection and I'll hand you the line."],
    account:     ["Want a quick read on this account?",    "I can pull the last three touches if you want."],
    lead:        ["Fresh lead. Want a fast qualifying question?", "I can draft the first outreach if you like."],
    quote:       ["Want me to sanity check this quote?",   "Margins look tight. Want options?"],
    task:        ["Knock this out and I'll cheer.",         "Want me to draft the follow up?"],
    generic:     ["I'll hang out here while you work.",     "Holler if you need me.", "Take your time."]
};
const BUBBLE_OFFERS = [
    "Want me to open a site visit form?",
    "Morning. Want me to log a site visit?",
    "Need help? I can pull up the site visit form."
];

// ── Module-level singleton ─────────────────────────────────────────────────
// Prevents multiple utility bar instances from all claiming the overlay.
let _owned = false;

function pick(arr, last) {
    const opts = arr.filter(l => l !== last);
    return opts[Math.floor(Math.random() * opts.length)] || arr[0];
}

// ── Component ──────────────────────────────────────────────────────────────
export default class AskMclovin extends LightningElement {

    @track isOwner = false;

    peekUrl  = '';
    headUrl  = '';
    happyUrl = '';

    // state: 'perch' | 'badge'
    _state       = 'perch';
    _currentCard = null;
    _facing      = 1;
    _lastLine    = '';

    // DOM refs (set in renderedCallback)
    _mc      = null;
    _flip    = null;
    _lean    = null;
    _badge   = null;
    _badgeImg= null;
    _bubble  = null;
    _bubText = null;
    _bubChip = null;
    _scrim   = null;
    _popform = null;
    _refsSet = false;

    // Timers
    _bubTimer   = null;
    _lifeTimer  = null;

    // Drag state
    _dragging  = false;
    _dragMoved = false;
    _sx = 0; _sy = 0; _bx = 0; _by = 0;

    // Bound global handlers
    _onMove   = null;
    _onUp     = null;
    _onKey    = null;
    _onScroll = null;
    _onResize = null;
    _rafPending = false;

    /* ── Lifecycle ─────────────────────────────────────────────────────────── */
    connectedCallback() {
        this.peekUrl  = ASSETS + '/peek.png';
        this.headUrl  = ASSETS + '/head.png';
        this.happyUrl = ASSETS + '/happy.png';

        if (_owned) return;
        _owned = true;
        this.isOwner = true;
    }

    renderedCallback() {
        if (!this.isOwner || this._refsSet) return;
        const q = (sel) => this.template.querySelector(sel);
        this._mc       = q('[data-ref="mc"]');
        this._flip     = q('[data-ref="flip"]');
        this._lean     = q('[data-ref="lean"]');
        this._badge    = q('[data-ref="badge"]');
        this._badgeImg = q('[data-ref="badgeImg"]');
        this._bubble   = q('[data-ref="bubble"]');
        this._bubText  = q('[data-ref="bubText"]');
        this._bubChip  = q('[data-ref="bubChip"]');
        this._scrim    = q('[data-ref="scrim"]');
        this._popform  = q('[data-ref="popform"]');

        if (!this._mc) return; // not rendered yet
        this._refsSet = true;
        this._bindEvents();
        this._bindGlobalEvents();

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this._setState('perch');
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                if (this._currentCard) {
                    this._showBubble(pick(BUBBLE_OFFERS, ''), true);
                }
            }, 1200);
        }, 500);
    }

    disconnectedCallback() {
        if (!this.isOwner) return;
        _owned = false;
        clearTimeout(this._bubTimer);
        clearInterval(this._lifeTimer);
        if (this._onMove)   { window.removeEventListener('mousemove',  this._onMove); window.removeEventListener('touchmove',  this._onMove); }
        if (this._onUp)     { window.removeEventListener('mouseup',    this._onUp);   window.removeEventListener('touchend',   this._onUp); }
        if (this._onKey)    { window.removeEventListener('keydown',    this._onKey); }
        if (this._onScroll) { document.removeEventListener('scroll',   this._onScroll, true); }
        if (this._onResize) { window.removeEventListener('resize',     this._onResize); }
    }

    /* ── State machine ─────────────────────────────────────────────────────── */
    _setState(s) {
        this._state = s;
        if (!this._lean) return;
        if (s === 'perch') {
            this._lean.classList.remove('hidden');
            this._badge.classList.remove('show');
            this._reperch(true);
        } else if (s === 'badge') {
            this._lean.classList.add('hidden');
            this._badge.classList.add('show');
            this._badgeImg.src = this.headUrl;
            this._startBadgeLife();
        }
    }

    /* ── Positioning — one eased transform ────────────────────────────────── */
    _place(x, y, faceDir) {
        if (!this._mc) return;
        this._mc.style.transform = `translate(${x}px,${y}px)`;
        if (faceDir !== undefined && faceDir !== this._facing) {
            this._facing = faceDir;
            this._flip.style.transform = `scaleX(${faceDir})`;
        }
    }

    /* ── Perch system ──────────────────────────────────────────────────────── */
    _visibleCards() {
        try {
            return [...document.querySelectorAll('[data-mclovin-perch]')].map(el => {
                const r   = el.getBoundingClientRect();
                const vis = Math.max(0, Math.min(r.bottom, window.innerHeight) - Math.max(r.top, 0));
                const score = vis > 40 ? (+el.dataset.mclovinPriority || 0) + vis / window.innerHeight * 5 : -1;
                return { el, r, vis, score };
            }).filter(c => c.score >= 0).sort((a, b) => b.score - a.score);
        } catch (e) {
            return [];
        }
    }

    _leanOn(card, say) {
        this._currentCard = card;
        const r = card.getBoundingClientRect();
        const w = (this._lean && this._lean.offsetWidth)  || 180;
        const h = (this._lean && this._lean.offsetHeight) || 330;
        let x = r.right - w * 0.46;
        let y = r.top   - h * 0.16;
        x = Math.min(x, window.innerWidth  - w * 0.62);
        y = Math.max(70, Math.min(y, window.innerHeight - h * 0.6));
        this._place(x, y, 1);
        this._state = 'perch';

        if (say !== false) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const ctx  = card.dataset.mclovinContext;
                const bank = (ctx && LINES[ctx]) ? LINES[ctx] : LINES.generic;
                const line = pick(bank, this._lastLine);
                this._lastLine = line;
                this._showBubble(line, true);
            }, 700);
        }
    }

    _reperch(say) {
        const cards = this._visibleCards();
        if (!cards.length) { this._goToEdge(); return; }
        const best = cards[0];
        if (best.el !== this._currentCard || say) this._leanOn(best.el, say);
    }

    _goToEdge() {
        this._currentCard = null;
        const x = window.innerWidth  - 130;
        const y = window.innerHeight * 0.42;
        this._place(x, y, 1);
    }

    /* ── Badge facial life ─────────────────────────────────────────────────── */
    _startBadgeLife() {
        clearInterval(this._lifeTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._lifeTimer = setInterval(() => {
            if (this._state !== 'badge' || !this._badgeImg) return;
            this._badgeImg.style.transform = 'scaleY(.86)';
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                if (!this._badgeImg) return;
                this._badgeImg.style.transform = 'scaleY(1)';
                if (Math.random() < 0.5) {
                    this._badgeImg.src = this.happyUrl;
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => { if (this._badgeImg) this._badgeImg.src = this.headUrl; }, 1400);
                }
            }, 120);
        }, 3200 + Math.random() * 2600);
    }

    /* ── Lean image click → expression flash + bubble ──────────────────────── */
    _onLeanClick() {
        if (this._dragMoved) return;
        // quick squash blink on the lean image
        if (this._lean) {
            this._lean.style.transform = 'scaleY(.88)';
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => { if (this._lean) this._lean.style.transform = ''; }, 110);
        }
        this._showBubble(pick(BUBBLE_OFFERS, this._lastLine), true);
    }

    /* ── Bubble ────────────────────────────────────────────────────────────── */
    _showBubble(text, withChip) {
        if (!this._bubble || !text) return;
        this._bubText.textContent = text;
        this._bubChip.style.display = withChip ? 'inline-block' : 'none';

        // Position bubble to the left of and slightly above the character
        if (this._mc) {
            const r = this._mc.getBoundingClientRect();
            this._bubble.style.left = Math.max(12, r.left - 210) + 'px';
            this._bubble.style.top  = Math.max(70, r.top + 24)   + 'px';
        }

        this._bubble.classList.add('show');
        clearTimeout(this._bubTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._bubTimer = setTimeout(() => { if (this._bubble) this._bubble.classList.remove('show'); }, 5200);
    }

    _hideBubble() {
        if (this._bubble) this._bubble.classList.remove('show');
    }

    /* ── Pop-up form ───────────────────────────────────────────────────────── */
    _showPopForm() {
        if (!this._scrim) return;
        this._scrim.classList.add('show');
        this._popform.classList.add('show');
        this._hideBubble();
    }

    _hidePopForm() {
        if (!this._scrim) return;
        this._scrim.classList.remove('show');
        this._popform.classList.remove('show');
    }

    /* ── Bind events ───────────────────────────────────────────────────────── */
    _bindEvents() {
        // Lean image — drag + click
        this._lean.addEventListener('mousedown',  (e) => this._onDragStart(e));
        this._lean.addEventListener('touchstart', (e) => this._onDragStart(e), { passive: false });
        this._lean.addEventListener('click',      ()  => this._onLeanClick());

        // Badge — click returns to perch
        this._badge.addEventListener('mousedown',  (e) => this._onDragStart(e));
        this._badge.addEventListener('touchstart', (e) => this._onDragStart(e), { passive: false });
        this._badge.addEventListener('click',      ()  => { if (!this._dragMoved) this._setState('perch'); });

        // Bubble chip → pop form
        this._bubChip.addEventListener('click', () => this._showPopForm());

        // Scrim + close buttons → hide form
        this._scrim.addEventListener('click', () => this._hidePopForm());
        this._popform.querySelectorAll('.pf-close').forEach(b => b.addEventListener('click', () => this._hidePopForm()));
        this._popform.querySelectorAll('.pf-save').forEach(b => b.addEventListener('click', () => this._hidePopForm()));
    }

    _bindGlobalEvents() {
        this._onMove   = (e) => this._onDragMove(e);
        this._onUp     = ()  => this._onDragEnd();
        this._onKey    = (e) => { if (e.key === 'Escape') this._hidePopForm(); };
        this._onScroll = ()  => this._onScrollThrottled();
        this._onResize = ()  => { if (this._state === 'perch') this._reperch(false); };

        window.addEventListener('mousemove',  this._onMove);
        window.addEventListener('touchmove',  this._onMove, { passive: false });
        window.addEventListener('mouseup',    this._onUp);
        window.addEventListener('touchend',   this._onUp);
        window.addEventListener('keydown',    this._onKey);
        window.addEventListener('resize',     this._onResize);
        document.addEventListener('scroll',   this._onScroll, true);
    }

    /* ── Scroll (throttled via RAF) ────────────────────────────────────────── */
    _onScrollThrottled() {
        if (this._rafPending || this._state !== 'perch') return;
        this._rafPending = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            this._rafPending = false;
            if (this._state === 'perch') this._reperch(false);
        });
    }

    /* ── Drag ──────────────────────────────────────────────────────────────── */
    _onDragStart(e) {
        if (!this._mc) return;
        const p = e.touches ? e.touches[0] : e;
        this._dragging  = true;
        this._dragMoved = false;
        const r = this._mc.getBoundingClientRect();
        this._bx = r.left;
        this._by = r.top;
        this._sx = p.clientX;
        this._sy = p.clientY;
        this._mc.classList.add('drag');
        e.preventDefault();
    }

    _onDragMove(e) {
        if (!this._dragging || !this._mc) return;
        const p  = e.touches ? e.touches[0] : e;
        const dx = p.clientX - this._sx;
        const dy = p.clientY - this._sy;
        if (Math.abs(dx) + Math.abs(dy) > 4) this._dragMoved = true;
        this._mc.style.transform = `translate(${this._bx + dx}px,${this._by + dy}px)`;
        this._hideBubble();
    }

    _onDragEnd() {
        if (!this._dragging) return;
        this._dragging = false;
        this._mc.classList.remove('drag');
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._dragMoved = false; }, 40);

        // Snap to nearest visible card after drop
        if (this._state === 'perch') {
            const mr  = this._mc.getBoundingClientRect();
            const cx  = mr.left + mr.width  / 2;
            const cy  = mr.top  + mr.height / 2;
            const cards = this._visibleCards();
            if (cards.length) {
                let best = cards[0].el, bestDist = Infinity;
                cards.forEach(c => {
                    const ccx = c.r.left + c.r.width  / 2;
                    const ccy = c.r.top  + c.r.height / 2;
                    const d   = (ccx - cx) ** 2 + (ccy - cy) ** 2;
                    if (d < bestDist) { bestDist = d; best = c.el; }
                });
                this._leanOn(best, false);
            } else {
                this._goToEdge();
            }
        }
    }
}
