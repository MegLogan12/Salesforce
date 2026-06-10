#!/usr/bin/env python3
"""
Automate Salesforce Lightning App Manager to enable "Start Automatically"
for "Ask mcLOVIN'" utility item in all apps that have a Utility Bar.
"""

import os
import sys
import time
import subprocess
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

LOGIN_URL = "https://loving.my.salesforce.com/secur/frontdoor.jsp?otp=00Da500001UEK0H%21AQEAQCWOnO_wvZZI2cuAZWjxhR_Ezrqbv0X8ooS5OVO2oBTueyZqxIo2PCA.NxM4ceCjQ9kHMut7vzoBTxyv1kxGvs_.laML&cshc=500001mhIYb500001UEK0H"
APP_MANAGER_URL = "https://loving.my.salesforce.com/lightning/setup/NavigationMenus/home"
SCREENSHOT_DIR = "/home/user/Salesforce/screenshots"
os.makedirs(SCREENSHOT_DIR, exist_ok=True)

screenshot_counter = [0]

def ss(page, name):
    screenshot_counter[0] += 1
    path = f"{SCREENSHOT_DIR}/{screenshot_counter[0]:03d}_{name}.png"
    page.screenshot(path=path, full_page=False)
    print(f"  [screenshot] {path}")
    return path

def wait_for_sf(page):
    """Wait for Salesforce to settle - spinner gone, network idle."""
    try:
        page.wait_for_load_state("networkidle", timeout=30000)
    except Exception:
        pass
    # Also wait for any SF loading spinner to disappear
    try:
        page.wait_for_selector(".slds-spinner_container", state="hidden", timeout=15000)
    except Exception:
        pass
    time.sleep(1)

def login(page):
    print("Navigating to login URL...")
    page.goto(LOGIN_URL, timeout=60000)
    wait_for_sf(page)
    ss(page, "01_after_login")
    print(f"  Current URL: {page.url}")

def go_to_app_manager(page):
    print("Going to App Manager...")
    page.goto(APP_MANAGER_URL, timeout=60000)
    wait_for_sf(page)
    ss(page, "02_app_manager")

def get_app_list(page):
    """Return list of (app_name, row_element) for all apps visible."""
    # The App Manager page has a table with apps
    # We need to look inside the iframe if present
    print("Looking for app list...")

    # Wait for table to appear
    try:
        page.wait_for_selector("table", timeout=30000)
    except Exception:
        print("  No table found, trying iframe...")

    # Check for iframe
    frames = page.frames
    print(f"  Frames found: {len(frames)}")
    for f in frames:
        print(f"    Frame URL: {f.url}")

    ss(page, "03_app_manager_loaded")
    return frames

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

    updated_apps = []
    skipped_apps = []
    no_mclovin_apps = []

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(
                headless=False,
                args=["--no-sandbox", "--disable-dev-shm-usage", f"--display={display}"]
            )
            context = browser.new_context(
                viewport={"width": 1920, "height": 1080},
                ignore_https_errors=True
            )
            page = context.new_page()
            page.set_default_timeout(60000)
            page.set_default_navigation_timeout(60000)

            # Login
            login(page)

            # Go to App Manager
            go_to_app_manager(page)

            # The App Manager in Lightning Setup is inside an iframe
            # Let's find the right frame
            sf_frame = None
            for attempt in range(5):
                frames = page.frames
                for f in frames:
                    if "NavigationMenus" in f.url or "lightning" in f.url:
                        try:
                            # Check if it has table content
                            f.wait_for_selector("table", timeout=5000)
                            sf_frame = f
                            print(f"  Found app table in frame: {f.url}")
                            break
                        except Exception:
                            pass
                if sf_frame:
                    break
                time.sleep(2)

            if not sf_frame:
                # Try the main page
                print("  No iframe with table found, using main page")
                sf_frame = page

            ss(page, "04_frame_check")

            # Get all rows in the table
            # First, let's see what's on the page
            try:
                rows = sf_frame.query_selector_all("table tbody tr")
                print(f"  Found {len(rows)} rows in app table")
            except Exception as e:
                print(f"  Error getting rows: {e}")
                rows = []

            if not rows:
                # Try scrolling down in the iframe or page to load more
                print("  Trying to find table rows differently...")
                # Take a screenshot to see current state
                ss(page, "05_no_rows_debug")

                # Try waiting longer
                time.sleep(5)
                try:
                    sf_frame.wait_for_selector("table tbody tr", timeout=20000)
                    rows = sf_frame.query_selector_all("table tbody tr")
                    print(f"  Found {len(rows)} rows after wait")
                except Exception as e:
                    print(f"  Still no rows: {e}")

            ss(page, "06_app_list")

            # Collect app names and whether they appear to be console apps
            # Console/Lightning apps have a "Utility Bar" concept
            # We'll try to edit each app and check
            app_names = []
            for row in rows:
                try:
                    cells = row.query_selector_all("td")
                    if cells:
                        name_cell = cells[0].inner_text().strip()
                        if name_cell:
                            app_names.append(name_cell)
                except Exception:
                    pass

            print(f"\nApps found: {app_names}")

            # Priority apps to check first
            priority_apps = [
                "Outdoor Living",
                "Field Service",
                "LOVING Field Service",
                "Sales Console",
                "Lightning Sales Console",
                "Customer Success",
            ]

            # Process each app
            def process_app(app_name):
                """Process a single app - check/set mcLOVIN Start Automatically."""
                print(f"\n{'='*60}")
                print(f"Processing app: {app_name}")
                print('='*60)

                # Go back to App Manager
                page.goto(APP_MANAGER_URL, timeout=60000)
                wait_for_sf(page)
                time.sleep(2)

                # Find the frame again
                target_frame = None
                for f in page.frames:
                    try:
                        f.wait_for_selector("table", timeout=5000)
                        target_frame = f
                        break
                    except Exception:
                        pass
                if not target_frame:
                    target_frame = page

                # Find the row for this app
                try:
                    # Look for the app name in table
                    app_row = target_frame.locator(f"table tbody tr").filter(has_text=app_name).first
                    if not app_row:
                        print(f"  App '{app_name}' not found in table")
                        return "not_found"

                    # Click the dropdown arrow (last cell with a button/dropdown)
                    # The row has a dropdown at the end
                    row_text = app_row.inner_text()
                    print(f"  Row text: {row_text[:100]}")

                except Exception as e:
                    print(f"  Error finding app row: {e}")
                    return "error"

                # Click dropdown for this app
                try:
                    # Find the dropdown trigger in this row
                    dropdown_btn = app_row.locator("button, a.dropdown-trigger, [title='Open Actions'], .slds-button_icon-border-filled").last
                    dropdown_btn.click()
                    time.sleep(1)

                    # Click "Edit" in the dropdown menu
                    edit_option = page.locator("a:has-text('Edit'), button:has-text('Edit')").first
                    edit_option.wait_for(state="visible", timeout=10000)
                    edit_option.click()

                except Exception as e:
                    print(f"  Error clicking dropdown: {e}")
                    ss(page, f"error_{app_name.replace(' ', '_')}_dropdown")
                    return "error"

                # Wait for app editor to load
                wait_for_sf(page)
                ss(page, f"app_{app_name.replace(' ', '_')}_editor_opened")
                print(f"  App editor opened, URL: {page.url}")

                # Click "Utility Items (Desktop Only)" in left nav
                try:
                    utility_nav = page.locator("text=Utility Items (Desktop Only)").first
                    utility_nav.wait_for(state="visible", timeout=15000)
                    utility_nav.click()
                    wait_for_sf(page)
                    ss(page, f"app_{app_name.replace(' ', '_')}_utility_items")
                    print("  Clicked 'Utility Items (Desktop Only)'")
                except Exception as e:
                    print(f"  No 'Utility Items' nav found (app may not support utility bar): {e}")
                    ss(page, f"app_{app_name.replace(' ', '_')}_no_utility")
                    return "no_utility_bar"

                # Look for "Ask mcLOVIN'" in the utility items list
                try:
                    mclovin_item = page.locator("text=Ask mcLOVIN'").first
                    mclovin_item.wait_for(state="visible", timeout=10000)
                    print("  Found 'Ask mcLOVIN'' utility item")
                    ss(page, f"app_{app_name.replace(' ', '_')}_mclovin_found")
                except Exception as e:
                    print(f"  'Ask mcLOVIN'' not found in utility items: {e}")
                    ss(page, f"app_{app_name.replace(' ', '_')}_no_mclovin")
                    return "no_mclovin"

                # Click on the mcLOVIN' item to expand its settings
                try:
                    mclovin_item.click()
                    time.sleep(1)
                    wait_for_sf(page)
                    ss(page, f"app_{app_name.replace(' ', '_')}_mclovin_expanded")
                    print("  Clicked to expand mcLOVIN' settings")
                except Exception as e:
                    print(f"  Error expanding mcLOVIN': {e}")

                # Find "Start Automatically" checkbox
                try:
                    # Look for "Start Automatically" label and its checkbox
                    start_auto_label = page.locator("text=Start Automatically").first
                    start_auto_label.wait_for(state="visible", timeout=10000)
                    print("  Found 'Start Automatically' option")

                    # Find the associated checkbox
                    # It's usually near the label
                    checkbox = page.locator("input[type='checkbox']").filter(
                        has=page.locator("text=Start Automatically")
                    ).first

                    if not checkbox:
                        # Try finding checkbox near label
                        # Get parent of label and find checkbox within
                        parent = start_auto_label.locator("xpath=ancestor::div[contains(@class,'slds-form-element')]").first
                        checkbox = parent.locator("input[type='checkbox']").first

                    if not checkbox:
                        # Try a different approach - find checkbox by looking at label text proximity
                        checkbox = page.locator("label:has-text('Start Automatically') input[type='checkbox']").first

                    # Check if already checked
                    is_checked = checkbox.is_checked()
                    print(f"  'Start Automatically' currently checked: {is_checked}")
                    ss(page, f"app_{app_name.replace(' ', '_')}_before_check")

                    if not is_checked:
                        checkbox.click()
                        time.sleep(0.5)
                        is_checked_after = checkbox.is_checked()
                        print(f"  Checked! Now: {is_checked_after}")
                        ss(page, f"app_{app_name.replace(' ', '_')}_after_check")

                        # Save the app
                        save_btn = page.locator("button:has-text('Save')").first
                        save_btn.wait_for(state="visible", timeout=10000)
                        save_btn.click()
                        wait_for_sf(page)
                        ss(page, f"app_{app_name.replace(' ', '_')}_saved")
                        print("  Saved!")
                        return "updated"
                    else:
                        print("  Already checked, no change needed")
                        ss(page, f"app_{app_name.replace(' ', '_')}_already_set")
                        return "already_set"

                except Exception as e:
                    print(f"  Error with Start Automatically checkbox: {e}")
                    ss(page, f"app_{app_name.replace(' ', '_')}_checkbox_error")
                    return "error"

            # First, let's get the actual list from the page
            page.goto(APP_MANAGER_URL, timeout=60000)
            wait_for_sf(page)
            time.sleep(3)
            ss(page, "07_app_manager_reload")

            # Find table frame
            target_frame = None
            for f in page.frames:
                try:
                    f.wait_for_selector("table tbody tr", timeout=8000)
                    rows = f.query_selector_all("table tbody tr")
                    if len(rows) > 0:
                        target_frame = f
                        print(f"Found table in frame: {f.url}, rows: {len(rows)}")
                        break
                except Exception:
                    pass

            if not target_frame:
                print("Trying main page for table...")
                try:
                    page.wait_for_selector("table tbody tr", timeout=10000)
                    target_frame = page
                    rows = page.query_selector_all("table tbody tr")
                    print(f"Found {len(rows)} rows in main page")
                except Exception as e:
                    print(f"No table found anywhere: {e}")
                    ss(page, "ERROR_no_table")
                    sys.exit(1)

            # Get all app names and types from table
            rows = target_frame.query_selector_all("table tbody tr")
            all_apps = []
            for row in rows:
                try:
                    cells = row.query_selector_all("td")
                    if len(cells) >= 2:
                        name = cells[0].inner_text().strip()
                        app_type = cells[1].inner_text().strip() if len(cells) > 1 else ""
                        if name:
                            all_apps.append((name, app_type))
                except Exception:
                    pass

            print(f"\nAll apps ({len(all_apps)}):")
            for name, atype in all_apps:
                print(f"  - {name} [{atype}]")

            ss(page, "08_all_apps_listed")

            # Filter to Lightning apps (console apps have utility bars)
            # Standard Navigation and Console apps can have utility bars
            # We'll try all Lightning apps
            lightning_apps = [(name, atype) for name, atype in all_apps
                            if "lightning" in atype.lower() or "console" in atype.lower() or atype == ""]

            print(f"\nLightning/Console apps to check ({len(lightning_apps)}):")
            for name, atype in lightning_apps:
                print(f"  - {name} [{atype}]")

            # Process each app
            results = {}

            # We'll iterate through the rows and click the dropdown for each
            # Re-fetch the rows each time as DOM might change after navigation

            def get_app_rows_from_frame():
                """Get app rows from the table, refreshing as needed."""
                for f in page.frames:
                    try:
                        f.wait_for_selector("table tbody tr", timeout=8000)
                        rs = f.query_selector_all("table tbody tr")
                        if rs:
                            return f, rs
                    except Exception:
                        pass
                # Try main page
                try:
                    page.wait_for_selector("table tbody tr", timeout=8000)
                    rs = page.query_selector_all("table tbody tr")
                    return page, rs
                except Exception:
                    return None, []

            def click_edit_for_app(app_name_to_find):
                """Navigate to App Manager, find the app, and click Edit."""
                page.goto(APP_MANAGER_URL, timeout=60000)
                wait_for_sf(page)
                time.sleep(3)

                frame, rs = get_app_rows_from_frame()
                if not frame:
                    print(f"  Cannot get frame for {app_name_to_find}")
                    return False

                for row in rs:
                    try:
                        cells = row.query_selector_all("td")
                        if cells and cells[0].inner_text().strip() == app_name_to_find:
                            # Found the row - click the dropdown button
                            # The dropdown is usually the last cell
                            last_cell = cells[-1]
                            dropdown_btn = last_cell.query_selector("button")
                            if not dropdown_btn:
                                dropdown_btn = last_cell.query_selector("a")
                            if dropdown_btn:
                                dropdown_btn.click()
                                time.sleep(1)

                                # Now find the Edit option in the popup
                                # It might be on the main page even if table is in frame
                                edit_link = page.locator("a:has-text('Edit')").first
                                try:
                                    edit_link.wait_for(state="visible", timeout=5000)
                                    edit_link.click()
                                    wait_for_sf(page)
                                    return True
                                except Exception:
                                    # Try in frame
                                    try:
                                        edit_link_f = frame.locator("a:has-text('Edit')").first
                                        edit_link_f.wait_for(state="visible", timeout=5000)
                                        edit_link_f.click()
                                        wait_for_sf(page)
                                        return True
                                    except Exception as e2:
                                        print(f"  Edit link not found: {e2}")
                                        return False
                            else:
                                print(f"  No dropdown button found in row for {app_name_to_find}")
                                return False
                    except Exception as e:
                        continue

                print(f"  App '{app_name_to_find}' not found in table rows")
                return False

            def check_and_set_mclovin(app_name):
                """In the app editor, go to Utility Items and set Start Automatically."""
                safe_name = app_name.replace(' ', '_').replace("'", "").replace("/", "_")

                # Check current URL - should be in app editor
                current_url = page.url
                print(f"  App editor URL: {current_url}")

                if "NavigationMenus" in current_url and "edit" not in current_url.lower():
                    print(f"  Not in app editor, skipping")
                    return "error"

                ss(page, f"app_{safe_name}_01_editor")

                # Find and click "Utility Items (Desktop Only)" in left nav
                try:
                    # The left nav might use different selectors
                    utility_selector = "text=Utility Items (Desktop Only)"
                    utility_link = page.locator(utility_selector).first
                    utility_link.wait_for(state="visible", timeout=15000)
                    utility_link.click()
                    wait_for_sf(page)
                    time.sleep(1)
                    ss(page, f"app_{safe_name}_02_utility_items")
                    print(f"  Clicked Utility Items tab")
                except Exception as e:
                    print(f"  No Utility Items nav: {e}")
                    ss(page, f"app_{safe_name}_02_no_utility")
                    return "no_utility_bar"

                # Look for Ask mcLOVIN'
                try:
                    mclovin_locator = page.locator("text=Ask mcLOVIN'").first
                    mclovin_locator.wait_for(state="visible", timeout=10000)
                    print(f"  Found 'Ask mcLOVIN'' item!")
                    ss(page, f"app_{safe_name}_03_mclovin_found")
                except Exception as e:
                    print(f"  'Ask mcLOVIN'' not found: {e}")
                    ss(page, f"app_{safe_name}_03_no_mclovin")
                    return "no_mclovin"

                # Click the item to expand settings
                try:
                    mclovin_locator.click()
                    time.sleep(1)
                    wait_for_sf(page)
                    ss(page, f"app_{safe_name}_04_expanded")
                    print(f"  Expanded mcLOVIN settings")
                except Exception as e:
                    print(f"  Error expanding: {e}")

                # Find Start Automatically checkbox
                try:
                    # Try multiple strategies to find the checkbox
                    start_auto_checked = None

                    # Strategy 1: Look for checkbox near "Start Automatically" text
                    start_auto_text = page.locator("text=Start Automatically").first
                    start_auto_text.wait_for(state="visible", timeout=10000)
                    print(f"  Found 'Start Automatically' text")

                    # Strategy 2: Find the checkbox in the same form row
                    # Try to find an input near this text
                    # Check the parent elements

                    # Common SF pattern: label + checkbox in a form-element div
                    checkboxes = page.locator("input[type='checkbox']").all()
                    print(f"  Found {len(checkboxes)} checkboxes on page")

                    # Find which checkbox corresponds to Start Automatically
                    # by checking labels
                    for cb in checkboxes:
                        try:
                            cb_id = cb.get_attribute("id")
                            if cb_id:
                                label = page.locator(f"label[for='{cb_id}']").first
                                label_text = label.inner_text().strip() if label else ""
                                print(f"    Checkbox id={cb_id}, label='{label_text}'")
                                if "start automatically" in label_text.lower():
                                    start_auto_checked = cb
                                    print(f"    --> This is the Start Automatically checkbox!")
                                    break
                        except Exception:
                            pass

                    if not start_auto_checked:
                        # Try looking for it by name attribute
                        start_auto_checked = page.locator("input[name*='startAutomatically'], input[name*='start_automatically']").first
                        try:
                            start_auto_checked.wait_for(state="attached", timeout=3000)
                        except Exception:
                            start_auto_checked = None

                    if not start_auto_checked:
                        # Find the checkbox closest to the Start Automatically text
                        # Using JavaScript to find the associated input
                        result = page.evaluate("""() => {
                            const labels = Array.from(document.querySelectorAll('label, span, div'));
                            for (const el of labels) {
                                if (el.textContent.trim().toLowerCase().includes('start automatically')) {
                                    // Look for nearby input
                                    const parent = el.closest('.slds-form-element, .slds-form-element__control, .property-editor-panel');
                                    if (parent) {
                                        const input = parent.querySelector('input[type="checkbox"]');
                                        if (input) {
                                            return {found: true, checked: input.checked, id: input.id};
                                        }
                                    }
                                    // Try siblings
                                    const row = el.closest('tr, .slds-form-element__row, .form-row');
                                    if (row) {
                                        const input = row.querySelector('input[type="checkbox"]');
                                        if (input) {
                                            return {found: true, checked: input.checked, id: input.id};
                                        }
                                    }
                                }
                            }
                            return {found: false};
                        }""")
                        print(f"  JS search result: {result}")
                        if result.get("found"):
                            cb_id = result.get("id")
                            if cb_id:
                                start_auto_checked = page.locator(f"#{cb_id}").first

                    if not start_auto_checked:
                        print("  Could not find Start Automatically checkbox")
                        ss(page, f"app_{safe_name}_05_no_checkbox")
                        return "error"

                    is_checked = start_auto_checked.is_checked()
                    print(f"  'Start Automatically' is currently: {'CHECKED' if is_checked else 'UNCHECKED'}")
                    ss(page, f"app_{safe_name}_05_before_{('checked' if is_checked else 'unchecked')}")

                    if not is_checked:
                        # Click the checkbox
                        start_auto_checked.click()
                        time.sleep(0.5)
                        new_state = start_auto_checked.is_checked()
                        print(f"  After clicking: {'CHECKED' if new_state else 'UNCHECKED'}")
                        ss(page, f"app_{safe_name}_06_after_check")

                        if not new_state:
                            # Try clicking the label instead
                            print("  Checkbox didn't change, trying label click...")
                            cb_id = start_auto_checked.get_attribute("id")
                            if cb_id:
                                label = page.locator(f"label[for='{cb_id}']").first
                                label.click()
                                time.sleep(0.5)
                                new_state = start_auto_checked.is_checked()
                                print(f"  After label click: {'CHECKED' if new_state else 'UNCHECKED'}")

                        # Save
                        ss(page, f"app_{safe_name}_07_before_save")
                        save_btn = page.locator("button:has-text('Save')").first
                        save_btn.wait_for(state="visible", timeout=10000)
                        save_btn.click()
                        wait_for_sf(page)
                        time.sleep(2)
                        ss(page, f"app_{safe_name}_08_saved")
                        print(f"  SAVED!")
                        return "updated"
                    else:
                        print(f"  Already checked, no save needed")
                        ss(page, f"app_{safe_name}_05_already_set")
                        return "already_set"

                except Exception as e:
                    print(f"  Error with Start Automatically: {e}")
                    ss(page, f"app_{safe_name}_error")
                    return "error"

            # Process all apps
            for app_name, app_type in all_apps:
                safe_name = app_name.replace(' ', '_').replace("'", "").replace("/", "_")
                print(f"\n{'='*60}")
                print(f"Processing: {app_name} [{app_type}]")

                # Try to edit the app
                success = click_edit_for_app(app_name)

                if not success:
                    print(f"  Could not open editor for {app_name}")
                    results[app_name] = "could_not_open"
                    ss(page, f"app_{safe_name}_could_not_open")
                    continue

                # Now check/set mcLOVIN
                result = check_and_set_mclovin(app_name)
                results[app_name] = result
                print(f"  Result: {result}")

            # Summary
            print("\n" + "="*60)
            print("SUMMARY")
            print("="*60)
            for app_name, result in results.items():
                print(f"  {app_name}: {result}")

            updated = [k for k, v in results.items() if v == "updated"]
            already_set = [k for k, v in results.items() if v == "already_set"]
            no_mclovin = [k for k, v in results.items() if v == "no_mclovin"]
            no_util = [k for k, v in results.items() if v == "no_utility_bar"]
            errors = [k for k, v in results.items() if v in ("error", "could_not_open")]

            print(f"\nUpdated (Start Automatically now checked): {updated}")
            print(f"Already had Start Automatically checked: {already_set}")
            print(f"No 'Ask mcLOVIN'' item: {no_mclovin}")
            print(f"No Utility Bar: {no_util}")
            print(f"Errors/Could not open: {errors}")

            browser.close()

    finally:
        xvfb_proc.terminate()
        print("\nXvfb terminated.")

if __name__ == "__main__":
    main()
