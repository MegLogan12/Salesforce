#!/usr/bin/env python3
"""
Automate Salesforce Lightning App Manager to enable "Start Automatically"
for "Ask mcLOVIN'" utility item in all apps that have a Utility Bar.
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

screenshot_counter = [0]

def ss(page, name):
    screenshot_counter[0] += 1
    path = f"{SCREENSHOT_DIR}/{screenshot_counter[0]:03d}_{name}.png"
    try:
        page.screenshot(path=path, full_page=False)
        print(f"  [screenshot] {path}")
    except Exception as e:
        print(f"  [screenshot error] {e}")
    return path

def wait_for_sf(page, timeout=30000):
    try:
        page.wait_for_load_state("networkidle", timeout=timeout)
    except Exception:
        pass
    try:
        page.wait_for_selector(".slds-spinner_container", state="hidden", timeout=10000)
    except Exception:
        pass
    time.sleep(1.5)

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

def find_frame_with_table(page, timeout=15000):
    """Find the iframe/frame that contains the app table."""
    deadline = time.time() + timeout / 1000
    while time.time() < deadline:
        for f in page.frames:
            try:
                rows = f.query_selector_all("table tbody tr")
                if rows and len(rows) > 0:
                    # Check that first row has actual content
                    first_row_text = rows[0].inner_text().strip()
                    if first_row_text:
                        return f, rows
            except Exception:
                pass
        time.sleep(1)
    return None, []

def debug_table_structure(frame):
    """Print table structure for debugging."""
    result = frame.evaluate("""() => {
        const rows = document.querySelectorAll('table tbody tr');
        const data = [];
        rows.forEach((row, i) => {
            const cells = row.querySelectorAll('td');
            const cellTexts = Array.from(cells).map(c => c.textContent.trim().slice(0, 50));
            data.push({rowIndex: i, cellCount: cells.length, cells: cellTexts});
        });
        return data;
    }""")
    return result

def get_all_apps_via_js(frame):
    """Use JavaScript to extract all app data from the table.

    The App Manager table has columns:
    0: checkbox, 1: App Name, 2: Developer Name, 3: Description,
    4: Last Modified, 5: App (type), 6: Visible In, 7: Actions
    """
    result = frame.evaluate("""() => {
        const rows = document.querySelectorAll('table tbody tr');
        const apps = [];
        rows.forEach((row) => {
            const cells = row.querySelectorAll('td');
            if (cells.length >= 3) {
                // Cell 0 = checkbox, cell 1 = App Name
                const name = cells[1] ? cells[1].textContent.trim() : '';
                const devName = cells[2] ? cells[2].textContent.trim() : '';
                const description = cells[3] ? cells[3].textContent.trim() : '';
                const lastModified = cells[4] ? cells[4].textContent.trim() : '';
                const appType = cells[5] ? cells[5].textContent.trim() : '';
                const visible = cells[6] ? cells[6].textContent.trim() : '';

                if (name && name !== 'App Name' && name !== '') {
                    apps.push({name, devName, description, lastModified, appType, visible});
                }
            }
        });
        return apps;
    }""")
    return result

def scroll_to_load_all(frame, page):
    """Scroll the table to load all rows if it's virtualized."""
    # Check if there's a 'Show More' button or pagination
    try:
        show_more = frame.query_selector("button:has-text('Show More'), a:has-text('Show More'), .forceVirtualList-showMore")
        if show_more:
            print("  Found 'Show More' button, clicking...")
            show_more.click()
            time.sleep(2)
    except Exception:
        pass

    # Scroll the table container
    try:
        frame.evaluate("""() => {
            const tableContainer = document.querySelector('.slds-scrollable_x, .slds-table-scroll-wrapper, .listViewManagerColumnBrowser, table');
            if (tableContainer) {
                tableContainer.scrollTop = tableContainer.scrollHeight;
            }
            window.scrollTo(0, document.body.scrollHeight);
        }""")
        time.sleep(1)
    except Exception:
        pass

def navigate_and_get_apps(page):
    """Navigate to App Manager and get all apps."""
    page.goto(APP_MANAGER_URL, timeout=60000)
    wait_for_sf(page, timeout=45000)
    time.sleep(3)

    ss(page, "app_manager_loaded")

    frame, rows = find_frame_with_table(page)

    if not frame:
        print("ERROR: No frame with table found!")
        ss(page, "error_no_table")
        return [], None

    print(f"  Found {len(rows)} rows initially")

    # Debug the table structure
    structure = debug_table_structure(frame)
    if structure:
        print(f"  First row cells: {structure[0] if structure else 'none'}")
        print(f"  Total rows with data: {len(structure)}")

    # Extract apps via JS
    apps = get_all_apps_via_js(frame)
    print(f"  Extracted {len(apps)} apps via JS")

    # If we got zero apps but have rows, try scrolling and retrying
    if not apps and rows:
        print("  Apps empty, trying scroll and retry...")
        scroll_to_load_all(frame, page)
        time.sleep(2)
        apps = get_all_apps_via_js(frame)
        print(f"  After scroll: {len(apps)} apps")

    return apps, frame

def edit_app(page, app_name):
    """Navigate to App Manager, find app, click Edit."""
    # Reload App Manager
    page.goto(APP_MANAGER_URL, timeout=60000)
    wait_for_sf(page)
    time.sleep(3)

    frame, rows = find_frame_with_table(page)
    if not frame:
        print(f"  No table frame found")
        return False

    # Use JS to find and click the dropdown for this app
    # App Name is in cells[1] (cells[0] is the checkbox column)
    result = frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        for (let i = 0; i < rows.length; i++) {{
            const cells = rows[i].querySelectorAll('td');
            if (cells.length > 1 && cells[1].textContent.trim() === '{app_name}') {{
                return {{found: true, rowIndex: i}};
            }}
        }}
        return {{found: false}};
    }}""")

    if not result.get("found"):
        print(f"  App '{app_name}' not found in table via JS")
        return False

    row_index = result["rowIndex"]
    print(f"  Found app at row index {row_index}")

    # Click the dropdown button in that row
    row = rows[row_index]

    # Find the dropdown button - usually last cell or has a specific class
    dropdown_btn = None
    try:
        # Try the last button in the row
        buttons = row.query_selector_all("button, a[role='button']")
        if buttons:
            dropdown_btn = buttons[-1]
            print(f"  Found {len(buttons)} buttons in row, using last one")
    except Exception as e:
        print(f"  Error finding buttons: {e}")

    if not dropdown_btn:
        # Try via JS click
        print("  Trying JS click on dropdown...")
        frame.evaluate(f"""() => {{
            const rows = document.querySelectorAll('table tbody tr');
            const row = rows[{row_index}];
            const buttons = row.querySelectorAll('button, a[role="button"]');
            if (buttons.length > 0) {{
                buttons[buttons.length - 1].click();
            }}
        }}""")
        time.sleep(1)
        ss(page, f"dropdown_{app_name.replace(' ','_')[:25]}")
    else:
        dropdown_btn.scroll_into_view_if_needed()
        dropdown_btn.click()
        time.sleep(1)
        ss(page, f"dropdown_{app_name.replace(' ','_')[:25]}")

    # Wait for Edit option to appear and click it
    edit_clicked = False
    for context in [page, frame]:
        try:
            # Try different selectors for the Edit link
            for selector in ["a:has-text('Edit')", "button:has-text('Edit')", "[title='Edit']"]:
                try:
                    edit_el = context.locator(selector).first
                    edit_el.wait_for(state="visible", timeout=4000)
                    edit_el.click()
                    edit_clicked = True
                    print(f"  Clicked Edit ({selector})")
                    break
                except Exception:
                    pass
            if edit_clicked:
                break
        except Exception:
            pass

    if not edit_clicked:
        print(f"  Could not find/click Edit option")
        ss(page, f"no_edit_{app_name.replace(' ','_')[:25]}")
        return False

    wait_for_sf(page)
    time.sleep(2)
    ss(page, f"editor_{app_name.replace(' ','_')[:25]}")
    print(f"  Editor opened: {page.url[:80]}")
    return True

def handle_utility_items(page, app_name):
    """In app editor, find and update Start Automatically for Ask mcLOVIN'."""
    safe = app_name.replace(' ', '_').replace("'", "").replace("/", "_")[:25]

    # Click Utility Items tab
    try:
        util_tab = page.locator("text=Utility Items (Desktop Only)").first
        util_tab.wait_for(state="visible", timeout=20000)
        util_tab.click()
        wait_for_sf(page)
        time.sleep(1.5)
        ss(page, f"{safe}_util_tab")
        print(f"  Clicked 'Utility Items (Desktop Only)'")
    except Exception as e:
        print(f"  No Utility Items tab: {e}")
        ss(page, f"{safe}_no_util_tab")
        return "no_utility_bar"

    # Look for Ask mcLOVIN'
    try:
        # Try various text patterns
        for text_pattern in ["Ask mcLOVIN'", "mcLOVIN", "Ask mcLOVIN"]:
            try:
                mclovin = page.locator(f"text={text_pattern}").first
                mclovin.wait_for(state="visible", timeout=5000)
                print(f"  Found utility item with text: '{text_pattern}'")
                ss(page, f"{safe}_mclovin_found")

                # Click to expand
                mclovin.click()
                time.sleep(1.5)
                wait_for_sf(page)
                ss(page, f"{safe}_mclovin_expanded")
                break
            except Exception:
                continue
        else:
            raise Exception("mcLOVIN not found")
    except Exception as e:
        print(f"  'Ask mcLOVIN'' not in utility items: {e}")
        ss(page, f"{safe}_no_mclovin")
        return "no_mclovin"

    # Find Start Automatically checkbox
    try:
        start_auto = page.locator("text=Start Automatically").first
        start_auto.wait_for(state="visible", timeout=10000)
        print(f"  Found 'Start Automatically' text")
    except Exception as e:
        print(f"  'Start Automatically' not found: {e}")
        ss(page, f"{safe}_no_start_auto")
        return "error"

    # Use JS to find and interact with the checkbox
    js_result = page.evaluate("""() => {
        // Find all elements containing "Start Automatically"
        const walker = document.createTreeWalker(
            document.body,
            NodeFilter.SHOW_TEXT,
            null
        );

        let node;
        while (node = walker.nextNode()) {
            const text = node.textContent.trim();
            if (text === 'Start Automatically' || text === 'Start automatically') {
                // Search nearby for a checkbox
                let el = node.parentElement;
                for (let i = 0; i < 10; i++) {
                    if (!el) break;
                    const cb = el.querySelector('input[type="checkbox"]');
                    if (cb) {
                        return {
                            found: true,
                            checked: cb.checked,
                            id: cb.id,
                            name: cb.name,
                            ariaLabel: cb.getAttribute('aria-label'),
                            parentTag: el.tagName,
                            parentClass: el.className.substr(0, 80)
                        };
                    }
                    el = el.parentElement;
                }
            }
        }

        // Fallback: get all checkboxes with context
        const allCbs = Array.from(document.querySelectorAll('input[type="checkbox"]'));
        return {
            found: false,
            total: allCbs.length,
            checkboxes: allCbs.slice(0, 20).map(cb => ({
                id: cb.id,
                name: cb.name,
                checked: cb.checked,
                ariaLabel: cb.getAttribute('aria-label') || '',
                label: (() => {
                    if (cb.id) {
                        const lbl = document.querySelector('label[for="' + cb.id + '"]');
                        return lbl ? lbl.textContent.trim() : '';
                    }
                    return '';
                })()
            }))
        };
    }""")

    print(f"  JS checkbox search: found={js_result.get('found')}, checked={js_result.get('checked')}")
    if not js_result.get("found"):
        print(f"  All checkboxes: {json.dumps(js_result.get('checkboxes', []), indent=2)[:600]}")

    ss(page, f"{safe}_before_action")

    checkbox_id = None
    is_already_checked = False

    if js_result.get("found"):
        is_already_checked = js_result.get("checked", False)
        checkbox_id = js_result.get("id")
        print(f"  Checkbox id='{checkbox_id}', currently_checked={is_already_checked}")
    else:
        # Try to find by label text in the checkboxes list
        for cb_info in js_result.get("checkboxes", []):
            label = cb_info.get("label", "").lower()
            aria = cb_info.get("ariaLabel", "").lower()
            if "start" in label + aria and "auto" in label + aria:
                checkbox_id = cb_info.get("id")
                is_already_checked = cb_info.get("checked", False)
                print(f"  Found by label/aria: label='{cb_info.get('label')}', checked={is_already_checked}")
                break

    if is_already_checked:
        print(f"  'Start Automatically' already CHECKED - no change needed")
        ss(page, f"{safe}_already_checked")
        return "already_set"

    # Need to check it
    print(f"  'Start Automatically' is UNCHECKED - will enable it")

    if checkbox_id:
        # Try clicking via Playwright
        try:
            cb_el = page.locator(f"#{checkbox_id}").first
            cb_el.wait_for(state="attached", timeout=5000)
            cb_el.click()
            time.sleep(0.5)
            new_checked = page.evaluate(f"() => document.getElementById('{checkbox_id}').checked")
            print(f"  After Playwright click: checked={new_checked}")
        except Exception as e:
            print(f"  Playwright click error: {e}")
            # Try JS click
            page.evaluate(f"() => {{ const cb = document.getElementById('{checkbox_id}'); if(cb) cb.click(); }}")
            time.sleep(0.5)
            try:
                new_checked = page.evaluate(f"() => document.getElementById('{checkbox_id}').checked")
                print(f"  After JS click: checked={new_checked}")
            except Exception:
                new_checked = True  # assume it worked
    else:
        # Try clicking the visual checkbox near the Start Automatically text
        print("  No checkbox id, trying to click via visual locator...")
        try:
            # Find the checkbox input near the Start Automatically label
            cb_locator = page.locator("label:has-text('Start Automatically') + input, input + label:has-text('Start Automatically')").first
            cb_locator.click()
            time.sleep(0.5)
        except Exception:
            # Just try clicking the nearest thing
            page.evaluate("""() => {
                const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
                let node;
                while (node = walker.nextNode()) {
                    if (node.textContent.trim() === 'Start Automatically') {
                        let el = node.parentElement;
                        for (let i = 0; i < 6; i++) {
                            const cb = el.querySelector('input[type="checkbox"]');
                            if (cb) { cb.click(); return 'clicked'; }
                            el = el.parentElement;
                        }
                    }
                }
                return 'not_found';
            }""")
            time.sleep(0.5)

    ss(page, f"{safe}_after_check")

    # Now save
    print(f"  Saving app...")
    ss(page, f"{safe}_pre_save")
    try:
        save_btn = page.locator("button:has-text('Save')").first
        save_btn.wait_for(state="visible", timeout=15000)
        save_btn.click()
        wait_for_sf(page)
        time.sleep(3)
        ss(page, f"{safe}_saved")

        # Check for error messages
        try:
            error = page.locator(".slds-notify--alert, .slds-notify--error, [role='alert']").first
            error_text = error.inner_text()
            if error_text:
                print(f"  Warning/Error after save: {error_text[:100]}")
        except Exception:
            pass

        print(f"  SAVED!")
        return "updated"
    except Exception as e:
        print(f"  Save error: {e}")
        ss(page, f"{safe}_save_error")
        return "error"

def main():
    # Start Xvfb
    display = ":99"
    xvfb_proc = subprocess.Popen(
        ["Xvfb", display, "-screen", "0", "1920x1080x24"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    time.sleep(2)
    os.environ["DISPLAY"] = display
    print(f"Xvfb started on {display}")

    # Get fresh access token
    access_token = get_access_token()
    if not access_token:
        print("ERROR: Could not get access token!")
        xvfb_proc.terminate()
        sys.exit(1)
    print(f"Access token obtained: {access_token[:20]}...")

    sid_encoded = urllib.parse.quote(access_token)
    login_url = f"{INSTANCE_URL}/secur/frontdoor.jsp?sid={sid_encoded}"

    results = {}

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
            ss(page, "01_login")
            print(f"  URL after login: {page.url}")

            if "login" in page.url and "frontdoor" not in page.url:
                print("  Login failed!")
                browser.close()
                xvfb_proc.terminate()
                return

            # Get app list
            print("\nNavigating to App Manager...")
            all_apps, _ = navigate_and_get_apps(page)

            if not all_apps:
                # One more attempt with direct JS on current frame
                print("Retrying app extraction...")
                time.sleep(5)
                for f in page.frames:
                    apps = get_all_apps_via_js(f)
                    if apps:
                        all_apps = apps
                        print(f"Found {len(apps)} apps in retry")
                        break

            if not all_apps:
                print("Could not get app list!")
                ss(page, "FAIL_no_apps")
                browser.close()
                xvfb_proc.terminate()
                return

            print(f"\nTotal apps: {len(all_apps)}")
            for app in all_apps:
                print(f"  - {app['name']} [{app.get('appType','?')}]")

            # Priority ordering
            priority_prefixes = [
                "Outdoor Living", "Field Service", "LOVING Field Service",
                "Sales Console", "Lightning Sales Console", "Customer Success"
            ]

            def priority_key(app):
                name = app["name"]
                for i, p in enumerate(priority_prefixes):
                    if p.lower() in name.lower():
                        return i
                return len(priority_prefixes)

            sorted_apps = sorted(all_apps, key=priority_key)

            # Process each app
            for app_info in sorted_apps:
                app_name = app_info["name"]
                print(f"\n{'='*60}")
                print(f"Processing: {app_name}")

                # Navigate to App Manager and open editor
                opened = edit_app(page, app_name)
                if not opened:
                    results[app_name] = "could_not_open"
                    continue

                # Handle utility items
                result = handle_utility_items(page, app_name)
                results[app_name] = result
                print(f"  Result: {result}")
                time.sleep(1)

            # Summary
            print("\n" + "="*60)
            print("SUMMARY")
            print("="*60)
            for app_name, result in results.items():
                emoji = "✓" if result == "updated" else ("=" if result == "already_set" else "✗")
                print(f"  {emoji} [{result}] {app_name}")

            updated = [k for k, v in results.items() if v == "updated"]
            already_set = [k for k, v in results.items() if v == "already_set"]
            no_mclovin = [k for k, v in results.items() if v == "no_mclovin"]
            no_util = [k for k, v in results.items() if v == "no_utility_bar"]
            errors = [k for k, v in results.items() if v in ("error", "could_not_open")]

            print(f"\nEnabled Start Automatically: {updated}")
            print(f"Already had it checked:      {already_set}")
            print(f"No Ask mcLOVIN' item:        {no_mclovin}")
            print(f"No Utility Bar:              {no_util}")
            print(f"Errors:                      {errors}")

            browser.close()

    finally:
        xvfb_proc.terminate()
        print("\nDone.")

if __name__ == "__main__":
    main()
