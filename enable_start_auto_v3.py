#!/usr/bin/env python3
"""
Enable 'Start Automatically' for 'Ask mcLOVIN'' utility bar item
across multiple Lightning apps in Salesforce.
Uses sf CLI access token for authentication.
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
        page.wait_for_selector(".slds-spinner_container", state="hidden", timeout=10000)
    except Exception:
        pass
    time.sleep(2)

def get_sf_credentials():
    """Get access token and instance URL from sf CLI."""
    result = subprocess.run(
        ["sf", "org", "display", "--target-org", "dispatch", "--json"],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout)
    r = data.get("result", {})
    return r.get("accessToken"), r.get("instanceUrl")

def login_via_frontdoor(page, access_token, instance_url):
    """Login using frontdoor.jsp with the access token."""
    import urllib.parse
    token_encoded = urllib.parse.quote(access_token)
    frontdoor_url = f"{instance_url}/secur/frontdoor.jsp?sid={token_encoded}"
    print(f"  Navigating to frontdoor URL...")
    page.goto(frontdoor_url, timeout=60000)
    wait_sf(page, timeout=60000)
    print(f"  Current URL: {page.url}")
    ss(page, "login")
    return "login.salesforce.com" not in page.url and "secur/frontdoor" not in page.url

def find_frame_with_table(page, timeout=20000):
    """Find the iframe that contains the app manager table."""
    deadline = time.time() + timeout / 1000
    while time.time() < deadline:
        for f in page.frames:
            try:
                rows = f.query_selector_all("table tbody tr")
                if rows and len(rows) > 0:
                    first_text = rows[0].inner_text().strip()
                    if first_text and len(first_text) > 3:
                        return f, rows
            except Exception:
                pass
        time.sleep(1)
    return None, []

def get_apps_from_table(frame):
    """Extract app names from the table using JavaScript."""
    return frame.evaluate("""() => {
        const rows = document.querySelectorAll('table tbody tr');
        const apps = [];
        rows.forEach((row) => {
            const cells = row.querySelectorAll('td');
            if (cells.length >= 2) {
                // Cell 0 = checkbox (maybe), cell 1 = App Name
                // But let's check both
                const c0 = cells[0] ? cells[0].textContent.trim() : '';
                const c1 = cells[1] ? cells[1].textContent.trim() : '';
                const name = c1 || c0;
                if (name && name.length > 1) {
                    apps.push({name: name, cellCount: cells.length});
                }
            }
        });
        return apps;
    }""")

def find_and_click_edit(page, frame, rows, app_name):
    """Find the app row and click the Edit dropdown option."""
    # Use JS to find the row index
    result = frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        for (let i = 0; i < rows.length; i++) {{
            const text = rows[i].textContent.trim();
            const cells = rows[i].querySelectorAll('td');
            // Check if app name matches any cell
            for (let j = 0; j < cells.length; j++) {{
                const cellText = cells[j].textContent.trim();
                if (cellText === '{app_name}' || cellText.startsWith('{app_name}\\n')) {{
                    return {{found: true, rowIndex: i, cellIndex: j}};
                }}
            }}
        }}
        return {{found: false}};
    }}""")

    if not result.get("found"):
        print(f"  '{app_name}' not found in table")
        return False

    row_index = result["rowIndex"]
    print(f"  Found '{app_name}' at row {row_index}")

    # Click the dropdown button in that row using JS
    frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        const row = rows[{row_index}];
        if (row) {{
            const buttons = row.querySelectorAll('button, a[role="button"]');
            if (buttons.length > 0) {{
                buttons[buttons.length - 1].click();
            }}
        }}
    }}""")
    time.sleep(1.5)
    ss(page, f"dropdown_{app_name.replace(' ','_')[:20]}")

    # Click "Edit" option
    edit_clicked = False
    for ctx in [page, frame]:
        for sel in ["a:has-text('Edit')", "button:has-text('Edit')", "[title='Edit']", "a[title='Edit']"]:
            try:
                el = ctx.locator(sel).first
                el.wait_for(state="visible", timeout=3000)
                el.click()
                edit_clicked = True
                print(f"  Clicked Edit")
                break
            except Exception:
                pass
        if edit_clicked:
            break

    if not edit_clicked:
        # Try JS click on Edit
        for ctx in [page, frame]:
            try:
                result2 = ctx.evaluate("""() => {
                    const links = document.querySelectorAll('a, button, li');
                    for (const el of links) {
                        if (el.textContent.trim() === 'Edit' && el.offsetParent !== null) {
                            el.click();
                            return true;
                        }
                    }
                    return false;
                }""")
                if result2:
                    edit_clicked = True
                    print(f"  Clicked Edit via JS")
                    break
            except Exception:
                pass

    if not edit_clicked:
        print(f"  Could not click Edit for '{app_name}'")
        ss(page, f"no_edit_{app_name.replace(' ','_')[:20]}")
        return False

    wait_sf(page)
    time.sleep(2)
    ss(page, f"editor_{app_name.replace(' ','_')[:20]}")
    print(f"  Editor URL: {page.url[:80]}")
    return True

def click_utility_items_tab(page, app_name):
    """Click the Utility Items tab in the app editor sidebar."""
    safe = app_name.replace(' ', '_').replace("'", "")[:20]

    for sel in [
        "text=Utility Items (Desktop Only)",
        "button:has-text('Utility Items')",
        "a:has-text('Utility Items')",
        "li:has-text('Utility Items')",
        "span:has-text('Utility Items (Desktop Only)')",
    ]:
        try:
            el = page.locator(sel).first
            el.wait_for(state="visible", timeout=8000)
            el.click()
            wait_sf(page, 15000)
            ss(page, f"{safe}_utility_tab")
            print(f"  Clicked Utility Items tab")
            return True
        except Exception:
            continue

    print(f"  Could not find Utility Items tab for '{app_name}'")
    ss(page, f"{safe}_no_utility_tab")
    return False

def find_and_enable_start_auto(page, app_name):
    """Find Ask mcLOVIN' and enable Start Automatically."""
    safe = app_name.replace(' ', '_').replace("'", "")[:20]

    # Check if Ask mcLOVIN is on the page
    content = page.content()
    if "mcLOVIN" not in content:
        print(f"  'Ask mcLOVIN'' not found in utility items for '{app_name}'")
        ss(page, f"{safe}_no_mclovin")
        return "not_found"

    print(f"  'Ask mcLOVIN'' found in page content")

    # Click on Ask mcLOVIN to expand it
    for text_pattern in ["Ask mcLOVIN'", "Ask mcLOVIN", "mcLOVIN"]:
        try:
            el = page.locator(f"text={text_pattern}").first
            el.wait_for(state="visible", timeout=5000)
            el.scroll_into_view_if_needed()
            ss(page, f"{safe}_mclovin_visible")
            el.click()
            wait_sf(page, 10000)
            ss(page, f"{safe}_mclovin_clicked")
            print(f"  Clicked on '{text_pattern}'")
            break
        except Exception as e:
            continue

    # Look for "Start Automatically" on page
    content = page.content()
    if "Start Automatically" not in content:
        print(f"  'Start Automatically' not in page content after clicking mcLOVIN")
        ss(page, f"{safe}_no_start_auto")
        return "not_found"

    print(f"  'Start Automatically' found in page content")

    # Find the checkbox - try multiple approaches
    checkbox = None
    checkbox_state = None

    # Approach 1: Lightning input with label
    for sel in [
        "lightning-input[label='Start Automatically'] input",
        "lightning-input:has-text('Start Automatically') input",
        "label:has-text('Start Automatically') ~ input[type='checkbox']",
        "label:has-text('Start Automatically') input[type='checkbox']",
    ]:
        try:
            el = page.locator(sel).first
            if el.count() > 0:
                checkbox = el
                checkbox_state = el.is_checked(timeout=3000)
                print(f"  Found checkbox via '{sel}': {'checked' if checkbox_state else 'unchecked'}")
                break
        except Exception:
            continue

    # Approach 2: JavaScript
    if checkbox is None:
        try:
            result = page.evaluate("""() => {
                // Find all label elements containing 'Start Automatically'
                const labels = document.querySelectorAll('label, span, div');
                for (const label of labels) {
                    if (label.textContent.trim() === 'Start Automatically') {
                        // Look for associated input
                        const forAttr = label.getAttribute('for');
                        if (forAttr) {
                            const input = document.getElementById(forAttr);
                            if (input && input.type === 'checkbox') {
                                return {found: true, id: input.id, checked: input.checked};
                            }
                        }
                        // Look in parent
                        let parent = label.parentElement;
                        for (let i = 0; i < 5; i++) {
                            if (!parent) break;
                            const inputs = parent.querySelectorAll('input[type="checkbox"]');
                            if (inputs.length > 0) {
                                return {found: true, id: inputs[0].id, name: inputs[0].name, checked: inputs[0].checked};
                            }
                            parent = parent.parentElement;
                        }
                    }
                }
                // Also try lightning-input
                const lightningInputs = document.querySelectorAll('lightning-input');
                for (const li of lightningInputs) {
                    if (li.textContent.includes('Start Automatically')) {
                        const input = li.querySelector('input[type="checkbox"]');
                        if (input) {
                            return {found: true, id: input.id, name: input.name, checked: input.checked};
                        }
                    }
                }
                // Fallback: all checkboxes
                const allCbs = document.querySelectorAll('input[type="checkbox"]');
                const cbData = [];
                allCbs.forEach(cb => {
                    const label = document.querySelector('label[for="' + cb.id + '"]');
                    cbData.push({
                        id: cb.id, name: cb.name, checked: cb.checked,
                        labelText: label ? label.textContent.trim() : '',
                        parentText: cb.parentElement ? cb.parentElement.textContent.trim().slice(0, 100) : ''
                    });
                });
                return {found: false, allCheckboxes: cbData};
            }""")

            print(f"  JS checkbox result: {result}")

            if result.get("found"):
                cb_id = result.get("id", "")
                cb_name = result.get("name", "")
                is_checked = result.get("checked", False)

                if cb_id:
                    sel = f'#{cb_id}'
                elif cb_name:
                    sel = f'input[name="{cb_name}"]'

                if cb_id or cb_name:
                    checkbox = page.locator(sel).first
                    checkbox_state = is_checked
                    print(f"  Found checkbox via JS: {'checked' if is_checked else 'unchecked'}")
            else:
                # Log all checkboxes for debugging
                all_cbs = result.get("allCheckboxes", [])
                print(f"  All checkboxes found: {len(all_cbs)}")
                for cb in all_cbs:
                    print(f"    - id='{cb.get('id')}' name='{cb.get('name')}' checked={cb.get('checked')} label='{cb.get('labelText')}'")
                    if 'Start' in cb.get('labelText', '') or 'Start' in cb.get('parentText', ''):
                        # This is likely our checkbox
                        if cb.get('id'):
                            checkbox = page.locator(f'#{cb["id"]}').first
                        elif cb.get('name'):
                            checkbox = page.locator(f'input[name="{cb["name"]}"]').first
                        checkbox_state = cb.get('checked', False)
                        print(f"  Using checkbox with label containing 'Start'")

        except Exception as e:
            print(f"  JS approach error: {e}")

    ss(page, f"{safe}_before_checkbox_action")

    if checkbox is None:
        print(f"  Could not find Start Automatically checkbox")
        return "not_found"

    if checkbox_state:
        print(f"  'Start Automatically' already enabled for '{app_name}'")
        ss(page, f"{safe}_already_enabled")
        return "already_enabled"

    # Click to enable
    print(f"  Enabling 'Start Automatically'...")
    try:
        checkbox.scroll_into_view_if_needed(timeout=5000)
        checkbox.click(timeout=10000)
        time.sleep(1)

        # Verify it's now checked
        try:
            new_state = checkbox.is_checked(timeout=3000)
            print(f"  Checkbox after click: {'checked' if new_state else 'unchecked'}")
        except Exception:
            pass

        ss(page, f"{safe}_enabled")
    except Exception as e:
        print(f"  Error clicking checkbox: {e}")
        # Try JS click
        try:
            page.evaluate("""() => {
                const labels = document.querySelectorAll('label, span');
                for (const label of labels) {
                    if (label.textContent.trim() === 'Start Automatically') {
                        const forAttr = label.getAttribute('for');
                        if (forAttr) {
                            const input = document.getElementById(forAttr);
                            if (input) { input.click(); return true; }
                        }
                    }
                }
                return false;
            }""")
            ss(page, f"{safe}_js_click_cb")
            print(f"  Used JS click on checkbox")
        except Exception as e2:
            print(f"  JS click also failed: {e2}")
            return "error"

    return "enabled"

def save_app(page, app_name):
    """Click the Save button."""
    safe = app_name.replace(' ', '_').replace("'", "")[:20]

    for sel in [
        "button:has-text('Save')",
        "input[value='Save']",
        "button[title='Save']",
        ".slds-button:has-text('Save')",
    ]:
        try:
            btn = page.locator(sel).first
            btn.wait_for(state="visible", timeout=8000)
            btn.click()
            print(f"  Clicked Save ({sel})")

            wait_sf(page, 60000)
            time.sleep(2)
            ss(page, f"{safe}_saved")
            return True
        except Exception:
            continue

    print(f"  Could not find Save button")
    ss(page, f"{safe}_save_failed")
    return False

def main():
    results = {}

    # Get credentials
    print("Getting sf CLI credentials...")
    access_token, instance_url = get_sf_credentials()
    if not access_token:
        print("ERROR: Could not get access token from sf CLI")
        sys.exit(1)
    print(f"  Instance URL: {instance_url}")
    print(f"  Access token: {access_token[:20]}...")

    with sync_playwright() as p:
        print("\nLaunching Chromium...")
        browser = p.chromium.launch(
            headless=False,
            env={"DISPLAY": ":99"},
            args=[
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--window-size=1440,900',
                '--disable-web-security',
            ]
        )

        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )
        page = context.new_page()

        try:
            # Login
            print("\n--- Logging in ---")
            logged_in = login_via_frontdoor(page, access_token, instance_url)
            if not logged_in:
                print("WARNING: Login may not have succeeded, continuing anyway...")
                # Check if we're on a login page
                if "login" in page.url.lower() and "secur/frontdoor" not in page.url:
                    print("ERROR: Stuck on login page!")
                    ss(page, "stuck_on_login")
                    sys.exit(1)

            print(f"  Logged in, current URL: {page.url}")

            # Navigate to App Manager first to see what apps are there
            print("\n--- Exploring App Manager ---")
            page.goto(APP_MANAGER_URL, timeout=60000)
            wait_sf(page, 45000)
            time.sleep(3)
            ss(page, "app_manager_initial")

            frame, rows = find_frame_with_table(page)
            if frame:
                apps = get_apps_from_table(frame)
                print(f"  Apps found in table ({len(apps)}):")
                for app in apps:
                    print(f"    - '{app['name']}' ({app['cellCount']} cells)")
            else:
                print("  No table frame found!")
                ss(page, "no_table_frame")

            # Process each target app
            for app_name in TARGET_APPS:
                print(f"\n{'='*60}")
                print(f"PROCESSING: {app_name}")
                print("="*60)

                try:
                    # Go to App Manager
                    page.goto(APP_MANAGER_URL, timeout=60000)
                    wait_sf(page, 45000)
                    time.sleep(3)

                    frame, rows = find_frame_with_table(page)
                    if not frame:
                        print(f"  No table frame found for '{app_name}'")
                        results[app_name] = "error"
                        continue

                    # Check for alternative names
                    names_to_try = [app_name]
                    if app_name == "LOVING Field Service":
                        names_to_try = ["LOVING Field Service", "Field Services", "Field Service", "LOVING Field Services"]

                    edit_success = False
                    for try_name in names_to_try:
                        if find_and_click_edit(page, frame, rows, try_name):
                            edit_success = True
                            break
                        # Refresh rows after failed attempt
                        frame, rows = find_frame_with_table(page)
                        if not frame:
                            break

                    if not edit_success:
                        print(f"  Could not open editor for '{app_name}'")
                        results[app_name] = None
                        continue

                    # Click Utility Items tab
                    if not click_utility_items_tab(page, app_name):
                        results[app_name] = "no_utility_bar"
                        # Try to go back
                        page.go_back()
                        wait_sf(page)
                        continue

                    # Find and enable Start Automatically
                    result = find_and_enable_start_auto(page, app_name)
                    results[app_name] = result
                    print(f"  Result: {result}")

                    if result == "enabled":
                        # Save
                        if not save_app(page, app_name):
                            results[app_name] = "save_failed"
                    elif result == "already_enabled":
                        print(f"  Already enabled, no save needed")

                except Exception as e:
                    print(f"  EXCEPTION for '{app_name}': {e}")
                    import traceback
                    traceback.print_exc()
                    results[app_name] = "error"
                    ss(page, f"exception_{app_name.replace(' ','_')[:20]}")

        finally:
            browser.close()

    # Summary
    print("\n" + "="*60)
    print("FINAL SUMMARY")
    print("="*60)
    for app, result in results.items():
        status_map = {
            "enabled": "ENABLED Start Automatically (saved)",
            "already_enabled": "Already enabled (no change needed)",
            "not_found": "'Ask mcLOVIN'' not found in utility items",
            "no_utility_bar": "App has no Utility Bar / tab not found",
            "save_failed": "Enabled but SAVE FAILED",
            "error": "Error occurred",
            None: "App not found in App Manager",
        }
        status = status_map.get(result, f"Unknown: {result}")
        print(f"  {app}: {status}")

    return results

if __name__ == "__main__":
    main()
