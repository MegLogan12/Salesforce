#!/usr/bin/env python3
"""
Final Playwright test for the 'Ask mcLOVIN'' floating AI assistant.
Uses @salesforce/core to get fresh session, then precisely clicks the utility bar button.
"""

import os
import sys
import time
import json
import asyncio
import subprocess
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots"
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

async def screenshot(page, name, desc=""):
    path = f"{SCREENSHOTS_DIR}/{name}"
    await page.screenshot(path=path, full_page=False)
    log(f"Screenshot: {name} — {desc}")
    return path

def get_fresh_frontdoor_url(retURL=""):
    js = f"""
const {{ AuthInfo }} = require('/opt/node22/lib/node_modules/@salesforce/cli/node_modules/@salesforce/core');
async function main() {{
    const auth = await AuthInfo.create({{ username: 'megan.logan@thelovingcompanies.com' }});
    let url = await auth.getOrgFrontDoorUrl();
    if ('{retURL}') url += '&retURL={retURL}';
    process.stdout.write(url + '\\n');
}}
main().catch(e => {{ process.stderr.write(e.message + '\\n'); process.exit(1); }});
"""
    r = subprocess.run(["node", "-e", js], capture_output=True, text=True, timeout=15)
    if r.returncode != 0:
        raise RuntimeError(f"Failed: {r.stderr}")
    return r.stdout.strip()

async def main():
    log("Getting fresh Salesforce session URL ...")
    frontdoor_url = get_fresh_frontdoor_url(retURL="/lightning/n/Home")
    log(f"Got URL: {frontdoor_url[:80]}...")

    async with async_playwright() as p:
        log("Launching Chromium 1440x900 ...")
        browser = await p.chromium.launch(
            headless=False,
            args=["--no-sandbox", "--disable-setuid-sandbox",
                  "--disable-dev-shm-usage", "--disable-gpu",
                  "--window-size=1440,900"],
        )
        context = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )
        page = await context.new_page()

        # ── STEP 1: Login ─────────────────────────────────────────────────────
        log("Step 1: Logging into Salesforce ...")
        await page.goto(frontdoor_url, timeout=60000, wait_until="domcontentloaded")
        await page.wait_for_timeout(5000)
        log(f"URL after login: {page.url}")
        await screenshot(page, "mclovin_01_utility_bar.png",
                         "After login — utility bar visible at bottom")

        if "login" in page.url.lower() and "lightning" not in page.url:
            log("ERROR: Still on login page — session may have expired")
            await browser.close()
            return

        log(f"Logged in! Title: {await page.title()}")

        # ── STEP 2: Navigate to Outdoor Living app ────────────────────────────
        log("Step 2: Navigating to Outdoor Living app via App Launcher ...")

        # Try to use App Launcher to find Outdoor Living
        try:
            # Click the 9-dot waffle icon (App Launcher)
            launcher_btn = page.locator("button[title='App Launcher']").first
            if await launcher_btn.count() > 0:
                log("Clicking App Launcher ...")
                await launcher_btn.click()
                await page.wait_for_timeout(3000)
                await screenshot(page, "mclovin_01b_app_launcher.png", "App Launcher opened")

                # Search for Outdoor Living
                search = page.locator("input[type='search'], input[placeholder*='Search']").first
                if await search.count() > 0:
                    await search.fill("Outdoor Living")
                    await page.wait_for_timeout(2000)
                    await screenshot(page, "mclovin_01c_search.png", "Searched for Outdoor Living")

                    # Click the app link
                    app_link = page.get_by_text("Outdoor Living", exact=True).first
                    if await app_link.count() > 0:
                        await app_link.click()
                        await page.wait_for_timeout(8000)
                        log(f"Navigated to Outdoor Living. URL: {page.url}")
                    else:
                        log("Outdoor Living not found in search results — pressing Escape")
                        await page.keyboard.press("Escape")
            else:
                log("App Launcher button not found")
        except Exception as e:
            log(f"App Launcher failed: {e}")
            try:
                await page.keyboard.press("Escape")
            except:
                pass

        await screenshot(page, "mclovin_02_app_loaded.png", "App loaded state")

        # ── STEP 3: Full page screenshot showing utility bar ─────────────────
        log("Step 3: Full page screenshot — checking utility bar ...")
        await page.wait_for_timeout(3000)
        await screenshot(page, "mclovin_03_utility_bar_visible.png",
                         "Full page — utility bar should be at bottom")

        # Get exact position of the mcLOVIN' button in the utility bar
        btn_pos = await page.evaluate("""
            () => {
                // Find the utility bar button specifically
                const utilBar = document.querySelector('.slds-utility-bar, .utilitybar');
                if (!utilBar) return {found: false, reason: 'no utility bar'};

                const buttons = utilBar.querySelectorAll('button');
                for (const btn of buttons) {
                    const text = btn.textContent.trim().toLowerCase();
                    const title = (btn.getAttribute('title') || '').toLowerCase();
                    const aria = (btn.getAttribute('aria-label') || '').toLowerCase();
                    if (text.includes('mclovin') || title.includes('mclovin') || aria.includes('mclovin')) {
                        const rect = btn.getBoundingClientRect();
                        return {
                            found: true,
                            x: Math.round(rect.x + rect.width/2),
                            y: Math.round(rect.y + rect.height/2),
                            w: rect.width, h: rect.height,
                            text: btn.textContent.trim(),
                            title: title
                        };
                    }
                }

                // Also check parent elements
                const items = utilBar.querySelectorAll('.slds-utility-bar__item, .slds-utility-bar__action, .utilityBarButton');
                const result = [];
                for (const item of items) {
                    const rect = item.getBoundingClientRect();
                    result.push({
                        tag: item.tagName, text: item.textContent.trim().substring(0, 40),
                        x: Math.round(rect.x), y: Math.round(rect.y),
                        w: Math.round(rect.width), h: Math.round(rect.height)
                    });
                }
                return {found: false, utilBarItems: result, utilBarHTML: utilBar.innerHTML.substring(0, 500)};
            }
        """)
        log(f"Button position result: {btn_pos}")

        # ── STEP 4: Click the mcLOVIN' utility bar button ────────────────────
        log("Step 4: Clicking the mcLOVIN' utility bar button ...")
        clicked = False

        if btn_pos.get('found'):
            x, y = btn_pos['x'], btn_pos['y']
            log(f"Found mcLOVIN' button at ({x}, {y}). Clicking ...")
            await page.mouse.click(x, y)
            clicked = True
        else:
            # The utility bar is at y≈870 based on previous runs. Let's scan
            log("Scanning bottom of screen for mcLOVIN' button ...")
            util_items = btn_pos.get('utilBarItems', [])
            log(f"Utility bar items: {util_items}")

            # Try clicking each item to find mcLOVIN'
            for item in util_items:
                text = (item.get('text') or '').lower()
                if 'mclovin' in text:
                    x = item['x'] + item['w'] // 2
                    y = item['y'] + item['h'] // 2
                    if 0 < x < 1440 and 0 < y < 900:
                        log(f"Clicking utility bar item '{item['text']}' at ({x},{y})")
                        await page.mouse.click(x, y)
                        clicked = True
                        break

            if not clicked:
                # Last resort: click at the bottom-left area of the screen
                log("Trying direct coordinate click at bottom of screen ...")
                # Utility bar is at y=860 based on the fixed elements we found earlier
                # mcLOVIN' is the first item
                await page.mouse.click(70, 870)
                clicked = True
                log("Clicked at (70, 870) — utility bar area")

        await page.wait_for_timeout(3000)
        await screenshot(page, "mclovin_04_badge_appears.png",
                         "After clicking mcLOVIN' button — badge should appear")

        # Check what appeared after clicking
        after_click = await page.evaluate("""
            () => {
                // Look for the mcLOVIN panel/dialog that appeared
                const result = {panels: [], dialogs: [], chatbox: null, badgeEl: null};

                // Docking panels that may have appeared
                const docked = document.querySelectorAll('[class*="docked"], [class*="Docked"]');
                for (const d of docked) {
                    if (d.offsetWidth > 0 && d.offsetHeight > 0) {
                        result.panels.push({
                            className: d.className.substring(0, 80),
                            visible: d.offsetParent !== null,
                            text: d.textContent.trim().substring(0, 100)
                        });
                    }
                }

                // Dialog/panel
                const dialogs = document.querySelectorAll('[role="dialog"], [class*="panel"]');
                for (const d of dialogs) {
                    if (d.offsetWidth > 0) {
                        result.dialogs.push({text: d.textContent.trim().substring(0, 100)});
                    }
                }

                // Chat box input
                const chatbox = document.querySelector('.chat-box, [class*="chat"], textarea[placeholder*="ask"], textarea[placeholder*="question"]');
                if (chatbox) {
                    const rect = chatbox.getBoundingClientRect();
                    result.chatbox = {visible: chatbox.offsetParent !== null, x: rect.x, y: rect.y};
                }

                // Check if the mcLOVIN character panel is visible
                const mclovinPanel = document.querySelector('[data-component-id*="mcLovin"], [class*="mcLovin"], [class*="mclovin"]');
                if (mclovinPanel) {
                    result.badgeEl = {
                        tag: mclovinPanel.tagName,
                        className: mclovinPanel.className.substring(0, 80),
                        text: mclovinPanel.textContent.trim().substring(0, 100)
                    };
                }

                return result;
            }
        """)
        log(f"After click analysis: {after_click}")

        # ── STEP 5: Click the badge to open full panel ────────────────────────
        log("Step 5: Looking for floating badge character ...")

        # Find the floating character badge (round head image)
        badge_pos = await page.evaluate("""
            () => {
                // The badge should be a fixed element that appeared after clicking utility bar
                // It might be an img or a div with background-image
                const candidates = [];
                const all = document.querySelectorAll('img, [class*="badge"], [class*="avatar"], [class*="character"]');
                for (const el of all) {
                    const style = window.getComputedStyle(el);
                    const rect = el.getBoundingClientRect();
                    if (rect.width > 20 && rect.width < 200 && rect.height > 20 &&
                        (style.position === 'fixed' || style.position === 'absolute') &&
                        rect.y > 0) {
                        candidates.push({
                            tag: el.tagName,
                            src: el.getAttribute('src') || '',
                            className: el.className.substring(0, 80),
                            x: Math.round(rect.x + rect.width/2),
                            y: Math.round(rect.y + rect.height/2),
                            w: rect.width, h: rect.height
                        });
                    }
                }

                // Also look for the docking panel that should show
                const dockedPanels = document.querySelectorAll('[class*="forceDockingPanel"], [class*="dockingPanel"]');
                const panelInfo = [];
                for (const p of dockedPanels) {
                    const rect = p.getBoundingClientRect();
                    panelInfo.push({
                        tag: p.tagName,
                        className: p.className.substring(0, 80),
                        visible: p.offsetParent !== null || window.getComputedStyle(p).display !== 'none',
                        text: p.textContent.trim().substring(0, 100),
                        x: Math.round(rect.x), y: Math.round(rect.y),
                        w: rect.width, h: rect.height
                    });
                }

                return {imageCandidates: candidates, dockedPanels: panelInfo};
            }
        """)
        log(f"Badge search: {badge_pos}")

        # Check if a docked panel appeared
        for panel in badge_pos.get('dockedPanels', []):
            if panel.get('visible') and panel.get('w', 0) > 0:
                log(f"Docked panel visible: {panel}")

        # Look for the mcLOVIN badge that should appear
        # Based on the component, it uses a floating DIV with a character image
        # Let's check what the component renders by looking at the LWC shadow DOM
        panel_content = await page.evaluate("""
            () => {
                // Walk through the utility bar component to find what's rendered
                const compEl = document.querySelector('[data-component-id="c_mcLovinEmployeeAgentWorkspace"]');
                if (!compEl) return {found: false, reason: 'component not found'};

                // Get all shadow DOM content
                function getShadowContent(el, depth=0) {
                    if (depth > 10) return '';
                    let content = el.innerHTML || '';
                    for (const child of el.querySelectorAll('*')) {
                        if (child.shadowRoot) {
                            content += '\\n[SHADOW ' + child.tagName + ']:\\n' + getShadowContent(child.shadowRoot, depth+1);
                        }
                    }
                    return content.substring(0, 2000);
                }

                return {
                    found: true,
                    outerHTML: compEl.outerHTML.substring(0, 200),
                    shadowContent: getShadowContent(compEl)
                };
            }
        """)
        log(f"Panel LWC content: {panel_content}")

        # Check for the Aura component that handles the mcLOVIN panel
        # The panel might be in a separate Aura overlay
        overlay_info = await page.evaluate("""
            () => {
                // Check for Aura overlays/modals
                const overlays = document.querySelectorAll(
                    '.slds-docked-composer, [class*="docked-composer"], ' +
                    '.modal-container, [class*="modal-container"], ' +
                    '[aria-live], [data-aura-class*="docking"]'
                );
                const result = [];
                for (const ov of overlays) {
                    const rect = ov.getBoundingClientRect();
                    if (rect.width > 50) {
                        result.push({
                            tag: ov.tagName,
                            className: ov.className.substring(0, 80),
                            text: ov.textContent.trim().substring(0, 80),
                            x: Math.round(rect.x), y: Math.round(rect.y),
                            w: rect.width, h: rect.height,
                            display: window.getComputedStyle(ov).display
                        });
                    }
                }

                // Also check the body for any injected elements
                const bodyChildren = Array.from(document.body.children).map(el => ({
                    tag: el.tagName,
                    id: el.id,
                    className: el.className.substring(0, 60),
                    visible: el.offsetWidth > 0
                }));

                return {overlays: result, bodyChildren: bodyChildren.slice(0, 20)};
            }
        """)
        log(f"Overlay info: {overlay_info}")

        await screenshot(page, "mclovin_05_panel_check.png", "Panel check after clicking")

        # ── Now directly click the utility bar button at precise position ─────
        # From the previous run, the utility bar is at y≈860, and mcLOVIN' is the first item
        # The utility bar HTML showed: <button class="bare slds-button slds-utility-bar__action utilityBarButton"
        # Let's get the exact position

        log("Getting precise button location ...")
        precise_pos = await page.evaluate("""
            () => {
                // Find ALL buttons in the utility bar
                const utilBar = document.querySelector('.slds-utility-bar');
                if (!utilBar) return {error: 'no utility bar found'};

                const allBtns = utilBar.querySelectorAll('button');
                const btnList = [];
                for (const btn of allBtns) {
                    const rect = btn.getBoundingClientRect();
                    btnList.push({
                        text: btn.textContent.trim().substring(0, 40),
                        title: btn.getAttribute('title'),
                        aria: btn.getAttribute('aria-label'),
                        x: Math.round(rect.x), y: Math.round(rect.y),
                        w: Math.round(rect.width), h: Math.round(rect.height),
                        cx: Math.round(rect.x + rect.width/2),
                        cy: Math.round(rect.y + rect.height/2)
                    });
                }
                return {buttons: btnList, utilBarRect: utilBar.getBoundingClientRect()};
            }
        """)
        log(f"Precise button positions: {precise_pos}")

        mclovin_btn = None
        if 'buttons' in precise_pos:
            for btn in precise_pos['buttons']:
                text = (btn.get('text') or '').lower()
                if 'mclovin' in text:
                    mclovin_btn = btn
                    log(f"Found mcLOVIN' button at cx={btn['cx']}, cy={btn['cy']}")
                    break

        if mclovin_btn:
            cx, cy = mclovin_btn['cx'], mclovin_btn['cy']
            log(f"Step 4 (retry): Clicking mcLOVIN' at ({cx}, {cy}) ...")
            await page.mouse.click(cx, cy)
            await page.wait_for_timeout(3000)
            await screenshot(page, "mclovin_04_retry_click.png",
                             "After precise click on mcLOVIN' utility bar button")

            # Check what the button click did
            post_click = await page.evaluate("""
                () => {
                    // Check if a panel/overlay is now visible
                    const allVisible = [];
                    const all = document.querySelectorAll('*');
                    for (const el of all) {
                        const rect = el.getBoundingClientRect();
                        const style = window.getComputedStyle(el);
                        if (rect.width > 100 && rect.width < 800 &&
                            rect.height > 100 && rect.height < 800 &&
                            (style.position === 'fixed' || style.position === 'absolute') &&
                            rect.y > 50 && rect.y < 850) {
                            allVisible.push({
                                tag: el.tagName,
                                className: el.className.substring(0, 60),
                                text: el.textContent.trim().substring(0, 80),
                                x: Math.round(rect.x), y: Math.round(rect.y),
                                w: Math.round(rect.width), h: Math.round(rect.height)
                            });
                        }
                    }
                    return allVisible.slice(0, 15);
                }
            """)
            log(f"Elements after precise click: {post_click}")

            # Wait longer and take another screenshot
            await page.wait_for_timeout(5000)
            await screenshot(page, "mclovin_05_badge_appears.png",
                             "5 seconds after clicking — badge should be visible")

            # Now look for the floating badge character to click
            badge_click_result = await page.evaluate("""
                () => {
                    // Find the floating badge/character image
                    function findBadge(root, depth=0) {
                        if (depth > 10) return null;
                        const imgs = root.querySelectorAll('img');
                        for (const img of imgs) {
                            const src = img.getAttribute('src') || '';
                            const alt = img.getAttribute('alt') || '';
                            const style = window.getComputedStyle(img);
                            if (style.position === 'fixed' && img.offsetWidth > 30) {
                                const rect = img.getBoundingClientRect();
                                return {tag: 'IMG', src: src.substring(0, 80),
                                        x: Math.round(rect.x + rect.width/2),
                                        y: Math.round(rect.y + rect.height/2),
                                        w: img.offsetWidth, h: img.offsetHeight};
                            }
                        }
                        // Check LWC components
                        const lwcEls = root.querySelectorAll('c-mc-lovin-employee-agent-workspace, c-mc-lovin, [data-component-id*="mcLovin"]');
                        for (const el of lwcEls) {
                            if (el.shadowRoot) {
                                const inner = findBadge(el.shadowRoot, depth+1);
                                if (inner) return inner;
                            }
                        }
                        // Check all shadow roots
                        for (const el of root.querySelectorAll('*')) {
                            if (el.shadowRoot) {
                                const inner = findBadge(el.shadowRoot, depth+1);
                                if (inner) return inner;
                            }
                        }
                        return null;
                    }
                    return findBadge(document);
                }
            """)
            log(f"Badge element search result: {badge_click_result}")

            if badge_click_result:
                x, y = badge_click_result['x'], badge_click_result['y']
                log(f"Step 5: Clicking badge at ({x}, {y}) ...")
                await page.mouse.click(x, y)
                await page.wait_for_timeout(3000)
                await screenshot(page, "mclovin_06_panel_opened.png",
                                 "After clicking badge — full panel should open")
            else:
                log("No badge image found — checking what's visible now ...")
                await screenshot(page, "mclovin_05b_no_badge.png", "Badge not found in shadow DOM")

        # ── STEP 6: Try to interact with the AI panel ─────────────────────────
        log("Step 6: Looking for AI panel input and typing question ...")

        # Look for the chat input textarea
        chat_input = await page.evaluate("""
            () => {
                function findInput(root, depth=0) {
                    if (depth > 10) return null;
                    const inputs = root.querySelectorAll('textarea, input[type="text"], [contenteditable="true"]');
                    for (const inp of inputs) {
                        const placeholder = inp.placeholder || inp.getAttribute('placeholder') || '';
                        const visible = inp.offsetParent !== null || window.getComputedStyle(inp).display !== 'none';
                        const rect = inp.getBoundingClientRect();
                        if (rect.width > 50) {
                            return {
                                tag: inp.tagName,
                                placeholder: placeholder,
                                visible: visible,
                                x: Math.round(rect.x + rect.width/2),
                                y: Math.round(rect.y + rect.height/2),
                                w: rect.width, h: rect.height
                            };
                        }
                    }
                    for (const el of root.querySelectorAll('*')) {
                        if (el.shadowRoot) {
                            const found = findInput(el.shadowRoot, depth+1);
                            if (found) return found;
                        }
                    }
                    return null;
                }
                return findInput(document);
            }
        """)
        log(f"Chat input found: {chat_input}")

        if chat_input and chat_input.get('w', 0) > 50:
            x = chat_input['x']
            y = chat_input['y']
            if 0 < x < 1440 and 0 < y < 900:
                log(f"Clicking and typing into input at ({x}, {y}) ...")
                await page.mouse.click(x, y)
                await page.wait_for_timeout(500)
                await page.keyboard.type("how do I create a new account")
                await page.wait_for_timeout(500)
                await screenshot(page, "mclovin_07_question_typed.png",
                                 "Question typed in AI input")
                await page.keyboard.press("Enter")
                log("Waiting 15s for AI response ...")
                await page.wait_for_timeout(15000)
                await screenshot(page, "mclovin_08_ai_response.png",
                                 "AI response to 'how do I create a new account'")
            else:
                log(f"Input position out of viewport: ({x}, {y})")
                await screenshot(page, "mclovin_07_input_offscreen.png", "Input out of viewport")
        else:
            log("No chat input found — taking current state screenshot")
            await screenshot(page, "mclovin_07_no_input.png", "No chat input found")

        # ── STEP 7: Try Upload PO chip ────────────────────────────────────────
        log("Step 7: Looking for quick-action chips ...")

        chips = await page.evaluate("""
            () => {
                function findChips(root, depth=0) {
                    if (depth > 10) return [];
                    const result = [];
                    const els = root.querySelectorAll('[class*="chip"], [class*="quick"], button, [role="button"]');
                    for (const el of els) {
                        const text = (el.textContent || '').trim();
                        if (text.length > 2 && text.length < 30 && el.offsetWidth > 0) {
                            const rect = el.getBoundingClientRect();
                            if (rect.y > 400) {  // Only look in lower half of screen
                                result.push({
                                    text: text,
                                    x: Math.round(rect.x + rect.width/2),
                                    y: Math.round(rect.y + rect.height/2),
                                    w: rect.width, h: rect.height
                                });
                            }
                        }
                        if (el.shadowRoot) {
                            result.push(...findChips(el.shadowRoot, depth+1));
                        }
                    }
                    return result;
                }
                return findChips(document).slice(0, 20);
            }
        """)
        log(f"Chips/buttons in lower half: {chips}")

        upload_po_clicked = False
        for chip in chips:
            if 'upload po' in chip['text'].lower():
                x, y = chip['x'], chip['y']
                if 0 < x < 1440 and 0 < y < 900:
                    log(f"Clicking 'Upload PO' at ({x}, {y})")
                    await page.mouse.click(x, y)
                    upload_po_clicked = True
                    await page.wait_for_timeout(15000)
                    await screenshot(page, "mclovin_09_upload_po_response.png",
                                     "Response after clicking Upload PO chip")
                    break

        if not upload_po_clicked:
            log("Upload PO chip not found")
            await screenshot(page, "mclovin_09_no_upload_po.png", "Upload PO not found")

        # ── STEP 8: Try minimize ──────────────────────────────────────────────
        log("Step 8: Looking for minimize button ...")

        minimize = await page.evaluate("""
            () => {
                function findMinimize(root, depth=0) {
                    if (depth > 10) return null;
                    const btns = root.querySelectorAll('button, [role="button"]');
                    for (const btn of btns) {
                        const title = (btn.getAttribute('title') || '').toLowerCase();
                        const aria = (btn.getAttribute('aria-label') || '').toLowerCase();
                        const text = (btn.textContent || '').trim();
                        if (title === 'minimize' || aria === 'minimize' ||
                            title.includes('minimize') || aria.includes('minimize')) {
                            const rect = btn.getBoundingClientRect();
                            if (rect.width > 0 && rect.y > 400) {
                                return {
                                    x: Math.round(rect.x + rect.width/2),
                                    y: Math.round(rect.y + rect.height/2),
                                    title: title, text: text.substring(0, 20)
                                };
                            }
                        }
                        if (btn.shadowRoot) {
                            const found = findMinimize(btn.shadowRoot, depth+1);
                            if (found) return found;
                        }
                    }
                    for (const el of root.querySelectorAll('*')) {
                        if (el.shadowRoot) {
                            const found = findMinimize(el.shadowRoot, depth+1);
                            if (found) return found;
                        }
                    }
                    return null;
                }
                return findMinimize(document);
            }
        """)
        log(f"Minimize button: {minimize}")

        if minimize:
            x, y = minimize['x'], minimize['y']
            if 0 < x < 1440 and 0 < y < 900:
                log(f"Clicking minimize at ({x}, {y})")
                await page.mouse.click(x, y)
                await page.wait_for_timeout(2000)
                await screenshot(page, "mclovin_10_minimized.png",
                                 "After minimize — badge should return to badge state")
        else:
            log("No minimize button found")
            await screenshot(page, "mclovin_10_no_minimize.png", "Minimize not found")

        # ── STEP 9: Test drag ─────────────────────────────────────────────────
        log("Step 9: Testing drag of floating element ...")

        drag_target = await page.evaluate("""
            () => {
                // Find fixed element that could be dragged (the badge)
                function findDraggable(root, depth=0) {
                    if (depth > 10) return null;
                    const all = root.querySelectorAll('*');
                    for (const el of all) {
                        const style = window.getComputedStyle(el);
                        const rect = el.getBoundingClientRect();
                        if (style.position === 'fixed' && rect.width > 30 && rect.width < 200 &&
                            rect.height > 30 && rect.height < 200 &&
                            rect.y > 100 && rect.y < 800) {
                            const className = el.className.toLowerCase();
                            if (className.includes('badge') || className.includes('avatar') ||
                                className.includes('mclovin') || className.includes('float') ||
                                el.draggable) {
                                return {
                                    x: Math.round(rect.x + rect.width/2),
                                    y: Math.round(rect.y + rect.height/2),
                                    w: rect.width, h: rect.height,
                                    className: el.className.substring(0, 60)
                                };
                            }
                        }
                        if (el.shadowRoot) {
                            const found = findDraggable(el.shadowRoot, depth+1);
                            if (found) return found;
                        }
                    }
                    return null;
                }
                return findDraggable(document);
            }
        """)
        log(f"Drag target: {drag_target}")

        if drag_target:
            sx, sy = drag_target['x'], drag_target['y']
            ex = max(100, sx - 200)
            ey = max(200, sy - 100)
            log(f"Dragging from ({sx},{sy}) to ({ex},{ey})")
            await page.mouse.move(sx, sy)
            await page.mouse.down()
            await page.wait_for_timeout(300)
            # Slow drag
            steps = 20
            for i in range(steps):
                t = (i+1) / steps
                nx = int(sx + (ex - sx) * t)
                ny = int(sy + (ey - sy) * t)
                await page.mouse.move(nx, ny)
                await page.wait_for_timeout(30)
            await page.mouse.up()
            await page.wait_for_timeout(1000)
            await screenshot(page, "mclovin_11_after_drag.png",
                             f"After drag from ({sx},{sy}) to ({ex},{ey})")
        else:
            log("No draggable badge found")
            await screenshot(page, "mclovin_11_no_drag.png", "No drag target found")

        # ── Final screenshot ───────────────────────────────────────────────────
        await screenshot(page, "mclovin_12_final_state.png", "Final state of page")
        log("All test steps complete!")

        await browser.close()

if __name__ == "__main__":
    os.environ["DISPLAY"] = ":99"
    asyncio.run(main())
