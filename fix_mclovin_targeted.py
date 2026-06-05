#!/usr/bin/env python3
"""
Targeted script: Find Lightning apps with utility bars and enable
"Start Automatically" for the "Ask mcLOVIN'" utility item.

Uses App Manager search to find each specific app.
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

def wait_for_sf(page, timeout=30000):
    try:
        page.wait_for_load_state("networkidle", timeout=timeout)
    except Exception:
        pass
    try:
        page.wait_for_selector(".slds-spinner_container", state="hidden", timeout=8000)
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

def find_table_frame(page):
    """Find frame containing the app table."""
    for f in page.frames:
        try:
            rows = f.query_selector_all("table tbody tr")
            if rows and len(rows) > 0:
                return f, rows
        except Exception:
            pass
    # Try main page
    try:
        rows = page.query_selector_all("table tbody tr")
        if rows:
            return page, rows
    except Exception:
        pass
    return None, []

def search_for_app_in_manager(page, app_label):
    """
    Navigate to App Manager and use search to find a specific app.
    Returns True if found and Edit was clicked successfully.
    """
    print(f"\n--- Searching for '{app_label}' ---")

    page.goto(APP_MANAGER_URL, timeout=60000)
    wait_for_sf(page, timeout=45000)
    time.sleep(3)

    # Find the search/filter input in the App Manager
    # The App Manager has a search input to filter apps
    search_input = None

    # Try to find search box in frames
    for f in page.frames:
        try:
            inp = f.query_selector("input[placeholder*='Search'], input[type='search'], input[name*='search']")
            if inp:
                search_input = inp
                print(f"  Found search input in frame")
                break
        except Exception:
            pass

    if not search_input:
        try:
            search_input = page.query_selector("input[placeholder*='Search'], input[type='search']")
            if search_input:
                print(f"  Found search input in main page")
        except Exception:
            pass

    if search_input:
        print(f"  Using search box to find '{app_label}'")
        search_input.click()
        search_input.fill(app_label)
        time.sleep(2)
        wait_for_sf(page)
        ss(page, f"search_{app_label.replace(' ','_')[:20]}")
    else:
        print(f"  No search box found, using full table")
        ss(page, f"no_search_box")

    # Find the frame with the table (after search)
    target_frame, rows = find_table_frame(page)

    if not target_frame:
        print(f"  No table found")
        return False

    print(f"  Table has {len(rows)} rows after search")

    # Find the app row - name is in cells[1]
    found_row = None
    found_idx = None
    for i, row in enumerate(rows):
        try:
            cells = row.query_selector_all("td")
            if len(cells) > 1:
                cell_text = cells[1].inner_text().strip()
                if app_label.lower() in cell_text.lower() or cell_text.lower() in app_label.lower():
                    found_row = row
                    found_idx = i
                    print(f"  Found row {i}: '{cell_text}'")
                    break
        except Exception:
            pass

    if not found_row:
        # Try searching for partial match
        for i, row in enumerate(rows):
            try:
                cells = row.query_selector_all("td")
                if len(cells) > 1:
                    cell_text = cells[1].inner_text().strip()
                    # Try matching any significant word
                    for word in app_label.split():
                        if len(word) > 3 and word.lower() in cell_text.lower():
                            found_row = row
                            found_idx = i
                            print(f"  Partial match row {i}: '{cell_text}' (matched word '{word}')")
                            break
                if found_row:
                    break
            except Exception:
                pass

    if not found_row:
        print(f"  App '{app_label}' not found in visible rows")
        ss(page, f"not_found_{app_label.replace(' ','_')[:20]}")
        return False

    # Click the dropdown button in this row
    buttons = found_row.query_selector_all("button, a[role='button']")
    if not buttons:
        print(f"  No buttons in row")
        return False

    dropdown_btn = buttons[-1]
    dropdown_btn.scroll_into_view_if_needed()
    dropdown_btn.click()
    time.sleep(1)
    ss(page, f"dd_{app_label.replace(' ','_')[:20]}")

    # Click Edit
    for ctx in [page, target_frame]:
        try:
            edit_el = ctx.locator("a:has-text('Edit')").first
            edit_el.wait_for(state="visible", timeout=5000)
            edit_el.click()
            wait_for_sf(page)
            time.sleep(2)
            print(f"  Opened editor: {page.url[:80]}")
            ss(page, f"editor_{app_label.replace(' ','_')[:20]}")
            return True
        except Exception:
            pass

    print(f"  Could not click Edit")
    ss(page, f"no_edit_{app_label.replace(' ','_')[:20]}")
    return False

def set_mclovin_start_auto(page, app_label):
    """In the app editor, go to Utility Items and enable Start Automatically for Ask mcLOVIN'."""
    safe = app_label.replace(' ', '_').replace("'", "").replace("/", "_")[:20]

    # Click Utility Items tab
    try:
        util_tab = page.locator("text=Utility Items (Desktop Only)").first
        util_tab.wait_for(state="visible", timeout=20000)
        util_tab.click()
        wait_for_sf(page)
        time.sleep(1.5)
        ss(page, f"ut_{safe}")
        print(f"  Opened Utility Items tab")
    except Exception as e:
        print(f"  No Utility Items tab: {e}")
        ss(page, f"no_ut_{safe}")
        return "no_utility_bar"

    # Look for Ask mcLOVIN' item
    mclovin_found = False
    for pattern in ["Ask mcLOVIN'", "Ask mcLOVIN", "mcLOVIN"]:
        try:
            el = page.locator(f"text={pattern}").first
            el.wait_for(state="visible", timeout=5000)
            mclovin_found = True
            print(f"  Found '{pattern}'!")
            ss(page, f"mcl_found_{safe}")

            # Click to expand
            el.click()
            time.sleep(1.5)
            wait_for_sf(page)
            ss(page, f"mcl_exp_{safe}")
            break
        except Exception:
            continue

    if not mclovin_found:
        print(f"  Ask mcLOVIN' NOT found in utility items")
        ss(page, f"no_mcl_{safe}")
        return "no_mclovin"

    # Find Start Automatically
    try:
        start_auto_el = page.locator("text=Start Automatically").first
        start_auto_el.wait_for(state="visible", timeout=10000)
        print(f"  Found 'Start Automatically'")
    except Exception as e:
        print(f"  'Start Automatically' not visible: {e}")
        ss(page, f"no_sa_{safe}")
        return "error"

    # Use JS to find the checkbox
    js = page.evaluate("""() => {
        // Walk text nodes to find "Start Automatically"
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        let node;
        while (node = walker.nextNode()) {
            const txt = node.textContent.trim();
            if (txt === 'Start Automatically' || txt === 'Start automatically') {
                let el = node.parentElement;
                for (let depth = 0; depth < 12; depth++) {
                    if (!el) break;
                    const cb = el.querySelector('input[type="checkbox"]');
                    if (cb) {
                        return {found: true, checked: cb.checked, id: cb.id, name: cb.name};
                    }
                    el = el.parentElement;
                }
            }
        }
        // Fallback: get all checkboxes
        const cbs = Array.from(document.querySelectorAll('input[type="checkbox"]'));
        return {found: false, count: cbs.length, cbs: cbs.map(cb => {
            let label = '';
            if (cb.id) {
                const lbl = document.querySelector('label[for="'+cb.id+'"]');
                label = lbl ? lbl.textContent.trim() : '';
            }
            return {id: cb.id, name: cb.name, checked: cb.checked,
                    label, aria: cb.getAttribute('aria-label')||''};
        })};
    }""")

    print(f"  JS result: found={js.get('found')}, checked={js.get('checked')}")

    ss(page, f"before_{safe}")

    is_checked = None
    cb_id = None

    if js.get("found"):
        is_checked = js["checked"]
        cb_id = js.get("id")
    else:
        # Try to find by label
        for cb in js.get("cbs", []):
            label = (cb.get("label", "") + " " + cb.get("aria", "")).lower()
            if "start" in label and ("auto" in label or "automatic" in label):
                is_checked = cb["checked"]
                cb_id = cb.get("id")
                print(f"  Found by label: '{cb.get('label')}', checked={is_checked}")
                break

        if is_checked is None:
            print(f"  Could not find checkbox. All checkboxes: {json.dumps(js.get('cbs',[]),indent=2)[:500]}")
            ss(page, f"err_{safe}")
            return "error"

    if is_checked:
        print(f"  Already CHECKED - nothing to do")
        return "already_set"

    print(f"  UNCHECKED - will enable Start Automatically")

    # Click the checkbox
    if cb_id:
        try:
            cb_el = page.locator(f"#{cb_id}").first
            cb_el.scroll_into_view_if_needed()
            cb_el.click()
            time.sleep(0.5)
        except Exception as e:
            print(f"  Direct click error: {e}, trying JS...")
            page.evaluate(f"() => {{ const cb = document.getElementById('{cb_id}'); if(cb) cb.click(); }}")
            time.sleep(0.5)
    else:
        # Click via JS text search
        page.evaluate("""() => {
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let node;
            while (node = walker.nextNode()) {
                const txt = node.textContent.trim();
                if (txt === 'Start Automatically' || txt === 'Start automatically') {
                    let el = node.parentElement;
                    for (let d = 0; d < 12; d++) {
                        if (!el) break;
                        const cb = el.querySelector('input[type="checkbox"]');
                        if (cb) { cb.click(); return; }
                        el = el.parentElement;
                    }
                }
            }
        }""")
        time.sleep(0.5)

    # Verify it's now checked
    new_state = page.evaluate(f"""() => {{
        {'const cb = document.getElementById("'+cb_id+'"); return cb ? cb.checked : null;' if cb_id else 'return null;'}
    }}""") if cb_id else None
    print(f"  After check: {new_state}")
    ss(page, f"after_check_{safe}")

    # Save
    print(f"  Saving...")
    try:
        save_btn = page.locator("button:has-text('Save')").first
        save_btn.wait_for(state="visible", timeout=15000)
        save_btn.click()
        wait_for_sf(page)
        time.sleep(3)
        ss(page, f"saved_{safe}")

        # Check for errors
        try:
            err_el = page.locator(".slds-notify--alert, [role='alert']:visible").first
            err_txt = err_el.inner_text(timeout=2000)
            if err_txt:
                print(f"  Post-save alert: {err_txt[:100]}")
        except Exception:
            pass

        print(f"  SAVED SUCCESSFULLY!")
        return "updated"
    except Exception as e:
        print(f"  Save error: {e}")
        ss(page, f"save_err_{safe}")
        return "error"

def get_all_visible_apps_with_scroll(page):
    """
    Load all apps from the App Manager by scrolling the virtual list.
    Returns list of {name, devName, type} dicts.
    """
    print("Loading all apps (with scroll)...")
    page.goto(APP_MANAGER_URL, timeout=60000)
    wait_for_sf(page, timeout=45000)
    time.sleep(3)

    ss(page, "app_manager_initial")

    # Find the frame with the table
    target_frame = None
    for f in page.frames:
        try:
            rows = f.query_selector_all("table tbody tr")
            if rows and len(rows) > 0:
                target_frame = f
                break
        except Exception:
            pass

    if not target_frame:
        print("No frame with table found")
        return []

    all_apps = {}  # name -> info

    def extract_visible_apps():
        result = target_frame.evaluate("""() => {
            const rows = document.querySelectorAll('table tbody tr');
            const apps = [];
            rows.forEach(row => {
                const cells = row.querySelectorAll('td');
                if (cells.length > 1) {
                    const name = cells[1] ? cells[1].textContent.trim() : '';
                    const devName = cells[2] ? cells[2].textContent.trim() : '';
                    const appType = cells[5] ? cells[5].textContent.trim() : '';
                    if (name && name !== 'App Name') {
                        apps.push({name, devName, appType});
                    }
                }
            });
            return apps;
        }""")
        return result

    # Get initial batch
    initial = extract_visible_apps()
    for a in initial:
        all_apps[a["name"]] = a
    print(f"  Initial batch: {len(initial)} apps")

    # Scroll to load more
    # Find the scrollable container in the frame
    scrolled_positions = set()
    max_scrolls = 30

    for scroll_num in range(max_scrolls):
        # Scroll in the frame
        scroll_result = target_frame.evaluate("""() => {
            // Try different scrollable containers
            const containers = [
                document.querySelector('.slds-table-scroll-wrapper'),
                document.querySelector('.slds-scrollable_y'),
                document.querySelector('.slds-card__body'),
                document.querySelector('tbody').parentElement,
                document.scrollingElement,
                document.body
            ];
            for (const c of containers) {
                if (!c) continue;
                const prevScroll = c.scrollTop;
                c.scrollTop += 500;
                if (c.scrollTop !== prevScroll) {
                    return {container: c.tagName + '.' + c.className.substr(0,30), scrollTop: c.scrollTop};
                }
            }
            window.scrollBy(0, 500);
            return {container: 'window', scrollTop: window.scrollY};
        }""")

        time.sleep(0.8)

        # Extract new apps
        new_batch = extract_visible_apps()
        before_count = len(all_apps)
        for a in new_batch:
            all_apps[a["name"]] = a

        if len(all_apps) > before_count:
            print(f"  Scroll {scroll_num+1}: {len(new_batch)} visible, {len(all_apps)} total unique")
        else:
            # Check if we've reached the end
            scroll_top = scroll_result.get("scrollTop", 0)
            if str(scroll_top) in scrolled_positions:
                print(f"  Scroll {scroll_num+1}: No new apps, scroll stuck at {scroll_top}")
                # Try parent frame
                page.evaluate("window.scrollBy(0, 500)")
                time.sleep(0.8)
                new_batch2 = extract_visible_apps()
                before = len(all_apps)
                for a in new_batch2:
                    all_apps[a["name"]] = a
                if len(all_apps) == before:
                    print(f"  No more apps to load after {scroll_num+1} scrolls")
                    break
            scrolled_positions.add(str(scroll_top))

    print(f"  Total unique apps loaded: {len(all_apps)}")
    return list(all_apps.values())

def main():
    # Start Xvfb
    display = ":99"
    try:
        subprocess.run(["pkill", "Xvfb"], capture_output=True)
        time.sleep(1)
    except Exception:
        pass

    xvfb_proc = subprocess.Popen(
        ["Xvfb", display, "-screen", "0", "1920x1080x24"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    time.sleep(2)
    os.environ["DISPLAY"] = display
    print(f"Xvfb started on {display}")

    # Get access token
    access_token = get_access_token()
    if not access_token:
        print("ERROR: No access token")
        xvfb_proc.terminate()
        sys.exit(1)
    print(f"Token: {access_token[:20]}...")

    sid_encoded = urllib.parse.quote(access_token)
    login_url = f"{INSTANCE_URL}/secur/frontdoor.jsp?sid={sid_encoded}"

    results = {}

    # These are the apps we know exist (from AppMenuItem query) that are TabSet type
    # We'll also scan all visible apps in the manager
    KNOWN_TABSET_APPS = [
        "Outdoor Living Console",
        "Field Services",
        "Service Console",
        "Loving Foreman",
        "mcLOVIN'",
        "Aqua Service",
        "VP Operations Dashboard",
        "Measuring Cup",
        "RingCentral for Lightning",
        "Docusign Apps Launcher",
        "Forecasting",
        "Analytics Studio",
        "Data Manager",
        "Data Cloud",
        "Commerce",
        "Sales Engagement",
        "Automation",
        "Marketing",
        "Personalization",
        "Digital Wallet",
        "Platform",
        "Service",
        "Sales",
        "Usage",
        "Home",
        "Foreman",
        # Also try these in case they have utility bars
        "Aqua_Service_Console",
        "Customer_Success_Service_Console",
    ]

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(
                headless=False,
                args=["--no-sandbox", "--disable-dev-shm-usage",
                      f"--display={display}", "--window-size=1920,1080"]
            )
            context = browser.new_context(
                viewport={"width": 1920, "height": 1080},
                ignore_https_errors=True
            )
            page = context.new_page()
            page.set_default_timeout(60000)
            page.set_default_navigation_timeout(60000)

            # Login
            print("\nLogging in...")
            page.goto(login_url, timeout=60000)
            wait_for_sf(page)
            ss(page, "login")
            print(f"  URL: {page.url}")

            if "login" in page.url.lower() and "frontdoor" not in page.url.lower():
                print("  Login might have failed!")

            # First, let's load the App Manager and get all visible apps by scrolling
            all_apps = get_all_visible_apps_with_scroll(page)

            if all_apps:
                print(f"\nAll apps from scroll ({len(all_apps)}):")
                for app in sorted(all_apps, key=lambda x: x['name']):
                    print(f"  [{app.get('appType','?'):12s}] {app['name']}")

                # Find apps that are Lightning type (have utility bar capability)
                lightning_apps = [a for a in all_apps
                                  if 'lightning' in a.get('appType','').lower()
                                  or 'console' in a.get('appType','').lower()]
                print(f"\nLightning apps: {[a['name'] for a in lightning_apps]}")
            else:
                # Fall back to known list
                print("Scroll didn't work, using known app list")
                all_apps = [{"name": n, "appType": "Unknown"} for n in KNOWN_TABSET_APPS]

            ss(page, "all_apps_loaded")

            # Now process each app - prioritizing the key ones
            priority_map = {
                "Outdoor Living Console": 1,
                "Outdoor Living": 1,
                "Field Services": 2,
                "LOVING Field Service": 2,
                "Field Service": 2,
                "Sales Console": 3,
                "Lightning Sales Console": 3,
                "Customer Success": 4,
                "Customer_Success_Service_Console": 4,
                "Service Console": 5,
                "Aqua Service": 6,
                "Aqua_Service_Console": 6,
                "Loving Foreman": 7,
                "mcLOVIN'": 8,
            }

            def sort_key(app):
                name = app["name"]
                for k, v in priority_map.items():
                    if k.lower() in name.lower() or name.lower() in k.lower():
                        return v
                return 99

            sorted_apps = sorted(all_apps, key=sort_key)

            for app_info in sorted_apps:
                app_name = app_info["name"]
                print(f"\n{'='*60}")
                print(f"APP: {app_name} [{app_info.get('appType','?')}]")

                # Open editor
                opened = search_for_app_in_manager(page, app_name)
                if not opened:
                    results[app_name] = "could_not_open"
                    continue

                # Process utility items
                result = set_mclovin_start_auto(page, app_name)
                results[app_name] = result
                print(f"  RESULT: {result}")
                time.sleep(0.5)

            # Final summary
            print("\n" + "="*60)
            print("FINAL SUMMARY")
            print("="*60)
            for app_name, result in sorted(results.items()):
                print(f"  [{result:20s}] {app_name}")

            updated = [k for k, v in results.items() if v == "updated"]
            already_set = [k for k, v in results.items() if v == "already_set"]
            no_mclovin = [k for k, v in results.items() if v == "no_mclovin"]
            no_util = [k for k, v in results.items() if v == "no_utility_bar"]
            errors = [k for k, v in results.items() if v in ("error", "could_not_open")]

            print(f"\nEnabled (Start Automatically now ON): {updated}")
            print(f"Already had it ON:                    {already_set}")
            print(f"No 'Ask mcLOVIN'' utility item:      {no_mclovin}")
            print(f"No Utility Bar:                       {no_util}")
            print(f"Errors:                               {errors}")

            browser.close()

    finally:
        xvfb_proc.terminate()
        print("\nDone.")

if __name__ == "__main__":
    main()
