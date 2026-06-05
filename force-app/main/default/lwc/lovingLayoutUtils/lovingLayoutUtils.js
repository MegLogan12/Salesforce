/**
 * Expands an LWC host element to fill the viewport width and removes dead space
 * imposed by the flexipage 8-of-12 column template.
 *
 * @param {HTMLElement} host - component's host element (this.template.host)
 * @returns {boolean} true if layout was fixed or was already full-width
 */
export function applyFullWidthLayout(host) {
    try {
        if (typeof window === 'undefined' || !host) return false;
        const rect = host.getBoundingClientRect();
        if (!rect || rect.width === 0) return false;
        const vw = window.innerWidth;
        // Expand width when component is narrower than 90% of viewport
        if (rect.width < vw * 0.9) {
            host.style.setProperty('width', `${vw - rect.left}px`, 'important');
            host.style.setProperty('max-width', 'none', 'important');
        }
        // Always collapse dead space above (target y≈90, just below the Salesforce tab bar)
        if (rect.top > 95) {
            host.style.setProperty('margin-top', `-${Math.round(rect.top - 90)}px`, 'important');
        }
        return true;
    } catch (e) {
        return false;
    }
}
