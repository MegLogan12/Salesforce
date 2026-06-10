#!/usr/bin/env python3
"""
Enable 'Start Automatically' for 'Ask mcLOVIN'' utility bar item
across specified Lightning apps in Salesforce.
"""

import os
import time
import subprocess
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

LOGIN_URL = "https://loving.my.salesforce.com/secur/frontdoor.jsp?otp=00Da500001UEK0H%21AQEAQCWOnO_wvZZI2cuAZWjxhR_Ezrqbv0X8ooS5OVO2oBTueyZqxIo2PCA.NxM4ceCjQ9kHMut7vzoBTxyv1kxGvs_.laML&cshc=500001mhIYb500001UEK0H"
APP_MANAGER_URL = "https://loving.my.salesforce.com/lightning/setup/NavigationMenus/home"
SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots"
TARGET_APPS = [
    "Outdoor Living",
    "LOVING Field Service",
    "Field Services",
    "Lightning Sales Console",
    "Customer Success",
]

screenshot_counter = [0]

def screenshot(page, name):
    screenshot_counter[0] += 1
    path = os.path.join(SCREENSHOTS_DIR, f"startauto_{screenshot_counter[0]:02d}_{name}.png")
    page.screenshot(path=path, full_page=False)
    print(f"  [screenshot] {path}")
    return path

def wait_and_screenshot(page, name, timeout=30000):
    page.wait_for_load_state('networkidle', timeout=timeout)
    return screenshot(page, name)

def login(page):
    print("Logging in to Salesforce...")
    page.goto(LOGIN_URL, timeout=60000)
    page.wait_for_load_state('networkidle', timeout=60000)
    screenshot(page, "after_login")
    print(f"  Current URL: {page.url}")

def go_to_app_manager(page):
    print("\nNavigating to App Manager...")
    page.goto(APP_MANAGER_URL, timeout=60000)
    page.wait_for_load_state('networkidle', timeout=60000)
    time.sleep(3)
    screenshot(page, "appmanager")

def find_app_row_and_edit(page, app_name):
    """Find the app in the table and click Edit from the dropdown."""
    print(f"\n  Looking for app: {app_name}")

    # The App Manager loads in an iframe
    # Try to find the iframe first
    frames = page.frames
    print(f"  Found {len(frames)} frames")

    target_frame = None
    for frame in frames:
        frame_url = frame.url
        print(f"    Frame URL: {frame_url}")
        if 'NavigationMenus' in frame_url or 'setup' in frame_url.lower():
            target_frame = frame
            break

    # Also try the main page
    search_contexts = [page]
    if target_frame and target_frame != page:
        search_contexts.insert(0, target_frame)

    for ctx in search_contexts:
        try:
            # Look for table rows containing the app name
            # The App Manager table has rows with app names
            rows = ctx.locator('table tbody tr').all()
            print(f"  Found {len(rows)} rows in context {ctx}")

            for row in rows:
                try:
                    row_text = row.inner_text(timeout=2000)
                    if app_name.lower() in row_text.lower():
                        print(f"  Found row with text: {row_text[:100]}")
                        screenshot(page, f"found_row_{app_name.replace(' ', '_')}")

                        # Click the dropdown button (last button in the row)
                        dropdown_buttons = row.locator('button, a[role="button"]').all()
                        print(f"  Found {len(dropdown_buttons)} buttons in row")

                        if dropdown_buttons:
                            # The dropdown arrow is typically the last button
                            last_btn = dropdown_buttons[-1]
                            last_btn.click(timeout=10000)
                            time.sleep(1)
                            screenshot(page, f"dropdown_open_{app_name.replace(' ', '_')}")

                            # Look for "Edit" in the dropdown
                            # It might be in a dropdown menu that appeared
                            edit_item = page.locator('a:has-text("Edit"), button:has-text("Edit")').first
                            if edit_item.is_visible(timeout=5000):
                                edit_item.click(timeout=10000)
                                return True

                except Exception as e:
                    continue

        except Exception as e:
            print(f"  Error searching context: {e}")
            continue

    return False

def process_app_via_search(page, app_name):
    """Try to find and edit the app using the search/filter functionality."""
    print(f"\nProcessing app: {app_name}")

    # Navigate to App Manager fresh
    go_to_app_manager(page)

    # Try searching in the App Manager
    # There might be a search input
    try:
        search_input = page.locator('input[placeholder*="Search"], input[placeholder*="search"]').first
        if search_input.is_visible(timeout=5000):
            search_input.fill(app_name)
            time.sleep(2)
            screenshot(page, f"search_{app_name.replace(' ', '_')}")
    except:
        pass

    screenshot(page, f"appmanager_for_{app_name.replace(' ', '_')}")

    # Try finding in iframe
    all_frames = page.frames

    for frame in all_frames:
        try:
            # Look for the app name in each frame
            if app_name.lower() in frame.content().lower():
                print(f"  Found app name in frame: {frame.url}")

                # Try to find and click the row's dropdown
                # First, find cells with the app name
                cells = frame.locator(f'td:has-text("{app_name}"), td:has-text("{app_name.lower()}")').all()
                print(f"  Found {len(cells)} cells with app name")

                for cell in cells:
                    try:
                        # Get the parent row
                        row = cell.locator('xpath=ancestor::tr[1]')
                        row_text = row.inner_text(timeout=2000)
                        print(f"  Row text: {row_text[:150]}")

                        # Find the dropdown trigger in this row
                        # In Salesforce App Manager, it's usually a button with lightning-button-menu
                        dropdown_btn = row.locator('lightning-button-menu button, button[aria-haspopup="true"], .slds-button_icon-border-filled').first

                        if not dropdown_btn.is_visible(timeout=3000):
                            # Try any button at end of row
                            btns = row.locator('button').all()
                            if btns:
                                dropdown_btn = btns[-1]

                        print(f"  Clicking dropdown button...")
                        dropdown_btn.scroll_into_view_if_needed()
                        dropdown_btn.click(timeout=10000)
                        time.sleep(1.5)
                        screenshot(page, f"dropdown_{app_name.replace(' ', '_')}")

                        # Click Edit
                        edit_btn = page.locator('a:has-text("Edit")').first
                        if not edit_btn.is_visible(timeout=3000):
                            edit_btn = frame.locator('a:has-text("Edit")').first

                        edit_btn.click(timeout=10000)
                        page.wait_for_load_state('networkidle', timeout=60000)
                        time.sleep(3)
                        screenshot(page, f"editor_loaded_{app_name.replace(' ', '_')}")
                        return True

                    except Exception as e:
                        print(f"  Error with cell: {e}")
                        continue

        except Exception as e:
            print(f"  Frame error: {e}")
            continue

    return False

def enable_start_automatically(page, app_name):
    """In the app editor, find Utility Items and enable Start Automatically for Ask mcLOVIN'."""

    print(f"  Looking for 'Utility Items' in the left nav...")

    # The app editor has a sidebar with steps
    # Try clicking "Utility Items (Desktop Only)"
    try:
        # Look for utility items nav item
        utility_nav = page.locator('text="Utility Items (Desktop Only)"').first
        if not utility_nav.is_visible(timeout=10000):
            # Try partial match
            utility_nav = page.locator('[class*="nav"] :text-matches("Utility Items", "i")').first

        utility_nav.click(timeout=15000)
        page.wait_for_load_state('networkidle', timeout=30000)
        time.sleep(2)
        screenshot(page, f"utility_items_{app_name.replace(' ', '_')}")
        print("  Clicked 'Utility Items'")
    except Exception as e:
        print(f"  Error clicking Utility Items nav: {e}")
        screenshot(page, f"utility_nav_error_{app_name.replace(' ', '_')}")
        return "error", "Could not find Utility Items nav"

    # Now find "Ask mcLOVIN'" in the list
    print("  Looking for 'Ask mcLOVIN'' item...")

    # Try to find the mcLOVIN item
    mclovin_item = None

    try:
        # Try exact or partial text match
        mclovin_item = page.locator(':text-matches("Ask mcLOVIN", "i"), :text-matches("mcLOVIN", "i")').first
        if mclovin_item.is_visible(timeout=10000):
            print("  Found 'Ask mcLOVIN'' item")
            mclovin_item.click(timeout=10000)
            time.sleep(1.5)
            screenshot(page, f"mclovin_expanded_{app_name.replace(' ', '_')}")
        else:
            screenshot(page, f"no_mclovin_{app_name.replace(' ', '_')}")
            return "not_found", "Ask mcLOVIN' not found in utility items"
    except Exception as e:
        print(f"  Error finding mcLOVIN item: {e}")
        screenshot(page, f"mclovin_error_{app_name.replace(' ', '_')}")
        return "not_found", f"Ask mcLOVIN' not found: {e}"

    # Look for "Start Automatically" checkbox
    print("  Looking for 'Start Automatically' checkbox...")

    try:
        # Find the Start Automatically control
        start_auto_label = page.locator(':text-matches("Start Automatically", "i")').first

        if not start_auto_label.is_visible(timeout=10000):
            screenshot(page, f"no_start_auto_{app_name.replace(' ', '_')}")
            return "error", "Could not find Start Automatically option"

        print("  Found 'Start Automatically' label")
        screenshot(page, f"start_auto_found_{app_name.replace(' ', '_')}")

        # Find the associated checkbox/toggle
        # It could be a checkbox input, a toggle, or a lightning-input
        # Try to find checkbox near the label

        # Method 1: Look for checkbox in the same container
        start_auto_container = start_auto_label.locator('xpath=ancestor::*[contains(@class, "form-element") or contains(@class, "input") or contains(@class, "row")][1]')

        checkbox = None

        # Try finding input[type="checkbox"] near the label
        try:
            checkbox = page.locator('input[type="checkbox"]').filter(has=page.locator(':text-matches("Start Automatically", "i")')).first
        except:
            pass

        if not checkbox or not checkbox.is_visible(timeout=2000):
            # Try looking for the checkbox near the "Start Automatically" text
            # Navigate up from the label then find input
            try:
                # Find all checkboxes on page and look for one associated with Start Automatically
                all_checkboxes = page.locator('input[type="checkbox"]').all()
                print(f"  Found {len(all_checkboxes)} checkboxes on page")

                # Get bounding box of Start Automatically text to find nearby checkbox
                label_box = start_auto_label.bounding_box()
                print(f"  Label bounding box: {label_box}")

                for cb in all_checkboxes:
                    try:
                        cb_box = cb.bounding_box()
                        if cb_box and label_box:
                            # Check if checkbox is near the label (within 200px)
                            dist_x = abs(cb_box['x'] - label_box['x'])
                            dist_y = abs(cb_box['y'] - label_box['y'])
                            print(f"  Checkbox at ({cb_box['x']:.0f}, {cb_box['y']:.0f}), dist: ({dist_x:.0f}, {dist_y:.0f})")
                            if dist_y < 50:  # Same row approximately
                                checkbox = cb
                                print(f"  Selected checkbox at ({cb_box['x']:.0f}, {cb_box['y']:.0f})")
                                break
                    except:
                        continue

            except Exception as e:
                print(f"  Error finding checkbox by proximity: {e}")

        if not checkbox:
            # Try lightning-input with "Start Automatically" label
            try:
                lightning_input = page.locator('lightning-input:has(:text-matches("Start Automatically", "i")) input[type="checkbox"]').first
                if lightning_input.is_visible(timeout=3000):
                    checkbox = lightning_input
            except:
                pass

        if checkbox and checkbox.is_visible(timeout=3000):
            is_checked = checkbox.is_checked()
            print(f"  Checkbox is currently: {'checked' if is_checked else 'unchecked'}")
            screenshot(page, f"checkbox_state_{app_name.replace(' ', '_')}")

            if is_checked:
                return "already_enabled", "Start Automatically was already enabled"
            else:
                # Click the checkbox to enable it
                checkbox.click(timeout=10000)
                time.sleep(1)
                is_checked_after = checkbox.is_checked()
                print(f"  Checkbox after click: {'checked' if is_checked_after else 'unchecked'}")
                screenshot(page, f"checkbox_after_click_{app_name.replace(' ', '_')}")

                if is_checked_after:
                    return "enabled", "Successfully enabled Start Automatically"
                else:
                    return "error", "Checkbox did not get checked after clicking"
        else:
            # Try clicking the label itself (might be a toggle)
            try:
                start_auto_label.click(timeout=5000)
                time.sleep(1)
                screenshot(page, f"after_label_click_{app_name.replace(' ', '_')}")
                return "enabled", "Clicked label (toggle behavior)"
            except Exception as e:
                screenshot(page, f"no_checkbox_{app_name.replace(' ', '_')}")
                return "error", f"Could not find or click Start Automatically checkbox: {e}"

    except Exception as e:
        print(f"  Error with Start Automatically: {e}")
        screenshot(page, f"start_auto_error_{app_name.replace(' ', '_')}")
        return "error", str(e)

def save_app(page, app_name):
    """Click the Save button and wait for confirmation."""
    print(f"  Saving app {app_name}...")

    try:
        save_btn = page.locator('button:has-text("Save"), input[value="Save"]').first
        if not save_btn.is_visible(timeout=10000):
            # Try more specific locators
            save_btn = page.locator('[class*="save"], [data-aura-action*="save"]').first

        save_btn.click(timeout=15000)
        page.wait_for_load_state('networkidle', timeout=60000)
        time.sleep(3)
        screenshot(page, f"saved_{app_name.replace(' ', '_')}")
        print(f"  Saved!")
        return True
    except Exception as e:
        print(f"  Error saving: {e}")
        screenshot(page, f"save_error_{app_name.replace(' ', '_')}")
        return False

def process_app(page, app_name, results):
    """Full workflow to process a single app."""
    print(f"\n{'='*60}")
    print(f"Processing: {app_name}")
    print(f"{'='*60}")

    # Go to App Manager and find the app
    found = process_app_via_search(page, app_name)

    if not found:
        print(f"  Could not find app '{app_name}' in App Manager")
        results[app_name] = ("not_found", "App not found in App Manager")
        return

    # We're now in the app editor
    print(f"  Successfully opened app editor for '{app_name}'")

    # Enable Start Automatically
    status, message = enable_start_automatically(page, app_name)

    if status == "enabled":
        # Save the app
        saved = save_app(page, app_name)
        if saved:
            results[app_name] = ("success", "Enabled and saved Start Automatically")
        else:
            results[app_name] = ("save_error", "Enabled but save failed")
    elif status == "already_enabled":
        results[app_name] = ("already_enabled", "Was already enabled")
    else:
        results[app_name] = (status, message)

def main():
    os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

    results = {}

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            args=[
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                f'--display={os.environ.get("DISPLAY", ":99")}',
            ]
        )

        context = browser.new_context(
            viewport={'width': 1440, 'height': 900},
            ignore_https_errors=True,
        )

        page = context.new_page()
        page.set_default_timeout(60000)

        # Login
        login(page)

        # Process each app
        # We need to check which aliases exist for Field Service
        apps_to_process = [
            "Outdoor Living",
            "LOVING Field Service",
            "Lightning Sales Console",
            "Customer Success",
        ]

        for app_name in apps_to_process:
            try:
                process_app(page, app_name, results)
            except Exception as e:
                print(f"\nERROR processing {app_name}: {e}")
                screenshot(page, f"error_{app_name.replace(' ', '_')}")
                results[app_name] = ("error", str(e))

        browser.close()

    # Print summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    for app_name, (status, message) in results.items():
        print(f"\n{app_name}:")
        print(f"  Status: {status}")
        print(f"  Details: {message}")

    return results

if __name__ == "__main__":
    main()
