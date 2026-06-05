#!/usr/bin/env python3
"""
Playwright test for the 'Ask mcLOVIN'' floating AI assistant in Salesforce.
Gets a fresh session via @salesforce/core AuthInfo.getOrgFrontDoorUrl().
"""

import os
import sys
import time
import json
import asyncio
import subprocess
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots"
APP_URL = "https://loving.my.salesforce.com/lightning/app/01Ia5000000blTIEAY"
INSTANCE_URL = "https://loving.my.salesforce.com"

os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

async def screenshot(page, name, desc=""):
    path = f"{SCREENSHOTS_DIR}/{name}"
    await page.screenshot(path=path, full_page=False)
    log(f"Screenshot saved: {name} — {desc}")
    return path

def get_fresh_frontdoor_url():
    """Use @salesforce/core to get a fresh frontdoor URL."""
    js = """
const { AuthInfo } = require('/opt/node22/lib/node_modules/@salesforce/cli/node_modules/@salesforce/core');
async function main() {
    const auth = await AuthInfo.create({ username: 'megan.logan@thelovingcompanies.com' });
    const url = await auth.getOrgFrontDoorUrl();
    process.stdout.write(url + '\\n');
}
main().catch(e => { process.stderr.write(e.message + '\\n'); process.exit(1); });
"""
    result = subprocess.run(
        ["node", "-e", js],
        capture_output=True, text=True, timeout=15
    )
    if result.returncode != 0:
        raise RuntimeError(f"Failed to get frontdoor URL: {result.stderr}")
    return result.stdout.strip()

async def main():
    log("Getting fresh Salesforce frontdoor URL ...")
    try:
        frontdoor_url = get_fresh_frontdoor_url()
        log(f"Got frontdoor URL: {frontdoor_url[:80]}...")
    except Exception as e:
        log(f"Failed to get frontdoor URL: {e}")
        return

    # Build the app URL with retURL
    app_frontdoor_url = frontdoor_url + "&retURL=/lightning/app/01Ia5000000blTIEAY"

    async with async_playwright() as p:
        log("Launching Chromium (1440x900) on DISPLAY :99 ...")
        browser = await p.chromium.launch(
            headless=False,
            args=[
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu",
                "--window-size=1440,900",
            ],
        )

        context = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )

        page = await context.new_page()

        # ── STEP 1: Login via frontdoor URL ───────────────────────────────────
        log("Step 1: Navigating to Salesforce via frontdoor URL ...")
        try:
            await page.goto(app_frontdoor_url, timeout=60000, wait_until="domcontentloaded")
            await page.wait_for_timeout(8000)
            url_after = page.url
            log(f"URL after login: {url_after}")
            await screenshot(page, "mclovin_01_after_login.png", "After login navigation")
        except Exception as e:
            log(f"ERROR during login: {e}")
            await screenshot(page, "mclovin_01_error.png", f"Login error: {e}")
            await browser.close()
            return

        # Check if logged in
        is_logged_in = "lightning" in page.url or "home.jsp" in page.url
        if not is_logged_in:
            log(f"Not logged in. Page title: {await page.title()}")
            log(f"URL: {page.url}")
            await screenshot(page, "mclovin_LOGIN_FAILED.png", "Login failed")
            await browser.close()
            return

        log(f"Logged in! URL: {page.url}")

        # ── STEP 2: Navigate to Outdoor Living app ───────────────────────────
        log("Step 2: Navigating to Outdoor Living app ...")
        try:
            await page.goto(APP_URL, timeout=60000, wait_until="domcontentloaded")
            log(f"Waiting for Lightning to load ...")
            # Wait for the Lightning app to render
            try:
                await page.wait_for_selector(
                    "one-app-nav-bar, .slds-utility-bar, lightning-app, [class*='appBody']",
                    timeout=30000
                )
                log("Lightning app structure detected!")
            except PlaywrightTimeoutError:
                log("Lightning app selector not found within 30s — waiting longer ...")
                await page.wait_for_timeout(10000)

            await screenshot(page, "mclovin_02_outdoor_living_app.png", "Outdoor Living app loaded")
            log(f"URL: {page.url}")
        except Exception as e:
            log(f"ERROR navigating to app: {e}")
            await screenshot(page, "mclovin_02_error.png", f"Error: {e}")

        # ── STEP 3: Screenshot full page ─────────────────────────────────────
        log("Step 3: Taking full screenshot and analyzing page structure ...")

        # Give the page more time to load all LWC components
        await page.wait_for_timeout(5000)
        await screenshot(page, "mclovin_03_utility_bar.png", "Full page — looking for utility bar")

        # Analyze page structure
        page_info = await page.evaluate("""
            () => {
                const info = {
                    title: document.title,
                    url: window.location.href,
                    bodyTextPreview: document.body.innerText.substring(0, 300),
                    allButtons: [],
                    utilityBarHTML: null,
                    fixedElements: []
                };

                // All interactive elements
                const interactives = document.querySelectorAll(
                    'button, [role="button"], a[href], input, [data-key]'
                );
                for (const el of interactives) {
                    const text = (el.textContent || '').trim().substring(0, 60);
                    const title = el.getAttribute('title') || '';
                    const aria = el.getAttribute('aria-label') || '';
                    if (text || title || aria) {
                        info.allButtons.push({text, title, aria, tag: el.tagName, visible: el.offsetParent !== null});
                    }
                }

                // Utility bar
                const selectors = [
                    '.slds-utility-bar', '[class*="utility-bar"]',
                    'one-utility-bar', 'runtime_utilities-utility-bar',
                    '[class*="utilityBar"]'
                ];
                for (const sel of selectors) {
                    const el = document.querySelector(sel);
                    if (el) {
                        info.utilityBarHTML = el.outerHTML.substring(0, 1000);
                        break;
                    }
                }

                // Fixed positioned elements
                const all = document.querySelectorAll('*');
                for (const el of all) {
                    const style = window.getComputedStyle(el);
                    if (style.position === 'fixed' && el.offsetWidth > 0 && el.offsetHeight > 0) {
                        info.fixedElements.push({
                            tag: el.tagName,
                            id: el.id.substring(0, 30),
                            className: el.className.substring(0, 80),
                            text: el.textContent.trim().substring(0, 50),
                            bottom: style.bottom, right: style.right,
                            w: el.offsetWidth, h: el.offsetHeight
                        });
                    }
                }

                return info;
            }
        """)

        log(f"Page title: {page_info['title']}")
        log(f"Body text: {page_info['bodyTextPreview'][:200]}")
        log(f"Number of buttons: {len(page_info['allButtons'])}")
        log(f"Utility bar: {page_info['utilityBarHTML']}")
        log(f"Fixed elements ({len(page_info['fixedElements'])}): {page_info['fixedElements']}")

        # ── STEP 4: Find and click mcLOVIN button ────────────────────────────
        log("Step 4: Searching for 'Ask mcLOVIN'' button ...")

        mclovin_button = None
        for btn in page_info['allButtons']:
            text = (btn.get('text') or '').lower()
            title = (btn.get('title') or '').lower()
            aria = (btn.get('aria') or '').lower()
            if 'mclovin' in text or 'mclovin' in title or 'mclovin' in aria:
                log(f"Found mcLOVIN button: {btn}")
                mclovin_button = btn
                break

        # Try clicking via JavaScript (handles shadow DOM)
        click_result = await page.evaluate("""
            () => {
                function findAndClickMcLovin(root, depth=0) {
                    if (depth > 8) return null;
                    const els = root.querySelectorAll('button, [role="button"], a, span, div');
                    for (const el of els) {
                        const text = (el.textContent || '').trim().toLowerCase();
                        const title = (el.getAttribute('title') || '').toLowerCase();
                        const aria = (el.getAttribute('aria-label') || '').toLowerCase();
                        const dataKey = (el.getAttribute('data-key') || '').toLowerCase();
                        if (text.includes('mclovin') || title.includes('mclovin') ||
                            aria.includes('mclovin') || dataKey.includes('mclovin')) {
                            // Make sure it's a leaf/small element, not body/html
                            if (el.children.length < 5) {
                                el.click();
                                return {
                                    found: true, tag: el.tagName,
                                    text: el.textContent.trim().substring(0, 60),
                                    title: title, aria: aria
                                };
                            }
                        }
                        if (el.shadowRoot) {
                            const found = findAndClickMcLovin(el.shadowRoot, depth + 1);
                            if (found) return found;
                        }
                    }
                    return null;
                }
                return findAndClickMcLovin(document) || {found: false};
            }
        """)
        log(f"Click result: {click_result}")

        if click_result.get('found'):
            log("Clicked mcLOVIN button!")
            await page.wait_for_timeout(3000)
            await screenshot(page, "mclovin_04_after_click.png", "After clicking mcLOVIN button")
        else:
            log("mcLOVIN button NOT found via shadow DOM search")
            # Try the utility bar area at the bottom of the screen
            await screenshot(page, "mclovin_04_no_button.png", "mcLOVIN button not found")

            # Try to find it via App Launcher instead
            log("Trying App Launcher to navigate to Outdoor Living ...")
            try:
                launcher = page.locator("button[title='App Launcher'], [aria-label='App Launcher']").first
                if await launcher.count() > 0:
                    log("Found App Launcher")
                    await launcher.click()
                    await page.wait_for_timeout(3000)
                    await screenshot(page, "mclovin_04b_launcher.png", "App Launcher opened")

                    # Search for the app
                    search = page.locator("input[placeholder*='Search'], input[placeholder*='search']").first
                    if await search.count() > 0:
                        await search.fill("Outdoor Living")
                        await page.wait_for_timeout(2000)
                        await screenshot(page, "mclovin_04c_search.png", "Searching for Outdoor Living")

                        # Click the app
                        app_link = page.get_by_text("Outdoor Living").first
                        if await app_link.count() > 0:
                            await app_link.click()
                            await page.wait_for_timeout(15000)
                            await screenshot(page, "mclovin_04d_app_opened.png", "Outdoor Living app opened via launcher")
                else:
                    log("App Launcher button not found")
            except Exception as e:
                log(f"App Launcher failed: {e}")

        # ── STEP 5: Look for floating badge ──────────────────────────────────
        log("Step 5: Looking for floating badge ...")
        await page.wait_for_timeout(3000)

        badge_info = await page.evaluate("""
            () => {
                function findBadge(root, depth=0) {
                    if (depth > 8) return [];
                    const results = [];
                    const els = root.querySelectorAll('*');
                    for (const el of els) {
                        const style = window.getComputedStyle(el);
                        if ((style.position === 'fixed' || style.position === 'absolute') &&
                            el.offsetWidth > 20 && el.offsetHeight > 20) {
                            const rect = el.getBoundingClientRect();
                            results.push({
                                tag: el.tagName,
                                id: el.id.substring(0, 40),
                                className: el.className.substring(0, 100),
                                text: el.textContent.trim().substring(0, 50),
                                x: Math.round(rect.x), y: Math.round(rect.y),
                                w: el.offsetWidth, h: el.offsetHeight,
                                position: style.position
                            });
                        }
                        if (el.shadowRoot) {
                            results.push(...findBadge(el.shadowRoot, depth + 1));
                        }
                    }
                    return results;
                }
                return findBadge(document).slice(0, 30);
            }
        """)
        log(f"Floating/absolute elements ({len(badge_info)}): {badge_info}")
        await screenshot(page, "mclovin_05_badge_check.png", "Badge check")

        # Try clicking any floating element that might be the badge
        badge_clicked = False
        for elem in badge_info:
            if 20 < elem['w'] < 200 and 20 < elem['h'] < 200:
                text = (elem.get('text') or '').lower()
                cls = (elem.get('className') or '').lower()
                if 'mclovin' in text or 'mclovin' in cls or 'assistant' in cls or 'badge' in cls or 'avatar' in cls:
                    log(f"Clicking potential badge at ({elem['x']}, {elem['y']}): {elem}")
                    await page.mouse.click(elem['x'] + elem['w']//2, elem['y'] + elem['h']//2)
                    badge_clicked = True
                    await page.wait_for_timeout(2000)
                    await screenshot(page, "mclovin_05b_badge_clicked.png", "After clicking badge")
                    break

        # ── STEP 6: Look for panel and text input ────────────────────────────
        log("Step 6: Looking for AI panel and text input ...")

        panel_result = await page.evaluate("""
            () => {
                function findInputs(root, depth=0) {
                    if (depth > 8) return [];
                    const results = [];
                    const inputs = root.querySelectorAll('input[type="text"], textarea, [contenteditable="true"]');
                    for (const inp of inputs) {
                        if (inp.offsetParent !== null || window.getComputedStyle(inp).display !== 'none') {
                            results.push({
                                tag: inp.tagName,
                                type: inp.type || '',
                                placeholder: inp.placeholder || inp.getAttribute('placeholder') || '',
                                className: inp.className.substring(0, 80),
                                visible: inp.offsetParent !== null,
                                rect: {
                                    x: Math.round(inp.getBoundingClientRect().x),
                                    y: Math.round(inp.getBoundingClientRect().y),
                                    w: inp.offsetWidth,
                                    h: inp.offsetHeight
                                }
                            });
                        }
                        if (inp.shadowRoot) {
                            results.push(...findInputs(inp.shadowRoot, depth + 1));
                        }
                    }
                    for (const el of root.querySelectorAll('*')) {
                        if (el.shadowRoot) {
                            results.push(...findInputs(el.shadowRoot, depth + 1));
                        }
                    }
                    return results;
                }
                return findInputs(document);
            }
        """)
        log(f"Input fields found ({len(panel_result)}): {panel_result}")

        typed_question = False
        for inp in panel_result:
            ph = (inp.get('placeholder') or '').lower()
            cls = (inp.get('className') or '').lower()
            visible = inp.get('visible')
            rect = inp.get('rect', {})
            if visible and rect.get('w', 0) > 0 and rect.get('h', 0) > 0:
                if 'search' not in ph or 'ask' in ph or 'question' in ph or 'type' in ph or 'message' in ph:
                    x = rect['x'] + rect['w'] // 2
                    y = rect['y'] + rect['h'] // 2
                    if 0 < x < 1440 and 0 < y < 900:
                        log(f"Clicking input at ({x}, {y}): {inp}")
                        await page.mouse.click(x, y)
                        await page.wait_for_timeout(500)
                        await page.keyboard.type("how do I create a new account")
                        await page.wait_for_timeout(500)
                        await screenshot(page, "mclovin_06_typed_question.png", "Question typed")
                        await page.keyboard.press("Enter")
                        typed_question = True
                        break

        if typed_question:
            log("Waiting up to 15 seconds for response ...")
            await page.wait_for_timeout(15000)
            await screenshot(page, "mclovin_07_ai_response.png", "AI response")
        else:
            log("No suitable text input found")
            await screenshot(page, "mclovin_06_no_input.png", "No input found")

        # ── STEP 7: Try Upload PO chip ────────────────────────────────────────
        log("Step 7: Looking for 'Upload PO' chip ...")

        chip_result = await page.evaluate("""
            () => {
                function findChips(root, depth=0) {
                    if (depth > 8) return [];
                    const results = [];
                    const els = root.querySelectorAll('button, [role="button"], span, a, div');
                    for (const el of els) {
                        const text = (el.textContent || '').trim();
                        if (text.toLowerCase().includes('upload po') || text.toLowerCase() === 'upload po') {
                            const rect = el.getBoundingClientRect();
                            results.push({
                                tag: el.tagName,
                                text: text.substring(0, 50),
                                x: Math.round(rect.x), y: Math.round(rect.y),
                                w: el.offsetWidth, h: el.offsetHeight,
                                visible: el.offsetParent !== null
                            });
                        }
                        if (el.shadowRoot) {
                            results.push(...findChips(el.shadowRoot, depth + 1));
                        }
                    }
                    return results;
                }
                return findChips(document);
            }
        """)
        log(f"Upload PO chips found: {chip_result}")

        chip_clicked = False
        for chip in chip_result:
            if chip.get('visible') or (chip.get('w', 0) > 0 and chip.get('h', 0) > 0):
                x = chip['x'] + chip['w'] // 2
                y = chip['y'] + chip['h'] // 2
                if 0 < x < 1440 and 0 < y < 900:
                    log(f"Clicking Upload PO at ({x}, {y})")
                    await page.mouse.click(x, y)
                    chip_clicked = True
                    await page.wait_for_timeout(15000)
                    await screenshot(page, "mclovin_08_upload_po.png", "Upload PO chip response")
                    break

        if not chip_clicked:
            log("Upload PO chip not found")
            await screenshot(page, "mclovin_08_no_chip.png", "No chip found")

        # ── STEP 8: Try minimize ──────────────────────────────────────────────
        log("Step 8: Looking for minimize/close button ...")

        minimize_result = await page.evaluate("""
            () => {
                function findClose(root, depth=0) {
                    if (depth > 8) return [];
                    const results = [];
                    const els = root.querySelectorAll('button, [role="button"]');
                    for (const el of els) {
                        const text = (el.textContent || '').trim().toLowerCase();
                        const title = (el.getAttribute('title') || '').toLowerCase();
                        const aria = (el.getAttribute('aria-label') || '').toLowerCase();
                        if (text === '×' || text === '✕' || text === 'x' || text === '—' ||
                            title.includes('close') || title.includes('minimize') || title.includes('collapse') ||
                            aria.includes('close') || aria.includes('minimize') || aria.includes('collapse')) {
                            const rect = el.getBoundingClientRect();
                            const style = window.getComputedStyle(el);
                            const isHidden = style.display === 'none' || style.visibility === 'hidden';
                            if (!isHidden && rect.width > 0) {
                                results.push({
                                    tag: el.tagName, text: el.textContent.trim().substring(0, 20),
                                    title, aria, x: Math.round(rect.x), y: Math.round(rect.y),
                                    w: el.offsetWidth, h: el.offsetHeight
                                });
                            }
                        }
                        if (el.shadowRoot) {
                            results.push(...findClose(el.shadowRoot, depth + 1));
                        }
                    }
                    return results;
                }
                return findClose(document);
            }
        """)
        log(f"Close/minimize buttons: {minimize_result}")

        minimized = False
        for btn in minimize_result:
            x = btn['x'] + btn['w'] // 2
            y = btn['y'] + btn['h'] // 2
            if 0 < x < 1440 and 0 < y < 900:
                log(f"Clicking minimize at ({x}, {y}): {btn}")
                await page.mouse.click(x, y)
                minimized = True
                await page.wait_for_timeout(2000)
                await screenshot(page, "mclovin_09_minimized.png", "After minimize")
                break

        if not minimized:
            await screenshot(page, "mclovin_09_no_minimize.png", "No minimize button found")

        # ── STEP 9: Test drag ─────────────────────────────────────────────────
        log("Step 9: Testing drag ...")

        # Find any fixed/floating element to drag
        drag_candidates = await page.evaluate("""
            () => {
                function findDraggable(root, depth=0) {
                    if (depth > 8) return [];
                    const results = [];
                    const els = root.querySelectorAll('*');
                    for (const el of els) {
                        const style = window.getComputedStyle(el);
                        if (style.position === 'fixed' && el.offsetWidth > 30 && el.offsetWidth < 300) {
                            const rect = el.getBoundingClientRect();
                            const text = (el.textContent || '').trim().toLowerCase();
                            if (text.includes('mclovin') || el.className.toLowerCase().includes('mclovin') ||
                                el.className.toLowerCase().includes('assistant') ||
                                el.className.toLowerCase().includes('badge') ||
                                el.className.toLowerCase().includes('float')) {
                                results.push({
                                    tag: el.tagName,
                                    className: el.className.substring(0, 80),
                                    x: Math.round(rect.x), y: Math.round(rect.y),
                                    w: el.offsetWidth, h: el.offsetHeight
                                });
                            }
                        }
                        if (el.shadowRoot) {
                            results.push(...findDraggable(el.shadowRoot, depth + 1));
                        }
                    }
                    return results;
                }
                return findDraggable(document);
            }
        """)
        log(f"Drag candidates: {drag_candidates}")

        if drag_candidates:
            cand = drag_candidates[0]
            sx = cand['x'] + cand['w'] // 2
            sy = cand['y'] + cand['h'] // 2
            ex = max(100, sx - 200)
            ey = max(100, sy - 100)
            log(f"Dragging from ({sx},{sy}) to ({ex},{ey})")
            await page.mouse.move(sx, sy)
            await page.mouse.down()
            await page.wait_for_timeout(500)
            await page.mouse.move(sx - 50, sy - 25, steps=5)
            await page.mouse.move(ex, ey, steps=20)
            await page.wait_for_timeout(500)
            await page.mouse.up()
            await page.wait_for_timeout(1000)
            await screenshot(page, "mclovin_10_after_drag.png", "After drag")
        else:
            log("No drag candidates found")
            await screenshot(page, "mclovin_10_no_drag.png", "No drag targets")

        # ── Final ─────────────────────────────────────────────────────────────
        await screenshot(page, "mclovin_11_final.png", "Final state")
        log("All tests complete!")
        await browser.close()

if __name__ == "__main__":
    os.environ["DISPLAY"] = ":99"
    asyncio.run(main())
