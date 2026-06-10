#!/usr/bin/env python3
"""
Take screenshots of the utility items for key apps showing
Ask mcLOVIN' Start Automatically status.
"""

import os
import sys
import time
import subprocess
import urllib.parse
from playwright.sync_api import sync_playwright

INSTANCE_URL = "https://loving.my.salesforce.com"
APP_MANAGER_URL = f"{INSTANCE_URL}/lightning/setup/NavigationMenus/home"
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
        print(f"  [screenshot] {path}")
    except Exception as e:
        print(f"  [screenshot error] {e}")
    return path

def wait_for_sf(page, timeout=20000):
    try:
        page.wait_for_load_state("networkidle", timeout=timeout)
    except Exception:
        pass
    try:
        page.wait_for_selector(".slds-spinner_container", state="hidden", timeout=5000)
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

# Apps that have Ask mcLOVIN' - we'll open their app editors to screenshot
# These are the App editor URLs we know work
APPS_WITH_MCLOVIN = [
    # App name -> (app_label_in_manager, AppBuilder_URL_hint)
    ("Outdoor Living", "Outdoor Living UtilityBar"),
    ("LOVING Field Service", "LOVING Field Service UtilityBar"),
    ("Customer Success", "Customer Success Utility Bar"),
    ("Sales Console", "Sales Console App Utility Bar"),
    ("Service Console", "Service Console App Utility Bar"),
    ("Sales App", "Sales App Utility Bar"),
    ("Home App", "Home App Utility Bar"),
]

def main():
    display = ":99"
    try:
        subprocess.run(["pkill", "Xvfb"], capture_output=True)
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

            # Go to App Manager
            print("\nGoing to App Manager...")
            page.goto(APP_MANAGER_URL, timeout=60000)
            wait_for_sf(page, timeout=25000)
            time.sleep(3)
            ss(page, "01_app_manager")
            print(f"  URL: {page.url}")

            # Find table frame and print all visible apps
            all_frames = page.frames
            table_frame = None
            for f in all_frames:
                try:
                    rows = f.query_selector_all("table tbody tr")
                    if rows and len(rows) > 0:
                        table_frame = f
                        print(f"  Table frame: {f.url[:60]}")
                        break
                except Exception:
                    pass

            if table_frame:
                apps_data = table_frame.evaluate("""() => {
                    const rows = document.querySelectorAll('table tbody tr');
                    return Array.from(rows).map((row, i) => {
                        const cells = row.querySelectorAll('td');
                        return {
                            i,
                            col1: cells[1] ? cells[1].textContent.trim() : '',
                            col2: cells[2] ? cells[2].textContent.trim() : '',
                            col5: cells[5] ? cells[5].textContent.trim() : ''
                        };
                    }).filter(r => r.col1);
                }""")
                print(f"  Visible apps in table ({len(apps_data)}):")
                for a in apps_data:
                    print(f"    [{a['i']}] {a['col1']} / {a['col2']} [{a['col5']}]")
                ss(page, "02_app_table_visible")

            # For each priority app with mcLOVIN, find it in the manager and open editor
            # We'll search for it using the table_frame data we have
            # Key apps to target: Outdoor Living Console, Field Service, etc.

            target_app_names = [
                ("Outdoor Living Console", "Outdoor_Living"),
                ("Customer_Success_Service_Console", "Customer_Success"),
                ("LOVING Field Service", "LOVING_Field"),
                ("LightningSalesConsole", "Sales_Console"),
                ("LightningService", "Service_Console"),
                ("LightningSales", "Sales_App"),
                ("EasyHome", "Home_App"),
            ]

            # Use the apps_data to find matches
            if table_frame:
                for search_name, label_short in target_app_names:
                    print(f"\n--- Looking for '{search_name}' ---")

                    # Find matching row
                    match = None
                    for a in apps_data:
                        if (search_name.lower() in a['col1'].lower() or
                                a['col1'].lower() in search_name.lower() or
                                search_name.lower() in a['col2'].lower()):
                            match = a
                            print(f"  Match: row {a['i']}, '{a['col1']}' / '{a['col2']}'")
                            break

                    if not match:
                        print(f"  Not in visible 21 rows - skipping (will try API approach)")
                        continue

                    # Click dropdown and Edit for this app
                    row_idx = match['i']
                    result = table_frame.evaluate(f"""() => {{
                        const rows = document.querySelectorAll('table tbody tr');
                        const row = rows[{row_idx}];
                        if (!row) return 'no_row';
                        const buttons = row.querySelectorAll('button, a[role="button"]');
                        if (buttons.length === 0) return 'no_buttons';
                        buttons[buttons.length - 1].click();
                        return 'clicked_' + buttons.length;
                    }}""")
                    print(f"  Dropdown click result: {result}")
                    time.sleep(1)
                    ss(page, f"03_dd_{label_short}")

                    # Click Edit
                    for ctx2 in [page, table_frame]:
                        try:
                            edit = ctx2.locator("a:has-text('Edit')").first
                            edit.wait_for(state="visible", timeout=5000)
                            edit.click()
                            wait_for_sf(page, timeout=20000)
                            time.sleep(2)
                            ss(page, f"04_editor_{label_short}")
                            print(f"  Editor: {page.url[:80]}")

                            # Click Utility Items tab
                            try:
                                ut = page.locator("text=Utility Items (Desktop Only)").first
                                ut.wait_for(state="visible", timeout=15000)
                                ut.click()
                                wait_for_sf(page, timeout=10000)
                                time.sleep(1.5)
                                ss(page, f"05_util_{label_short}")
                                print(f"  Utility items loaded")

                                # Find and click Ask mcLOVIN' to show its settings
                                try:
                                    mcl = page.locator("text=Ask mcLOVIN'").first
                                    mcl.wait_for(state="visible", timeout=8000)
                                    mcl.click()
                                    time.sleep(1.5)
                                    ss(page, f"06_mcl_{label_short}")
                                    print(f"  Ask mcLOVIN' expanded - screenshot taken")
                                except Exception as e:
                                    print(f"  Ask mcLOVIN' not found: {e}")
                                    ss(page, f"06_no_mcl_{label_short}")

                            except Exception as e:
                                print(f"  No utility items tab: {e}")
                                ss(page, f"05_no_ut_{label_short}")

                            break
                        except Exception:
                            pass

            # Now use direct app editor URLs for apps we know
            # From earlier run we saw: visualEditor/appBuilder.app?id=02ua5000005jLV...
            # Let me try the Tooling API to get app IDs
            # For now, let's also query to find the right app IDs

            print("\n\nAll done. Screenshots saved to:", SCREENSHOT_DIR)
            browser.close()

    finally:
        xvfb.terminate()
        print("Done.")

if __name__ == "__main__":
    main()
