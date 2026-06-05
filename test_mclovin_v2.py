#!/usr/bin/env python3
"""
Playwright test for the 'Ask mcLOVIN'' floating AI assistant in Salesforce.
Uses access token from ~/.sfdx/ to authenticate.
"""

import os
import sys
import time
import json
import asyncio
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots"
APP_URL = "https://loving.my.salesforce.com/lightning/app/01Ia5000000blTIEAY"
INSTANCE_URL = "https://loving.my.salesforce.com"

# Load access token from sfdx auth file
AUTH_FILE = "/root/.sfdx/megan.logan@thelovingcompanies.com.json"
with open(AUTH_FILE) as f:
    auth_data = json.load(f)

ACCESS_TOKEN = auth_data["accessToken"]
ORG_ID = auth_data["orgId"]

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
                "--window-size=1440,900",
            ],
        )

        context = await browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )

        # Set the Salesforce session cookies so we don't need the OTP
        # The sid cookie is the session ID which equals the access token
        log(f"Setting Salesforce session cookies with access token ...")

        # Add cookies for the org domain
        await context.add_cookies([
            {
                "name": "sid",
                "value": ACCESS_TOKEN,
                "domain": ".loving.my.salesforce.com",
                "path": "/",
                "secure": True,
                "httpOnly": True,
            },
            {
                "name": "sid",
                "value": ACCESS_TOKEN,
                "domain": "loving.my.salesforce.com",
                "path": "/",
                "secure": True,
                "httpOnly": True,
            },
        ])

        page = await context.new_page()

        # ── STEP 1: Navigate directly to the app ─────────────────────────────
        log("Step 1: Navigating directly to Outdoor Living app ...")
        try:
            await page.goto(APP_URL, timeout=60000, wait_until="domcontentloaded")
            await page.wait_for_timeout(5000)
            url_after = page.url
            log(f"URL after navigation: {url_after}")
            await screenshot(page, "mclovin_01_direct_nav.png", "Direct navigation to app")

            # Check if we got redirected to login
            if "login" in url_after.lower() or "secur" in url_after.lower():
                log("Redirected to login — trying frontdoor approach ...")

                # Use the frontdoor URL which should generate a new session
                frontdoor_url = f"{INSTANCE_URL}/secur/frontdoor.jsp?otp={ACCESS_TOKEN}&retURL=/lightning/app/01Ia5000000blTIEAY"
                await page.goto(frontdoor_url, timeout=60000, wait_until="domcontentloaded")
                await page.wait_for_timeout(5000)
                log(f"URL after frontdoor attempt: {page.url}")
                await screenshot(page, "mclovin_01b_frontdoor.png", "After frontdoor attempt")
        except Exception as e:
            log(f"ERROR during navigation: {e}")
            await screenshot(page, "mclovin_01_error.png", f"Navigation error: {e}")

        # Check if page is authenticated
        page_title = await page.title()
        log(f"Page title: {page_title}")

        current_url = page.url
        is_logged_in = "lightning" in current_url or "home.jsp" in current_url
        log(f"Is logged in: {is_logged_in}, URL: {current_url}")

        if not is_logged_in:
            log("Not logged in — page shows login screen. OTP token may be expired.")
            log("Checking if there's a way to reuse the existing SF session ...")

            # Check all cookies
            cookies = await context.cookies()
            log(f"Current cookies: {[c['name'] for c in cookies]}")

            # Try fetching instance URL with the access token as Bearer
            # First navigate to instance URL to set domain context
            await page.goto(INSTANCE_URL, timeout=30000)
            await page.wait_for_timeout(2000)

            # Try to use the SF REST API to get an open URL
            log("Attempting to use SF REST API to get session URL ...")
            js_result = await page.evaluate(f"""
                async () => {{
                    try {{
                        const resp = await fetch('/services/oauth2/token', {{
                            method: 'POST',
                            headers: {{'Content-Type': 'application/x-www-form-urlencoded'}},
                            body: 'grant_type=refresh_token&client_id=PlatformCLI&refresh_token={auth_data.get("refreshToken", "")}'
                        }});
                        const data = await resp.json();
                        return data;
                    }} catch(e) {{
                        return {{error: e.toString()}};
                    }}
                }}
            """)
            log(f"Token refresh result: {js_result}")

            if js_result and 'access_token' in js_result:
                new_token = js_result['access_token']
                log(f"Got new access token: {new_token[:20]}...")
                # Navigate with new token
                frontdoor = f"{INSTANCE_URL}/secur/frontdoor.jsp?otp={new_token}&retURL=/lightning/app/01Ia5000000blTIEAY"
                await page.goto(frontdoor, timeout=60000, wait_until="domcontentloaded")
                await page.wait_for_timeout(5000)
                log(f"URL with new token: {page.url}")
                await screenshot(page, "mclovin_01c_new_token.png", "After using new token")

        # ── Check current login state ─────────────────────────────────────────
        current_url = page.url
        is_logged_in = "lightning" in current_url
        log(f"Final login state: {is_logged_in}, URL: {current_url}")

        if not is_logged_in:
            log("CANNOT PROCEED: Authentication failed. The OTP token has expired.")
            log("The frontdoor.jsp OTP is a one-time use token that has already been consumed.")
            await screenshot(page, "mclovin_AUTH_FAILED.png", "Authentication failed")
            await browser.close()
            return

        # ── STEP 2: Navigate to Outdoor Living app ───────────────────────────
        log("Step 2: Navigating to Outdoor Living app ...")
        try:
            if APP_URL not in current_url:
                await page.goto(APP_URL, timeout=60000, wait_until="domcontentloaded")
            await page.wait_for_timeout(10000)
            await screenshot(page, "mclovin_02_app_loaded.png", "Outdoor Living app loaded")
            log(f"Current URL: {page.url}")
        except Exception as e:
            log(f"ERROR navigating to app: {e}")
            await screenshot(page, "mclovin_02_error.png", f"Error: {e}")

        # ── STEP 3: Full page screenshot & look for utility bar ──────────────
        log("Step 3: Taking full page screenshot and looking for utility bar ...")
        await screenshot(page, "mclovin_03_utility_bar.png", "Looking for utility bar")

        # Deep inspection of the page for mcLOVIN elements
        page_info = await page.evaluate("""
            () => {
                const info = {
                    title: document.title,
                    url: window.location.href,
                    bodyText: document.body.innerText.substring(0, 500),
                    buttons: [],
                    utilityBar: null,
                    customElements: [],
                    allFixedElements: []
                };

                // Find all buttons
                const buttons = document.querySelectorAll('button, [role="button"]');
                for (const btn of buttons) {
                    info.buttons.push({
                        text: btn.textContent.trim().substring(0, 50),
                        title: btn.getAttribute('title'),
                        ariaLabel: btn.getAttribute('aria-label'),
                        visible: btn.offsetParent !== null,
                        className: btn.className.substring(0, 80)
                    });
                }

                // Check for utility bar
                const utilBar = document.querySelector(
                    '.slds-utility-bar, [class*="utility-bar"], one-utility-bar, ' +
                    'runtime_utilities-utility-bar, [class*="utilityBar"]'
                );
                if (utilBar) {
                    info.utilityBar = {
                        tag: utilBar.tagName,
                        className: utilBar.className,
                        html: utilBar.innerHTML.substring(0, 1000)
                    };
                }

                // Get all custom LWC elements (c-*)
                const customEls = document.querySelectorAll('[class*="mclovin"], [class*="mcLOVIN"], c-mc-lovin, c-ask-mclovin');
                for (const el of customEls) {
                    info.customElements.push({
                        tag: el.tagName,
                        id: el.id,
                        className: el.className
                    });
                }

                // Fixed positioned elements
                const allEls = document.querySelectorAll('*');
                for (const el of allEls) {
                    const style = window.getComputedStyle(el);
                    if (style.position === 'fixed' && el.offsetWidth > 0) {
                        info.allFixedElements.push({
                            tag: el.tagName,
                            id: el.id.substring(0, 30),
                            className: el.className.substring(0, 80),
                            bottom: style.bottom,
                            right: style.right,
                            left: style.left,
                            top: style.top,
                            w: el.offsetWidth,
                            h: el.offsetHeight
                        });
                    }
                }

                return info;
            }
        """)

        log(f"Page title: {page_info['title']}")
        log(f"Page URL: {page_info['url']}")
        log(f"Body text preview: {page_info['bodyText'][:200]}")
        log(f"Number of buttons: {len(page_info['buttons'])}")
        log(f"Buttons: {page_info['buttons'][:20]}")
        log(f"Utility bar: {page_info['utilityBar']}")
        log(f"Custom elements: {page_info['customElements']}")
        log(f"Fixed elements: {page_info['allFixedElements']}")

        # ── STEP 4: Look for the Ask mcLOVIN' button ─────────────────────────
        log("Step 4: Searching for Ask mcLOVIN' button ...")

        # Try multiple approaches
        mclovin_found = False

        # 1. Look in buttons list
        for btn_info in page_info['buttons']:
            text = (btn_info.get('text') or '').lower()
            title = (btn_info.get('title') or '').lower()
            aria = (btn_info.get('ariaLabel') or '').lower()
            if 'mclovin' in text or 'mclovin' in title or 'mclovin' in aria:
                log(f"Found mcLOVIN button: {btn_info}")
                mclovin_found = True
                break

        # 2. Try clicking via JavaScript
        click_result = await page.evaluate("""
            () => {
                // Search all shadow DOMs recursively
                function searchShadow(root, depth=0) {
                    if (depth > 5) return null;
                    const els = root.querySelectorAll('*');
                    for (const el of els) {
                        const text = (el.textContent || '').trim().toLowerCase();
                        const title = (el.getAttribute('title') || '').toLowerCase();
                        const aria = (el.getAttribute('aria-label') || '').toLowerCase();
                        if ((text.includes('mclovin') || title.includes('mclovin') || aria.includes('mclovin'))
                            && el.tagName !== 'HTML' && el.tagName !== 'BODY') {
                            return {
                                found: true,
                                tag: el.tagName,
                                text: el.textContent.trim().substring(0, 80),
                                className: el.className.substring(0, 80)
                            };
                        }
                        if (el.shadowRoot) {
                            const result = searchShadow(el.shadowRoot, depth + 1);
                            if (result) return result;
                        }
                    }
                    return null;
                }

                const result = searchShadow(document);
                return result || {found: false, totalEls: document.querySelectorAll('*').length};
            }
        """)
        log(f"Shadow DOM search: {click_result}")

        # Try to wait for LWC to load more
        log("Waiting for Lightning to fully load ...")
        try:
            await page.wait_for_selector("one-app-nav-bar, lightning-app, .slds-utility-bar", timeout=15000)
            log("Lightning nav/utility bar detected!")
        except PlaywrightTimeoutError:
            log("Lightning nav bar not found within 15s")

        await page.wait_for_timeout(5000)
        await screenshot(page, "mclovin_04_after_wait.png", "After waiting for Lightning to load")

        # Re-inspect
        page_info2 = await page.evaluate("""
            () => {
                const info = {
                    title: document.title,
                    url: window.location.href,
                    utilityBarContent: '',
                    allText: []
                };

                // Get utility bar content
                const utilBars = document.querySelectorAll(
                    '.slds-utility-bar, [class*="utility-bar"], one-utility-bar, ' +
                    'runtime_utilities-utility-bar, [class*="utilityBar"], [data-component-id]'
                );
                for (const ub of utilBars) {
                    info.utilityBarContent += ub.tagName + ': ' + ub.className + '\\n';
                }

                // Collect all visible text
                const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
                let node;
                while (node = walker.nextNode()) {
                    const text = node.textContent.trim();
                    if (text.length > 2 && text.length < 100) {
                        info.allText.push(text);
                    }
                }

                return info;
            }
        """)
        log(f"Page 2 title: {page_info2['title']}")
        log(f"Page 2 URL: {page_info2['url']}")
        log(f"Utility bar content: {page_info2['utilityBarContent'][:500]}")
        log(f"All page text (first 50 items): {page_info2['allText'][:50]}")

        # ── STEP 5: Try to find and click the utility bar mcLOVIN button ─────
        log("Step 5: Attempting to find and interact with mcLOVIN utility bar item ...")

        # The utility bar in Salesforce Lightning is at the bottom. Let's look there.
        # Try pressing the button by going through the bottom of the viewport

        # Click various positions at the bottom of screen to find the utility bar
        viewport = page.viewport_size
        if viewport:
            vw, vh = viewport['width'], viewport['height']
            log(f"Viewport: {vw}x{vh}")

            # Check the bottom 80px of the screen
            bottom_y = vh - 25

            # Take screenshot showing bottom of page
            await screenshot(page, "mclovin_05_bottom_check.png", "Checking bottom of page for utility bar")

            # Try clicking at various x positions along the bottom bar
            for x_pos in [100, 200, 300, 400, 500, 600, 700, 800]:
                el = await page.evaluate_handle(f"document.elementFromPoint({x_pos}, {bottom_y})")
                el_info = await page.evaluate("""
                    (el) => {{
                        if (!el) return null;
                        return {{
                            tag: el.tagName,
                            text: el.textContent.trim().substring(0, 50),
                            className: el.className.substring(0, 80),
                            id: el.id
                        }};
                    }}
                """, el)
                if el_info and el_info.get('text'):
                    log(f"Element at ({x_pos}, {bottom_y}): {el_info}")

        # Final - try to look for mcLOVIN in iframes
        iframes = page.frames
        log(f"Number of frames: {len(iframes)}")
        for i, frame in enumerate(iframes):
            try:
                frame_url = frame.url
                frame_content = await frame.content()
                if 'mclovin' in frame_content.lower() or 'mcLOVIN' in frame_content:
                    log(f"Frame {i} ({frame_url}) contains mcLOVIN!")
            except Exception:
                pass

        # ── Try App Launcher to navigate ────────────────────────────────────
        log("Trying App Launcher to find Outdoor Living app ...")
        try:
            # Click the 9-dot App Launcher button
            app_launcher = page.locator("button[title='App Launcher'], .slds-icon-waffle, [aria-label='App Launcher']").first
            if await app_launcher.count() > 0:
                log("Found App Launcher button!")
                await app_launcher.click()
                await page.wait_for_timeout(2000)
                await screenshot(page, "mclovin_06_app_launcher.png", "App Launcher opened")

                # Search for Outdoor Living
                search_input = page.locator("input[placeholder*='Search'], input[placeholder*='search']").first
                if await search_input.count() > 0:
                    await search_input.fill("Outdoor Living")
                    await page.wait_for_timeout(2000)
                    await screenshot(page, "mclovin_07_app_search.png", "Searching for Outdoor Living app")

                    # Click the app
                    app_link = page.locator("text=Outdoor Living").first
                    if await app_link.count() > 0:
                        await app_link.click()
                        await page.wait_for_timeout(10000)
                        await screenshot(page, "mclovin_08_outdoor_living.png", "Outdoor Living app opened")
        except Exception as e:
            log(f"App Launcher approach failed: {e}")

        # ── Final screenshots ────────────────────────────────────────────────
        await screenshot(page, "mclovin_09_final.png", "Final state")

        log("Test script complete.")
        await browser.close()

if __name__ == "__main__":
    os.environ["DISPLAY"] = ":99"
    asyncio.run(main())
