import { LightningElement, api } from 'lwc';
import ASSETS from '@salesforce/resourceUrl/askMclovin';
import sendMessage from '@salesforce/apex/McLovinChatController.sendMessage';

// ── Config ────────────────────────────────────────────────────────────────────
const C = {
    timings: {
        entranceDelayMs:          600,
        entranceFadeMs:           350,
        walkSpeedPxPerSec:        140,
        runSpeedPxPerSec:         240,
        perchSettleMs:            450,
        pageChangeSettleMs:       900,
        quietWhileTypingMs:      4000,
        celebrateCooldownMs:   120000
    },
    flags: {
        walkInOnLoad:              true,
        perchOnForms:              true,
        hangOnEdgeWhenNoPerch:     true,
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
            opportunity: ["Want the smart way to close this one?", "Tell me the objection and I'll hand you the line.", "Stage looks ready to move. Nudge it?"],
            account:     ["Want a quick read on this account before you call?", "I can pull the last three touches if you want."],
            lead:        ["Fresh lead. Want a fast qualifying question?", "I can draft the first outreach if you like."],
            quote:       ["Want me to sanity check this quote?", "Margins look tight. Want options?"],
            task:        ["Knock this out and I'll cheer.", "Want me to draft the follow up?"],
            report:      ["Want the one number that actually matters here?", "I can summarize this in a sentence."]
        },
        minimized:   ["Need a hand?", "Tap me anytime.", "I'll be over here."],
        peek:        ["Psst... need help closing this?", "Psst... I do shortcuts too.", "Knock knock. It's your unfair advantage."],
        drag_pickup: ["Wheee.", "Where to, boss?"],
        drag_drop:   ["Good spot.", "Right here works.", "Cozy."]
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

const PORTAL_ID  = 'mclovin-portal';
const STYLES_ID  = 'mclovin-styles';
const S = { ENTER:'enter', WELCOME:'welcome', PERCH:'perch', EDGE:'edge', DRAG:'drag' };

function pick(arr, last) {
    if (!arr || !arr.length) return '';
    const opts = arr.filter(l => l !== last);
    return opts[Math.floor(Math.random() * opts.length)] || arr[0];
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

// ── CSS injected into document.head ──────────────────────────────────────────
const PORTAL_CSS = `
#mclovin-portal { position:fixed; inset:0; z-index:9999; pointer-events:none; }
#mclovin-portal .mc {
  position:fixed; pointer-events:auto; transition-property:left,top;
  transition-timing-function:cubic-bezier(.22,.1,.3,1);
}
#mclovin-portal .mc.face-left { transform:scaleX(-1); }

@keyframes mcBob {
  0%,100% { transform:translateY(0) scale(1); }
  50%     { transform:translateY(-7px) scale(1.006); }
}
@keyframes mcBobFlip {
  0%,100% { transform:scaleX(-1) translateY(0) scale(1); }
  50%     { transform:scaleX(-1) translateY(-7px) scale(1.006); }
}
@keyframes mcWalkBob {
  0%,100% { transform:translateY(0); }
  50%     { transform:translateY(-5px); }
}
@keyframes mcPing {
  0%   { box-shadow:0 0 0 0 rgba(252,212,0,.45); }
  70%  { box-shadow:0 0 0 12px rgba(252,212,0,0); }
  100% { box-shadow:0 0 0 0 rgba(252,212,0,0); }
}

/* WALKING */
#mclovin-portal .walker {
  height:160px; display:block; cursor:grab;
  filter:drop-shadow(0 12px 20px rgba(20,24,40,.25));
  animation:mcWalkBob .45s ease-in-out infinite both;
  transform-origin:bottom center; will-change:transform;
}

/* PERCHED */
#mclovin-portal .perched {
  height:140px; display:block; cursor:pointer;
  filter:drop-shadow(0 12px 20px rgba(20,24,40,.22));
  animation:mcBob 4.5s ease-in-out infinite both;
  transform-origin:bottom center; will-change:transform;
}

/* EDGE HANG */
#mclovin-portal .edge-hang {
  height:160px; display:block; cursor:pointer;
  filter:drop-shadow(-10px 14px 22px rgba(20,24,40,.25));
  animation:mcBob 5s ease-in-out infinite both;
  transform-origin:center; will-change:transform;
}

/* OPEN CARD */
#mclovin-portal .open {
  position:relative; width:320px; padding-top:100px;
}
#mclovin-portal .open .body {
  position:absolute; right:8px; top:-180px; height:260px;
  filter:drop-shadow(0 16px 26px rgba(20,24,40,.28));
  animation:mcBob 4.2s ease-in-out infinite both;
  transform-origin:bottom center; will-change:transform; cursor:grab;
  pointer-events:auto;
}
#mclovin-portal .close-btn {
  position:absolute; right:0; top:-180px; width:28px; height:28px; border-radius:50%;
  background:#fff; border:1px solid rgba(0,0,0,.08); cursor:pointer;
  font-size:15px; color:#6b7280; display:grid; place-items:center; z-index:1;
}
#mclovin-portal .panel {
  display:flex; flex-direction:column; gap:10px;
  background:#fff; border:1px solid rgba(0,0,0,.08); border-radius:18px;
  padding:14px; box-shadow:0 18px 40px rgba(20,24,40,.18);
}
#mclovin-portal .chips { display:flex; gap:7px; flex-wrap:wrap; }
#mclovin-portal .chip {
  background:#fff; border:1px solid rgba(0,0,0,.08); border-radius:999px;
  padding:7px 12px; font-size:13px; font-weight:600; cursor:pointer;
}
#mclovin-portal .chip:hover { border-color:#FCD400; background:#fffdf0; }
#mclovin-portal .askbar {
  display:flex; gap:8px; background:#fff; border:1px solid rgba(0,0,0,.08);
  border-radius:14px; padding:7px 8px 7px 13px;
  box-shadow:0 10px 26px rgba(20,24,40,.12);
}
#mclovin-portal .askbar input { flex:1; border:none; outline:none; font-size:14px; background:transparent; }
#mclovin-portal .askbar button {
  border:none; background:#FCD400; color:#1b1f25; font-weight:800;
  border-radius:10px; padding:8px 12px; cursor:pointer; min-width:50px;
}
#mclovin-portal .askbar button:disabled { opacity:.5; cursor:default; }

/* BUBBLE */
#mclovin-portal .bubble {
  position:fixed; max-width:260px; background:#fff; border:1px solid rgba(0,0,0,.08);
  border-radius:18px; padding:12px 14px; box-shadow:0 18px 40px rgba(20,24,40,.18);
  font-size:14px; line-height:1.4; color:#1b1f25;
  opacity:0; transform:translateY(6px) scale(.98);
  transition:opacity .25s, transform .25s; pointer-events:none; z-index:10000;
}
#mclovin-portal .bubble.show { opacity:1; transform:none; }
#mclovin-portal .open .bubble { position:absolute; opacity:1; transform:none; }
#mclovin-portal .bubble b { color:#caa500; }
#mclovin-portal .spark {
  display:inline-grid; place-items:center; width:22px; height:22px; border-radius:50%;
  background:#FCD400; font-size:12px; vertical-align:-5px; margin-right:7px;
}
#mclovin-portal .tail {
  position:absolute; width:14px; height:14px; background:#fff;
  border-right:1px solid rgba(0,0,0,.08); border-bottom:1px solid rgba(0,0,0,.08);
  transform:rotate(45deg);
}

/* PEEK */
#mclovin-portal .peek {
  position:fixed; right:-260px; bottom:120px; width:240px;
  transition:right .5s cubic-bezier(.2,.8,.2,1); pointer-events:none; z-index:9998;
}
#mclovin-portal .peek.in { right:-20px; }
#mclovin-portal .peek img { width:240px; filter:drop-shadow(-12px 16px 26px rgba(20,24,40,.25)); }
#mclovin-portal .peek .bubble { position:absolute; right:220px; bottom:100px; }

@media (prefers-reduced-motion:reduce) {
  #mclovin-portal .walker,#mclovin-portal .perched,#mclovin-portal .edge-hang,
  #mclovin-portal .open .body { animation:none; }
  #mclovin-portal .peek { transition:none; }
  #mclovin-portal .bubble { transition:none; }
  #mclovin-portal .mc { transition:none !important; }
}
`;

// ── Component ─────────────────────────────────────────────────────────────────
export default class AskMclovin extends LightningElement {

    // Asset URLs (set in connectedCallback once ASSETS is resolved)
    _headUrl = '';
    _fullUrl  = '';
    _peekUrl  = '';

    // State
    _state     = S.EDGE;
    _posX      = null;   // null = use default corner
    _posY      = null;
    _faceRight = true;
    _isWalking = false;
    _isThinking = false;
    _nudgeText  = '';
    _nudgeOn    = false;
    _peekVis    = false;
    _peekBubble = false;
    _reducedMotion = false;

    // DOM refs (portal elements)
    _portal    = null;
    _mcEl      = null;
    _walkerEl  = null;
    _perchedEl = null;
    _edgeEl    = null;
    _openEl    = null;
    _nudgeEl   = null;
    _peekEl    = null;
    _peekBubEl = null;
    _inputEl   = null;

    // Timers / misc
    _walkTimer   = null;
    _idleTimer   = null;
    _nudgeTimer  = null;
    _typingTimer = null;
    _drag        = null;
    _dragMoved   = false;
    _lastLine    = '';
    _typing      = false;
    _history     = [];
    _isOwner     = false;   // true if this instance created the portal

    // Bound handlers stored for cleanup
    _onMove = null;
    _onUp   = null;
    _onKey  = null;
    _onType = null;
    _onNav  = null;

    /* ── Lifecycle ─────────────────────────────────────────────────────────── */
    connectedCallback() {
        this._headUrl = ASSETS + '/head.png';
        this._fullUrl  = ASSETS + '/full.png';
        this._peekUrl  = ASSETS + '/peek.png';
        this._reducedMotion = window.matchMedia?.('(prefers-reduced-motion:reduce)').matches;

        // Only the first mounted instance owns the portal
        if (document.getElementById(PORTAL_ID)) {
            return; // another instance already owns it
        }
        this._isOwner = true;
        this._injectStyles();
        this._createPortal();
        this._bindGlobalEvents();

        const savedX = this._loadPos();
        if (savedX !== null) {
            this._posX = savedX.x;
            this._posY = savedX.y;
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this._runEntrance(), C.timings.entranceDelayMs);
    }

    disconnectedCallback() {
        if (!this._isOwner) return;
        clearTimeout(this._walkTimer);
        clearTimeout(this._idleTimer);
        clearTimeout(this._nudgeTimer);
        clearTimeout(this._typingTimer);
        window.removeEventListener('mousemove',  this._onMove);
        window.removeEventListener('touchmove',  this._onMove);
        window.removeEventListener('mouseup',    this._onUp);
        window.removeEventListener('touchend',   this._onUp);
        window.removeEventListener('keydown',    this._onKey);
        window.removeEventListener('keypress',   this._onType);
        window.removeEventListener('hashchange', this._onNav);
        window.removeEventListener('popstate',   this._onNav);
        const portal = document.getElementById(PORTAL_ID);
        if (portal) portal.remove();
        const styles = document.getElementById(STYLES_ID);
        if (styles) styles.remove();
    }

    /* ── Public API ────────────────────────────────────────────────────────── */
    @api open() {
        // Ensure card lands in a visible corner (bottom-right)
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        if (this._posX === null) {
            this._posX = vw - 380;
            this._posY = vh - 420;
        } else {
            // Clamp existing position so 320px card + 260px character stay on screen
            this._posX = clamp(this._posX, 10, vw - 380);
            this._posY = clamp(this._posY, 200, vh - 320);
        }
        this._setState(S.WELCOME);
        this._setNudge('', false);
    }
    @api minimize() { this._goToEdge(); }
    @api peek()     { this._doPeek(); }
    @api say(text)  { this._showBubble(text, true); }

    /* ── Styles + Portal creation ──────────────────────────────────────────── */
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
        this._portal  = p;
        this._cacheRefs();
        this._bindPortalEvents();
        this._syncDOM();
    }

    _portalHTML() {
        return `
<div class="mc">
  <img class="walker"    src="${this._fullUrl}" alt="mcLOVIN walking">
  <img class="perched"   src="${this._fullUrl}" alt="mcLOVIN perched">
  <img class="edge-hang" src="${this._peekUrl}" alt="mcLOVIN edge">
  <div class="open pe">
    <img class="body grab" src="${this._fullUrl}" alt="mcLOVIN">
    <button class="close-btn">&#8211;</button>
    <div class="panel">
      <div class="bubble show intro-bubble">
        <span class="spark">&#10022;</span>
        Hey, I&rsquo;m <b>mcLOVIN&rsquo;</b>. What do you need?
      </div>
      <div class="chips pe">
        <span class="chip" data-q="po">Upload PO</span>
        <span class="chip" data-q="scope">Scope</span>
        <span class="chip" data-q="account">New Account</span>
        <span class="chip" data-q="homeowner">Homeowner Intake</span>
        <span class="chip" data-q="find">Find Existing Job</span>
        <span class="chip" data-q="missing">What&rsquo;s Missing?</span>
      </div>
      <div class="askbar pe">
        <input type="text" placeholder="Ask mcLOVIN' anything...">
        <button class="send-btn">Ask</button>
      </div>
    </div>
  </div>
</div>
<div class="bubble nudge-bubble pe"></div>
<div class="peek">
  <div class="bubble peek-bubble"></div>
  <img src="${this._peekUrl}" alt="peek">
</div>`;
    }

    _cacheRefs() {
        const p = this._portal;
        this._mcEl      = p.querySelector('.mc');
        this._walkerEl  = p.querySelector('.walker');
        this._perchedEl = p.querySelector('.perched');
        this._edgeEl    = p.querySelector('.edge-hang');
        this._openEl    = p.querySelector('.open');
        this._nudgeEl   = p.querySelector('.nudge-bubble');
        this._peekEl    = p.querySelector('.peek');
        this._peekBubEl = p.querySelector('.peek-bubble');
        this._inputEl   = p.querySelector('.askbar input');
    }

    _bindPortalEvents() {
        const p = this._portal;
        p.querySelector('.walker').addEventListener('mousedown',    (e) => this._onDragStart(e));
        p.querySelector('.walker').addEventListener('touchstart',   (e) => this._onDragStart(e), {passive:false});
        p.querySelector('.walker').addEventListener('click',        ()  => this.open());
        p.querySelector('.perched').addEventListener('click',       ()  => this.open());
        p.querySelector('.perched').addEventListener('mousedown',   (e) => this._onDragStart(e));
        p.querySelector('.edge-hang').addEventListener('click',     ()  => this.open());
        p.querySelector('.edge-hang').addEventListener('mousedown', (e) => this._onDragStart(e));
        p.querySelector('.open .body').addEventListener('mousedown',(e) => this._onDragStart(e));
        p.querySelector('.open .body').addEventListener('touchstart',(e)=> this._onDragStart(e), {passive:false});
        p.querySelector('.close-btn').addEventListener('click',     ()  => this.minimize());
        p.querySelector('.send-btn').addEventListener('click',      ()  => this._onSend());
        this._inputEl.addEventListener('keyup', (e) => { if (e.key==='Enter') this._onSend(); });
        p.querySelectorAll('.chip').forEach(c => c.addEventListener('click', (e) => this._onChip(e)));
    }

    _bindGlobalEvents() {
        this._onMove   = (e) => this._onDragMove(e);
        this._onUp     = ()  => this._onDragEnd();
        this._onKey    = (e) => { if (e.key==='Escape') this.minimize(); };
        this._onType   = ()  => this._onTyping();
        this._onNav    = ()  => this._onPageChange();
        window.addEventListener('mousemove',  this._onMove);
        window.addEventListener('touchmove',  this._onMove,  {passive:false});
        window.addEventListener('mouseup',    this._onUp);
        window.addEventListener('touchend',   this._onUp);
        window.addEventListener('keydown',    this._onKey);
        window.addEventListener('keypress',   this._onType);
        window.addEventListener('hashchange', this._onNav);
        window.addEventListener('popstate',   this._onNav);
    }

    /* ── DOM sync ─────────────────────────────────────────────────────────── */
    _syncDOM() {
        if (!this._mcEl) return;

        // Position
        if (this._posX === null) {
            this._mcEl.style.left   = 'auto';
            this._mcEl.style.right  = '34px';
            this._mcEl.style.top    = 'auto';
            this._mcEl.style.bottom = '34px';
        } else {
            this._mcEl.style.left   = this._posX + 'px';
            this._mcEl.style.top    = this._posY + 'px';
            this._mcEl.style.right  = 'auto';
            this._mcEl.style.bottom = 'auto';
        }

        // Direction flip
        this._mcEl.classList.toggle('face-left', !this._faceRight);

        // Hide all — then show exactly one
        this._walkerEl.style.display  = 'none';
        this._perchedEl.style.display = 'none';
        this._edgeEl.style.display    = 'none';
        this._openEl.style.display    = 'none';

        const moving = this._isWalking || this._state === S.DRAG;
        if      (moving || this._state === S.ENTER)   this._walkerEl.style.display  = '';
        else if (this._state === S.PERCH)              this._perchedEl.style.display = '';
        else if (this._state === S.EDGE)               this._edgeEl.style.display    = '';
        else if (this._state === S.WELCOME)            this._openEl.style.display    = '';

        // Nudge bubble
        if (this._nudgeOn && this._nudgeText) {
            this._nudgeEl.innerHTML = `<span class="spark">&#10022;</span>${this._nudgeText}<span class="tail" style="right:-7px;bottom:20px"></span>`;
            this._nudgeEl.classList.add('show');
        } else {
            this._nudgeEl.classList.remove('show');
        }

        // Peek
        this._peekEl.classList.toggle('in', this._peekVis);
        if (this._peekBubble && this._nudgeText) {
            this._peekBubEl.innerHTML = `<span class="spark">&#10022;</span>${this._nudgeText}`;
            this._peekBubEl.classList.add('show');
        } else {
            this._peekBubEl.classList.remove('show');
        }

        // Send button thinking state
        const sendBtn = this._portal?.querySelector('.send-btn');
        if (sendBtn) {
            sendBtn.textContent = this._isThinking ? '...' : 'Ask';
            sendBtn.disabled    = this._isThinking;
        }
        if (this._inputEl) this._inputEl.disabled = this._isThinking;
    }

    _setPos(x, y) { this._posX = x; this._posY = y; this._syncDOM(); }
    _setState(s)   { this._state = s; this._syncDOM(); }

    _setNudge(text, on) {
        // Position nudge near the character
        if (on && text && this._mcEl) {
            const b = this._mcEl.getBoundingClientRect();
            const nx = clamp(b.left - 270, 12, window.innerWidth - 280);
            const ny = clamp(b.top - 12, 8, window.innerHeight - 120);
            this._nudgeEl.style.left = nx + 'px';
            this._nudgeEl.style.top  = ny + 'px';
        }
        this._nudgeText = text;
        this._nudgeOn   = on;
        this._syncDOM();
    }

    /* ── Entrance ──────────────────────────────────────────────────────────── */
    _runEntrance() {
        if (!this._isOwner || !this._mcEl) return;
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        const groundY = vh - 180;

        if (this._reducedMotion) {
            this._setPos(vw - 160, groundY);
            this._setState(S.ENTER);
            this._showBubble(pick(C.dialogue.entrance, this._lastLine), true);
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._goToEdge(), 3000);
            return;
        }

        this._faceRight = true;
        this._setPos(-170, groundY);
        this._setState(S.ENTER);

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const perch   = this._findBestPerch();
            const targetX = perch ? this._perchX(perch) : clamp(vw * 0.18, 100, vw - 180);
            this._walkTo(targetX, groundY, () => {
                this._isWalking = false;
                this._clearTransition();
                this._showBubble(pick(C.dialogue.entrance, this._lastLine), true);
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    if (perch) this._perchOn(perch);
                    else       this._goToEdgeOrBadge();
                }, 3200);
            });
        }, C.timings.entranceFadeMs);
    }

    /* ── Walking ───────────────────────────────────────────────────────────── */
    _walkTo(tx, ty, onDone, fast) {
        if (!this._mcEl) return;
        const dist = Math.hypot(tx - this._posX, ty - this._posY);
        const spd  = fast ? C.timings.runSpeedPxPerSec : C.timings.walkSpeedPxPerSec;
        const dur  = Math.round((dist / spd) * 1000);
        this._faceRight = tx > this._posX;
        this._isWalking = true;
        this._mcEl.classList.toggle('face-left', !this._faceRight);
        // Apply transition
        this._mcEl.style.transitionDuration = dur + 'ms';
        // Nudge layout by reading offsetLeft before setting new pos
        // eslint-disable-next-line no-unused-expressions
        this._mcEl.offsetLeft; // force reflow
        this._setPos(tx, ty);
        clearTimeout(this._walkTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._walkTimer = setTimeout(() => {
            this._isWalking = false;
            this._clearTransition();
            onDone();
        }, dur + 80);
    }

    _clearTransition() {
        if (this._mcEl) this._mcEl.style.transitionDuration = '0ms';
    }

    /* ── Perch system ──────────────────────────────────────────────────────── */
    _findBestPerch() {
        if (!C.flags.perchOnForms) return null;
        const els = document.querySelectorAll('[data-mclovin-perch]');
        if (!els.length) return null;
        let best = null, bestScore = -Infinity;
        els.forEach(el => {
            const r = el.getBoundingClientRect();
            if (r.width < 10 || r.bottom < 0 || r.top > window.innerHeight) return;
            const pri   = parseInt(el.dataset.mclovinPriority || '0', 10);
            const score = pri * 100 - Math.abs((r.left + r.width/2) - window.innerWidth/2);
            if (score > bestScore) { bestScore = score; best = el; }
        });
        return best;
    }

    _perchX(el) {
        const r   = el.getBoundingClientRect();
        const cfg = C.perchTypes[el.dataset.mclovinPerch] || C.perchTypes['stand'];
        let x = 0;
        if (cfg.anchor === 'topRight' || cfg.anchor === 'rightMid' || cfg.anchor === 'bottomRight') x = r.right + cfg.offsetX;
        else if (cfg.anchor === 'leftMid')   x = r.left  + cfg.offsetX;
        else if (cfg.anchor === 'topCenter') x = r.left  + r.width/2 + cfg.offsetX;
        else                                 x = r.right + cfg.offsetX;
        return clamp(x, 8, window.innerWidth - 130);
    }

    _perchY(el) {
        const r   = el.getBoundingClientRect();
        const cfg = C.perchTypes[el.dataset.mclovinPerch] || C.perchTypes['stand'];
        let y = 0;
        if (cfg.anchor === 'topRight' || cfg.anchor === 'topCenter') y = r.top + cfg.offsetY;
        else if (cfg.anchor === 'leftMid' || cfg.anchor === 'rightMid') y = r.top + r.height/2 + cfg.offsetY;
        else if (cfg.anchor === 'bottomRight') y = r.bottom + cfg.offsetY;
        else y = r.top + cfg.offsetY;
        return clamp(y, 8, window.innerHeight - 160);
    }

    _perchOn(el) {
        const ctx = el.dataset.mclovinContext;
        const tx  = this._perchX(el);
        const ty  = this._perchY(el);
        if (this._reducedMotion) {
            this._setPos(tx, ty);
            this._setState(S.PERCH);
            this._sayContextLine(ctx);
            this._scheduleIdle();
        } else {
            this._walkTo(tx, ty, () => {
                this._setState(S.PERCH);
                this._sayContextLine(ctx);
                this._scheduleIdle();
            });
        }
    }

    _sayContextLine(ctx) {
        const bank = (ctx && C.dialogue.context[ctx]) ? C.dialogue.context[ctx] : C.dialogue.perch_generic;
        const line = pick(bank, this._lastLine);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this._showBubble(line, false), C.timings.perchSettleMs);
    }

    /* ── Edge ─────────────────────────────────────────────────────────────── */
    _goToEdge() {
        clearTimeout(this._idleTimer);
        const perch = this._findBestPerch();
        if (perch) { this._perchOn(perch); return; }
        const tx = window.innerWidth  - 110;
        const ty = window.innerHeight * 0.45;
        if (this._reducedMotion) {
            this._setPos(tx, ty);
            this._setState(S.EDGE);
            this._scheduleIdle();
        } else {
            this._walkTo(tx, ty, () => {
                this._setState(S.EDGE);
                this._scheduleIdle();
            });
        }
    }

    _goToEdgeOrBadge() { this._goToEdge(); }

    /* ── Idle ─────────────────────────────────────────────────────────────── */
    _scheduleIdle() { /* intentionally empty — mcLOVIN only moves on click or page change */ }

    /* ── Page change ──────────────────────────────────────────────────────── */
    _onPageChange() {
        if (!this._isOwner || this._state === S.WELCOME) return;
        clearTimeout(this._idleTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._idleTimer = setTimeout(() => {
            const perch = this._findBestPerch();
            if (perch) this._perchOn(perch);
            else       this._goToEdge();
        }, C.timings.pageChangeSettleMs);
    }

    /* ── Bubble ────────────────────────────────────────────────────────────── */
    _showBubble(text, sticky) {
        if (!text) return;
        if (this._typing && C.flags.muteLinesWhileTyping && !sticky) return;
        clearTimeout(this._nudgeTimer);
        this._setNudge(text, true);
        this._lastLine = text;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._nudgeTimer = setTimeout(() => this._setNudge('', false), sticky ? 7000 : 3500);
    }

    /* ── Typing detection ──────────────────────────────────────────────────── */
    _onTyping() {
        this._typing = true;
        clearTimeout(this._typingTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._typingTimer = setTimeout(() => { this._typing = false; }, C.timings.quietWhileTypingMs);
    }

    /* ── Interactions ──────────────────────────────────────────────────────── */
    _onChip(e) {
        const prompt = CHIP_PROMPTS[e.currentTarget.dataset.q];
        if (prompt) this._callAI(prompt);
    }

    _onSend() {
        if (!this._inputEl) return;
        const val = this._inputEl.value.trim();
        if (val) { this._callAI(val); this._inputEl.value = ''; }
    }

    /* ── AI call ────────────────────────────────────────────────────────────── */
    async _callAI(text) {
        if (this._isThinking) return;
        this._isThinking = true;
        this._syncDOM();
        this._showBubble('Thinking...', false);
        this._history.push({ role: 'user', content: text });
        const recent = this._history.slice(-10);
        try {
            const result = await sendMessage({ historyJson: JSON.stringify(recent) });
            if (result.success) {
                this._history.push({ role: 'assistant', content: result.reply });
                const display = result.reply.length > 280 ? result.reply.slice(0, 277) + '...' : result.reply;
                this._showBubble(display, true);
                // Show reply in panel bubble too
                const introBubble = this._openEl?.querySelector('.intro-bubble');
                if (introBubble) introBubble.innerHTML = `<span class="spark">&#10022;</span>${display}`;
            } else {
                this._showBubble('Ran into an issue. ' + (result.errorMessage || 'Try again.'), true);
            }
        } catch (err) {
            const msg = err?.body?.message || 'Check your connection.';
            this._showBubble('Could not reach the server. ' + msg, true);
        } finally {
            this._isThinking = false;
            this._syncDOM();
        }
    }

    /* ── Drag ───────────────────────────────────────────────────────────────── */
    _onDragStart(e) {
        const p = e.touches ? e.touches[0] : e;
        if (!this._mcEl) return;
        const b = this._mcEl.getBoundingClientRect();
        this._drag      = { baseX: b.left, baseY: b.top, startX: p.clientX, startY: p.clientY };
        this._dragMoved = false;
        this._clearTransition();
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
        this._faceRight = dx >= 0;
        this._setPos(
            clamp(this._drag.baseX + dx, 8, window.innerWidth  - 110),
            clamp(this._drag.baseY + dy, 8, window.innerHeight - 110)
        );
    }

    _onDragEnd() {
        if (!this._drag) return;
        this._drag = null;
        if (C.flags.rememberLastPosition && this._posX !== null) {
            try { localStorage.setItem('mclovin_pos', JSON.stringify({x:this._posX,y:this._posY})); } catch(_) { /* ignore */ }
        }
        this._showBubble(pick(C.dialogue.drag_drop, this._lastLine), false);
        const perch = this._findBestPerch();
        if (perch) this._perchOn(perch);
        else       this._goToEdgeOrBadge();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._dragMoved = false; }, 30);
    }

    /* ── Position persistence ─────────────────────────────────────────────── */
    _loadPos() {
        if (!C.flags.rememberLastPosition) return null;
        try {
            const s = localStorage.getItem('mclovin_pos');
            return s ? JSON.parse(s) : null;
        } catch (_) { return null; }
    }
}
