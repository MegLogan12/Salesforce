#!/usr/bin/env python3
"""
Automate Salesforce Lightning App Manager to enable "Start Automatically"
for "Ask mcLOVIN'" utility item in all apps that have a Utility Bar.
Uses direct access token from SF CLI for authentication.
"""

import os
import sys
import time
import json
import subprocess
import urllib.parse
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

# Get fresh access token from SF CLI
def get_fresh_credentials():
    result = subprocess.run(
        ["sf", "org", "display", "--target-org", "dispatch"],
        capture_output=True, text=True
    )
    output = result.stdout
    # Parse the access token from the table output
    for line in output.split('\n'):
        if 'Access Token' in line:
            # Extract the token value
            parts = line.split('│')
            if len(parts) >= 3:
                token = parts[2].strip()
                return token
    return None

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
    """Wait for Salesforce to settle."""
    try:
        page.wait_for_load_state("networkidle", timeout=timeout)
    except Exception:
        pass
    try:
        page.wait_for_selector(".slds-spinner_container", state="hidden", timeout=10000)
    except Exception:
        pass
    time.sleep(1.5)

def find_table_frame(page):
    """Find the frame or page that contains the app table."""
    # Try all frames
    for f in page.frames:
        try:
            f.wait_for_selector("table tbody tr", timeout=5000)
            rows = f.query_selector_all("table tbody tr")
            if rows:
                print(f"  Found {len(rows)} rows in frame: {f.url[:60]}")
                return f, rows
        except Exception:
            pass

    # Try main page
    try:
        page.wait_for_selector("table tbody tr", timeout=8000)
        rows = page.query_selector_all("table tbody tr")
        if rows:
            print(f"  Found {len(rows)} rows in main page")
            return page, rows
    except Exception:
        pass

    return None, []

def get_app_list(page):
    """Get all apps from the App Manager table."""
    page.goto(APP_MANAGER_URL, timeout=60000)
    wait_for_sf(page, timeout=45000)
    time.sleep(3)

    # Sometimes need to scroll or wait more
    ss(page, "app_manager_loaded")

    frame, rows = find_table_frame(page)

    if not frame:
        print("ERROR: Cannot find app table!")
        ss(page, "ERROR_no_table")
        return [], None

    all_apps = []
    for row in rows:
        try:
            cells = row.query_selector_all("td")
            if len(cells) >= 2:
                name = cells[0].inner_text().strip()
                app_type = cells[1].inner_text().strip() if len(cells) > 1 else ""
                if name and name != "App Name":  # Skip header if present
                    all_apps.append({"name": name, "type": app_type})
        except Exception as e:
            pass

    print(f"\nFound {len(all_apps)} apps in App Manager")
    return all_apps, frame

def click_dropdown_edit(page, frame, app_name):
    """Find the app row and click the dropdown Edit option."""
    # Re-navigate to app manager to get fresh state
    page.goto(APP_MANAGER_URL, timeout=60000)
    wait_for_sf(page)
    time.sleep(3)

    target_frame, rows = find_table_frame(page)
    if not target_frame:
        return False

    for row in rows:
        try:
            cells = row.query_selector_all("td")
            if not cells:
                continue
            row_name = cells[0].inner_text().strip()
            if row_name != app_name:
                continue

            print(f"  Found row for '{app_name}'")

            # The dropdown button is typically in the last cell
            # Try finding it in the row
            dropdown_trigger = None
            for cell in reversed(cells):
                btn = cell.query_selector("button, a[role='button']")
                if btn:
                    dropdown_trigger = btn
                    break

            if not dropdown_trigger:
                # Try with broader selector
                dropdown_trigger = row.query_selector("button")

            if not dropdown_trigger:
                print(f"  No dropdown button found in row")
                ss(page, f"no_dropdown_{app_name.replace(' ','_')[:30]}")
                return False

            # Click the dropdown
            dropdown_trigger.click()
            time.sleep(1)
            ss(page, f"dropdown_open_{app_name.replace(' ','_')[:30]}")

            # Look for Edit option - it could be on main page or in frame
            edit_found = False
            for context in [page, target_frame]:
                try:
                    edit_link = context.locator("a:has-text('Edit'), button:has-text('Edit')").first
                    edit_link.wait_for(state="visible", timeout=5000)
                    edit_link.click()
                    edit_found = True
                    print(f"  Clicked Edit")
                    break
                except Exception:
                    pass

            if not edit_found:
                print(f"  Edit option not found in dropdown")
                ss(page, f"no_edit_{app_name.replace(' ','_')[:30]}")
                return False

            wait_for_sf(page)
            time.sleep(2)
            ss(page, f"editor_opened_{app_name.replace(' ','_')[:30]}")
            return True

        except Exception as e:
            print(f"  Row error: {e}")
            continue

    print(f"  App '{app_name}' not found in rows")
    return False

def process_utility_items(page, app_name):
    """In the app editor, set Ask mcLOVIN' Start Automatically."""
    safe_name = app_name.replace(' ', '_').replace("'", "").replace("/", "_")[:30]

    print(f"  Current URL: {page.url}")

    # Check we're in the app editor (URL should contain something like /lightning/setup/NavigationMenus/...)
    # Or it redirected to the app edit page

    # Click "Utility Items (Desktop Only)" in left nav
    try:
        utility_link = page.locator("text=Utility Items (Desktop Only)").first
        utility_link.wait_for(state="visible", timeout=20000)
        utility_link.click()
        wait_for_sf(page)
        time.sleep(1)
        ss(page, f"{safe_name}_utility_tab")
        print(f"  Clicked Utility Items tab")
    except Exception as e:
        print(f"  No Utility Items tab found: {e}")
        ss(page, f"{safe_name}_no_utility_tab")
        return "no_utility_bar"

    # Look for Ask mcLOVIN' in the utility items list
    mclovin_text = "Ask mcLOVIN'"
    try:
        mclovin_el = page.locator(f"text={mclovin_text}").first
        mclovin_el.wait_for(state="visible", timeout=10000)
        print(f"  Found 'Ask mcLOVIN'' in utility items!")
        ss(page, f"{safe_name}_mclovin_visible")
    except Exception as e:
        print(f"  'Ask mcLOVIN'' not found: {e}")
        ss(page, f"{safe_name}_no_mclovin")
        return "no_mclovin"

    # Click on it to expand settings
    try:
        mclovin_el.click()
        time.sleep(1.5)
        wait_for_sf(page)
        ss(page, f"{safe_name}_mclovin_expanded")
    except Exception as e:
        print(f"  Error clicking mcLOVIN item: {e}")

    # Find Start Automatically
    try:
        start_auto = page.locator("text=Start Automatically").first
        start_auto.wait_for(state="visible", timeout=10000)
        print(f"  Found 'Start Automatically'")
    except Exception as e:
        print(f"  'Start Automatically' not visible: {e}")
        ss(page, f"{safe_name}_no_start_auto")
        return "error"

    # Find the checkbox for Start Automatically using JS
    result = page.evaluate("""() => {
        // Search for the Start Automatically label/text
        const allText = Array.from(document.querySelectorAll('span, label, div, p'));
        for (const el of allText) {
            if (el.textContent.trim() === 'Start Automatically' ||
                el.textContent.trim() === 'Start automatically') {
                // Look in parent hierarchy for a checkbox
                let parent = el;
                for (let i = 0; i < 8; i++) {
                    parent = parent.parentElement;
                    if (!parent) break;
                    const cb = parent.querySelector('input[type="checkbox"]');
                    if (cb) {
                        return {
                            found: true,
                            checked: cb.checked,
                            id: cb.id,
                            name: cb.name
                        };
                    }
                }
            }
        }
        // Fallback: find all checkboxes and their labels
        const checkboxes = Array.from(document.querySelectorAll('input[type="checkbox"]'));
        const results = [];
        for (const cb of checkboxes) {
            // Get label text
            let labelText = '';
            if (cb.id) {
                const lbl = document.querySelector(`label[for="${cb.id}"]`);
                if (lbl) labelText = lbl.textContent.trim();
            }
            if (!labelText) {
                // Try aria-label
                labelText = cb.getAttribute('aria-label') || '';
            }
            results.push({id: cb.id, name: cb.name, labelText, checked: cb.checked});
        }
        return {found: false, allCheckboxes: results};
    }""")

    print(f"  JS result: {json.dumps(result, indent=2)[:500]}")
    ss(page, f"{safe_name}_before_check")

    checkbox = None
    is_checked = None

    if result.get("found"):
        cb_id = result.get("id")
        cb_name = result.get("name")
        is_checked = result.get("checked")
        if cb_id:
            checkbox = page.locator(f"#{cb_id}").first
        elif cb_name:
            checkbox = page.locator(f"input[name='{cb_name}']").first
    else:
        # Try to find by label proximity
        all_cbs = result.get("allCheckboxes", [])
        for cb_info in all_cbs:
            label_text = cb_info.get("labelText", "").lower()
            if "start" in label_text and "auto" in label_text:
                cb_id = cb_info.get("id")
                if cb_id:
                    checkbox = page.locator(f"#{cb_id}").first
                    is_checked = cb_info.get("checked")
                    print(f"  Found checkbox by label: '{cb_info['labelText']}', checked={is_checked}")
                    break

    if not checkbox:
        # Last resort: try by name attributes
        for name_attr in ["startAutomatically", "start_automatically", "startauto"]:
            try:
                cb = page.locator(f"input[name*='{name_attr}']").first
                cb.wait_for(state="attached", timeout=2000)
                checkbox = cb
                is_checked = cb.is_checked()
                print(f"  Found checkbox by name attr containing '{name_attr}'")
                break
            except Exception:
                pass

    if not checkbox:
        print(f"  Could not find Start Automatically checkbox")
        # Print all checkboxes for debug
        all_cbs = result.get("allCheckboxes", [])
        print(f"  All checkboxes on page: {json.dumps(all_cbs, indent=2)[:800]}")
        ss(page, f"{safe_name}_error_no_checkbox")
        return "error"

    print(f"  Checkbox found, currently checked: {is_checked}")

    if not is_checked:
        print(f"  Checking the checkbox...")
        try:
            checkbox.click()
        except Exception:
            try:
                checkbox.check()
            except Exception as e2:
                print(f"  Error checking: {e2}")

        time.sleep(0.5)
        new_state = checkbox.is_checked()
        print(f"  New state: {'CHECKED' if new_state else 'UNCHECKED'}")
        ss(page, f"{safe_name}_after_check")

        if not new_state:
            # Try clicking via JS
            page.evaluate(f"""() => {{
                const cb = document.getElementById('{checkbox.get_attribute("id") or ""}');
                if (cb) cb.click();
            }}""")
            time.sleep(0.5)
            new_state = checkbox.is_checked()
            print(f"  After JS click: {'CHECKED' if new_state else 'UNCHECKED'}")

        # Save the app
        print(f"  Saving...")
        ss(page, f"{safe_name}_before_save")
        try:
            save_btn = page.locator("button:has-text('Save')").first
            save_btn.wait_for(state="visible", timeout=10000)
            save_btn.click()
            wait_for_sf(page)
            time.sleep(2)
            ss(page, f"{safe_name}_after_save")
            print(f"  Saved!")
            return "updated"
        except Exception as e:
            print(f"  Error saving: {e}")
            ss(page, f"{safe_name}_save_error")
            return "error"
    else:
        print(f"  Already checked, skipping save")
        return "already_set"

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
    access_token = get_fresh_credentials()
    if not access_token:
        print("ERROR: Could not get access token from SF CLI!")
        xvfb_proc.terminate()
        sys.exit(1)
    print(f"Got access token: {access_token[:20]}...")

    # Construct frontdoor URL with the access token (use sid parameter)
    sid_encoded = urllib.parse.quote(access_token)
    login_url = f"{INSTANCE_URL}/secur/frontdoor.jsp?sid={sid_encoded}"
    print(f"Login URL (truncated): {login_url[:80]}...")

    results = {}

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(
                headless=False,
                args=[
                    "--no-sandbox",
                    "--disable-dev-shm-usage",
                    f"--display={display}",
                    "--window-size=1920,1080"
                ]
            )
            context = browser.new_context(
                viewport={"width": 1920, "height": 1080},
                ignore_https_errors=True
            )
            page = context.new_page()
            page.set_default_timeout(60000)
            page.set_default_navigation_timeout(60000)

            # Login via frontdoor
            print("\nLogging in via frontdoor.jsp...")
            page.goto(login_url, timeout=60000)
            wait_for_sf(page)
            ss(page, "01_after_login")
            print(f"  Current URL after login: {page.url}")

            # Check if we landed on the right page
            if "login" in page.url.lower() and "frontdoor" not in page.url.lower():
                print("  Login may have failed! URL indicates login page still showing")
                ss(page, "02_login_check")
            else:
                print("  Login appears successful!")

            # Get app list from App Manager
            print("\nLoading App Manager...")
            all_apps, initial_frame = get_app_list(page)

            if not all_apps:
                print("Could not get app list. Trying to debug...")
                ss(page, "DEBUG_no_apps")
                # Try to see what's on the page
                page_content = page.content()
                print(f"Page content length: {len(page_content)}")
                print(f"Page title: {page.title()}")
                browser.close()
                xvfb_proc.terminate()
                return

            print(f"\nAll apps ({len(all_apps)}):")
            for app in all_apps:
                print(f"  - {app['name']} [{app['type']}]")

            ss(page, "03_app_list_visible")

            # Priority ordering: put key apps first
            priority_names = [
                "Outdoor Living",
                "Field Service",
                "LOVING Field Service",
                "Sales Console",
                "Lightning Sales Console",
                "Customer Success",
            ]

            def sort_key(app):
                name = app["name"]
                for i, p in enumerate(priority_names):
                    if p.lower() in name.lower():
                        return i
                return len(priority_names)

            sorted_apps = sorted(all_apps, key=sort_key)

            # Process each app
            for app_info in sorted_apps:
                app_name = app_info["name"]
                app_type = app_info["type"]

                print(f"\n{'='*60}")
                print(f"App: {app_name} [{app_type}]")
                print('='*60)

                # Open the app editor
                opened = click_dropdown_edit(page, initial_frame, app_name)
                if not opened:
                    print(f"  Could not open editor")
                    results[app_name] = "could_not_open"
                    continue

                # Process utility items
                result = process_utility_items(page, app_name)
                results[app_name] = result
                print(f"  Final result: {result}")

                # Small pause between apps
                time.sleep(1)

            # Print summary
            print("\n" + "="*60)
            print("FINAL SUMMARY")
            print("="*60)
            for app_name, result in results.items():
                print(f"  {result:20s}  {app_name}")

            updated = [k for k, v in results.items() if v == "updated"]
            already_set = [k for k, v in results.items() if v == "already_set"]
            no_mclovin = [k for k, v in results.items() if v == "no_mclovin"]
            no_util = [k for k, v in results.items() if v == "no_utility_bar"]
            errors = [k for k, v in results.items() if v in ("error", "could_not_open")]

            print(f"\nUpdated (enabled Start Automatically): {updated}")
            print(f"Already had Start Automatically set:    {already_set}")
            print(f"No 'Ask mcLOVIN'' utility item:        {no_mclovin}")
            print(f"No Utility Bar section:                 {no_util}")
            print(f"Errors/Could not open:                  {errors}")

            browser.close()

    finally:
        xvfb_proc.terminate()
        print("\nDone. Xvfb terminated.")

if __name__ == "__main__":
    main()
