import { LightningElement, track } from 'lwc';
import ask from '@salesforce/apex/McLovinDockController.ask';
import BODY from '@salesforce/resourceUrl/mcLovinBody';
import HEAD from '@salesforce/resourceUrl/mcLovinHead';

export default class McLovinDock extends LightningElement {
    @track message = "Hey, I'm mcLOVIN'. Ask me to pull up a customer or work order, give you a live number, scan for messy data, or explain how the system works.";
    @track inputValue = '';
    @track busy = false;
    @track expanded = false;

    speaking = false;
    motion = true;
    _voice = null;
    _greeted = false;
    _looping = false;
    _rafId = null;
    _t0 = 0;

    connectedCallback() {
        this.style.position = 'fixed';
        this.style.right = '22px';
        this.style.bottom = '22px';
        this.style.zIndex = '9000';
        this.style.display = 'block';
        this.style.pointerEvents = 'auto';
        this._pickVoice();
        try {
            if (window.speechSynthesis && window.speechSynthesis.onvoiceschanged !== undefined) {
                window.speechSynthesis.onvoiceschanged = () => this._pickVoice();
            }
        } catch (e) {
            // no-op
        }
    }

    _pickVoice() {
        const synth = window.speechSynthesis;
        if (!synth) {
            return;
        }
        let voices = synth.getVoices().filter((voice) => voice.lang && voice.lang.toLowerCase().startsWith('en'));
        if (!voices.length) {
            return;
        }

        const blocklist = /\b(albert|bad news|bahh|bells|boing|bubbles|cellos|eddy|flo|fred|good news|grandma|grandpa|jester|junior|kathy|organ|ralph|rocko|sandy|shelley|superstar|trinoids|whisper|wobble|zarvox)\b/i;
        const usable = voices.filter((voice) => !blocklist.test(voice.name || ''));
        if (usable.length) {
            voices = usable;
        }

        const isFemale = (voice) => /female|samantha|victoria|karen|moira|tessa|fiona|zoe|allison|ava|susan|zira|aria|jenny|nicky|noelle|joelle|google us english/i.test(voice.name || '');
        const isMale = (voice) => /\bmale\b/i.test(voice.name || '') ||
            /\b(guy|tom|aaron|evan|nathan|reed|daniel|alex|matthew|eric|fred|oliver|arthur|david|mark|ryan|google uk english male)\b/i.test(voice.name || '');
        const quality = (voice) => {
            const name = (voice.name || '').toLowerCase();
            let score = 0;
            if (name.includes('natural')) {
                score += 100;
            }
            if (name.includes('enhanced') || name.includes('premium')) {
                score += 90;
            }
            if (name.startsWith('google')) {
                score += 70;
            }
            if (name.includes('siri')) {
                score += 60;
            }
            if (voice.localService === false) {
                score += 6;
            }
            return score;
        };

        const usVoices = voices.filter((voice) => voice.lang.toLowerCase() === 'en-us');
        let pool = usVoices.length ? usVoices : voices;
        const males = pool.filter(isMale);
        const nonFemale = pool.filter((voice) => !isFemale(voice));
        pool = males.length ? males : (nonFemale.length ? nonFemale : pool);
        this._voice = pool.slice().sort((a, b) => quality(b) - quality(a))[0] || voices[0];
    }

    get bodySrc() {
        return BODY;
    }

    get headSrc() {
        return HEAD;
    }

    get wrapClass() {
        return this.expanded ? 'mcl-wrap mcl-expanded' : 'mcl-wrap mcl-minimized';
    }

    renderedCallback() {
        if (this.expanded && !this._greeted) {
            const root = this.template.querySelector('.mcl-wrap');
            if (root) {
                const rect = root.getBoundingClientRect();
                if (rect.width > 0 && rect.height > 0) {
                    this._greeted = true;
                    this.message = "Hey, I'm mcLOVIN'. Ask me to pull up a customer or work order, give you a live number, scan for messy data, or explain how the system works.";
                    this.speak(this.message);
                }
            }
        }
        if (!this._looping) {
            const img = this.template.querySelector('.mcl-body, .mcl-head');
            if (img) {
                this._looping = true;
                this._t0 = performance.now();
                this._raf();
            }
        }
    }

    disconnectedCallback() {
        if (this._rafId) {
            cancelAnimationFrame(this._rafId);
        }
        try {
            if (window.speechSynthesis) {
                window.speechSynthesis.cancel();
            }
        } catch (e) {
            // no-op
        }
    }

    _raf = () => {
        const img = this.template.querySelector('.mcl-body, .mcl-head');
        const shadow = this.template.querySelector('.mcl-shadow');
        if (img) {
            const t = (performance.now() - this._t0) / 1000;
            if (this.speaking) {
                const bob = Math.sin(t * 7) * 1.0;
                const sway = Math.sin(t * 1.4) * 1.2;
                img.style.transform = `translateY(${bob}px) rotate(${sway}deg)`;
            } else if (this.motion) {
                const breathe = Math.sin(t * 1.6) * 1.2;
                const scale = 1 + Math.sin(t * 1.6) * 0.006;
                const sway = Math.sin(t * 0.7 + 1) * 0.9;
                img.style.transform = `translateY(${breathe}px) rotate(${sway}deg) scale(${scale})`;
                if (shadow) {
                    shadow.style.transform = `translateX(-50%) scaleX(${1 - Math.sin(t * 1.6) * 0.03})`;
                }
            } else {
                img.style.transform = 'none';
            }
        }
        this._rafId = requestAnimationFrame(this._raf);
    };

    speak(text) {
        const voiceOn = false;
        const start = () => {
            this.speaking = true;
        };
        const end = () => {
            this.speaking = false;
        };
        const synth = window.speechSynthesis;
        if (!voiceOn || !synth || !text) {
            start();
            setTimeout(end, Math.min(6000, 400 + (text ? text.length * 45 : 0)));
            return;
        }
        try {
            synth.cancel();
            if (!this._voice) {
                this._pickVoice();
            }
            const utterance = new SpeechSynthesisUtterance(text);
            utterance.rate = 0.95;
            utterance.pitch = 1.02;
            if (this._voice) {
                utterance.voice = this._voice;
                utterance.lang = this._voice.lang;
            }
            utterance.onstart = start;
            utterance.onend = end;
            utterance.onerror = end;
            start();
            synth.speak(utterance);
        } catch (e) {
            start();
            setTimeout(end, 2500);
        }
    }

    handleInput(event) {
        this.inputValue = event.target.value;
    }

    handleKey(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.send();
        }
    }

    openDock() {
        this.expanded = true;
    }

    closeDock() {
        this.expanded = false;
    }

    send() {
        const q = (this.inputValue || '').trim();
        if (!q || this.busy) {
            return;
        }
        this.message = '…';
        this.inputValue = '';
        this.busy = true;
        ask({ message: q })
            .then((response) => {
                this.message = response;
                this.speak(response);
            })
            .catch((error) => {
                this.message = `Snag: ${((error && error.body && error.body.message) || (error && error.message) || 'try again')}`;
            })
            .finally(() => {
                this.busy = false;
            });
    }
}