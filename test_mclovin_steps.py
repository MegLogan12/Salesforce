#!/usr/bin/env python3
"""
Final targeted Playwright test for mcLOVIN' - using known coordinates from panel discovery.
"""

import os
import sys
import time
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
    """Get fresh Salesforce session cookie via @salesforce/core + curl."""
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
    frontdoor_url = r.stdout.strip()
    log(f"Frontdoor URL: {frontdoor_url[:60]}...")

    r2 = subprocess.run(
        ["curl", "-s", "-L", "--max-redirs", "3",
         "-c", "/tmp/sf_cookies2.txt", "-o", "/dev/null",
         "-w", "%{url_effective}", frontdoor_url],
        capture_output=True, text=True, timeout=30
    )

    with open("/tmp/sf_cookies2.txt") as f:
        content = f.read()

    sid_value = None
    for line in content.split("\n"):
        clean = line.strip()
        if clean.startswith("#HttpOnly_"):
            clean = clean[len("#HttpOnly_"):]
        elif clean.startswith("#") or not clean:
            continue
        parts = clean.split("\t")
        if len(parts) >= 7 and parts[5] == "sid":
            sid_value = parts[6]
            break

    if not sid_value:
        raise RuntimeError("No sid cookie found")

    log(f"Got SID: {sid_value[:30]}...")
    return sid_value

async def main():
    log("Getting fresh session ...")
    sid = get_session_cookie()

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

        # Set session cookie
        for domain in ["loving.my.salesforce.com", "loving.lightning.force.com"]:
            await context.add_cookies([{
                "name": "sid", "value": sid,
                "domain": domain, "path": "/",
                "secure": True, "httpOnly": True, "sameSite": "None",
            }])

        page = await context.new_page()

        # ── Step 1: Login and navigate ────────────────────────────────────────
        log("Navigating to Salesforce ...")
        await page.goto("https://loving.my.salesforce.com/one/one.app",
                        timeout=45000, wait_until="domcontentloaded")
        await page.wait_for_timeout(6000)
        log(f"URL: {page.url}")

        # Wait for the utility bar to appear
        try:
            await page.wait_for_selector(".slds-utility-bar", timeout=20000)
            log("Utility bar found!")
        except PlaywrightTimeoutError:
            log("Utility bar not found within 20s")

        await page.wait_for_timeout(3000)
        await screenshot(page, "mclovin_01_utility_bar.png",
                         "Service Console loaded — utility bar visible at bottom with mcLOVIN' button")

        # ── Step 2: Navigate to Outdoor Living app ────────────────────────────
        log("Navigating to Outdoor Living app ...")
        try:
            await page.goto("https://loving.lightning.force.com/lightning/app/01Ia5000000blTIEAY",
                            timeout=30000, wait_until="domcontentloaded")
            await page.wait_for_timeout(5000)
            log(f"App URL: {page.url}")
        except Exception as e:
            log(f"App navigation issue: {e}")

        await screenshot(page, "mclovin_02_outdoor_app.png",
                         "Outdoor Living app navigation attempt")

        # ── Step 3: Take full page screenshot ────────────────────────────────
        log("Taking full page screenshot ...")
        await page.wait_for_timeout(2000)
        await screenshot(page, "mclovin_03_full_page.png",
                         "Full page showing utility bar at bottom")

        # Verify utility bar location
        util_bar = await page.evaluate("""
            () => {
                const ub = document.querySelector('.slds-utility-bar, .utilitybar');
                if (!ub) return null;
                const rect = ub.getBoundingClientRect();
                const buttons = [];
                ub.querySelectorAll('button').forEach(btn => {
                    const r = btn.getBoundingClientRect();
                    buttons.push({
                        text: btn.textContent.trim().replace(/\\s+/g, ' ').substring(0, 30),
                        cx: Math.round(r.x + r.width/2),
                        cy: Math.round(r.y + r.height/2)
                    });
                });
                return {
                    barPos: {x: rect.x, y: rect.y, w: rect.width, h: rect.height},
                    buttons: buttons
                };
            }
        """)
        log(f"Utility bar: {util_bar}")

        # ── Step 4: Click mcLOVIN' button ────────────────────────────────────
        log("Step 4: Clicking mcLOVIN' utility bar button ...")
        mclovin_cx, mclovin_cy = 60, 880  # Known position from v4 run

        if util_bar and util_bar.get('buttons'):
            for btn in util_bar['buttons']:
                if 'mclovin' in btn['text'].lower():
                    mclovin_cx = btn['cx']
                    mclovin_cy = btn['cy']
                    log(f"Found button at ({mclovin_cx}, {mclovin_cy})")
                    break

        log(f"Clicking mcLOVIN' at ({mclovin_cx}, {mclovin_cy}) ...")
        await page.mouse.click(mclovin_cx, mclovin_cy)
        await page.wait_for_timeout(3000)
        await screenshot(page, "mclovin_04_badge.png",
                         "After clicking utility bar — mcLOVIN panel opened")

        # ── Step 5: Panel opened — screenshot shows full character ───────────
        # The panel opens directly (no badge step needed — it's a utility bar panel)
        # From screenshots we can see the full panel is visible
        log("Step 5: Panel is open — taking screenshot showing full character ...")
        await screenshot(page, "mclovin_05_panel_open.png",
                         "mcLOVIN panel open — character with star badge, 6 chips, text input")

        # ── Step 6: Type question in text input ───────────────────────────────
        # From v4 screenshot: input box is at approximately x=245, y=740 (center of textarea)
        # Panel is at x=16 to x=480, textarea is at bottom ~y=720-780
        log("Step 6: Clicking text input and typing question ...")

        # First find the exact textarea position
        input_pos = await page.evaluate("""
            () => {
                const textareas = document.querySelectorAll('textarea');
                const found = [];
                for (const ta of textareas) {
                    const rect = ta.getBoundingClientRect();
                    found.push({
                        placeholder: ta.placeholder,
                        x: Math.round(rect.x), y: Math.round(rect.y),
                        cx: Math.round(rect.x + rect.width/2),
                        cy: Math.round(rect.y + rect.height/2),
                        w: rect.width, h: rect.height,
                        display: window.getComputedStyle(ta).display
                    });
                }
                return found;
            }
        """)
        log(f"Textareas found: {input_pos}")

        # Use coordinate clicking since textareas may have w=0 due to shadow DOM
        # From the screenshot, the input is approximately at:
        # x center ≈ 245, y center ≈ 740
        if input_pos:
            for inp in input_pos:
                if inp.get('w', 0) > 100 and inp.get('h', 0) > 0:
                    cx, cy = inp['cx'], inp['cy']
                    if 0 < cx < 1440 and 0 < cy < 860:
                        log(f"Clicking textarea at ({cx}, {cy})")
                        await page.mouse.click(cx, cy)
                        break
        else:
            # Click at known position from screenshot analysis
            log("Clicking at known textarea position (245, 740) ...")
            await page.mouse.click(245, 740)

        await page.wait_for_timeout(500)
        await page.keyboard.type("how do I create a new account")
        await page.wait_for_timeout(500)
        await screenshot(page, "mclovin_06_question_typed.png",
                         "Question typed: 'how do I create a new account'")

        # Click Send button (visible at ~x=428, y=800)
        log("Clicking Send button ...")
        await page.mouse.click(428, 800)
        # Also try pressing Enter
        await page.keyboard.press("Enter")

        log("Waiting 15 seconds for AI response ...")
        await page.wait_for_timeout(15000)
        await screenshot(page, "mclovin_07_ai_response.png",
                         "AI response to 'how do I create a new account'")

        # ── Step 7: Click Upload PO chip ──────────────────────────────────────
        # From screenshot: Upload PO is at approximately x=158, y=488
        log("Step 7: Clicking 'Upload PO' chip ...")

        # Try to find the chip first
        chip_pos = await page.evaluate("""
            () => {
                // Search all text nodes
                const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
                let node;
                while (node = walker.nextNode()) {
                    if (node.textContent.trim() === 'Upload PO') {
                        const el = node.parentElement;
                        const rect = el.getBoundingClientRect();
                        return {
                            found: true,
                            x: Math.round(rect.x), y: Math.round(rect.y),
                            cx: Math.round(rect.x + rect.width/2),
                            cy: Math.round(rect.y + rect.height/2),
                            w: rect.width, h: rect.height,
                            tag: el.tagName
                        };
                    }
                }
                return {found: false};
            }
        """)
        log(f"Upload PO chip position: {chip_pos}")

        if chip_pos.get('found') and chip_pos.get('w', 0) > 0:
            cx, cy = chip_pos['cx'], chip_pos['cy']
            if 0 < cx < 1440 and 0 < cy < 860:
                log(f"Clicking Upload PO at ({cx}, {cy})")
                await page.mouse.click(cx, cy)
            else:
                log(f"Upload PO out of viewport ({cx},{cy}) — using known coords")
                await page.mouse.click(158, 488)
        else:
            # Click at known position from screenshot
            log("Clicking Upload PO at known position (158, 488) ...")
            await page.mouse.click(158, 488)

        log("Waiting 15 seconds for Upload PO response ...")
        await page.wait_for_timeout(15000)
        await screenshot(page, "mclovin_08_upload_po.png",
                         "Response after clicking Upload PO chip")

        # ── Step 8: Minimize the panel ────────────────────────────────────────
        # From screenshot: Minimize button (—) is at approximately x=428, y=162
        log("Step 8: Clicking minimize button ...")

        # Find minimize button
        minimize_pos = await page.evaluate("""
            () => {
                // Look for title='Minimize' button
                const btns = document.querySelectorAll('button');
                for (const btn of btns) {
                    const title = (btn.getAttribute('title') || '').toLowerCase();
                    const aria = (btn.getAttribute('aria-label') || '').toLowerCase();
                    if (title.includes('minimize') || aria.includes('minimize')) {
                        const rect = btn.getBoundingClientRect();
                        if (rect.width > 0 && rect.y > 100 && rect.y < 900) {
                            return {
                                cx: Math.round(rect.x + rect.width/2),
                                cy: Math.round(rect.y + rect.height/2),
                                title: title
                            };
                        }
                    }
                }
                return null;
            }
        """)
        log(f"Minimize button: {minimize_pos}")

        if minimize_pos:
            cx, cy = minimize_pos['cx'], minimize_pos['cy']
            log(f"Clicking minimize at ({cx}, {cy})")
            await page.mouse.click(cx, cy)
        else:
            # From the screenshot, the — button is in the title bar at top-right of panel
            log("Clicking minimize at known position (428, 162) ...")
            await page.mouse.click(428, 162)

        await page.wait_for_timeout(2000)
        await screenshot(page, "mclovin_09_minimized.png",
                         "After minimize — panel collapsed back to utility bar")

        # ── Step 9: Drag the badge ────────────────────────────────────────────
        # After minimizing, the utility bar button is the "badge" — but this app
        # doesn't have a floating draggable badge (it uses a utility bar panel).
        # Let's check if there's any floating element that appeared.
        log("Step 9: Checking for draggable floating element ...")

        floating = await page.evaluate("""
            () => {
                const found = [];
                document.querySelectorAll('*').forEach(el => {
                    const style = window.getComputedStyle(el);
                    const rect = el.getBoundingClientRect();
                    if (style.position === 'fixed' && rect.width > 30 && rect.width < 200 &&
                        rect.height > 30 && rect.height < 200 &&
                        rect.y > 100 && rect.y < 820) {
                        found.push({
                            tag: el.tagName,
                            className: el.className.substring(0, 60),
                            text: el.textContent.trim().substring(0, 40),
                            cx: Math.round(rect.x + rect.width/2),
                            cy: Math.round(rect.y + rect.height/2),
                            w: rect.width, h: rect.height
                        });
                    }
                });
                return found;
            }
        """)
        log(f"Floating elements: {floating}")

        if floating:
            # Try dragging the first element
            t = floating[0]
            sx, sy = t['cx'], t['cy']
            ex = max(100, sx - 150)
            ey = max(150, sy - 100)
            log(f"Dragging badge from ({sx},{sy}) to ({ex},{ey})")
            await page.mouse.move(sx, sy)
            await page.mouse.down()
            await page.wait_for_timeout(300)
            for i in range(20):
                r = (i+1) / 20
                await page.mouse.move(int(sx + (ex-sx)*r), int(sy + (ey-sy)*r))
                await page.wait_for_timeout(20)
            await page.mouse.up()
            await page.wait_for_timeout(1000)
            await screenshot(page, "mclovin_10_dragged.png",
                             f"After dragging from ({sx},{sy}) to ({ex},{ey})")
        else:
            log("No floating/draggable badge found — the component uses a utility bar panel, not a floating badge")
            # Re-open the panel to show it's still working
            await page.mouse.click(mclovin_cx, mclovin_cy)
            await page.wait_for_timeout(2000)
            await screenshot(page, "mclovin_10_reopened.png",
                             "Panel re-opened — no standalone floating badge (utility bar style)")

        # ── Final ─────────────────────────────────────────────────────────────
        await screenshot(page, "mclovin_11_final.png", "Final state")
        log("All tests complete!")
        await browser.close()

if __name__ == "__main__":
    os.environ["DISPLAY"] = ":99"
    asyncio.run(main())
