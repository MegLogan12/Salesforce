#!/usr/bin/env python3
"""
Take screenshots of the utility items for key apps showing
Ask mcLOVIN' Start Automatically is ON.

Uses direct app editor URLs from the CustomApplication IDs.
"""

import os
import sys
import time
import subprocess
import urllib.parse
from playwright.sync_api import sync_playwright

INSTANCE_URL = "https://loving.my.salesforce.com"
LF_URL = "https://loving.lightning.force.com"
SCREENSHOT_DIR = "/home/user/Salesforce/screenshots"
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

for f in os.listdir(SCREENSHOT_DIR):
    os.remove(os.path.join(SCREENSHOT_DIR, f))

counter = [0]
def ss(page, name):
    counter[0] += 1
    path = f"{SCREENSHOT_DIR}/{counter[0]:03d}_{name}.png"
    try:
        page.screenshot(path=path, full_page=False)
        print(f"  [ss] {path}")
    except Exception as e:
        print(f"  [ss error] {e}")
    return path

def wait_for_sf(page, timeout=20000):
    try:
        page.wait_for_load_state("networkidle", timeout=timeout)
    except Exception:
        pass
    time.sleep(1)

def get_token():
    result = subprocess.run(["sf", "org", "display", "--target-org", "dispatch"], capture_output=True, text=True)
    for line in result.stdout.split('\n'):
        if 'Access Token' in line:
            parts = line.split('│')
            if len(parts) >= 3:
                return parts[2].strip()
    return None

# Key apps with mcLOVIN' that need screenshots
# Format: (display_name, app_id, short_name)
KEY_APPS = [
    ("Outdoor Living Console", "02uVu000000scJdIAI", "outdoor_living"),
    ("Outdoor Living", "02uVu000000v8goIAA", "outdoor_living_v2"),
    ("LOVING Field Service / Field Services", "02uVu000000iJLVIA2", "field_services"),
    ("Customer Success Service Console", "02uVu000000v8aLIAQ", "customer_success"),
    ("Sales Console", "02ua5000005jLVXAA2", "sales_console"),
    ("Service Console", "02uVu000000hps5IAA", "service_console"),
    ("Sales (Lightning)", "02ua5000005jLVIAA2", "sales_app"),
    ("Home", "02ua5000005lgx1AAA", "home_app"),
    ("LOVING Field Service (Field Service)", "02uVu000000iIyvIAE", "field_service_v2"),
]

def open_app_editor(page, app_id, display_name):
    """Navigate directly to the app editor."""
    url = f"{LF_URL}/visualEditor/appBuilder.app?id={app_id}"
    print(f"  Navigating to: {url}")
    page.goto(url, timeout=60000)
    wait_for_sf(page, timeout=25000)
    time.sleep(3)

def click_utility_items(page, app_name):
    """Click 'Utility Items (Desktop Only)' tab."""
    try:
        tab = page.locator("text=Utility Items (Desktop Only)").first
        tab.wait_for(state="visible", timeout=20000)
        tab.click()
        wait_for_sf(page, timeout=10000)
        time.sleep(2)
        return True
    except Exception as e:
        print(f"  No utility items tab: {e}")
        return False

def main():
    display = ":99"
    try:
        subprocess.run(["pkill", "Xvfb"], capture_output=True)
        subprocess.run(["pkill", "-f", "chromium"], capture_output=True)
        time.sleep(1)
    except Exception:
        pass

    xvfb = subprocess.Popen(
        ["Xvfb", display, "-screen", "0", "1920x1080x24"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    time.sleep(2)
    os.environ["DISPLAY"] = display
    print("Xvfb started")

    token = get_token()
    if not token:
        print("ERROR: No token")
        xvfb.terminate()
        sys.exit(1)

    sid_enc = urllib.parse.quote(token)
    login_url = f"{INSTANCE_URL}/secur/frontdoor.jsp?sid={sid_enc}"

    results = {}

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(
                headless=False,
                args=["--no-sandbox", "--disable-dev-shm-usage",
                      f"--display={display}", "--window-size=1920,1080",
                      "--ignore-certificate-errors"]
            )
            ctx = browser.new_context(
                viewport={"width": 1920, "height": 1080},
                ignore_https_errors=True
            )
            page = ctx.new_page()
            page.set_default_timeout(60000)
            page.set_default_navigation_timeout(60000)

            # Login
            print("Logging in...")
            page.goto(login_url, timeout=60000)
            wait_for_sf(page, timeout=20000)
            ss(page, "00_login")
            print(f"  URL: {page.url}")

            for display_name, app_id, short_name in KEY_APPS:
                print(f"\n{'='*55}")
                print(f"APP: {display_name}")

                # Open app editor directly
                open_app_editor(page, app_id, display_name)
                ss(page, f"editor_{short_name}")
                print(f"  Editor URL: {page.url[:80]}")

                # Check if we landed on the editor
                if "appBuilder" not in page.url and "visualEditor" not in page.url:
                    print(f"  Not in app editor - might be redirected")
                    results[display_name] = "redirected"
                    continue

                # Click Utility Items tab
                has_util = click_utility_items(page, display_name)
                ss(page, f"util_{short_name}")

                if not has_util:
                    results[display_name] = "no_utility_tab"
                    continue

                # Check for Ask mcLOVIN'
                mclovin_found = False
                for pattern in ["Ask mcLOVIN'", "Ask mcLOVIN", "mcLOVIN"]:
                    try:
                        el = page.locator(f"text={pattern}").first
                        el.wait_for(state="visible", timeout=6000)
                        mclovin_found = True
                        print(f"  Found '{pattern}'!")

                        # Click to expand
                        el.click()
                        time.sleep(1.5)
                        wait_for_sf(page, timeout=8000)
                        ss(page, f"mcl_expanded_{short_name}")
                        break
                    except Exception:
                        continue

                if not mclovin_found:
                    print(f"  Ask mcLOVIN' NOT FOUND")
                    results[display_name] = "no_mclovin"
                    continue

                # Check Start Automatically status
                try:
                    sa = page.locator("text=Start Automatically").first
                    sa.wait_for(state="visible", timeout=8000)
                    print(f"  'Start Automatically' is visible")
                except Exception as e:
                    print(f"  'Start Automatically' not visible: {e}")
                    ss(page, f"mcl_no_sa_{short_name}")
                    results[display_name] = "start_auto_not_visible"
                    continue

                # Get checkbox state
                js = page.evaluate("""() => {
                    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
                    let n;
                    while (n = walker.nextNode()) {
                        const t = n.textContent.trim();
                        if (t === 'Start Automatically' || t === 'Start automatically') {
                            let el = n.parentElement;
                            for (let i = 0; i < 15; i++) {
                                if (!el) break;
                                const cb = el.querySelector('input[type="checkbox"]');
                                if (cb) return {found: true, checked: cb.checked, id: cb.id};
                                el = el.parentElement;
                            }
                        }
                    }
                    return {found: false};
                }""")

                is_checked = js.get("checked")
                print(f"  'Start Automatically' checked: {is_checked}")
                ss(page, f"mcl_start_auto_{short_name}")

                if is_checked:
                    results[display_name] = "already_set_confirmed"
                    print(f"  CONFIRMED: Start Automatically is already ON")
                else:
                    print(f"  WARNING: Start Automatically is OFF! Enabling...")
                    # Enable it
                    cb_id = js.get("id")
                    if cb_id:
                        page.evaluate(f"() => {{ const cb = document.getElementById('{cb_id}'); if(cb) cb.click(); }}")
                    else:
                        page.evaluate("""() => {
                            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
                            let n;
                            while (n = walker.nextNode()) {
                                if (n.textContent.trim() === 'Start Automatically') {
                                    let el = n.parentElement;
                                    for (let i = 0; i < 15; i++) {
                                        if (!el) break;
                                        const cb = el.querySelector('input[type="checkbox"]');
                                        if (cb) { cb.click(); return; }
                                        el = el.parentElement;
                                    }
                                }
                            }
                        }""")
                    time.sleep(0.5)
                    ss(page, f"mcl_after_enable_{short_name}")

                    # Save
                    try:
                        save_btn = page.locator("button:has-text('Save')").first
                        save_btn.wait_for(state="visible", timeout=10000)
                        save_btn.click()
                        wait_for_sf(page, timeout=20000)
                        time.sleep(3)
                        ss(page, f"mcl_saved_{short_name}")
                        results[display_name] = "enabled_and_saved"
                        print(f"  ENABLED and SAVED!")
                    except Exception as e:
                        print(f"  Save error: {e}")
                        results[display_name] = "enabled_save_error"

            # Print summary
            print("\n" + "="*55)
            print("SUMMARY")
            print("="*55)
            for app, result in results.items():
                print(f"  [{result}] {app}")

            browser.close()

    finally:
        xvfb.terminate()
        print("\nDone. Screenshots in:", SCREENSHOT_DIR)

if __name__ == "__main__":
    main()
