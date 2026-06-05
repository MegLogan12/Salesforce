#!/usr/bin/env python3
"""
Enable 'Start Automatically' for 'Ask mcLOVIN'' utility bar item
across multiple Lightning apps in Salesforce.
"""

import os
import time
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

os.makedirs(SCREENSHOTS_DIR, exist_ok=True)
screenshot_counter = [0]

def take_screenshot(page, name):
    screenshot_counter[0] += 1
    path = os.path.join(SCREENSHOTS_DIR, f"startauto_{screenshot_counter[0]:02d}_{name}.png")
    page.screenshot(path=path)
    print(f"  Screenshot: {path}")
    return path

def wait_and_screenshot(page, name, timeout=30000):
    page.wait_for_load_state('networkidle', timeout=timeout)
    return take_screenshot(page, name)

def login(page):
    print("Logging in...")
    page.goto(LOGIN_URL, timeout=60000)
    page.wait_for_load_state('networkidle', timeout=60000)
    take_screenshot(page, "login")
    print(f"  Current URL after login: {page.url}")

def go_to_app_manager(page):
    print("\nNavigating to App Manager...")
    page.goto(APP_MANAGER_URL, timeout=60000)
    # Wait for the App Manager table to be visible
    try:
        page.wait_for_selector('text=App Manager', timeout=30000)
        page.wait_for_load_state('networkidle', timeout=30000)
    except PlaywrightTimeoutError:
        print("  Warning: Could not find 'App Manager' text")
    take_screenshot(page, "appmanager")

def find_app_row_and_edit(page, app_name):
    """Find the app row in the table and click Edit from the dropdown."""
    print(f"\n  Looking for app: '{app_name}'")

    # The App Manager uses an iframe - need to check
    # Try to find the app in the main frame first, then check iframes

    # Look for the app name in the table
    # The table rows contain the app name as text

    # First try: look for the app name directly
    try:
        # Try to find text matching the app name
        app_row = page.locator(f'text="{app_name}"').first
        if app_row.count() == 0:
            print(f"  Could not find '{app_name}' - trying partial match")
            return False

        # Scroll it into view
        app_row.scroll_into_view_if_needed(timeout=10000)
        take_screenshot(page, f"found_{app_name.replace(' ', '_').lower()}")

    except Exception as e:
        print(f"  Error finding app: {e}")
        return False

    return True

def process_app_in_iframe(page, app_name):
    """Process an app - find it in App Manager and enable Start Automatically."""
    print(f"\n{'='*60}")
    print(f"Processing: {app_name}")
    print('='*60)

    # Navigate to App Manager
    go_to_app_manager(page)

    # The App Manager table might be in an iframe
    # Let's check for iframes
    frames = page.frames
    print(f"  Number of frames: {len(frames)}")
    for i, frame in enumerate(frames):
        print(f"  Frame {i}: {frame.url}")

    # Try to find the app in the main frame or iframes
    target_frame = page

    # Check if there's a content iframe
    for frame in page.frames:
        if 'NavigationMenus' in frame.url or frame.url != page.url:
            if frame.url and frame.url != 'about:blank':
                try:
                    content = frame.content()
                    if app_name in content or (app_name == "LOVING Field Service" and "Field Service" in content):
                        target_frame = frame
                        print(f"  Found app in frame: {frame.url}")
                        break
                except:
                    pass

    # Search for the app name
    search_name = app_name
    if app_name == "LOVING Field Service":
        # Try both variations
        for name_attempt in ["LOVING Field Service", "Field Services", "Field Service"]:
            result = try_find_and_edit_app(page, target_frame, name_attempt)
            if result:
                return result
        return None
    else:
        return try_find_and_edit_app(page, target_frame, search_name)

def try_find_and_edit_app(page, frame, app_name):
    """Try to find an app by name and click its Edit button."""
    print(f"  Searching for '{app_name}' in table...")

    try:
        # Look for the app name in table cells
        # In Salesforce App Manager, rows have the app name in a th or td element
        selectors = [
            f'//tr[.//a[contains(text(), "{app_name}")]]',
            f'//tr[.//span[contains(text(), "{app_name}")]]',
            f'//tr[contains(., "{app_name}")]',
        ]

        row = None
        for selector in selectors:
            try:
                elements = frame.locator(selector)
                count = elements.count()
                if count > 0:
                    # Get the first matching row that exactly contains our app name
                    for i in range(count):
                        el = elements.nth(i)
                        text = el.inner_text()
                        if app_name in text:
                            row = el
                            print(f"  Found row with text containing '{app_name}'")
                            break
                    if row:
                        break
            except Exception as e:
                print(f"  Selector '{selector}' failed: {e}")
                continue

        if not row:
            print(f"  Could not find '{app_name}' in the table")
            take_screenshot(page, f"notfound_{app_name.replace(' ', '_').lower()}")
            return None

        # Scroll the row into view
        row.scroll_into_view_if_needed(timeout=10000)
        take_screenshot(page, f"row_{app_name.replace(' ', '_').lower()}")

        # Find the dropdown button in this row
        # It's usually a button with an arrow/chevron at the end of the row
        dropdown_selectors = [
            'button.slds-button_icon',
            'button[title="Show More"]',
            'button[aria-haspopup="true"]',
            'button.slds-button--icon-border-filled',
            'a.dropDownLink',
            '.actionColumn button',
            'td:last-child button',
            'th:last-child button',
        ]

        dropdown_btn = None
        for sel in dropdown_selectors:
            try:
                btn = row.locator(sel).last
                if btn.count() > 0:
                    dropdown_btn = btn
                    print(f"  Found dropdown with selector: {sel}")
                    break
            except:
                continue

        if not dropdown_btn:
            # Try finding any button in the row
            try:
                btns = row.locator('button')
                if btns.count() > 0:
                    dropdown_btn = btns.last
                    print(f"  Using last button in row")
            except:
                pass

        if not dropdown_btn:
            print(f"  Could not find dropdown button for '{app_name}'")
            return None

        # Click the dropdown
        print(f"  Clicking dropdown button...")
        dropdown_btn.click(timeout=10000)
        time.sleep(1)
        take_screenshot(page, f"dropdown_{app_name.replace(' ', '_').lower()}")

        # Click "Edit" from the dropdown menu
        print(f"  Looking for Edit option...")
        edit_selectors = [
            'text="Edit"',
            'a:has-text("Edit")',
            'lightning-menu-item:has-text("Edit")',
            '.slds-dropdown a:has-text("Edit")',
        ]

        for sel in edit_selectors:
            try:
                edit_option = page.locator(sel).first
                if edit_option.count() > 0 and edit_option.is_visible(timeout=5000):
                    edit_option.click(timeout=10000)
                    print(f"  Clicked Edit")
                    break
            except:
                continue

        # Wait for editor to load
        print(f"  Waiting for app editor to load...")
        try:
            page.wait_for_load_state('networkidle', timeout=60000)
            time.sleep(3)
        except PlaywrightTimeoutError:
            print("  Warning: networkidle timeout, continuing...")

        take_screenshot(page, f"editor_{app_name.replace(' ', '_').lower()}")
        print(f"  Editor URL: {page.url}")

        return app_name

    except Exception as e:
        print(f"  Error processing '{app_name}': {e}")
        take_screenshot(page, f"error_{app_name.replace(' ', '_').lower()}")
        return None

def click_utility_items_tab(page):
    """Click on 'Utility Items (Desktop Only)' in the left sidebar."""
    print("  Looking for 'Utility Items' tab...")

    selectors = [
        'text="Utility Items (Desktop Only)"',
        'text="Utility Items"',
        'button:has-text("Utility Items")',
        'a:has-text("Utility Items")',
        'li:has-text("Utility Items")',
        '.setupNavigationItem:has-text("Utility Items")',
    ]

    for sel in selectors:
        try:
            el = page.locator(sel).first
            if el.count() > 0 and el.is_visible(timeout=5000):
                el.click(timeout=10000)
                print(f"  Clicked Utility Items tab")
                time.sleep(2)
                page.wait_for_load_state('networkidle', timeout=30000)
                take_screenshot(page, "utility_items_tab")
                return True
        except Exception as e:
            continue

    print("  Could not find Utility Items tab")
    take_screenshot(page, "utility_items_notfound")
    return False

def find_and_enable_start_automatically(page, app_name):
    """Find 'Ask mcLOVIN'' and enable Start Automatically."""
    print(f"  Looking for 'Ask mcLOVIN'' utility item...")

    # First, look for the item
    mclovin_selectors = [
        'text="Ask mcLOVIN\'"',
        'text="Ask mcLOVIN"',
        '*:has-text("Ask mcLOVIN")',
    ]

    mclovin_el = None
    for sel in mclovin_selectors:
        try:
            el = page.locator(sel).first
            if el.count() > 0:
                # Check if it's visible or scroll to it
                el.scroll_into_view_if_needed(timeout=10000)
                mclovin_el = el
                print(f"  Found 'Ask mcLOVIN'' element")
                break
        except Exception as e:
            continue

    if not mclovin_el:
        print(f"  Could not find 'Ask mcLOVIN'' in utility items")
        take_screenshot(page, f"mclovin_notfound_{app_name.replace(' ', '_').lower()}")
        return "not_found"

    take_screenshot(page, f"mclovin_found_{app_name.replace(' ', '_').lower()}")

    # Click on it to expand its settings
    print(f"  Clicking on 'Ask mcLOVIN'' to expand settings...")
    try:
        mclovin_el.click(timeout=10000)
        time.sleep(2)
        page.wait_for_load_state('networkidle', timeout=30000)
    except Exception as e:
        print(f"  Click failed: {e}")

    take_screenshot(page, f"mclovin_expanded_{app_name.replace(' ', '_').lower()}")

    # Look for the "Start Automatically" checkbox or toggle
    print(f"  Looking for 'Start Automatically' checkbox...")

    start_auto_selectors = [
        'input[type="checkbox"][name*="start"]',
        'input[type="checkbox"][id*="start"]',
        'lightning-input:has-text("Start Automatically") input',
        'label:has-text("Start Automatically") input',
        'label:has-text("Start Automatically")',
        '*:has-text("Start Automatically") input[type="checkbox"]',
        'input[type="checkbox"]:near(:text("Start Automatically"))',
    ]

    checkbox = None
    for sel in start_auto_selectors:
        try:
            el = page.locator(sel).first
            if el.count() > 0:
                checkbox = el
                print(f"  Found checkbox with selector: {sel}")
                break
        except Exception as e:
            continue

    if not checkbox:
        # Try a broader search
        print(f"  Trying broader search for Start Automatically...")
        try:
            # Get all text on page and look for Start Automatically context
            page_text = page.content()
            if "Start Automatically" in page_text:
                print(f"  'Start Automatically' text found in page, but couldn't locate checkbox")
                # Try to find any checkbox near this text
                checkboxes = page.locator('input[type="checkbox"]')
                count = checkboxes.count()
                print(f"  Found {count} checkboxes on page")
                take_screenshot(page, f"checkboxes_{app_name.replace(' ', '_').lower()}")
            else:
                print(f"  'Start Automatically' not found in page content")
                take_screenshot(page, f"no_start_auto_{app_name.replace(' ', '_').lower()}")
                return "not_found"
        except Exception as e:
            print(f"  Error: {e}")

    if checkbox:
        try:
            is_checked = checkbox.is_checked(timeout=5000)
            print(f"  'Start Automatically' checkbox is currently: {'checked' if is_checked else 'unchecked'}")

            if is_checked:
                take_screenshot(page, f"already_enabled_{app_name.replace(' ', '_').lower()}")
                return "already_enabled"
            else:
                # Click to enable
                checkbox.click(timeout=10000)
                time.sleep(1)
                take_screenshot(page, f"enabled_{app_name.replace(' ', '_').lower()}")
                print(f"  Checked 'Start Automatically'")
                return "enabled"
        except Exception as e:
            print(f"  Error with checkbox: {e}")

    return "not_found"

def save_app(page, app_name):
    """Click the Save button and wait for confirmation."""
    print(f"  Looking for Save button...")

    save_selectors = [
        'button:has-text("Save")',
        'input[value="Save"]',
        'button[title="Save"]',
        '.slds-button:has-text("Save")',
    ]

    for sel in save_selectors:
        try:
            btn = page.locator(sel).first
            if btn.count() > 0 and btn.is_visible(timeout=5000):
                btn.click(timeout=10000)
                print(f"  Clicked Save button")

                # Wait for save to complete
                try:
                    page.wait_for_load_state('networkidle', timeout=60000)
                    time.sleep(3)
                except PlaywrightTimeoutError:
                    print("  Warning: networkidle timeout after save")

                take_screenshot(page, f"saved_{app_name.replace(' ', '_').lower()}")
                return True
        except Exception as e:
            continue

    print(f"  Could not find Save button")
    take_screenshot(page, f"save_failed_{app_name.replace(' ', '_').lower()}")
    return False

def main():
    results = {}

    with sync_playwright() as p:
        print("Starting Playwright with Chromium...")
        browser = p.chromium.launch(
            headless=False,
            env={"DISPLAY": ":99"},
            args=[
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--window-size=1440,900',
            ]
        )

        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )

        page = context.new_page()

        try:
            # Login
            login(page)

            # Process each target app
            for app_name in ["Outdoor Living", "LOVING Field Service", "Lightning Sales Console", "Customer Success"]:
                try:
                    result = process_single_app(page, app_name)
                    results[app_name] = result
                except Exception as e:
                    print(f"\nError processing '{app_name}': {e}")
                    import traceback
                    traceback.print_exc()
                    results[app_name] = "error"
                    take_screenshot(page, f"fatal_error_{app_name.replace(' ', '_').lower()}")

        finally:
            browser.close()

    # Print summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    for app, result in results.items():
        status = {
            "enabled": "✓ ENABLED Start Automatically",
            "already_enabled": "✓ Already enabled (no change needed)",
            "not_found": "✗ 'Ask mcLOVIN'' not found",
            "error": "✗ Error occurred",
            None: "✗ App not found in App Manager",
        }.get(result, f"? {result}")
        print(f"  {app}: {status}")

    return results

def process_single_app(page, app_name):
    """Process a single app: find it, edit it, enable Start Automatically, save."""
    print(f"\n{'='*60}")
    print(f"PROCESSING: {app_name}")
    print("="*60)

    # Go to App Manager
    print("Navigating to App Manager...")
    page.goto(APP_MANAGER_URL, timeout=60000)

    try:
        page.wait_for_load_state('networkidle', timeout=60000)
    except PlaywrightTimeoutError:
        print("  Warning: networkidle timeout on App Manager")

    time.sleep(3)
    take_screenshot(page, f"appmanager_{app_name.replace(' ', '_').lower()}")

    # Check frames
    frames = page.frames
    print(f"  Frames: {len(frames)}")

    # Try to find app in main frame or any content frame
    app_found = False
    edit_clicked = False

    # The App Manager in Salesforce Lightning is often embedded in an iframe
    # Let's find the right frame
    content_frame = None
    for frame in frames:
        try:
            if frame.url and 'NavigationMenus' in frame.url:
                content_frame = frame
                print(f"  Found NavigationMenus frame: {frame.url}")
                break
        except:
            pass

    # If no specific frame found, try all frames
    search_frames = [page] + [f for f in frames if f != page.main_frame]

    # Names to try for this app
    names_to_try = [app_name]
    if app_name == "LOVING Field Service":
        names_to_try = ["LOVING Field Service", "Field Services", "Field Service"]

    for search_frame in search_frames:
        if edit_clicked:
            break

        for try_name in names_to_try:
            if edit_clicked:
                break

            print(f"  Searching frame {search_frame.url[:50]} for '{try_name}'...")

            try:
                frame_content = search_frame.content()
                if try_name not in frame_content:
                    print(f"  '{try_name}' not in frame content, skipping...")
                    continue

                print(f"  Found '{try_name}' in frame content!")

                # Find the row containing this app name
                # Try XPath to find the row
                row_xpath = f'//tr[.//a[contains(text(), "{try_name}")] or .//span[contains(text(), "{try_name}")]]'
                rows = search_frame.locator(row_xpath)
                row_count = rows.count()
                print(f"  Found {row_count} row(s) matching xpath")

                if row_count == 0:
                    # Try a simpler approach: find all rows and check text
                    all_rows = search_frame.locator('tr')
                    total = all_rows.count()
                    print(f"  Total rows: {total}, checking each...")

                    for i in range(min(total, 50)):
                        try:
                            row = all_rows.nth(i)
                            text = row.inner_text(timeout=2000)
                            if try_name in text and ("Standard" in text or "Custom" in text or "Console" in text):
                                rows = search_frame.locator('tr').nth(i)
                                row_count = 1
                                print(f"  Found app in row {i}: {text[:100]}")
                                break
                        except:
                            continue

                if row_count == 0:
                    print(f"  No rows found for '{try_name}'")
                    continue

                # Use first matching row
                row = rows.first if row_count > 1 else rows
                row.scroll_into_view_if_needed(timeout=10000)
                take_screenshot(page, f"row_{try_name.replace(' ', '_').lower()}")

                # Find and click the dropdown button
                # In Salesforce App Manager, the dropdown is the last cell/button
                dropdown_clicked = False

                # Try various selectors for the dropdown button within the row
                for btn_sel in ['button', 'a.dropDownLink', '[aria-haspopup]']:
                    try:
                        btns = row.locator(btn_sel)
                        btn_count = btns.count()
                        if btn_count > 0:
                            # Use the last button (usually the action dropdown)
                            btn = btns.last
                            btn.scroll_into_view_if_needed(timeout=5000)
                            btn.click(timeout=10000)
                            print(f"  Clicked dropdown ({btn_sel})")
                            time.sleep(2)
                            take_screenshot(page, f"dropdown_{try_name.replace(' ', '_').lower()}")
                            dropdown_clicked = True
                            break
                    except Exception as e:
                        print(f"  Button selector '{btn_sel}' failed: {e}")
                        continue

                if not dropdown_clicked:
                    print(f"  Could not click dropdown for '{try_name}'")
                    continue

                # Now click "Edit" from the dropdown menu
                # The dropdown menu appears in the page (not necessarily in the frame)
                print(f"  Looking for Edit option in dropdown...")
                time.sleep(1)

                edit_clicked_success = False
                for edit_sel in [
                    'text="Edit"',
                    'a:has-text("Edit")',
                    '.slds-dropdown__item:has-text("Edit")',
                    'lightning-menu-item[value="Edit"]',
                    'li:has-text("Edit") a',
                ]:
                    try:
                        # Look in both page and frame
                        for context_to_search in [page, search_frame]:
                            edit_el = context_to_search.locator(edit_sel).first
                            if edit_el.count() > 0 and edit_el.is_visible(timeout=3000):
                                edit_el.click(timeout=10000)
                                print(f"  Clicked Edit ({edit_sel})")
                                edit_clicked_success = True
                                edit_clicked = True
                                break
                        if edit_clicked_success:
                            break
                    except Exception as e:
                        continue

                if not edit_clicked_success:
                    print(f"  Could not click Edit for '{try_name}'")
                    # Take screenshot to see what's on screen
                    take_screenshot(page, f"edit_failed_{try_name.replace(' ', '_').lower()}")
                    continue

                # Wait for editor to load
                print(f"  Waiting for editor to load...")
                try:
                    page.wait_for_load_state('networkidle', timeout=60000)
                    time.sleep(3)
                except PlaywrightTimeoutError:
                    print("  Warning: networkidle timeout")

                take_screenshot(page, f"editor_{try_name.replace(' ', '_').lower()}")
                print(f"  Editor URL: {page.url}")
                app_found = True
                break

            except Exception as e:
                print(f"  Error in frame search: {e}")
                import traceback
                traceback.print_exc()
                continue

    if not app_found or not edit_clicked:
        print(f"  App '{app_name}' not found or Edit not clicked")
        return None

    # Now we're in the app editor
    # Click on "Utility Items (Desktop Only)" tab
    print("\nLooking for Utility Items tab...")

    utility_found = False
    for util_sel in [
        'text="Utility Items (Desktop Only)"',
        'button:has-text("Utility Items")',
        'a:has-text("Utility Items")',
        'li:has-text("Utility Items")',
        'span:has-text("Utility Items (Desktop Only)")',
        '[title="Utility Items (Desktop Only)"]',
    ]:
        try:
            el = page.locator(util_sel).first
            if el.count() > 0 and el.is_visible(timeout=5000):
                el.click(timeout=10000)
                print(f"  Clicked Utility Items tab ({util_sel})")
                time.sleep(2)
                try:
                    page.wait_for_load_state('networkidle', timeout=30000)
                except:
                    pass
                take_screenshot(page, f"utility_items_{app_name.replace(' ', '_').lower()}")
                utility_found = True
                break
        except Exception as e:
            continue

    if not utility_found:
        print(f"  Could not find Utility Items tab")
        # Check what tabs/sections are available
        page_text = page.content()
        if "Utility Items" in page_text:
            print(f"  'Utility Items' text found in page but not clickable")
        take_screenshot(page, f"no_utility_tab_{app_name.replace(' ', '_').lower()}")
        return "error"

    # Now look for "Ask mcLOVIN'" in the utility items list
    print("\nLooking for 'Ask mcLOVIN'...")
    time.sleep(2)

    # Check page content for Ask mcLOVIN
    page_content = page.content()
    mclovin_in_page = "Ask mcLOVIN" in page_content
    print(f"  'Ask mcLOVIN' in page content: {mclovin_in_page}")

    if not mclovin_in_page:
        print(f"  'Ask mcLOVIN'' not found in utility items for '{app_name}'")
        take_screenshot(page, f"no_mclovin_{app_name.replace(' ', '_').lower()}")
        return "not_found"

    # Find and click on Ask mcLOVIN to expand it
    mclovin_found_and_expanded = False
    for mcl_sel in [
        'text="Ask mcLOVIN\'"',
        'text="Ask mcLOVIN"',
        'span:has-text("Ask mcLOVIN")',
        'div:has-text("Ask mcLOVIN")',
        'li:has-text("Ask mcLOVIN")',
        'article:has-text("Ask mcLOVIN")',
    ]:
        try:
            el = page.locator(mcl_sel).first
            if el.count() > 0:
                el.scroll_into_view_if_needed(timeout=10000)
                take_screenshot(page, f"mclovin_visible_{app_name.replace(' ', '_').lower()}")
                el.click(timeout=10000)
                time.sleep(2)
                print(f"  Clicked on 'Ask mcLOVIN' ({mcl_sel})")
                try:
                    page.wait_for_load_state('networkidle', timeout=15000)
                except:
                    pass
                mclovin_found_and_expanded = True
                take_screenshot(page, f"mclovin_clicked_{app_name.replace(' ', '_').lower()}")
                break
        except Exception as e:
            continue

    if not mclovin_found_and_expanded:
        print(f"  Could not click on 'Ask mcLOVIN'")
        take_screenshot(page, f"mclovin_click_failed_{app_name.replace(' ', '_').lower()}")

    # Now look for "Start Automatically" checkbox
    print("  Looking for 'Start Automatically' checkbox/toggle...")
    time.sleep(2)

    page_content = page.content()
    start_auto_in_page = "Start Automatically" in page_content
    print(f"  'Start Automatically' in page: {start_auto_in_page}")

    if not start_auto_in_page:
        print(f"  'Start Automatically' not found on page")
        take_screenshot(page, f"no_start_auto_{app_name.replace(' ', '_').lower()}")
        # Maybe we need to expand the item first
        return "not_found"

    # Find the Start Automatically checkbox
    checkbox_result = None

    # Try to find checkbox associated with "Start Automatically" label
    # In Salesforce Lightning, this is often a lightning-input or lightning-toggle
    for check_sel in [
        'lightning-input:has-text("Start Automatically") input[type="checkbox"]',
        'lightning-input[label="Start Automatically"] input',
        'label:has-text("Start Automatically") ~ input[type="checkbox"]',
        'label:has-text("Start Automatically") input',
        'input[name*="startAutomatically"]',
        'input[name*="start_automatically"]',
        'input[id*="startAutomatically"]',
        # Try to find any checkbox near "Start Automatically" text
    ]:
        try:
            el = page.locator(check_sel).first
            if el.count() > 0:
                is_checked = el.is_checked(timeout=5000)
                print(f"  Found checkbox ({check_sel}): {'checked' if is_checked else 'unchecked'}")
                checkbox_result = ("checked" if is_checked else "unchecked", el)
                break
        except Exception as e:
            continue

    if not checkbox_result:
        # Try a different approach: find all checkboxes and check which one is for Start Automatically
        print("  Trying to find Start Automatically via nearby text...")

        # Look for the parent element containing "Start Automatically"
        try:
            # Get the element containing "Start Automatically" text
            start_auto_el = page.locator('*:has-text("Start Automatically")').last
            if start_auto_el.count() > 0:
                # Look for a checkbox within or near it
                parent = start_auto_el.locator('xpath=..')
                checkbox = parent.locator('input[type="checkbox"]')
                if checkbox.count() > 0:
                    is_checked = checkbox.first.is_checked(timeout=5000)
                    print(f"  Found checkbox via parent: {'checked' if is_checked else 'unchecked'}")
                    checkbox_result = ("checked" if is_checked else "unchecked", checkbox.first)
        except Exception as e:
            print(f"  Parent search failed: {e}")

    if not checkbox_result:
        # Last resort: find all checkboxes on the page and use the one related to Start Automatically
        print("  Last resort: checking all checkboxes...")
        take_screenshot(page, f"all_checkboxes_{app_name.replace(' ', '_').lower()}")

        # Try JavaScript approach
        try:
            result = page.evaluate("""
                () => {
                    // Look for elements with "Start Automatically" text
                    const allElements = document.querySelectorAll('*');
                    for (const el of allElements) {
                        if (el.textContent.trim() === 'Start Automatically' ||
                            el.textContent.includes('Start Automatically')) {
                            // Look for nearby checkbox
                            const parent = el.parentElement;
                            if (parent) {
                                const cb = parent.querySelector('input[type="checkbox"]');
                                if (cb) {
                                    return {found: true, checked: cb.checked, id: cb.id, name: cb.name};
                                }
                            }
                        }
                    }
                    // Find all checkboxes
                    const cbs = document.querySelectorAll('input[type="checkbox"]');
                    const results = [];
                    for (const cb of cbs) {
                        results.push({id: cb.id, name: cb.name, checked: cb.checked,
                                      label: document.querySelector('label[for="' + cb.id + '"]')?.textContent});
                    }
                    return {found: false, checkboxes: results};
                }
            """)
            print(f"  JS result: {result}")

            if result.get('found'):
                cb_id = result.get('id')
                cb_name = result.get('name')
                is_checked = result.get('checked')

                # Find and click the checkbox
                sel = f'input[id="{cb_id}"]' if cb_id else f'input[name="{cb_name}"]'
                el = page.locator(sel).first
                checkbox_result = ("checked" if is_checked else "unchecked", el)

        except Exception as e:
            print(f"  JS approach failed: {e}")

    if not checkbox_result:
        print(f"  Could not find Start Automatically checkbox for '{app_name}'")
        take_screenshot(page, f"no_checkbox_{app_name.replace(' ', '_').lower()}")
        return "not_found"

    status, checkbox_el = checkbox_result
    take_screenshot(page, f"checkbox_state_{app_name.replace(' ', '_').lower()}")

    if status == "checked":
        print(f"  'Start Automatically' is already enabled for '{app_name}'")
        return "already_enabled"

    # Click to enable
    print(f"  Enabling 'Start Automatically' for '{app_name}'...")
    try:
        checkbox_el.click(timeout=10000)
        time.sleep(1)
        take_screenshot(page, f"checkbox_enabled_{app_name.replace(' ', '_').lower()}")
        print(f"  Checkbox clicked!")
    except Exception as e:
        print(f"  Could not click checkbox: {e}")
        return "error"

    # Save the app
    print(f"\nSaving '{app_name}'...")
    saved = False
    for save_sel in [
        'button:has-text("Save")',
        'input[value="Save"]',
        'button[title="Save"]',
        '.actionsContainer button:has-text("Save")',
        '.slds-button:has-text("Save")',
        'button[name="SaveEdit"]',
    ]:
        try:
            btn = page.locator(save_sel).first
            if btn.count() > 0 and btn.is_visible(timeout=5000):
                btn.click(timeout=10000)
                print(f"  Clicked Save ({save_sel})")
                saved = True
                break
        except:
            continue

    if not saved:
        print(f"  Could not find/click Save button!")
        take_screenshot(page, f"save_not_found_{app_name.replace(' ', '_').lower()}")
        return "error"

    # Wait for save
    try:
        page.wait_for_load_state('networkidle', timeout=60000)
        time.sleep(3)
    except PlaywrightTimeoutError:
        print("  Warning: networkidle timeout after save")

    take_screenshot(page, f"after_save_{app_name.replace(' ', '_').lower()}")
    print(f"  Save complete for '{app_name}'")

    return "enabled"

if __name__ == "__main__":
    main()
