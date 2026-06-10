#!/usr/bin/env python3
"""
Playwright test for mcLOVIN' - uses curl to get session cookie, then navigates directly.
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

def get_session_cookie():
    """Use @salesforce/core + curl to get a real session cookie."""
    # Get the frontdoor URL
    js = """
const { AuthInfo } = require('/opt/node22/lib/node_modules/@salesforce/cli/node_modules/@salesforce/core');
async function main() {
    const auth = await AuthInfo.create({ username: 'megan.logan@thelovingcompanies.com' });
    const url = await auth.getOrgFrontDoorUrl();
    process.stdout.write(url + '\\n');
}
main().catch(e => { process.stderr.write(e.message + '\\n'); process.exit(1); });
"""
    r = subprocess.run(["node", "-e", js], capture_output=True, text=True, timeout=15)
    if r.returncode != 0:
        raise RuntimeError(f"Node failed: {r.stderr}")
    frontdoor_url = r.stdout.strip()
    log(f"Frontdoor URL obtained: {frontdoor_url[:60]}...")

    # Use curl with JS disabled to get the session cookie
    # The frontdoor URL sets the sid cookie even without JS
    r2 = subprocess.run(
        ["curl", "-s", "-L", "--max-redirs", "3",
         "-c", "/tmp/sf_session.txt",
         "-o", "/dev/null",
         "-w", "%{url_effective}",
         frontdoor_url],
        capture_output=True, text=True, timeout=30
    )
    log(f"Curl final URL: {r2.stdout[:100]}")

    # Read the session cookie
    with open("/tmp/sf_session.txt") as f:
        content = f.read()

    cookies = {}
    for line in content.split("\n"):
        # Handle #HttpOnly_ prefix (curl marks HttpOnly cookies with this)
        clean_line = line.strip()
        if clean_line.startswith("#HttpOnly_"):
            clean_line = clean_line[len("#HttpOnly_"):]
        elif clean_line.startswith("#") or not clean_line:
            continue
        parts = clean_line.split("\t")
        if len(parts) >= 7:
            domain = parts[0].lstrip(".")
            name = parts[5]
            value = parts[6]
            cookies[name] = {"domain": domain, "name": name, "value": value}

    log(f"Cookies obtained: {list(cookies.keys())}")
    return cookies

async def main():
    log("Getting Salesforce session cookies ...")
    try:
        cookies = get_session_cookie()
        sid_cookie = cookies.get("sid")
        if not sid_cookie:
            log("ERROR: No sid cookie found!")
            return
        log(f"Got SID cookie: {sid_cookie['value'][:30]}...")
    except Exception as e:
        log(f"Failed to get cookies: {e}")
        return

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

        # Set the Salesforce session cookies before navigating
        log("Setting session cookies in browser ...")
        await context.add_cookies([
            {
                "name": "sid",
                "value": sid_cookie["value"],
                "domain": "loving.my.salesforce.com",
                "path": "/",
                "secure": True,
                "httpOnly": True,
                "sameSite": "None",
            },
            {
                "name": "sid",
                "value": sid_cookie["value"],
                "domain": "loving.lightning.force.com",
                "path": "/",
                "secure": True,
                "httpOnly": True,
                "sameSite": "None",
            },
        ])

        # Also add other cookies if available
        for key, c in cookies.items():
            if key != "sid":
                domain = c["domain"]
                if "salesforce.com" in domain or "force.com" in domain:
                    try:
                        await context.add_cookies([{
                            "name": c["name"],
                            "value": c["value"],
                            "domain": "loving.my.salesforce.com",
                            "path": "/",
                        }])
                    except:
                        pass

        page = await context.new_page()

        # ── STEP 1: Navigate directly to Lightning ───────────────────────────
        log("Step 1: Navigating directly to Salesforce Lightning ...")
        try:
            # Navigate to home first to use session
            await page.goto("https://loving.my.salesforce.com/one/one.app", timeout=45000,
                            wait_until="domcontentloaded")
            await page.wait_for_timeout(8000)
            url = page.url
            log(f"URL: {url}")
            title = await page.title()
            log(f"Title: {title}")
            await screenshot(page, "mclovin_01_utility_bar.png",
                             "After login — utility bar at bottom")
        except Exception as e:
            log(f"Error: {e}")
            await screenshot(page, "mclovin_01_error.png", f"Error: {e}")

        # Check if we're authenticated
        if "login" in page.url.lower() and "lightning" not in page.url:
            log("Not authenticated — trying frontdoor URL directly ...")
            # Get a fresh frontdoor URL and navigate
            js2 = """
const { AuthInfo } = require('/opt/node22/lib/node_modules/@salesforce/cli/node_modules/@salesforce/core');
async function main() {
    const auth = await AuthInfo.create({ username: 'megan.logan@thelovingcompanies.com' });
    const url = await auth.getOrgFrontDoorUrl();
    process.stdout.write(url + '\\n');
}
main().catch(e => process.exit(1));
"""
            r = subprocess.run(["node", "-e", js2], capture_output=True, text=True, timeout=15)
            frontdoor_url = r.stdout.strip()

            # Navigate with route handling to intercept file.force.com redirect
            try:
                async def handle_route(route):
                    url = route.request.url
                    if "file.force.com/secur/contentDoor" in url:
                        # Extract the startURL and navigate there directly
                        import urllib.parse
                        parsed = urllib.parse.urlparse(url)
                        params = urllib.parse.parse_qs(parsed.query)
                        start_url = params.get("startURL", [None])[0]
                        if start_url:
                            log(f"Intercepted contentDoor, redirecting to: {start_url[:80]}")
                            # Set the sid cookie from the redirect URL
                            sid_param = params.get("sid", [None])[0]
                            if sid_param:
                                await context.add_cookies([{
                                    "name": "sid", "value": sid_param,
                                    "domain": "loving.my.salesforce.com",
                                    "path": "/", "secure": True, "httpOnly": True
                                }])
                            await route.fulfill(
                                status=302,
                                headers={"Location": start_url}
                            )
                        else:
                            await route.continue_()
                    else:
                        await route.continue_()

                await context.route("**", handle_route)
                await page.goto(frontdoor_url, timeout=60000, wait_until="domcontentloaded")
                await page.wait_for_timeout(8000)
                log(f"After intercept URL: {page.url}")
                await screenshot(page, "mclovin_01b_after_intercept.png", "After route intercept")
                await context.unroute("**")
            except Exception as e:
                log(f"Intercept approach failed: {e}")

        # ── STEP 2: Navigate to Outdoor Living app ────────────────────────────
        log("Step 2: Navigating to the Outdoor Living app ...")
        try:
            await page.goto("https://loving.lightning.force.com/lightning/app/01Ia5000000blTIEAY",
                            timeout=45000, wait_until="domcontentloaded")
            await page.wait_for_timeout(5000)
            log(f"URL after app nav: {page.url}")
        except Exception as e:
            log(f"App navigation failed: {e}")
            # Try alternate URL
            try:
                await page.goto("https://loving.my.salesforce.com/lightning/app/01Ia5000000blTIEAY",
                                timeout=45000, wait_until="domcontentloaded")
                await page.wait_for_timeout(5000)
                log(f"URL after alt app nav: {page.url}")
            except Exception as e2:
                log(f"Alt app navigation also failed: {e2}")

        # ── Check current state ───────────────────────────────────────────────
        log("Checking current page state ...")
        await page.wait_for_timeout(5000)
        title = await page.title()
        url = page.url
        log(f"Title: {title}, URL: {url}")
        await screenshot(page, "mclovin_02_app_state.png", "Current app state")

        # ── STEP 3: Screenshot and find utility bar ───────────────────────────
        log("Step 3: Looking for utility bar ...")
        await page.wait_for_timeout(3000)
        await screenshot(page, "mclovin_03_full_page.png", "Full page — utility bar check")

        # Find the mcLOVIN' button specifically
        btn_pos = await page.evaluate("""
            () => {
                // Find the utility bar
                const utilBar = document.querySelector('.slds-utility-bar, .utilitybar');
                if (!utilBar) {
                    // Check if page is loaded
                    return {
                        found: false,
                        reason: 'no utility bar element',
                        pageTitle: document.title,
                        url: window.location.href,
                        bodyPreview: document.body.innerText.substring(0, 200)
                    };
                }

                // Find all buttons in utility bar
                const buttons = utilBar.querySelectorAll('button');
                const btnList = [];
                for (const btn of buttons) {
                    const rect = btn.getBoundingClientRect();
                    btnList.push({
                        text: btn.textContent.trim(),
                        title: btn.getAttribute('title'),
                        aria: btn.getAttribute('aria-label'),
                        cx: Math.round(rect.x + rect.width/2),
                        cy: Math.round(rect.y + rect.height/2),
                        w: rect.width, h: rect.height
                    });
                }

                // Also get utility bar items
                const items = utilBar.querySelectorAll('.slds-utility-bar__item');
                const itemList = [];
                for (const item of items) {
                    const rect = item.getBoundingClientRect();
                    itemList.push({
                        text: item.textContent.trim().substring(0, 40),
                        cx: Math.round(rect.x + rect.width/2),
                        cy: Math.round(rect.y + rect.height/2)
                    });
                }

                return {
                    found: true,
                    buttons: btnList,
                    items: itemList,
                    html: utilBar.innerHTML.substring(0, 300)
                };
            }
        """)
        log(f"Utility bar status: {btn_pos}")

        # ── STEP 4: Click mcLOVIN' button ────────────────────────────────────
        log("Step 4: Clicking mcLOVIN' utility bar button ...")
        clicked = False

        if btn_pos.get('found'):
            buttons = btn_pos.get('buttons', [])
            for btn in buttons:
                text = (btn.get('text') or '').lower()
                if 'mclovin' in text:
                    x, y = btn['cx'], btn['cy']
                    if 0 < x < 1440 and 0 < y < 900:
                        log(f"Clicking mcLOVIN' at ({x}, {y})")
                        await page.mouse.click(x, y)
                        clicked = True
                        break

        if not clicked:
            # From previous runs: utility bar is at y≈860, first item starts at x≈0
            # The mcLOVIN' button should be the first item
            log("Trying coordinate-based click at utility bar position ...")
            # Inspect button positions first by hovering along the bottom
            for x in [35, 70, 100, 150]:
                y = 870
                el_at_point = await page.evaluate(f"""
                    () => {{
                        const el = document.elementFromPoint({x}, {y});
                        if (!el) return null;
                        return {{
                            tag: el.tagName,
                            text: el.textContent.trim().substring(0, 30),
                            className: el.className.substring(0, 50)
                        }};
                    }}
                """)
                log(f"Element at ({x}, {y}): {el_at_point}")

            # Click at the mcLOVIN' position
            await page.mouse.click(70, 870)
            clicked = True
            log("Clicked at utility bar position (70, 870)")

        await page.wait_for_timeout(3000)
        await screenshot(page, "mclovin_04_after_click.png", "After clicking mcLOVIN'")

        # ── STEP 5: Look for badge ────────────────────────────────────────────
        log("Step 5: Looking for floating badge ...")
        await page.wait_for_timeout(3000)
        await screenshot(page, "mclovin_05_badge.png", "Looking for badge character")

        # Inspect what elements appeared
        elements_after = await page.evaluate("""
            () => {
                const result = {
                    newPanels: [],
                    dockedPanels: [],
                    fixedElements: []
                };

                // Look for docked panels that appeared
                document.querySelectorAll('[class*="docked"], [class*="Docked"]').forEach(el => {
                    const rect = el.getBoundingClientRect();
                    if (rect.width > 0) {
                        result.dockedPanels.push({
                            className: el.className.substring(0, 60),
                            text: el.textContent.trim().substring(0, 80),
                            visible: el.offsetParent !== null,
                            w: rect.width, h: rect.height,
                            x: Math.round(rect.x), y: Math.round(rect.y)
                        });
                    }
                });

                // Fixed elements
                document.querySelectorAll('*').forEach(el => {
                    const style = window.getComputedStyle(el);
                    const rect = el.getBoundingClientRect();
                    if (style.position === 'fixed' && rect.width > 20 && rect.height > 20 &&
                        rect.y > 50 && rect.y < 860) {
                        result.fixedElements.push({
                            tag: el.tagName,
                            className: el.className.substring(0, 60),
                            text: el.textContent.trim().substring(0, 40),
                            x: Math.round(rect.x), y: Math.round(rect.y),
                            w: rect.width, h: rect.height
                        });
                    }
                });

                return result;
            }
        """)
        log(f"Elements after click: {elements_after}")

        # Check if a panel is now visible and try to interact
        panel_visible = any(
            p.get('visible') and p.get('w', 0) > 100
            for p in elements_after.get('dockedPanels', [])
        )

        fixed_mclovin = [
            el for el in elements_after.get('fixedElements', [])
            if 'mclovin' in (el.get('className') or '').lower() or
               'mclovin' in (el.get('text') or '').lower()
        ]
        log(f"Panel visible: {panel_visible}, mcLOVIN fixed elements: {fixed_mclovin}")

        # ── Now re-run with the best approach from V3 ─────────────────────────
        # From v3 run we know the utility bar IS there and the button IS there
        # We need to find the actual button position

        # Try to find by looking at the bottom portion of the page
        log("Doing detailed utility bar button scan ...")
        scan_result = await page.evaluate("""
            () => {
                const utilBar = document.querySelector('.slds-utility-bar, .utilitybar');
                if (!utilBar) return {error: 'no utility bar'};

                const rect = utilBar.getBoundingClientRect();
                const html = utilBar.innerHTML;

                // Find all clickable items
                const clickables = [];
                utilBar.querySelectorAll('button, a, [role="button"]').forEach(el => {
                    const r = el.getBoundingClientRect();
                    clickables.push({
                        tag: el.tagName,
                        text: el.textContent.trim().substring(0, 60),
                        title: el.getAttribute('title'),
                        aria: el.getAttribute('aria-label'),
                        cx: Math.round(r.x + r.width/2),
                        cy: Math.round(r.y + r.height/2),
                        w: Math.round(r.width), h: Math.round(r.height)
                    });
                });

                return {
                    utilBarRect: {x: rect.x, y: rect.y, w: rect.width, h: rect.height},
                    clickables: clickables,
                    html: html.substring(0, 800)
                };
            }
        """)
        log(f"Detailed scan: {scan_result}")

        # Click the mcLOVIN' button precisely
        if 'clickables' in scan_result:
            for btn in scan_result['clickables']:
                text = (btn.get('text') or '').lower()
                if 'mclovin' in text:
                    cx, cy = btn['cx'], btn['cy']
                    if 0 < cx < 1440 and 0 < cy < 900:
                        log(f"Precise click on mcLOVIN' at ({cx}, {cy})")
                        await page.mouse.click(cx, cy)
                        await page.wait_for_timeout(4000)
                        await screenshot(page, "mclovin_05b_after_precise_click.png",
                                         "After precise utility bar click")
                        break

        # ── STEP 6: Look for text input and type question ────────────────────
        log("Step 6: Looking for AI chat input ...")
        await page.wait_for_timeout(2000)

        # Find any visible text area with a reasonable position
        inputs = await page.evaluate("""
            () => {
                const found = [];
                document.querySelectorAll('textarea, input[type="text"]').forEach(inp => {
                    const rect = inp.getBoundingClientRect();
                    const style = window.getComputedStyle(inp);
                    found.push({
                        tag: inp.tagName,
                        placeholder: inp.placeholder || inp.getAttribute('placeholder') || '',
                        className: inp.className.substring(0, 60),
                        visible: inp.offsetParent !== null,
                        display: style.display,
                        visibility: style.visibility,
                        x: Math.round(rect.x), y: Math.round(rect.y),
                        cx: Math.round(rect.x + rect.width/2),
                        cy: Math.round(rect.y + rect.height/2),
                        w: Math.round(rect.width), h: Math.round(rect.height)
                    });
                });
                return found;
            }
        """)
        log(f"All text inputs: {inputs}")

        # Try clicking on visible inputs
        typed = False
        for inp in inputs:
            if inp.get('visible') and inp.get('w', 0) > 100 and inp.get('h', 0) > 0:
                cx, cy = inp['cx'], inp['cy']
                if 0 < cx < 1440 and 0 < cy < 860:
                    log(f"Typing into input at ({cx},{cy}): {inp}")
                    await page.mouse.click(cx, cy)
                    await page.wait_for_timeout(300)
                    await page.keyboard.type("how do I create a new account")
                    await screenshot(page, "mclovin_06_typed.png", "Question typed")
                    await page.keyboard.press("Enter")
                    typed = True
                    log("Waiting 15s for response ...")
                    await page.wait_for_timeout(15000)
                    await screenshot(page, "mclovin_07_response.png", "AI response")
                    break

        if not typed:
            log("No visible text input found")
            await screenshot(page, "mclovin_06_no_input.png", "No input found")

        # ── STEP 7: Look for chips ────────────────────────────────────────────
        log("Step 7: Looking for quick-action chips ...")
        await page.wait_for_timeout(1000)

        chips = await page.evaluate("""
            () => {
                const found = [];
                const chipTexts = ['Upload PO', 'Create Work Order', 'Schedule', 'New Quote', 'Get Help', 'Contact'];
                document.querySelectorAll('button, [role="button"], [class*="chip"]').forEach(el => {
                    const text = el.textContent.trim();
                    const rect = el.getBoundingClientRect();
                    if (rect.width > 0 && rect.height > 0 && rect.y > 300 && rect.y < 900) {
                        for (const chipText of chipTexts) {
                            if (text.toLowerCase().includes(chipText.toLowerCase())) {
                                found.push({
                                    text: text.substring(0, 40),
                                    cx: Math.round(rect.x + rect.width/2),
                                    cy: Math.round(rect.y + rect.height/2),
                                    w: rect.width, h: rect.height
                                });
                                break;
                            }
                        }
                    }
                });
                return found;
            }
        """)
        log(f"Quick-action chips: {chips}")

        for chip in chips:
            if 'upload po' in chip['text'].lower():
                cx, cy = chip['cx'], chip['cy']
                if 0 < cx < 1440 and 0 < cy < 900:
                    log(f"Clicking Upload PO at ({cx},{cy})")
                    await page.mouse.click(cx, cy)
                    await page.wait_for_timeout(15000)
                    await screenshot(page, "mclovin_08_upload_po.png", "Upload PO response")
                    break
        else:
            log("Upload PO not found")
            await screenshot(page, "mclovin_08_no_chip.png", "No chip found")

        # ── STEP 8: Minimize ──────────────────────────────────────────────────
        log("Step 8: Looking for minimize button ...")

        minimize_btns = await page.evaluate("""
            () => {
                const found = [];
                document.querySelectorAll('button, [role="button"]').forEach(btn => {
                    const title = (btn.getAttribute('title') || '').toLowerCase();
                    const aria = (btn.getAttribute('aria-label') || '').toLowerCase();
                    const text = btn.textContent.trim().toLowerCase();
                    if (title.includes('minimize') || aria.includes('minimize') ||
                        title.includes('collapse') || aria.includes('collapse') ||
                        text === '—' || text === '_') {
                        const rect = btn.getBoundingClientRect();
                        if (rect.width > 0 && rect.y > 300) {
                            found.push({
                                title, aria, text: text.substring(0, 20),
                                cx: Math.round(rect.x + rect.width/2),
                                cy: Math.round(rect.y + rect.height/2)
                            });
                        }
                    }
                });
                return found;
            }
        """)
        log(f"Minimize buttons: {minimize_btns}")

        for btn in minimize_btns:
            cx, cy = btn['cx'], btn['cy']
            if 0 < cx < 1440 and 0 < cy < 900:
                log(f"Clicking minimize at ({cx},{cy})")
                await page.mouse.click(cx, cy)
                await page.wait_for_timeout(2000)
                await screenshot(page, "mclovin_09_minimized.png", "After minimize")
                break
        else:
            await screenshot(page, "mclovin_09_no_minimize.png", "No minimize found")

        # ── STEP 9: Drag ──────────────────────────────────────────────────────
        log("Step 9: Looking for draggable badge element ...")

        # The floating badge would be a fixed element between 30-150px
        drag_targets = await page.evaluate("""
            () => {
                const found = [];
                document.querySelectorAll('*').forEach(el => {
                    const style = window.getComputedStyle(el);
                    const rect = el.getBoundingClientRect();
                    if (style.position === 'fixed' &&
                        rect.width > 30 && rect.width < 150 &&
                        rect.height > 30 && rect.height < 150 &&
                        rect.y > 200 && rect.y < 800) {
                        found.push({
                            tag: el.tagName,
                            className: el.className.substring(0, 60),
                            text: el.textContent.trim().substring(0, 30),
                            cx: Math.round(rect.x + rect.width/2),
                            cy: Math.round(rect.y + rect.height/2),
                            w: rect.width, h: rect.height
                        });
                    }
                });
                return found;
            }
        """)
        log(f"Drag targets: {drag_targets}")

        if drag_targets:
            t = drag_targets[0]
            sx, sy = t['cx'], t['cy']
            ex = max(100, sx - 200)
            ey = max(200, sy - 100)
            log(f"Dragging from ({sx},{sy}) to ({ex},{ey})")
            await page.mouse.move(sx, sy)
            await page.mouse.down()
            await page.wait_for_timeout(300)
            for i in range(20):
                t_ratio = (i+1) / 20
                nx = int(sx + (ex - sx) * t_ratio)
                ny = int(sy + (ey - sy) * t_ratio)
                await page.mouse.move(nx, ny)
                await page.wait_for_timeout(20)
            await page.mouse.up()
            await page.wait_for_timeout(1000)
            await screenshot(page, "mclovin_10_after_drag.png", "After drag")
        else:
            await screenshot(page, "mclovin_10_no_drag.png", "No draggable element")

        # ── Final ─────────────────────────────────────────────────────────────
        await screenshot(page, "mclovin_11_final.png", "Final state")
        log("All tests complete!")
        await browser.close()

if __name__ == "__main__":
    os.environ["DISPLAY"] = ":99"
    asyncio.run(main())
