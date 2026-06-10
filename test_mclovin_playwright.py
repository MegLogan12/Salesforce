#!/usr/bin/env python3
"""
Playwright test for the 'Ask mcLOVIN'' floating AI assistant in Salesforce.
"""

import os
import sys
import time
import asyncio
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

LOGIN_URL = "https://loving.my.salesforce.com/secur/frontdoor.jsp?otp=00Da500001UEK0H%21AQEAQCWOnO_wvZZI2cuAZWjxhR_Ezrqbv0X8ooS5OVO2oBTueyZqxIo2PCA.NxM4ceCjQ9kHMut7vzoBTxyv1kxGvs_.laML&cshc=500001mhIYb500001UEK0H"
APP_URL = "https://loving.my.salesforce.com/lightning/app/01Ia5000000blTIEAY"
SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots"

os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

async def screenshot(page, name, desc=""):
    path = f"{SCREENSHOTS_DIR}/{name}"
    await page.screenshot(path=path, full_page=False)
    log(f"Screenshot saved: {name} — {desc}")
    return path

async def main():
    async with async_playwright() as p:
        log("Launching Chromium (1440x900) on DISPLAY :99 ...")
        browser = await p.chromium.launch(
            headless=False,
            args=[
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu",
            ],
            env={**os.environ, "DISPLAY": ":99"},
        )

        context = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )
        page = await context.new_page()

        # ── STEP 1: Login ────────────────────────────────────────────────────
        log("Step 1: Navigating to login URL ...")
        try:
            await page.goto(LOGIN_URL, timeout=60000, wait_until="domcontentloaded")
            await page.wait_for_timeout(5000)
            await screenshot(page, "mclovin_00_login.png", "After login URL navigation")
            log(f"Current URL after login: {page.url}")
        except Exception as e:
            log(f"ERROR during login: {e}")
            await screenshot(page, "mclovin_00_login_error.png", f"Login error: {e}")

        # ── STEP 2: Navigate to Outdoor Living app ───────────────────────────
        log("Step 2: Navigating to Outdoor Living app ...")
        try:
            await page.goto(APP_URL, timeout=60000, wait_until="domcontentloaded")
            await page.wait_for_timeout(8000)
            await screenshot(page, "mclovin_01_app_loaded.png", "Outdoor Living app loaded")
            log(f"Current URL: {page.url}")
        except Exception as e:
            log(f"ERROR navigating to app: {e}")
            await screenshot(page, "mclovin_01_app_error.png", f"App nav error: {e}")

        # ── STEP 3: Look for utility bar ─────────────────────────────────────
        log("Step 3: Looking for utility bar and 'Ask mcLOVIN'' button ...")
        await screenshot(page, "mclovin_02_full_page.png", "Full page before looking for utility bar")

        # Check for utility bar items
        utility_bar_found = False
        mclovin_button = None

        # Try multiple selectors for the utility bar
        selectors_to_try = [
            "button:has-text('Ask mcLOVIN')",
            "button:has-text('mcLOVIN')",
            "[title*='mcLOVIN']",
            "[aria-label*='mcLOVIN']",
            ".utility-bar button",
            "runtime_utilities-utility-bar-item",
            "one-utility-bar-item",
            "[class*='utility'] button",
        ]

        for sel in selectors_to_try:
            try:
                el = page.locator(sel).first
                if await el.count() > 0:
                    log(f"Found utility bar element with selector: {sel}")
                    utility_bar_found = True
                    mclovin_button = el
                    break
            except Exception:
                continue

        if not utility_bar_found:
            log("Utility bar button not found with standard selectors — trying JavaScript search ...")
            # Try to find via JavaScript
            result = await page.evaluate("""
                () => {
                    // Look for any button containing mcLOVIN text
                    const allButtons = document.querySelectorAll('button, [role="button"]');
                    const found = [];
                    for (const btn of allButtons) {
                        if (btn.textContent.toLowerCase().includes('mclovin') ||
                            btn.getAttribute('title')?.toLowerCase().includes('mclovin') ||
                            btn.getAttribute('aria-label')?.toLowerCase().includes('mclovin')) {
                            found.push({
                                text: btn.textContent.trim().substring(0, 100),
                                title: btn.getAttribute('title'),
                                ariaLabel: btn.getAttribute('aria-label'),
                                className: btn.className,
                                id: btn.id,
                                tagName: btn.tagName
                            });
                        }
                    }
                    // Also check for utility bar structure
                    const utilityBar = document.querySelector('[class*="utility-bar"], [class*="utilityBar"], .slds-utility-bar');
                    return {
                        mclovinButtons: found,
                        utilityBarExists: !!utilityBar,
                        utilityBarHTML: utilityBar ? utilityBar.innerHTML.substring(0, 500) : null
                    };
                }
            """)
            log(f"JS search result: {result}")

        # Try to find the utility bar by scrolling to bottom
        await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        await page.wait_for_timeout(2000)
        await screenshot(page, "mclovin_03_scrolled_bottom.png", "Page scrolled to bottom — looking for utility bar")

        # ── STEP 4: Click the mcLOVIN button ─────────────────────────────────
        log("Step 4: Attempting to click 'Ask mcLOVIN'' button ...")
        clicked_button = False

        # Try via JavaScript click
        click_result = await page.evaluate("""
            () => {
                const allButtons = document.querySelectorAll('button, [role="button"], a');
                for (const btn of allButtons) {
                    const text = (btn.textContent || '').toLowerCase();
                    const title = (btn.getAttribute('title') || '').toLowerCase();
                    const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
                    if (text.includes('mclovin') || title.includes('mclovin') || ariaLabel.includes('mclovin')) {
                        btn.click();
                        return {found: true, text: btn.textContent.trim().substring(0, 100)};
                    }
                }
                // Also check shadow DOM for LWC components
                return {found: false, totalButtons: allButtons.length};
            }
        """)
        log(f"Click attempt result: {click_result}")

        if click_result.get('found'):
            clicked_button = True
            log("Clicked mcLOVIN button via JavaScript!")
            await page.wait_for_timeout(3000)
            await screenshot(page, "mclovin_04_after_button_click.png", "After clicking mcLOVIN button")

        # Try Playwright locator approach
        if not clicked_button:
            try:
                btn = page.get_by_role("button", name=lambda n: "mclovin" in n.lower() if n else False)
                if await btn.count() > 0:
                    await btn.first.click()
                    clicked_button = True
                    await page.wait_for_timeout(3000)
                    await screenshot(page, "mclovin_04_after_button_click.png", "After clicking mcLOVIN button (role locator)")
            except Exception as e:
                log(f"Role locator attempt failed: {e}")

        # ── Look for badge after button click ─────────────────────────────────
        log("Step 4b: Looking for the floating badge after button click ...")
        await page.wait_for_timeout(2000)

        # Check what appeared
        badge_result = await page.evaluate("""
            () => {
                // Look for the floating badge / character
                const elements = document.querySelectorAll('*');
                const floating = [];
                for (const el of elements) {
                    const style = window.getComputedStyle(el);
                    if ((style.position === 'fixed' || style.position === 'absolute') &&
                        el.offsetWidth > 20 && el.offsetHeight > 20 &&
                        el.offsetWidth < 200 && el.offsetHeight < 200) {
                        floating.push({
                            tag: el.tagName,
                            id: el.id,
                            className: el.className.substring(0, 100),
                            text: el.textContent.trim().substring(0, 50),
                            x: el.getBoundingClientRect().x,
                            y: el.getBoundingClientRect().y,
                            w: el.offsetWidth,
                            h: el.offsetHeight
                        });
                    }
                }
                return floating.slice(0, 20);
            }
        """)
        log(f"Floating elements after click: {badge_result}")
        await screenshot(page, "mclovin_04b_badge_check.png", "After waiting for badge")

        # ── STEP 5: Find and click badge to open panel ────────────────────────
        log("Step 5: Looking for badge and clicking it to open full panel ...")

        # Try to find badge element
        badge_selectors = [
            "c-mc-lovin-assistant",
            "[class*='mclovin']",
            "[class*='mcLOVIN']",
            "[class*='assistant-badge']",
            "[class*='floating']",
            "img[src*='mclovin']",
            "img[src*='character']",
            "img[alt*='mclovin']",
            "img[alt*='mcLOVIN']",
        ]

        badge_clicked = False
        for sel in badge_selectors:
            try:
                el = page.locator(sel).first
                cnt = await el.count()
                if cnt > 0:
                    log(f"Found badge with selector: {sel}")
                    await el.click()
                    badge_clicked = True
                    await page.wait_for_timeout(2000)
                    await screenshot(page, "mclovin_05_panel_opened.png", f"Panel opened via {sel}")
                    break
            except Exception as e:
                log(f"Badge selector {sel} failed: {e}")

        if not badge_clicked:
            log("Could not find badge with known selectors — taking screenshot of current state")
            await screenshot(page, "mclovin_05_no_badge.png", "No badge found")

        # ── Check for open panel / character UI ──────────────────────────────
        panel_result = await page.evaluate("""
            () => {
                // Look for various AI panel indicators
                const indicators = {
                    iframes: Array.from(document.querySelectorAll('iframe')).map(f => ({src: f.src, id: f.id})),
                    dialogs: Array.from(document.querySelectorAll('[role="dialog"]')).map(d => ({
                        id: d.id, className: d.className.substring(0, 100),
                        text: d.textContent.trim().substring(0, 100)
                    })),
                    panels: Array.from(document.querySelectorAll('[class*="panel"], [class*="Panel"]')).slice(0, 5).map(p => ({
                        className: p.className.substring(0, 100),
                        visible: p.offsetParent !== null
                    })),
                    customElements: Array.from(document.querySelectorAll('c-mc-lovin-assistant, c-ask-mclovin, lightning-utility-bar-api')).map(e => ({
                        tag: e.tagName,
                        id: e.id,
                        shadowRoot: e.shadowRoot ? 'yes' : 'no'
                    }))
                };
                return indicators;
            }
        """)
        log(f"Panel check result: {panel_result}")

        # ── STEP 6: Type a question ────────────────────────────────────────────
        log("Step 6: Looking for text input to type question ...")

        # Look for text input
        input_selectors = [
            "input[placeholder*='question']",
            "input[placeholder*='ask']",
            "input[placeholder*='Ask']",
            "textarea[placeholder*='ask']",
            "textarea[placeholder*='question']",
            "[contenteditable='true']",
            "input[type='text']:visible",
            "textarea:visible",
        ]

        input_found = False
        for sel in input_selectors:
            try:
                el = page.locator(sel).first
                cnt = await el.count()
                if cnt > 0:
                    is_visible = await el.is_visible()
                    if is_visible:
                        log(f"Found input with selector: {sel}")
                        await el.click()
                        await el.fill("how do I create a new account")
                        await page.wait_for_timeout(1000)
                        await screenshot(page, "mclovin_06_typed_question.png", "Question typed in input")
                        # Press Enter or find send button
                        await el.press("Enter")
                        input_found = True
                        break
            except Exception as e:
                log(f"Input selector {sel} failed: {e}")

        if input_found:
            log("Waiting up to 15 seconds for AI response ...")
            await page.wait_for_timeout(15000)
            await screenshot(page, "mclovin_07_ai_response.png", "AI response to question")
        else:
            log("No text input found — taking current state screenshot")
            await screenshot(page, "mclovin_06_no_input.png", "No text input found")

        # ── STEP 7: Try clicking a chip ────────────────────────────────────────
        log("Step 7: Looking for 'Upload PO' chip ...")

        chip_selectors = [
            "button:has-text('Upload PO')",
            "[class*='chip']:has-text('Upload PO')",
            "[class*='quick-action']:has-text('Upload PO')",
            "span:has-text('Upload PO')",
        ]

        chip_clicked = False
        for sel in chip_selectors:
            try:
                el = page.locator(sel).first
                cnt = await el.count()
                if cnt > 0:
                    is_visible = await el.is_visible()
                    if is_visible:
                        log(f"Found Upload PO chip with selector: {sel}")
                        await el.click()
                        chip_clicked = True
                        await page.wait_for_timeout(15000)
                        await screenshot(page, "mclovin_08_upload_po_response.png", "Upload PO chip response")
                        break
            except Exception as e:
                log(f"Chip selector {sel} failed: {e}")

        if not chip_clicked:
            log("Upload PO chip not found — taking screenshot of current state")
            await screenshot(page, "mclovin_08_no_chip.png", "Upload PO chip not found")

        # ── STEP 8: Try minimizing ────────────────────────────────────────────
        log("Step 8: Looking for minimize/close button ...")

        minimize_selectors = [
            "button[title='Minimize']",
            "button[aria-label='Minimize']",
            "button[title='Close']",
            "button[aria-label='Close']",
            "[class*='minimize']",
            "[class*='close']:visible",
            "button:has-text('×')",
            "button:has-text('✕')",
        ]

        minimized = False
        for sel in minimize_selectors:
            try:
                el = page.locator(sel).first
                cnt = await el.count()
                if cnt > 0:
                    is_visible = await el.is_visible()
                    if is_visible:
                        log(f"Found minimize button with selector: {sel}")
                        await el.click()
                        minimized = True
                        await page.wait_for_timeout(2000)
                        await screenshot(page, "mclovin_09_minimized.png", "After minimizing panel")
                        break
            except Exception as e:
                log(f"Minimize selector {sel} failed: {e}")

        if not minimized:
            log("Minimize button not found — taking screenshot")
            await screenshot(page, "mclovin_09_no_minimize.png", "Minimize button not found")

        # ── STEP 9: Test drag ─────────────────────────────────────────────────
        log("Step 9: Testing drag of badge ...")

        # Try to find the floating badge for drag
        drag_result = await page.evaluate("""
            () => {
                // Find fixed-position elements that could be the badge
                const all = document.querySelectorAll('*');
                const candidates = [];
                for (const el of all) {
                    const style = window.getComputedStyle(el);
                    if (style.position === 'fixed' && el.offsetWidth > 30 && el.offsetWidth < 200) {
                        const rect = el.getBoundingClientRect();
                        candidates.push({
                            tag: el.tagName,
                            className: el.className.substring(0, 80),
                            x: Math.round(rect.x),
                            y: Math.round(rect.y),
                            w: el.offsetWidth,
                            h: el.offsetHeight,
                            draggable: el.draggable || el.getAttribute('draggable')
                        });
                    }
                }
                return candidates.slice(0, 10);
            }
        """)
        log(f"Drag candidates: {drag_result}")

        if drag_result:
            # Try dragging the first candidate
            cand = drag_result[0]
            start_x = cand['x'] + cand['w'] // 2
            start_y = cand['y'] + cand['h'] // 2
            end_x = start_x - 150
            end_y = start_y - 100
            log(f"Attempting drag from ({start_x},{start_y}) to ({end_x},{end_y})")
            try:
                await page.mouse.move(start_x, start_y)
                await page.mouse.down()
                await page.wait_for_timeout(500)
                await page.mouse.move(end_x, end_y, steps=20)
                await page.wait_for_timeout(500)
                await page.mouse.up()
                await page.wait_for_timeout(1000)
                await screenshot(page, "mclovin_10_after_drag.png", "After drag attempt")
            except Exception as e:
                log(f"Drag failed: {e}")
                await screenshot(page, "mclovin_10_drag_error.png", f"Drag error: {e}")
        else:
            log("No drag candidates found")
            await screenshot(page, "mclovin_10_no_drag_target.png", "No drag target found")

        # ── FINAL: Full page summary screenshot ───────────────────────────────
        await screenshot(page, "mclovin_11_final_state.png", "Final state of page")

        # Get all page text for analysis
        page_text = await page.evaluate("document.body.innerText.substring(0, 2000)")
        log(f"Page text snippet: {page_text[:500]}")

        log("Test complete! All screenshots saved.")
        await browser.close()

if __name__ == "__main__":
    os.environ["DISPLAY"] = ":99"
    asyncio.run(main())
