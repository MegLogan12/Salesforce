#!/usr/bin/env python3
"""Quick test to specifically test the Upload PO chip."""

import os, time, asyncio, subprocess
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError

SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots"
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

async def screenshot(page, name, desc=""):
    path = f"{SCREENSHOTS_DIR}/{name}"
    await page.screenshot(path=path, full_page=False)
    log(f"Screenshot: {name} — {desc}")

def get_sid():
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
    subprocess.run(["curl", "-s", "-L", "--max-redirs", "3",
                    "-c", "/tmp/sf_chip_cookies.txt", "-o", "/dev/null",
                    frontdoor_url], capture_output=True, text=True, timeout=30)
    with open("/tmp/sf_chip_cookies.txt") as f:
        content = f.read()
    for line in content.split("\n"):
        clean = line.strip()
        if clean.startswith("#HttpOnly_"):
            clean = clean[len("#HttpOnly_"):]
        elif clean.startswith("#") or not clean:
            continue
        parts = clean.split("\t")
        if len(parts) >= 7 and parts[5] == "sid":
            return parts[6]
    raise RuntimeError("No sid found")

async def main():
    sid = get_sid()
    log(f"Got SID: {sid[:30]}...")

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=False,
            args=["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage",
                  "--disable-gpu", "--window-size=1440,900"],
        )
        context = await browser.new_context(viewport={"width": 1440, "height": 900}, ignore_https_errors=True)
        for domain in ["loving.my.salesforce.com", "loving.lightning.force.com"]:
            await context.add_cookies([{"name": "sid", "value": sid, "domain": domain,
                                        "path": "/", "secure": True, "httpOnly": True, "sameSite": "None"}])
        page = await context.new_page()

        # Login and wait for app
        await page.goto("https://loving.my.salesforce.com/one/one.app", timeout=45000, wait_until="domcontentloaded")
        try:
            await page.wait_for_selector(".slds-utility-bar", timeout=20000)
        except:
            pass
        await page.wait_for_timeout(3000)

        # Click mcLOVIN' to open panel (closed state)
        log("Opening mcLOVIN panel ...")
        await page.mouse.click(60, 880)
        await page.wait_for_timeout(3000)
        await screenshot(page, "mclovin_chip_01_panel_open.png", "Panel just opened — chip grid visible")

        # Click the reset/refresh button (the circular arrow icon) to clear any conversation
        log("Clicking reset button to clear conversation ...")
        await page.mouse.click(420, 213)  # Approximate position of refresh/reset icon
        await page.wait_for_timeout(2000)
        await screenshot(page, "mclovin_chip_02_after_reset.png", "After reset — should show chip grid")

        # Now click Upload PO chip
        # From screenshot analysis: Upload PO chip is at approximately x=158, y=488
        # Panel starts at x=16, width=480
        # Chip grid row 1: y≈488, row 2: y≈531, row 3: y≈575
        # Upload PO is first chip in row 1
        log("Clicking Upload PO chip at (158, 488) ...")
        await page.mouse.click(158, 488)
        await page.wait_for_timeout(15000)
        await screenshot(page, "mclovin_chip_03_upload_po_response.png", "Upload PO chip response")

        # Also take a screenshot of what the chip grid looks like (should be visible now)
        await screenshot(page, "mclovin_chip_04_final.png", "Final state after Upload PO")

        await browser.close()
        log("Done!")

if __name__ == "__main__":
    os.environ["DISPLAY"] = ":99"
    asyncio.run(main())
