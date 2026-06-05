"""
Playwright test for "Ask mcLOVIN'" floating AI assistant in Salesforce org.
"""

import os
import time
from playwright.sync_api import sync_playwright

LOGIN_URL = "https://loving.my.salesforce.com/secur/frontdoor.jsp?otp=00Da500001UEK0H%21AQEAQCWOnO_wvZZI2cuAZWjxhR_Ezrqbv0X8ooS5OVO2oBTueyZqxIo2PCA.NxM4ceCjQ9kHMut7vzoBTxyv1kxGvs_.laML&cshc=500001mhIYb500001UEK0H"
APP_URL = "https://loving.my.salesforce.com/lightning/app/01Ia5000000blTIEAY"
SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots"

os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

def save_screenshot(page, name, description=""):
    path = os.path.join(SCREENSHOTS_DIR, name)
    page.screenshot(path=path, full_page=False)
    print(f"[SCREENSHOT] {name}: {description}")
    return path

def find_mclovin_button(page):
    """Find the Ask mcLOVIN' button in the utility bar."""
    # Try various selectors
    selectors = [
        "button[title*='mcLOVIN']",
        "button[title*='LOVIN']",
        "[class*='utility'] button",
        "button:has-text('mcLOVIN')",
        "button:has-text('LOVIN')",
        ".utilitybar button",
        "[data-aura-class*='utility'] button",
        "//button[contains(., 'mcLOVIN')]",
        "//button[contains(., 'LOVIN')]",
        "//button[contains(@title, 'mcLOVIN')]",
        "//button[contains(@title, 'LOVIN')]",
        "//button[contains(@aria-label, 'mcLOVIN')]",
        "//button[contains(@aria-label, 'LOVIN')]",
    ]

    for sel in selectors:
        try:
            if sel.startswith("//"):
                el = page.locator(f"xpath={sel}").first
            else:
                el = page.locator(sel).first
            if el.count() > 0 and el.is_visible(timeout=1000):
                print(f"  Found mcLOVIN button with selector: {sel}")
                return el
        except Exception as e:
            pass
    return None

def run_test():
    with sync_playwright() as p:
        print("=== Starting mcLOVIN' Playwright Test ===\n")

        browser = p.chromium.launch(
            headless=False,
            args=["--no-sandbox", "--disable-dev-shm-usage", f"--display=:99"]
        )

        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True
        )
        page = context.new_page()

        # ── STEP 1: Login ──────────────────────────────────────────────────
        print("STEP 1: Navigating to Salesforce login URL...")
        try:
            page.goto(LOGIN_URL, wait_until="networkidle", timeout=45000)
        except Exception as e:
            print(f"  Warning during login navigation: {e}")
            page.goto(LOGIN_URL, timeout=45000)

        time.sleep(3)
        save_screenshot(page, "mclovin_01_after_login.png", "After login navigation")
        print(f"  Current URL: {page.url}")

        # ── STEP 2: Navigate to Outdoor Living app ─────────────────────────
        print("\nSTEP 2: Navigating to Outdoor Living app...")
        try:
            page.goto(APP_URL, wait_until="networkidle", timeout=45000)
        except Exception as e:
            print(f"  Warning during app navigation: {e}")

        time.sleep(5)
        print(f"  Current URL: {page.url}")
        save_screenshot(page, "mclovin_02_outdoor_living_app.png", "Outdoor Living app loaded")

        # ── STEP 3: Look for utility bar and mcLOVIN button ────────────────
        print("\nSTEP 3: Looking for utility bar and mcLOVIN' button...")

        # Wait a bit more for utility bar to fully render
        time.sleep(3)

        # First, let's dump what's in the utility bar area
        try:
            util_bar = page.locator(".oneUtilityBar, [class*='utilityBar'], .slds-utility-bar")
            if util_bar.count() > 0:
                print(f"  Found utility bar element: {util_bar.count()} matches")
                inner = util_bar.first.inner_html()
                print(f"  Utility bar HTML snippet (500 chars): {inner[:500]}")
        except Exception as e:
            print(f"  Could not inspect utility bar: {e}")

        # Look for all buttons in utility bar area
        try:
            all_buttons = page.locator("button")
            btn_count = all_buttons.count()
            print(f"  Total buttons on page: {btn_count}")
            for i in range(min(btn_count, 30)):
                btn = all_buttons.nth(i)
                try:
                    title = btn.get_attribute("title") or ""
                    aria = btn.get_attribute("aria-label") or ""
                    text = btn.inner_text() or ""
                    if any(kw in (title + aria + text).lower() for kw in ["lovin", "mclovin", "ask", "ai"]):
                        print(f"  Button {i}: title='{title}' aria='{aria}' text='{text[:50]}'")
                except:
                    pass
        except Exception as e:
            print(f"  Could not list buttons: {e}")

        mclovin_btn = find_mclovin_button(page)

        if mclovin_btn:
            print("  mcLOVIN' button FOUND in utility bar!")
            save_screenshot(page, "mclovin_03_utility_bar_found.png", "Utility bar with mcLOVIN button visible")

            # ── STEP 4: Click the button ───────────────────────────────────
            print("\nSTEP 4: Clicking mcLOVIN' button...")
            mclovin_btn.click()
            time.sleep(3)
            save_screenshot(page, "mclovin_04_after_click_badge.png", "After clicking - looking for badge")

            # Look for the floating badge/character
            badge_selectors = [
                "[class*='mclovin']",
                "[class*='mcLOVIN']",
                "[class*='floating']",
                "[class*='avatar']",
                "[class*='badge']",
                "[class*='assistant']",
                "img[alt*='mcLOVIN']",
                "img[alt*='LOVIN']",
            ]
            badge_found = False
            for sel in badge_selectors:
                try:
                    el = page.locator(sel).first
                    if el.count() > 0 and el.is_visible(timeout=2000):
                        print(f"  Found badge with selector: {sel}")
                        badge_found = True
                        break
                except:
                    pass

            if badge_found:
                print("  Badge/character APPEARED!")
                save_screenshot(page, "mclovin_04b_badge_visible.png", "Floating badge visible")

                # ── STEP 5: Click badge to open full panel ─────────────────
                print("\nSTEP 5: Clicking badge to open full panel...")
                page.locator(sel).first.click()
                time.sleep(2)
                save_screenshot(page, "mclovin_05_full_panel.png", "Full panel opened")

            else:
                print("  Badge not found by specific selectors, checking for any new elements...")
                save_screenshot(page, "mclovin_04b_no_badge.png", "No badge found after click")
        else:
            print("  mcLOVIN' button NOT found by specific selectors")
            print("  Checking utility bar buttons by text content...")

            # Try to find any utility bar items
            try:
                # Salesforce utility bar is typically in a specific region
                body_html = page.content()
                if "mcLOVIN" in body_html or "mclovin" in body_html.lower():
                    print("  'mcLOVIN' found in page HTML!")
                    # Find position in HTML
                    idx = body_html.lower().find("mclovin")
                    print(f"  Context: ...{body_html[max(0,idx-100):idx+200]}...")
                elif "LOVIN" in body_html:
                    idx = body_html.find("LOVIN")
                    print(f"  'LOVIN' found in HTML. Context: ...{body_html[max(0,idx-100):idx+200]}...")
                else:
                    print("  'mcLOVIN' NOT found in page HTML at all")
            except Exception as e:
                print(f"  HTML search error: {e}")

            save_screenshot(page, "mclovin_03_no_button.png", "Utility bar without mcLOVIN button")

        # Regardless of button state, let's look for any open AI panel
        print("\nChecking for any open AI assistant panel...")
        panel_selectors = [
            "[class*='panel']",
            "[class*='chat']",
            "[class*='assistant']",
            "[role='dialog']",
            "[aria-label*='mcLOVIN']",
            "[aria-label*='LOVIN']",
        ]
        for sel in panel_selectors:
            try:
                el = page.locator(sel)
                if el.count() > 0:
                    print(f"  Found panel with selector: {sel} ({el.count()} matches)")
            except:
                pass

        # ── STEP 6: Check if panel is open - look for text input ──────────
        print("\nSTEP 6: Looking for text input in panel...")
        input_selectors = [
            "input[placeholder*='ask']",
            "input[placeholder*='Ask']",
            "input[placeholder*='type']",
            "textarea[placeholder*='ask']",
            "textarea[placeholder*='Ask']",
            "[class*='chat'] input",
            "[class*='chat'] textarea",
        ]

        input_found = None
        for sel in input_selectors:
            try:
                el = page.locator(sel).first
                if el.count() > 0 and el.is_visible(timeout=1000):
                    print(f"  Found input with: {sel}")
                    input_found = el
                    break
            except:
                pass

        if input_found:
            print("  Typing question into input...")
            input_found.fill("how do I create a new account")
            time.sleep(1)
            save_screenshot(page, "mclovin_06_typed_question.png", "Question typed in input")

            # Try pressing Enter or finding Ask button
            try:
                ask_btn = page.locator("button:has-text('Ask'), button[type='submit']").first
                if ask_btn.count() > 0:
                    ask_btn.click()
                else:
                    input_found.press("Enter")
            except:
                input_found.press("Enter")

            print("  Waiting up to 15 seconds for response...")
            time.sleep(15)
            save_screenshot(page, "mclovin_06_response.png", "Response to question")
        else:
            print("  No chat input found - panel may not be open")

        # Final screenshot
        save_screenshot(page, "mclovin_final.png", "Final state of page")

        # Print all visible text on page for debugging
        print("\n=== Checking page for utility bar content ===")
        try:
            # Look specifically for the utility bar area
            util_items = page.locator("[class*='utility'], [class*='utilityBar']")
            for i in range(util_items.count()):
                item = util_items.nth(i)
                try:
                    text = item.inner_text()
                    if text.strip():
                        print(f"  Utility item {i}: {text[:200]}")
                except:
                    pass
        except Exception as e:
            print(f"  Error checking utility items: {e}")

        print("\n=== Test Complete ===")
        browser.close()

if __name__ == "__main__":
    run_test()
