#!/usr/bin/env python3
"""
Final version: Use App Manager search box to find specific apps and enable
"Start Automatically" for "Ask mcLOVIN'" utility item.

Known Lightning apps from AppMenuItem API query (TabSet type).
"""

import os
import sys
import time
import json
import subprocess
import urllib.parse
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

INSTANCE_URL = "https://loving.my.salesforce.com"
APP_MANAGER_URL = f"{INSTANCE_URL}/lightning/setup/NavigationMenus/home"
SCREENSHOT_DIR = "/home/user/Salesforce/screenshots"
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

# Clear old screenshots
for f in os.listdir(SCREENSHOT_DIR):
    os.remove(os.path.join(SCREENSHOT_DIR, f))

screenshot_counter = [0]

def ss(page, name):
    screenshot_counter[0] += 1
    path = f"{SCREENSHOT_DIR}/{screenshot_counter[0]:03d}_{name}.png"
    try:
        page.screenshot(path=path, full_page=False)
        print(f"  [ss] {path}")
    except Exception as e:
        print(f"  [ss error] {e}")
    return path

def wait_for_sf(page, timeout=20000):
    """Wait for Salesforce - shorter timeout to not block."""
    try:
        page.wait_for_load_state("networkidle", timeout=timeout)
    except Exception:
        pass
    try:
        page.wait_for_selector(".slds-spinner_container", state="hidden", timeout=5000)
    except Exception:
        pass
    time.sleep(1)

def get_access_token():
    result = subprocess.run(
        ["sf", "org", "display", "--target-org", "dispatch"],
        capture_output=True, text=True
    )
    for line in result.stdout.split('\n'):
        if 'Access Token' in line:
            parts = line.split('│')
            if len(parts) >= 3:
                return parts[2].strip()
    return None

def find_frame_with_table(page, timeout_s=15):
    """Find frame containing the app table."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        for f in page.frames:
            try:
                rows = f.query_selector_all("table tbody tr")
                if rows and len(rows) > 0:
                    # Verify it has actual content
                    first = rows[0].inner_text().strip()
                    if first:
                        return f, rows
            except Exception:
                pass
        time.sleep(0.5)
    return None, []

def clear_search_and_reload(page):
    """Go back to App Manager with no filters."""
    page.goto(APP_MANAGER_URL, timeout=60000)
    wait_for_sf(page, timeout=25000)
    time.sleep(2)

def search_app_manager(page, search_term):
    """Use the search box in App Manager to filter apps."""
    # Navigate to App Manager
    clear_search_and_reload(page)

    # Find the search input
    search_input = None

    # Check all frames for search input
    for f in page.frames:
        try:
            inp = f.locator("input[placeholder*='earch'], input[type='search']").first
            inp.wait_for(state="visible", timeout=3000)
            search_input = inp
            print(f"  Search box found in frame: {f.url[:50]}")
            break
        except Exception:
            pass

    if not search_input:
        # Check main page
        try:
            inp = page.locator("input[placeholder*='earch'], input[type='search']").first
            inp.wait_for(state="visible", timeout=3000)
            search_input = inp
            print(f"  Search box found in main page")
        except Exception:
            print(f"  No search box found, proceeding without filter")

    if search_input:
        search_input.click()
        search_input.fill(search_term)
        time.sleep(2)
        wait_for_sf(page, timeout=8000)

    return find_frame_with_table(page)

def safe_name(s, maxlen=18):
    return s.replace(' ', '_').replace("'", "").replace("/", "_")[:maxlen]

def click_edit_on_row(page, frame, rows, app_display_name):
    """
    Find the row for app_display_name (or partial match) and click Edit.
    The table columns are: [0]=checkbox, [1]=App Name, [2]=Dev Name, etc.
    """
    target_row = None
    sname = safe_name(app_display_name)

    for row in rows:
        try:
            cells = row.query_selector_all("td")
            if len(cells) < 2:
                continue
            # Check app name (cell 1) - case insensitive partial match
            cell1 = cells[1].inner_text().strip()
            if (app_display_name.lower() in cell1.lower() or
                    cell1.lower() in app_display_name.lower()):
                target_row = row
                print(f"  Matched row: '{cell1}'")
                break
        except Exception:
            continue

    if not target_row:
        print(f"  No matching row for '{app_display_name}'")
        return False

    # Click the dropdown button (last button in the row)
    try:
        buttons = target_row.query_selector_all("button, a[role='button']")
        if not buttons:
            print(f"  No buttons in row")
            return False

        btn = buttons[-1]
        btn.scroll_into_view_if_needed()
        btn.click()
        time.sleep(1)
        ss(page, f"dd_{sname}")
    except Exception as e:
        print(f"  Error clicking dropdown: {e}")
        return False

    # Click Edit
    for ctx in [page, frame]:
        try:
            edit_el = ctx.locator("a:has-text('Edit')").first
            edit_el.wait_for(state="visible", timeout=5000)
            edit_el.click()
            wait_for_sf(page, timeout=20000)
            time.sleep(2)
            print(f"  Editor opened: {page.url[:80]}")
            ss(page, f"ed_{sname}")
            return True
        except Exception:
            pass

    print(f"  Edit option not found")
    ss(page, f"noedit_{sname}")
    return False

def click_utility_items_tab(page, app_display_name):
    """Click 'Utility Items (Desktop Only)' tab in app editor."""
    safe = app_display_name.replace(' ','_').replace("'","").replace("/","_")[:18]
    try:
        tab = page.locator("text=Utility Items (Desktop Only)").first
        tab.wait_for(state="visible", timeout=20000)
        tab.click()
        wait_for_sf(page, timeout=10000)
        time.sleep(1.5)
        ss(page, f"ut_{safe}")
        return True
    except Exception as e:
        print(f"  No 'Utility Items' tab: {e}")
        ss(page, f"nout_{safe}")
        return False

def find_and_enable_start_auto(page, app_display_name):
    """
    In utility items panel, find Ask mcLOVIN', expand it, and
    check 'Start Automatically' if not already checked.
    Returns: 'updated', 'already_set', 'no_mclovin', 'error'
    """
    safe = app_display_name.replace(' ','_').replace("'","").replace("/","_")[:18]

    # Find Ask mcLOVIN'
    mclovin_el = None
    for pattern in ["Ask mcLOVIN'", "Ask mcLOVIN", "mcLOVIN"]:
        try:
            el = page.locator(f"text={pattern}").first
            el.wait_for(state="visible", timeout=6000)
            mclovin_el = el
            print(f"  Found '{pattern}'!")
            ss(page, f"mcl_{safe}")
            break
        except Exception:
            continue

    if not mclovin_el:
        print(f"  'Ask mcLOVIN'' not in utility items")
        ss(page, f"nomcl_{safe}")
        return "no_mclovin"

    # Click it to expand settings
    mclovin_el.click()
    time.sleep(1.5)
    wait_for_sf(page, timeout=8000)
    ss(page, f"mclex_{safe}")

    # Check if "Start Automatically" is visible
    try:
        sa_text = page.locator("text=Start Automatically").first
        sa_text.wait_for(state="visible", timeout=10000)
        print(f"  'Start Automatically' is visible")
    except Exception as e:
        print(f"  'Start Automatically' not visible: {e}")
        ss(page, f"nosa_{safe}")
        return "error"

    # Find the checkbox via JS
    js = page.evaluate("""() => {
        const textWalker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        let n;
        while (n = textWalker.nextNode()) {
            const t = n.textContent.trim();
            if (t === 'Start Automatically' || t === 'Start automatically') {
                let el = n.parentElement;
                for (let i = 0; i < 15; i++) {
                    if (!el) break;
                    const cb = el.querySelector('input[type="checkbox"]');
                    if (cb) return {found: true, checked: cb.checked, id: cb.id, name: cb.name};
                    el = el.parentElement;
                }
            }
        }
        // list all checkboxes
        const cbs = Array.from(document.querySelectorAll('input[type="checkbox"]'));
        return {found: false, cbs: cbs.map(cb => {
            const lbl = cb.id ? (document.querySelector('label[for="'+cb.id+'"]') || {}).textContent : '';
            return {id: cb.id, name: cb.name, checked: cb.checked,
                    label: (lbl || '').trim(),
                    aria: cb.getAttribute('aria-label') || ''};
        })};
    }""")

    print(f"  JS: found={js.get('found')}, checked={js.get('checked')}")

    cb_id = None
    is_checked = None

    if js.get("found"):
        cb_id = js.get("id")
        is_checked = js.get("checked")
    else:
        # Try matching by label
        for cb in js.get("cbs", []):
            combined = (cb.get("label","") + " " + cb.get("aria","")).lower()
            if "start" in combined and ("auto" in combined or "automatic" in combined):
                cb_id = cb.get("id")
                is_checked = cb.get("checked")
                print(f"  Matched checkbox by label: '{cb.get('label')}', checked={is_checked}")
                break

    ss(page, f"bef_{safe}")

    if is_checked is None:
        print(f"  Could not identify Start Automatically checkbox")
        print(f"  Checkboxes: {json.dumps(js.get('cbs',[]), indent=2)[:500]}")
        ss(page, f"err_{safe}")
        return "error"

    if is_checked:
        print(f"  Already CHECKED - no action needed")
        return "already_set"

    print(f"  UNCHECKED - enabling Start Automatically...")

    # Click the checkbox
    success = False
    if cb_id:
        # Try Playwright click
        try:
            cb_el = page.locator(f"#{cb_id}").first
            cb_el.scroll_into_view_if_needed()
            cb_el.click(force=True)
            time.sleep(0.5)
            new_state = page.evaluate(f"() => {{ const e = document.getElementById('{cb_id}'); return e ? e.checked : null; }}")
            print(f"  After click: checked={new_state}")
            success = True
        except Exception as e:
            print(f"  Playwright click error: {e}")

        if not success or page.evaluate(f"() => {{ const e = document.getElementById('{cb_id}'); return e ? !e.checked : true; }}"):
            # Try JS dispatch
            print(f"  Trying JS click...")
            page.evaluate(f"""() => {{
                const cb = document.getElementById('{cb_id}');
                if (cb) {{
                    cb.click();
                    cb.dispatchEvent(new Event('change', {{bubbles: true}}));
                }}
            }}""")
            time.sleep(0.5)
            success = True
    else:
        # Blind JS click
        page.evaluate("""() => {
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let node;
            while (node = walker.nextNode()) {
                if (node.textContent.trim() === 'Start Automatically') {
                    let el = node.parentElement;
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
        success = True

    ss(page, f"aft_{safe}")

    if not success:
        return "error"

    # Save the app
    print(f"  Saving app...")
    try:
        save_btn = page.locator("button:has-text('Save')").first
        save_btn.wait_for(state="visible", timeout=15000)
        save_btn.click()
        wait_for_sf(page, timeout=20000)
        time.sleep(3)
        ss(page, f"sav_{safe}")

        # Check for success/error notifications
        try:
            notif = page.locator(".slds-notify, [role='alert'], .slds-toast").first
            notif_text = notif.inner_text(timeout=3000)
            if notif_text:
                print(f"  Notification: {notif_text[:100]}")
        except Exception:
            pass

        print(f"  SAVED!")
        return "updated"
    except Exception as e:
        print(f"  Save error: {e}")
        ss(page, f"saverr_{safe}")
        return "error"

def process_app(page, app_name):
    """Full flow: search for app, open editor, set mcLOVIN start auto."""
    safe = app_name.replace(' ','_').replace("'","").replace("/","_")[:18]
    print(f"\n{'='*55}")
    print(f"APP: {app_name}")
    print('='*55)

    # Use search to filter app manager to just this app
    frame, rows = search_app_manager(page, app_name)

    if not frame:
        print(f"  No table found after search")
        ss(page, f"notbl_{safe}")
        return "could_not_open"

    print(f"  {len(rows)} rows visible after search for '{app_name}'")

    # Find and click Edit for this app
    opened = click_edit_on_row(page, frame, rows, app_name)
    if not opened:
        return "could_not_open"

    # Click Utility Items tab
    has_utility = click_utility_items_tab(page, app_name)
    if not has_utility:
        return "no_utility_bar"

    # Find and enable mcLOVIN Start Automatically
    return find_and_enable_start_auto(page, app_name)

def main():
    # Apps to check - from AppMenuItem API (TabSet type = Lightning apps)
    # These are the apps with utility bars
    TARGET_APPS = [
        # Priority apps (per task requirements)
        "Outdoor Living",
        "Outdoor Living Console",
        "Field Services",
        "Field Service",
        "LOVING Field Service",
        "Sales Console",
        "Lightning Sales Console",
        "Customer Success",
        "Customer_Success_Service_Console",
        # Other known console/lightning apps
        "Service Console",
        "Aqua Service",
        "Aqua_Service_Console",
        "Loving Foreman",
        "mcLOVIN'",
        "VP Operations Dashboard",
        "Measuring Cup",
        "RingCentral for Lightning",
        "Docusign Apps Launcher",
        # Standard Lightning apps that might have utility bars
        "Analytics Studio",
        "Data Manager",
        "Data Cloud",
        "Commerce",
        "Sales Engagement",
        "Automation",
        "Forecasting",
        "Marketing",
        "Personalization",
        "Digital Wallet",
        "Platform",
        "Service",
        "Sales",
        "Usage",
        "Home",
    ]

    # Start Xvfb
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
    print(f"Xvfb started on {display}")

    token = get_access_token()
    if not token:
        print("ERROR: No access token!")
        xvfb.terminate()
        sys.exit(1)
    print(f"Token: {token[:20]}...")

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
            print("\nLogging in via frontdoor.jsp...")
            page.goto(login_url, timeout=60000)
            wait_for_sf(page, timeout=25000)
            ss(page, "login")
            print(f"  URL: {page.url}")

            # Confirm login
            if "frontdoor" in page.url or "login" in page.url.lower():
                print("  Warning: May still be on login page")

            # Process each target app
            for app_name in TARGET_APPS:
                result = process_app(page, app_name)
                results[app_name] = result
                print(f"  --> RESULT: {result}")
                time.sleep(0.5)

            # Print final summary
            print("\n" + "="*55)
            print("FINAL SUMMARY")
            print("="*55)

            updated = [k for k, v in results.items() if v == "updated"]
            already_set = [k for k, v in results.items() if v == "already_set"]
            no_mclovin = [k for k, v in results.items() if v == "no_mclovin"]
            no_util = [k for k, v in results.items() if v == "no_utility_bar"]
            errors = [k for k, v in results.items() if v in ("error", "could_not_open")]

            print(f"\n[ENABLED] Start Automatically now ON ({len(updated)}):")
            for a in updated:
                print(f"  - {a}")

            print(f"\n[ALREADY SET] Was already ON ({len(already_set)}):")
            for a in already_set:
                print(f"  - {a}")

            print(f"\n[NO mcLOVIN] Ask mcLOVIN' not in utility items ({len(no_mclovin)}):")
            for a in no_mclovin:
                print(f"  - {a}")

            print(f"\n[NO UTIL BAR] No Utility Bar section ({len(no_util)}):")
            for a in no_util:
                print(f"  - {a}")

            print(f"\n[ERRORS] Could not open or process ({len(errors)}):")
            for a in errors:
                print(f"  - {a}")

            browser.close()

    finally:
        xvfb.terminate()
        print("\nDone.")

if __name__ == "__main__":
    main()
