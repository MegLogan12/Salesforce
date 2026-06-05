import { LightningElement, api } from 'lwc';
import ASSETS from '@salesforce/resourceUrl/askMclovin';
import sendMessage from '@salesforce/apex/McLovinChatController.sendMessage';

// ── Config ─────────────────────────────────────────────────────────────────
const C = {
    entranceDelayMs: 500,
    quietWhileTypingMs: 4000,
    bubbleHoldMs: 5200,
    dialogue: {
        entrance: [
            "Morning. Let's go close something.",
            "I'm up. Point me at the hard one.",
            "Back at it. What are we winning today?",
            "Reporting for duty. And snacks."
        ],
        context: {
            opportunity: ["Want the smart way to close this one?", "Tell me the objection and I'll hand you the line."],
            account:     ["Want a quick read on this account?", "I can pull the last three touches if you want."],
            lead:        ["Fresh lead. Want a fast qualifying question?", "I can draft the first outreach if you like."],
            quote:       ["Want me to sanity check this quote?", "Margins look tight. Want options?"],
            task:        ["Knock this out and I'll cheer.", "Want me to draft the follow up?"],
            report:      ["Want the one number that actually matters here?", "I can summarize this in a sentence."]
        },
        generic: ["I'll hang out here while you work.", "Holler if you need me.", "Take your time."]
    }
};

const CHIP_PROMPTS = {
    po:        'I need to process a Purchase Order. What information do I need and how do I enter it in Salesforce? Keep it brief.',
    scope:     'Walk me through a scope of work intake quickly. What do I need to provide?',
    account:   'I need to create a new account. What type should it be and what information is required?',
    homeowner: 'I have a homeowner intake to process. What do I need to collect from them?',
    find:      'Help me find an existing job or work order. What is the best way to search?',
    missing:   'What information is most commonly missing on work orders that causes problems later? Be specific and brief.'
};

const PORTAL_ID = 'mclovin-portal';
const STYLES_ID = 'mclovin-styles';
const S = { PERCH:'perch', EDGE:'edge', OPEN:'open', DRAG:'drag' };

// Module-level singleton — shared across all LWC instances in the page.
// Prevents two utility bars mounting simultaneously from both creating a portal.
let _portalOwned = false;

function pick(arr, last) {
    if (!arr || !arr.length) return '';
    const opts = arr.filter(l => l !== last);
    return opts[Math.floor(Math.random() * opts.length)] || arr[0];
}

// ── CSS ────────────────────────────────────────────────────────────────────
const PORTAL_CSS = `
#mclovin-portal { position:fixed; inset:0; z-index:9999; pointer-events:none; }

/* ONE eased transform for travel — no left/top animation = no glitch */
#mclovin-portal .mc {
  position:fixed; left:0; top:0; pointer-events:auto;
  transition:transform 1.1s cubic-bezier(.22,.61,.36,1);
  will-change:transform;
}
#mclovin-portal .mc.drag { transition:none; }

/* Flip lives on an inner wrapper so it eases without fighting travel */
#mclovin-portal .flip { transition:transform .45s ease; transform-origin:center bottom; }

/* Breathing — applied to the image only, not the mc wrapper */
@keyframes mcBreathe {
  0%,100% { transform:translateY(0) scale(1); }
  50%     { transform:translateY(-6px) scale(1.008); }
}

#mclovin-portal .lean-img {
  height:300px; display:block; cursor:grab; background:transparent;
  filter:drop-shadow(0 18px 26px rgba(20,24,40,.24));
  animation:mcBreathe 4.6s ease-in-out infinite;
  transform-origin:bottom center; will-change:transform;
}

/* OPEN CARD — position:fixed, placed programmatically near the character */
#mclovin-open-card {
  display:none; position:fixed; z-index:10001;
  width:320px; background:#fff; border:1px solid rgba(0,0,0,.08);
  border-radius:18px; padding:14px; box-shadow:0 18px 40px rgba(20,24,40,.18);
  flex-direction:column; gap:10px; pointer-events:auto;
}
#mclovin-open-card.show { display:flex; }
#mclovin-open-card .close-btn {
  align-self:flex-end; background:none; border:none; cursor:pointer;
  font-size:18px; color:#9aa1ad; line-height:1; padding:0 2px;
}
#mclovin-open-card .chips { display:flex; gap:7px; flex-wrap:wrap; }
#mclovin-open-card .chip {
  background:#fff; border:1px solid rgba(0,0,0,.08); border-radius:999px;
  padding:6px 12px; font-size:13px; font-weight:600; cursor:pointer;
}
#mclovin-open-card .chip:hover { border-color:#FCD400; background:#fffdf0; }
#mclovin-open-card .askbar {
  display:flex; gap:8px; background:#fcfcfd; border:1px solid #dfe2e8;
  border-radius:12px; padding:7px 8px 7px 13px;
}
#mclovin-open-card .askbar input { flex:1; border:none; outline:none; font-size:14px; background:transparent; }
#mclovin-open-card .askbar .send-btn {
  border:none; background:#FCD400; color:#1b1f25; font-weight:800;
  border-radius:9px; padding:7px 12px; cursor:pointer; min-width:46px;
}
#mclovin-open-card .askbar .send-btn:disabled { opacity:.5; cursor:default; }

/* BUBBLE */
#mclovin-portal .bubble {
  position:fixed; max-width:240px; background:#fff; border:1px solid rgba(0,0,0,.08);
  border-radius:18px; padding:12px 14px; box-shadow:0 18px 40px rgba(20,24,40,.18);
  font-size:14px; line-height:1.4; color:#1b1f25;
  opacity:0; transform:translateY(6px); transition:opacity .25s, transform .25s;
  pointer-events:auto; z-index:10000;
}
#mclovin-portal .bubble.show { opacity:1; transform:none; }
#mclovin-portal .spark {
  display:inline-grid; place-items:center; width:20px; height:20px; border-radius:50%;
  background:#FCD400; font-size:11px; vertical-align:-4px; margin-right:6px;
}
#mclovin-portal .bubble-chip {
  display:inline-block; margin-top:8px; background:#fff7cc; border:1px solid #f1e08a;
  border-radius:999px; padding:5px 11px; font-size:12.5px; font-weight:700;
  cursor:pointer;
}

/* SCRIM + POP-UP FORM */
#mclovin-scrim {
  position:fixed; inset:0; background:rgba(15,19,28,.28);
  opacity:0; pointer-events:none; transition:.25s; z-index:9998;
}
#mclovin-scrim.show { opacity:1; pointer-events:auto; }
#mclovin-popform {
  position:fixed; left:50%; top:52%;
  transform:translate(-50%,-50%) scale(.9);
  opacity:0; pointer-events:none;
  width:min(540px,92vw); background:#fff; border:1px solid #e9eaee;
  border-radius:20px; box-shadow:0 40px 90px rgba(15,19,28,.35);
  z-index:9999; transition:transform .32s cubic-bezier(.2,.8,.2,1), opacity .32s;
  font-family:inherit;
}
#mclovin-popform.show { opacity:1; transform:translate(-50%,-50%) scale(1); pointer-events:auto; }
#mclovin-popform .pf-hd {
  display:flex; align-items:center; gap:10px; padding:16px 20px;
  border-bottom:1px solid #e9eaee;
}
#mclovin-popform .pf-dot { width:9px; height:9px; border-radius:50%; background:#FCD400; }
#mclovin-popform .pf-title { font-size:15px; font-weight:800; color:#1b1f25; }
#mclovin-popform .pf-close {
  margin-left:auto; background:none; border:1px solid #e9eaee; border-radius:8px;
  padding:5px 10px; cursor:pointer; font-size:13px; font-weight:700; color:#525a66;
}
#mclovin-popform .pf-bd {
  padding:18px 20px 22px; display:grid; grid-template-columns:1fr 1fr; gap:14px 18px;
}
#mclovin-popform .pf-field { display:flex; flex-direction:column; gap:5px; }
#mclovin-popform .pf-field.full { grid-column:1/-1; }
#mclovin-popform .pf-field label { font-size:12.5px; font-weight:700; color:#525a66; }
#mclovin-popform .pf-field input,
#mclovin-popform .pf-field select {
  font-family:inherit; font-size:14px; border:1px solid #dfe2e8; border-radius:10px;
  padding:9px 11px; background:#fcfcfd; color:#1b1f25;
}
#mclovin-popform .pf-actions { grid-column:1/-1; display:flex; justify-content:flex-end; gap:10px; }
#mclovin-popform .pf-btn {
  font-family:inherit; font-weight:700; border-radius:11px; padding:10px 16px;
  cursor:pointer; border:1px solid #e9eaee; background:#fff; font-size:14px;
}
#mclovin-popform .pf-btn.primary { background:#FCD400; border-color:#e7c200; }

@media (prefers-reduced-motion:reduce) {
  #mclovin-portal .lean-img { animation:none; }
  #mclovin-portal .mc { transition:none !important; }
  #mclovin-portal .flip { transition:none; }
  #mclovin-portal .bubble { transition:none; }
}
`;

// ── Component ──────────────────────────────────────────────────────────────
export default class AskMclovin extends LightningElement {

    _fullUrl  = '';
    _peekUrl  = '';
    _happyUrl = '';

    _state       = S.PERCH;
    _currentCard = null;
    _facing      = 1;     // 1 = right (default), -1 = left
    _lastLine    = '';
    _isThinking  = false;
    _typing      = false;
    _history     = [];
    _isOwner     = false;
    _rafPending  = false;

    // DOM refs
    _portal   = null;
    _mcEl     = null;
    _flipEl   = null;
    _leanEl   = null;
    _openCard = null;
    _bubbleEl = null;
    _bubTxtEl = null;
    _bubChipEl= null;
    _inputEl  = null;
    _scrimEl  = null;
    _popFormEl= null;

    // Bound handlers
    _onMove   = null;
    _onUp     = null;
    _onKey    = null;
    _onType   = null;
    _onNav    = null;
    _onScroll = null;
    _onResize = null;

    // Drag state
    _dragging  = false;
    _dragMoved = false;
    _sx = 0; _sy = 0; _bx = 0; _by = 0;

    // Bubble hide timer
    _bubTimer = null;
    _typingTimer = null;

    /* ── Lifecycle ────────────────────────────────────────────────────────── */
    connectedCallback() {
        this._fullUrl  = ASSETS + '/full.png';
        this._peekUrl  = ASSETS + '/peek.png';
        this._happyUrl = ASSETS + '/happy.png';

        if (_portalOwned || document.getElementById(PORTAL_ID)) return;
        _portalOwned = true;
        this._isOwner = true;

        this._injectStyles();
        this._createPortal();
        this._bindGlobalEvents();

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this._reperch(true);
        }, C.entranceDelayMs);
    }

    disconnectedCallback() {
        if (!this._isOwner) return;
        _portalOwned = false;
        clearTimeout(this._bubTimer);
        clearTimeout(this._typingTimer);
        window.removeEventListener('mousemove',  this._onMove);
        window.removeEventListener('touchmove',  this._onMove);
        window.removeEventListener('mouseup',    this._onUp);
        window.removeEventListener('touchend',   this._onUp);
        window.removeEventListener('keydown',    this._onKey);
        window.removeEventListener('keypress',   this._onType);
        window.removeEventListener('hashchange', this._onNav);
        window.removeEventListener('popstate',   this._onNav);
        window.removeEventListener('resize',     this._onResize);
        document.removeEventListener('scroll',   this._onScroll, true);
        const portal = document.getElementById(PORTAL_ID);
        if (portal) portal.remove();
        const styles = document.getElementById(STYLES_ID);
        if (styles) styles.remove();
        const oc = document.getElementById('mclovin-open-card');
        if (oc) oc.remove();
        const scrim = document.getElementById('mclovin-scrim');
        if (scrim) scrim.remove();
        const pf = document.getElementById('mclovin-popform');
        if (pf) pf.remove();
    }

    /* ── Public API ───────────────────────────────────────────────────────── */
    @api open()      { this._showOpenCard(); }
    @api minimize()  { this._hideOpenCard(); }
    @api say(text)   { this._showBubble(text, false); }

    /* ── Styles + Portal ──────────────────────────────────────────────────── */
    _injectStyles() {
        if (document.getElementById(STYLES_ID)) return;
        const s = document.createElement('style');
        s.id = STYLES_ID;
        s.textContent = PORTAL_CSS;
        document.head.appendChild(s);
    }

    _createPortal() {
        const p = document.createElement('div');
        p.id = PORTAL_ID;
        p.innerHTML = this._portalHTML();
        document.body.appendChild(p);
        this._portal = p;

        // Open card lives on body so position:fixed works outside any transform context
        const oc = document.createElement('div');
        oc.id = 'mclovin-open-card';
        oc.innerHTML = this._openCardHTML();
        document.body.appendChild(oc);

        // Scrim + popform live directly on body (outside the z-index stack)
        const scrim = document.createElement('div');
        scrim.id = 'mclovin-scrim';
        document.body.appendChild(scrim);

        const pf = document.createElement('div');
        pf.id = 'mclovin-popform';
        pf.innerHTML = this._popFormHTML();
        document.body.appendChild(pf);

        this._cacheRefs();
        this._bindPortalEvents();
    }

    _portalHTML() {
        return `
<div class="mc pe">
  <div class="flip">
    <img class="lean-img" src="${this._fullUrl}" alt="mcLOVIN'">
  </div>
</div>
<div class="bubble pe" id="mclovin-bubble">
  <span class="spark">&#10022;</span><span id="mclovin-bub-text"></span><span class="bubble-chip pe" id="mclovin-bub-chip" style="display:none">Log a site visit</span>
</div>`;
    }

    _openCardHTML() {
        return `
<button class="close-btn pe">&#x2715;</button>
<p class="intro-line" style="margin:0;font-size:13px;color:#525a66">What can I help with?</p>
<div class="chips">
  <span class="chip pe" data-q="po">PO</span>
  <span class="chip pe" data-q="scope">Scope</span>
  <span class="chip pe" data-q="account">Account</span>
  <span class="chip pe" data-q="homeowner">Homeowner</span>
  <span class="chip pe" data-q="find">Find job</span>
  <span class="chip pe" data-q="missing">Missing info</span>
</div>
<div class="askbar">
  <input type="text" placeholder="Ask me anything…">
  <button class="send-btn pe">Ask</button>
</div>`;
    }

    _popFormHTML() {
        return `
<div class="pf-hd">
  <span class="pf-dot"></span>
  <span class="pf-title">Log Site Visit</span>
  <button class="pf-close pe">Close</button>
</div>
<div class="pf-bd">
  <div class="pf-field"><label>Access notes</label><input placeholder="Gate code, key location..."></div>
  <div class="pf-field"><label>Slope / grade</label><select><option>Flat</option><option>Moderate slope</option><option>Steep</option></select></div>
  <div class="pf-field"><label>Drainage concern</label><select><option>None</option><option>Minor pooling</option><option>Major issue</option></select></div>
  <div class="pf-field"><label>Photos taken</label><select><option>Yes</option><option>No</option></select></div>
  <div class="pf-field full"><label>Recommended scope</label><input placeholder="Describe recommended work..."></div>
  <div class="pf-actions">
    <button class="pf-btn pe pf-close">Cancel</button>
    <button class="pf-btn primary pe pf-save">Save Visit</button>
  </div>
</div>`;
    }

    _cacheRefs() {
        const p = this._portal;
        this._mcEl     = p.querySelector('.mc');
        this._flipEl   = p.querySelector('.flip');
        this._leanEl   = p.querySelector('.lean-img');
        this._openCard = document.getElementById('mclovin-open-card');
        this._bubbleEl = document.getElementById('mclovin-bubble');
        this._bubTxtEl = document.getElementById('mclovin-bub-text');
        this._bubChipEl= document.getElementById('mclovin-bub-chip');
        this._inputEl  = this._openCard.querySelector('.askbar input');
        this._scrimEl  = document.getElementById('mclovin-scrim');
        this._popFormEl= document.getElementById('mclovin-popform');
    }

    _bindPortalEvents() {
        const oc = this._openCard;
        // Drag on the character image
        this._leanEl.addEventListener('mousedown',  (e) => this._onDragStart(e));
        this._leanEl.addEventListener('touchstart', (e) => this._onDragStart(e), {passive:false});
        this._leanEl.addEventListener('click',      ()  => { if (!this._dragMoved) this._onCharacterClick(); });
        // Open card (body-level element)
        oc.querySelector('.close-btn').addEventListener('click', () => this._hideOpenCard());
        oc.querySelector('.send-btn').addEventListener('click',  () => this._onSend());
        this._inputEl.addEventListener('keyup', (e) => { if (e.key === 'Enter') this._onSend(); });
        oc.querySelectorAll('.chip').forEach(c => c.addEventListener('click', (e) => this._onChip(e)));
        // Bubble chip → pop form
        this._bubChipEl.addEventListener('click', () => this._showPopForm());
        // Scrim + popform close
        this._scrimEl.addEventListener('click', () => this._hidePopForm());
        this._popFormEl.querySelectorAll('.pf-close').forEach(b => b.addEventListener('click', () => this._hidePopForm()));
        this._popFormEl.querySelectorAll('.pf-save').forEach(b => b.addEventListener('click', () => this._hidePopForm()));
    }

    _bindGlobalEvents() {
        this._onMove   = (e) => this._onDragMove(e);
        this._onUp     = ()  => this._onDragEnd();
        this._onKey    = (e) => { if (e.key === 'Escape') this._hideOpenCard(); };
        this._onType   = ()  => this._onTyping();
        this._onNav    = ()  => this._onPageChange();
        this._onScroll = ()  => this._onScrollThrottled();
        this._onResize = ()  => { if (this._state === S.PERCH) this._reperch(false); };

        window.addEventListener('mousemove',  this._onMove);
        window.addEventListener('touchmove',  this._onMove,  {passive:false});
        window.addEventListener('mouseup',    this._onUp);
        window.addEventListener('touchend',   this._onUp);
        window.addEventListener('keydown',    this._onKey);
        window.addEventListener('keypress',   this._onType);
        window.addEventListener('hashchange', this._onNav);
        window.addEventListener('popstate',   this._onNav);
        window.addEventListener('resize',     this._onResize);
        document.addEventListener('scroll',   this._onScroll, true);
    }

    /* ── Positioning — one eased transform ────────────────────────────────── */
    _place(x, y, faceDir) {
        if (!this._mcEl) return;
        this._mcEl.style.transform = `translate(${x}px,${y}px)`;
        if (faceDir !== undefined && faceDir !== this._facing) {
            this._facing = faceDir;
            this._flipEl.style.transform = `scaleX(${faceDir})`;
        }
    }

    /* ── Perch system ─────────────────────────────────────────────────────── */
    _visibleCards() {
        return [...document.querySelectorAll('[data-mclovin-perch]')].map(el => {
            const r = el.getBoundingClientRect();
            const vis = Math.max(0, Math.min(r.bottom, window.innerHeight) - Math.max(r.top, 0));
            const score = vis > 40 ? (+el.dataset.mclovinPriority || 0) + vis / window.innerHeight * 5 : -1;
            return { el, r, vis, score };
        }).filter(c => c.score >= 0).sort((a, b) => b.score - a.score);
    }

    _leanOn(card, say) {
        this._currentCard = card;
        const r   = card.getBoundingClientRect();
        const w   = this._leanEl.offsetWidth  || 160;
        const h   = this._leanEl.offsetHeight || 300;
        let x = r.right - w * 0.46;
        let y = r.top   - h * 0.16;
        x = Math.min(x, window.innerWidth  - w * 0.62);
        y = Math.max(70, Math.min(y, window.innerHeight - h * 0.6));
        this._place(x, y, 1); // art faces left by default; scaleX(1) = face the form
        this._state = S.PERCH;

        if (say !== false) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const ctx  = card.dataset.mclovinContext;
                const bank = (ctx && C.dialogue.context[ctx]) ? C.dialogue.context[ctx] : C.dialogue.generic;
                const line = pick(bank, this._lastLine);
                this._lastLine = line;
                this._showBubble(line, true);
            }, 700);
        }
    }

    _reperch(say) {
        const cards = this._visibleCards();
        if (!cards.length) {
            this._goToEdge();
            return;
        }
        const best = cards[0];
        if (best.el !== this._currentCard || say) this._leanOn(best.el, say);
    }

    _goToEdge() {
        this._state = S.EDGE;
        this._currentCard = null;
        const x = window.innerWidth  - 120;
        const y = window.innerHeight * 0.42;
        this._place(x, y, 1);
    }

    /* ── Scroll (throttled via RAF) ───────────────────────────────────────── */
    _onScrollThrottled() {
        if (this._rafPending || this._state === S.OPEN || this._state === S.DRAG) return;
        this._rafPending = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            this._rafPending = false;
            if (this._state === S.PERCH) this._reperch(false);
        });
    }

    /* ── Page change ──────────────────────────────────────────────────────── */
    _onPageChange() {
        if (!this._isOwner || this._state === S.OPEN) return;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this._reperch(true), 900);
    }

    /* ── Open card ────────────────────────────────────────────────────────── */
    _showOpenCard() {
        if (!this._openCard || !this._mcEl) return;
        this._state = S.OPEN;
        // Position card beside the character (prefer left, fall back to right)
        const r = this._mcEl.getBoundingClientRect();
        const cardW = 320;
        let left = r.left - cardW - 16;
        if (left < 10) left = Math.min(r.right + 10, window.innerWidth - cardW - 10);
        const top = Math.max(10, r.top - 60);
        this._openCard.style.left = left + 'px';
        this._openCard.style.top  = top  + 'px';
        this._openCard.classList.add('show');
        this._hideBubble();
    }

    _hideOpenCard() {
        this._openCard.classList.remove('show');
        this._state = this._currentCard ? S.PERCH : S.EDGE;
    }

    /* ── Pop-up form ──────────────────────────────────────────────────────── */
    _showPopForm() {
        this._scrimEl.classList.add('show');
        this._popFormEl.classList.add('show');
        this._hideBubble();
    }

    _hidePopForm() {
        this._scrimEl.classList.remove('show');
        this._popFormEl.classList.remove('show');
    }

    /* ── Bubble ───────────────────────────────────────────────────────────── */
    _showBubble(text, withChip) {
        if (!text || !this._bubbleEl) return;
        if (this._typing && !withChip) return;

        this._bubTxtEl.textContent = text;
        this._bubChipEl.style.display = withChip ? 'inline-block' : 'none';

        // Position bubble to the left and slightly above the character
        if (this._mcEl) {
            const r = this._mcEl.getBoundingClientRect();
            this._bubbleEl.style.left = Math.max(12, r.left - 220) + 'px';
            this._bubbleEl.style.top  = Math.max(70,  r.top  + 20)  + 'px';
        }

        this._bubbleEl.classList.add('show');
        clearTimeout(this._bubTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._bubTimer = setTimeout(() => this._hideBubble(), C.bubbleHoldMs);
    }

    _hideBubble() {
        if (this._bubbleEl) this._bubbleEl.classList.remove('show');
    }

    /* ── Click on character ───────────────────────────────────────────────── */
    _onCharacterClick() {
        this._expressionFlash();
        if (this._state === S.OPEN) {
            this._hideOpenCard();
        } else {
            this._showOpenCard();
        }
    }

    _expressionFlash() {
        if (!this._leanEl || !this._happyUrl) return;
        // Quick squash blink + happy expression, then back to lean pose
        this._leanEl.style.transform = 'scaleY(.88)';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this._leanEl.style.transform = '';
            this._leanEl.src = this._happyUrl;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => { this._leanEl.src = this._fullUrl; }, 1400);
        }, 110);
    }

    /* ── Typing detection ─────────────────────────────────────────────────── */
    _onTyping() {
        this._typing = true;
        clearTimeout(this._typingTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._typingTimer = setTimeout(() => { this._typing = false; }, C.quietWhileTypingMs);
    }

    /* ── Chips + AI ───────────────────────────────────────────────────────── */
    _onChip(e) {
        const prompt = CHIP_PROMPTS[e.currentTarget.dataset.q];
        if (prompt) this._callAI(prompt);
    }

    _onSend() {
        if (!this._inputEl) return;
        const val = this._inputEl.value.trim();
        if (val) { this._callAI(val); this._inputEl.value = ''; }
    }

    async _callAI(text) {
        if (this._isThinking) return;
        this._isThinking = true;
        this._updateSendBtn();
        this._showBubble('Thinking…', false);
        this._history.push({ role: 'user', content: text });
        const recent = this._history.slice(-10);
        try {
            const result = await sendMessage({ historyJson: JSON.stringify(recent) });
            if (result.success) {
                this._history.push({ role: 'assistant', content: result.reply });
                const display = result.reply.length > 280 ? result.reply.slice(0, 277) + '…' : result.reply;
                this._showBubble(display, false);
                const intro = this._openCard?.querySelector('.intro-line');
                if (intro) intro.textContent = display;
            } else {
                this._showBubble('Ran into an issue. ' + (result.errorMessage || 'Try again.'), false);
            }
        } catch (err) {
            this._showBubble('Could not reach the server. ' + (err?.body?.message || 'Check your connection.'), false);
        } finally {
            this._isThinking = false;
            this._updateSendBtn();
        }
    }

    _updateSendBtn() {
        const btn = this._openCard?.querySelector('.send-btn');
        if (!btn) return;
        btn.textContent = this._isThinking ? '…' : 'Ask';
        btn.disabled    = this._isThinking;
        if (this._inputEl) this._inputEl.disabled = this._isThinking;
    }

    /* ── Drag ─────────────────────────────────────────────────────────────── */
    _onDragStart(e) {
        if (!this._mcEl) return;
        const p = e.touches ? e.touches[0] : e;
        this._dragging  = true;
        this._dragMoved = false;
        const r = this._mcEl.getBoundingClientRect();
        this._bx = r.left; this._by = r.top;
        this._sx = p.clientX; this._sy = p.clientY;
        this._mcEl.classList.add('drag');
        e.preventDefault();
    }

    _onDragMove(e) {
        if (!this._dragging) return;
        const p  = e.touches ? e.touches[0] : e;
        const dx = p.clientX - this._sx;
        const dy = p.clientY - this._sy;
        if (Math.abs(dx) + Math.abs(dy) > 4) this._dragMoved = true;
        this._mcEl.style.transform = `translate(${this._bx + dx}px,${this._by + dy}px)`;
        this._hideBubble();
    }

    _onDragEnd() {
        if (!this._dragging) return;
        this._dragging = false;
        this._mcEl.classList.remove('drag');
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._dragMoved = false; }, 40);
        // Snap to nearest visible card after drop
        if (this._state !== S.OPEN) {
            const mr  = this._mcEl.getBoundingClientRect();
            const cx  = mr.left + mr.width / 2;
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
