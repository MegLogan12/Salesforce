#!/usr/bin/env python3
"""
Enable 'Start Automatically' for 'Ask mcLOVIN'' utility bar item
across multiple Lightning apps in Salesforce.
"""

import os
import sys
import time
import json
import subprocess
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

INSTANCE_URL = "https://loving.my.salesforce.com"
APP_MANAGER_URL = f"{INSTANCE_URL}/lightning/setup/NavigationMenus/home"
SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots"

TARGET_APPS = [
    "Outdoor Living",
    "LOVING Field Service",
    "Lightning Sales Console",
    "Customer Success",
]

os.makedirs(SCREENSHOTS_DIR, exist_ok=True)
screenshot_counter = [0]

def ss(page, name):
    screenshot_counter[0] += 1
    path = f"{SCREENSHOTS_DIR}/startauto_{screenshot_counter[0]:03d}_{name}.png"
    try:
        page.screenshot(path=path, full_page=False)
        print(f"  [ss] {path}")
    except Exception as e:
        print(f"  [ss error] {e}")
    return path

def wait_sf(page, timeout=30000):
    try:
        page.wait_for_load_state("networkidle", timeout=timeout)
    except Exception:
        pass
    try:
        page.wait_for_selector(".slds-spinner_container", state="hidden", timeout=8000)
    except Exception:
        pass
    time.sleep(1.5)

def get_sf_credentials():
    result = subprocess.run(
        ["sf", "org", "display", "--target-org", "dispatch", "--json"],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout)
    r = data.get("result", {})
    return r.get("accessToken"), r.get("instanceUrl")

def login(page, access_token, instance_url):
    import urllib.parse
    token = urllib.parse.quote(access_token)
    url = f"{instance_url}/secur/frontdoor.jsp?sid={token}"
    page.goto(url, timeout=60000)
    wait_sf(page, 60000)
    ss(page, "login")
    print(f"  Logged in: {page.url[:80]}")

def find_table_frame(page, timeout=20000):
    """Find the iframe with the App Manager table."""
    deadline = time.time() + timeout / 1000
    while time.time() < deadline:
        for f in page.frames:
            try:
                rows = f.query_selector_all("table tbody tr")
                if rows and len(rows) > 2:
                    return f
            except Exception:
                pass
        time.sleep(1)
    return None

def get_all_table_text(frame):
    """Get all table content."""
    return frame.evaluate("""() => {
        const rows = document.querySelectorAll('table tbody tr');
        const result = [];
        rows.forEach((row, idx) => {
            const tds = row.querySelectorAll('td');
            const cells = Array.from(tds).map(td => td.textContent.trim());
            result.push({idx: idx, cells: cells, fullText: row.textContent.trim().slice(0, 200)});
        });
        return result;
    }""")

def scroll_and_get_all_apps(frame, page):
    """Scroll through the entire table to load all apps."""
    print("  Scrolling to load all apps...")

    # Get initial count
    initial_rows = frame.evaluate("() => document.querySelectorAll('table tbody tr').length")
    print(f"  Initial row count: {initial_rows}")

    # Scroll to bottom of table repeatedly
    prev_count = 0
    for attempt in range(10):
        frame.evaluate("""() => {
            // Try to scroll various containers
            const selectors = [
                '.slds-scrollable_x',
                '.slds-table-scroll-wrapper',
                '.forceListViewManagerBody',
                'tbody',
                '.slds-card__body',
                '.windowViewMode-normal',
            ];
            for (const sel of selectors) {
                const el = document.querySelector(sel);
                if (el) {
                    el.scrollTop = el.scrollHeight;
                }
            }
            window.scrollTo(0, document.body.scrollHeight);
        }""")
        time.sleep(1)
        count = frame.evaluate("() => document.querySelectorAll('table tbody tr').length")
        print(f"  Row count after scroll {attempt+1}: {count}")
        if count == prev_count:
            break
        prev_count = count

    return frame.evaluate("() => document.querySelectorAll('table tbody tr').length")

def find_app_in_table(frame, app_name):
    """Find an app by its LABEL name (first column) in the table."""
    result = frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        const results = [];
        for (let i = 0; i < rows.length; i++) {{
            const tds = rows[i].querySelectorAll('td');
            if (tds.length < 2) continue;
            // Column 0 is App Name (Label), Column 1 is Developer Name
            const col0 = tds[0] ? tds[0].textContent.trim() : '';
            const col1 = tds[1] ? tds[1].textContent.trim() : '';
            const col2 = tds[2] ? tds[2].textContent.trim() : '';
            const fullText = rows[i].textContent.trim();

            // Check if any column matches
            if (col0 === '{app_name}' || col1 === '{app_name}' ||
                col0.includes('{app_name}') || col1.includes('{app_name}')) {{
                results.push({{
                    found: true, rowIndex: i,
                    col0: col0.slice(0, 50), col1: col1.slice(0, 50), col2: col2.slice(0, 50),
                    fullText: fullText.slice(0, 150)
                }});
            }}
        }}
        return results;
    }}""")
    return result

def click_dropdown_and_edit(frame, page, row_index, app_name):
    """Click dropdown for app at row_index and click Edit."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    # First scroll the row into view
    frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        if (rows[{row_index}]) {{
            rows[{row_index}].scrollIntoView({{block: 'center'}});
        }}
    }}""")
    time.sleep(0.5)

    # Click the last button in the row (dropdown)
    frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        const row = rows[{row_index}];
        if (!row) {{ console.log('Row not found'); return; }}
        const buttons = row.querySelectorAll('button, a[role="button"], .slds-button');
        console.log('Buttons in row:', buttons.length);
        if (buttons.length > 0) {{
            buttons[buttons.length - 1].click();
        }} else {{
            // Try clicking the last td
            const tds = row.querySelectorAll('td');
            if (tds.length > 0) {{
                tds[tds.length - 1].click();
            }}
        }}
    }}""")
    time.sleep(1.5)
    ss(page, f"{safe}_dropdown")

    # Check what appeared
    page_content = page.content()

    # Try to click Edit
    for ctx in [page, frame]:
        for sel in [
            "a:has-text('Edit')",
            "button:has-text('Edit')",
            "a[title='Edit']",
            ".slds-dropdown__item a:has-text('Edit')",
            "li a:has-text('Edit')",
        ]:
            try:
                el = ctx.locator(sel).first
                if el.count() > 0:
                    # Make sure it's actually visible (not hidden)
                    if el.is_visible(timeout=2000):
                        el.click(timeout=5000)
                        print(f"  Clicked Edit ({sel})")
                        wait_sf(page)
                        time.sleep(2)
                        ss(page, f"{safe}_editor")
                        print(f"  Editor URL: {page.url[:80]}")
                        return True
            except Exception:
                pass

    # JS fallback
    for ctx in [page, frame]:
        try:
            found = ctx.evaluate("""() => {
                const elems = document.querySelectorAll('a, button');
                for (const el of elems) {
                    const text = el.textContent.trim();
                    if (text === 'Edit' && el.offsetParent !== null) {
                        el.click();
                        return true;
                    }
                }
                return false;
            }""")
            if found:
                print(f"  Clicked Edit via JS")
                wait_sf(page)
                time.sleep(2)
                ss(page, f"{safe}_editor_js")
                return True
        except Exception:
            pass

    print(f"  Could not click Edit for '{app_name}'")
    ss(page, f"{safe}_edit_failed")
    return False

def click_utility_items(page, app_name):
    """Click the Utility Items tab."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    for sel in [
        "text=Utility Items (Desktop Only)",
        "text=Utility Items",
        "button:has-text('Utility Items')",
        "a:has-text('Utility Items')",
    ]:
        try:
            el = page.locator(sel).first
            el.wait_for(state="visible", timeout=10000)
            el.click(timeout=5000)
            wait_sf(page, 15000)
            ss(page, f"{safe}_utility_items")
            print(f"  Clicked 'Utility Items (Desktop Only)' tab")
            return True
        except Exception:
            continue

    ss(page, f"{safe}_no_utility_tab")
    print(f"  No 'Utility Items' tab found")
    return False

def enable_start_automatically(page, app_name):
    """Enable Start Automatically for Ask mcLOVIN'."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    content = page.content()
    if "mcLOVIN" not in content:
        ss(page, f"{safe}_no_mclovin")
        print(f"  'Ask mcLOVIN'' not in utility items")
        return "not_found"

    print(f"  Found 'Ask mcLOVIN'' in utility items!")

    # Expand the Ask mcLOVIN item by clicking on it
    clicked_mclovin = False
    for text_pat in ["Ask mcLOVIN'", "Ask mcLOVIN"]:
        try:
            # Use more specific locator to get the item header/title
            el = page.locator(f"text={text_pat}").first
            el.wait_for(state="visible", timeout=5000)
            el.scroll_into_view_if_needed()
            ss(page, f"{safe}_mclovin_before_click")
            el.click(timeout=5000)
            time.sleep(2)
            wait_sf(page, 10000)
            ss(page, f"{safe}_mclovin_after_click")
            clicked_mclovin = True
            print(f"  Clicked '{text_pat}'")
            break
        except Exception as e:
            print(f"  Could not click '{text_pat}': {e}")

    # Look for Start Automatically
    content = page.content()
    if "Start Automatically" not in content:
        ss(page, f"{safe}_no_start_auto_text")
        print(f"  'Start Automatically' not in page after clicking mcLOVIN")
        return "not_found"

    print(f"  'Start Automatically' found in page")
    ss(page, f"{safe}_start_auto_visible")

    # Find the checkbox via JavaScript
    js_result = page.evaluate("""() => {
        // Strategy 1: Look for label with text 'Start Automatically'
        const allText = document.querySelectorAll('*');
        for (const el of allText) {
            if (el.children.length === 0 && el.textContent.trim() === 'Start Automatically') {
                // Found the text node container
                // Look up the tree for a checkbox
                let ancestor = el;
                for (let i = 0; i < 8; i++) {
                    ancestor = ancestor.parentElement;
                    if (!ancestor) break;
                    // Look for input checkbox within this ancestor
                    const cbs = ancestor.querySelectorAll('input[type="checkbox"]');
                    if (cbs.length > 0) {
                        const cb = cbs[0];
                        return {
                            found: true,
                            id: cb.id,
                            name: cb.name,
                            checked: cb.checked,
                            labelText: el.textContent.trim(),
                            depth: i
                        };
                    }
                }
            }
        }

        // Strategy 2: Find lightning-input with label
        const lightningInputs = document.querySelectorAll('lightning-input, lightning-toggle');
        for (const li of lightningInputs) {
            const label = li.shadowRoot ? li.shadowRoot.querySelector('label') : li.querySelector('label');
            const labelText = label ? label.textContent.trim() : li.getAttribute('label') || '';
            if (labelText.includes('Start Automatically') || li.getAttribute('label') === 'Start Automatically') {
                const input = li.querySelector('input') ||
                              (li.shadowRoot ? li.shadowRoot.querySelector('input') : null);
                if (input) {
                    return {found: true, id: input.id, name: input.name, checked: input.checked, via: 'lightning-input'};
                }
            }
        }

        // Strategy 3: Find label elements
        const labels = document.querySelectorAll('label');
        for (const label of labels) {
            if (label.textContent.trim().includes('Start Automatically')) {
                const forAttr = label.getAttribute('for');
                if (forAttr) {
                    const input = document.getElementById(forAttr);
                    if (input) {
                        return {found: true, id: input.id, name: input.name, checked: input.checked, via: 'label-for'};
                    }
                }
            }
        }

        // Strategy 4: Look for checkbox near the text
        const allCheckboxes = document.querySelectorAll('input[type="checkbox"]');
        const cbData = [];
        allCheckboxes.forEach(cb => {
            const nearbyText = cb.closest('div, li, article, section')?.textContent?.trim()?.slice(0, 200) || '';
            const label = document.querySelector(`label[for="${cb.id}"]`)?.textContent?.trim() || '';
            cbData.push({id: cb.id, name: cb.name, checked: cb.checked, label: label, nearbyText: nearbyText.slice(0, 100)});
        });

        return {found: false, allCheckboxes: cbData};
    }""")

    print(f"  JS result: {js_result}")

    checkbox = None
    is_checked = None

    if js_result.get("found"):
        cb_id = js_result.get("id", "")
        cb_name = js_result.get("name", "")
        is_checked = js_result.get("checked", False)
        print(f"  Found checkbox via JS: id='{cb_id}' name='{cb_name}' checked={is_checked}")

        if cb_id:
            checkbox = page.locator(f'input#{cb_id}').first
        elif cb_name:
            checkbox = page.locator(f'input[name="{cb_name}"]').first
    else:
        # Log all checkboxes for debugging
        all_cbs = js_result.get("allCheckboxes", [])
        print(f"  All checkboxes ({len(all_cbs)}):")
        for cb in all_cbs:
            label = cb.get('label', '')
            nearby = cb.get('nearbyText', '')
            if 'Start' in label or 'Start' in nearby or 'auto' in nearby.lower():
                print(f"  * LIKELY MATCH: id='{cb['id']}' name='{cb['name']}' checked={cb['checked']}")
                print(f"    label='{label}' nearby='{nearby[:80]}'")
                if cb.get('id'):
                    checkbox = page.locator(f'input#{cb["id"]}').first
                elif cb.get('name'):
                    checkbox = page.locator(f'input[name="{cb["name"]}"]').first
                is_checked = cb.get('checked', False)
            else:
                print(f"    id='{cb['id']}' name='{cb['name']}' checked={cb['checked']} label='{label}'")

    if checkbox is None:
        print(f"  Could not find Start Automatically checkbox")
        return "not_found"

    ss(page, f"{safe}_before_toggle")

    if is_checked:
        print(f"  Already enabled!")
        return "already_enabled"

    # Enable it
    print(f"  Clicking checkbox to enable Start Automatically...")
    try:
        checkbox.scroll_into_view_if_needed(timeout=5000)
        checkbox.click(timeout=10000)
        time.sleep(1)
        ss(page, f"{safe}_after_toggle")

        # Verify
        try:
            new_state = checkbox.is_checked(timeout=3000)
            print(f"  New checkbox state: {'checked' if new_state else 'unchecked'}")
        except Exception:
            pass

        return "enabled"
    except Exception as e:
        print(f"  Checkbox click failed: {e}")
        # Try JS click
        try:
            js_result2 = page.evaluate(f"""() => {{
                const cb = document.getElementById('{js_result.get("id", "")}') ||
                           document.querySelector('input[name="{js_result.get("name", "")}"]');
                if (cb) {{ cb.click(); return true; }}
                return false;
            }}""")
            if js_result2:
                ss(page, f"{safe}_js_toggle")
                return "enabled"
        except Exception as e2:
            print(f"  JS click also failed: {e2}")
        return "error"

def save(page, app_name):
    """Click Save."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    for sel in [
        "button:has-text('Save')",
        "input[value='Save']",
        "button[title='Save']",
    ]:
        try:
            btn = page.locator(sel).first
            btn.wait_for(state="visible", timeout=8000)
            btn.click(timeout=5000)
            print(f"  Clicked Save")
            wait_sf(page, 60000)
            time.sleep(2)
            ss(page, f"{safe}_after_save")
            return True
        except Exception:
            continue

    print(f"  Save button not found")
    ss(page, f"{safe}_no_save_btn")
    return False

def process_app(page, app_name, names_to_try=None):
    """Full workflow for one app."""
    if names_to_try is None:
        names_to_try = [app_name]

    # Navigate to App Manager
    page.goto(APP_MANAGER_URL, timeout=60000)
    wait_sf(page, 45000)
    time.sleep(3)
    ss(page, f"appmanager_{app_name.replace(' ','_')[:20]}")

    frame = find_table_frame(page)
    if not frame:
        print(f"  No table frame found!")
        ss(page, f"no_table_{app_name.replace(' ','_')[:20]}")
        return None

    # Scroll to load all rows
    total_rows = scroll_and_get_all_apps(frame, page)
    print(f"  Total rows loaded: {total_rows}")

    # Debug: show all apps
    all_rows = get_all_table_text(frame)
    print(f"  Table contents ({len(all_rows)} rows):")
    for row in all_rows:
        if row['cells']:
            print(f"    Row {row['idx']}: {row['cells'][:3]}")

    # Find the app
    row_index = None
    used_name = None

    for try_name in names_to_try:
        matches = find_app_in_table(frame, try_name)
        if matches:
            match = matches[0]
            row_index = match['rowIndex']
            used_name = try_name
            print(f"  Found '{try_name}' at row {row_index}: {match}")
            break
        else:
            print(f"  '{try_name}' not found in table")

    if row_index is None:
        print(f"  App '{app_name}' not found in App Manager")
        return None

    # Click Edit
    if not click_dropdown_and_edit(frame, page, row_index, app_name):
        return "error"

    # Click Utility Items tab
    if not click_utility_items(page, app_name):
        return "no_utility_bar"

    # Enable Start Automatically
    result = enable_start_automatically(page, app_name)
    print(f"  Start Automatically result: {result}")

    if result == "enabled":
        if not save(page, app_name):
            return "save_failed"

    return result

def main():
    results = {}

    # Get credentials
    access_token, instance_url = get_sf_credentials()
    print(f"Got credentials for {instance_url}")

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            env={"DISPLAY": ":99"},
            args=['--no-sandbox', '--disable-dev-shm-usage', '--window-size=1440,900']
        )
        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )
        page = context.new_page()

        try:
            login(page, access_token, instance_url)

            app_configs = {
                "Outdoor Living": ["Outdoor Living"],
                "LOVING Field Service": ["LOVING Field Service", "Field Services", "LOVING Field Services", "Field Service"],
                "Lightning Sales Console": ["Lightning Sales Console"],
                "Customer Success": ["Customer Success"],
            }

            for app_name, names_to_try in app_configs.items():
                print(f"\n{'='*60}")
                print(f"PROCESSING: {app_name}")
                print("="*60)
                try:
                    result = process_app(page, app_name, names_to_try)
                    results[app_name] = result
                except Exception as e:
                    print(f"  EXCEPTION: {e}")
                    import traceback
                    traceback.print_exc()
                    results[app_name] = "error"
                    ss(page, f"exception_{app_name.replace(' ','_')[:15]}")

        finally:
            browser.close()

    print("\n" + "="*60)
    print("FINAL SUMMARY")
    print("="*60)
    status_map = {
        "enabled": "ENABLED (saved)",
        "already_enabled": "Already enabled",
        "not_found": "'Ask mcLOVIN'' not found in utility items",
        "no_utility_bar": "No Utility Items tab",
        "save_failed": "Enabled but save FAILED",
        "error": "Error",
        None: "App not found in App Manager",
    }
    for app, result in results.items():
        print(f"  {app}: {status_map.get(result, str(result))}")

if __name__ == "__main__":
    main()
