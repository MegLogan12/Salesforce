#!/usr/bin/env python3
"""
Salesforce Lightning App Utility Bar Automation
Finds all apps with utility bars and checks "Start Automatically" for "Ask mcLOVIN'"
"""

import os
import time
import json
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

LOGIN_URL = "https://loving.my.salesforce.com/secur/frontdoor.jsp?otp=00Da500001UEK0H%21AQEAQCWOnO_wvZZI2cuAZWjxhR_Ezrqbv0X8ooS5OVO2oBTueyZqxIo2PCA.NxM4ceCjQ9kHMut7vzoBTxyv1kxGvs_.laML&cshc=500001mhIYb500001UEK0H"
APP_MANAGER_URL = "https://loving.my.salesforce.com/lightning/setup/NavigationMenus/home"
SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots_utility_bar"
TIMEOUT = 60000  # 60 seconds

os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

results = {
    "updated": [],
    "already_checked": [],
    "no_mclovin": [],
    "errors": [],
    "no_utility_bar": []
}

def screenshot(page, name):
    path = f"{SCREENSHOTS_DIR}/{name}.png"
    page.screenshot(path=path, full_page=False)
    print(f"  [screenshot] {path}")
    return path

def wait_for_sf_load(page):
    """Wait for Salesforce spinner to go away"""
    try:
        page.wait_for_load_state("networkidle", timeout=30000)
    except:
        pass
    time.sleep(2)

def login(page):
    print("Logging in to Salesforce...")
    page.goto(LOGIN_URL, timeout=TIMEOUT, wait_until="domcontentloaded")
    wait_for_sf_load(page)
    screenshot(page, "01_login_complete")
    print(f"  Current URL: {page.url}")

def go_to_app_manager(page):
    print("Navigating to App Manager...")
    page.goto(APP_MANAGER_URL, timeout=TIMEOUT, wait_until="domcontentloaded")
    wait_for_sf_load(page)
    screenshot(page, "02_app_manager")
    print(f"  Current URL: {page.url}")

def get_all_apps(page):
    """Get list of all Lightning apps in App Manager"""
    print("Getting list of apps...")

    # Wait for the app manager table to load
    try:
        page.wait_for_selector("table.setupTable, .appManagerTableList, lightning-datatable, .forceSetupPageBody table", timeout=30000)
    except:
        screenshot(page, "02b_app_manager_table_error")
        print("  Warning: Could not find app manager table selector")

    time.sleep(3)
    screenshot(page, "02c_app_manager_loaded")

    # Try to find app rows - SF App Manager uses an iframe
    frames = page.frames
    print(f"  Found {len(frames)} frames")

    return frames

def process_app_in_editor(page, app_name, app_index):
    """Process a single app in the Lightning App editor"""
    print(f"\n  Processing app: {app_name}")

    # Click on "Utility Items (Desktop Only)" in left nav
    try:
        # Look for the Utility Items nav item
        utility_nav = page.locator("text='Utility Items (Desktop Only)'").first
        if not utility_nav.is_visible(timeout=5000):
            # Try alternative selectors
            utility_nav = page.locator("a:has-text('Utility Items')").first

        utility_nav.click(timeout=10000)
        wait_for_sf_load(page)
        screenshot(page, f"app_{app_index:02d}_{app_name[:20].replace(' ', '_')}_utility_items")

    except Exception as e:
        print(f"    Could not click Utility Items nav: {e}")
        screenshot(page, f"app_{app_index:02d}_{app_name[:20].replace(' ', '_')}_no_utility_nav")
        results["errors"].append({"app": app_name, "error": f"Could not find Utility Items nav: {e}"})
        return False

    # Check if "Ask mcLOVIN'" is in the list
    try:
        mclovin = page.locator("text='Ask mcLOVIN\\''").first
        if not mclovin.is_visible(timeout=5000):
            # Try alternate text
            mclovin = page.locator("*:has-text(\"Ask mcLOVIN'\")").last
            if not mclovin.is_visible(timeout=3000):
                print(f"    'Ask mcLOVIN' not found in utility items")
                results["no_mclovin"].append(app_name)
                return False
    except:
        print(f"    'Ask mcLOVIN' not found in utility items")
        results["no_mclovin"].append(app_name)
        return False

    # Click on the Ask mcLOVIN' item to expand settings
    print(f"    Found 'Ask mcLOVIN'' - clicking to expand settings...")
    mclovin.click(timeout=10000)
    wait_for_sf_load(page)
    screenshot(page, f"app_{app_index:02d}_{app_name[:20].replace(' ', '_')}_mclovin_expanded")

    # Look for "Start Automatically" checkbox
    try:
        # Find the Start Automatically checkbox
        start_auto_label = page.locator("text='Start Automatically'").first
        if start_auto_label.is_visible(timeout=5000):
            # Find nearby checkbox
            checkbox = page.locator("input[type='checkbox']").filter(has=page.locator("text='Start Automatically'"))
            if not checkbox.count():
                # Try to find checkbox near the label
                checkbox = start_auto_label.locator("../..").locator("input[type='checkbox']")

            if checkbox.count() > 0:
                is_checked = checkbox.first.is_checked()
                screenshot(page, f"app_{app_index:02d}_{app_name[:20].replace(' ', '_')}_before_check")

                if is_checked:
                    print(f"    'Start Automatically' already checked")
                    results["already_checked"].append(app_name)
                    return True
                else:
                    print(f"    Checking 'Start Automatically'...")
                    checkbox.first.check()
                    time.sleep(1)
                    screenshot(page, f"app_{app_index:02d}_{app_name[:20].replace(' ', '_')}_after_check")
                    results["updated"].append(app_name)
                    return True
            else:
                print(f"    Could not find Start Automatically checkbox")
                screenshot(page, f"app_{app_index:02d}_{app_name[:20].replace(' ', '_')}_no_checkbox")
                results["errors"].append({"app": app_name, "error": "Could not find Start Automatically checkbox"})
                return False
        else:
            print(f"    'Start Automatically' label not found")
            results["errors"].append({"app": app_name, "error": "Start Automatically label not found"})
            return False
    except Exception as e:
        print(f"    Error handling checkbox: {e}")
        screenshot(page, f"app_{app_index:02d}_{app_name[:20].replace(' ', '_')}_checkbox_error")
        results["errors"].append({"app": app_name, "error": str(e)})
        return False

def save_app(page, app_name, app_index):
    """Click Save button"""
    try:
        save_btn = page.locator("button:has-text('Save'), input[value='Save']").first
        save_btn.click(timeout=10000)
        wait_for_sf_load(page)
        screenshot(page, f"app_{app_index:02d}_{app_name[:20].replace(' ', '_')}_saved")
        print(f"    App saved successfully")
        return True
    except Exception as e:
        print(f"    Error saving app: {e}")
        screenshot(page, f"app_{app_index:02d}_{app_name[:20].replace(' ', '_')}_save_error")
        return False

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            args=[
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu",
                "--window-size=1920,1080"
            ]
        )

        context = browser.new_context(
            viewport={"width": 1920, "height": 1080},
            ignore_https_errors=True
        )

        page = context.new_page()
        page.set_default_timeout(TIMEOUT)

        # Login
        login(page)

        # Go to App Manager
        go_to_app_manager(page)

        # The App Manager in SF Setup uses an iframe - find it
        time.sleep(5)

        # Check for iframe content
        main_frame = page.main_frame
        all_frames = page.frames
        print(f"Total frames: {len(all_frames)}")
        for i, frame in enumerate(all_frames):
            print(f"  Frame {i}: {frame.url}")

        # Look for the setup content iframe
        setup_frame = None
        for frame in all_frames:
            if "NavigationMenus" in frame.url or "setup" in frame.url.lower():
                setup_frame = frame
                print(f"  Using setup frame: {frame.url}")
                break

        if not setup_frame:
            # Try the page itself
            setup_frame = page
            print("  Using main page as setup frame")

        # Get app list from the frame
        time.sleep(3)

        # Take screenshot of current state
        screenshot(page, "03_app_manager_ready")

        # Try to get app rows - use JavaScript to extract app data
        try:
            # Look for the table in the iframe
            app_data = page.evaluate("""
                () => {
                    // Try to find in main page first
                    let rows = document.querySelectorAll('table tr, .listRelatedObject tr, lightning-datatable tr');
                    if (rows.length > 1) {
                        return Array.from(rows).slice(1).map(r => ({
                            text: r.innerText,
                            html: r.innerHTML.substring(0, 200)
                        }));
                    }

                    // Try iframes
                    let allFrames = Array.from(document.querySelectorAll('iframe'));
                    for (let frame of allFrames) {
                        try {
                            let frameRows = frame.contentDocument.querySelectorAll('table tr');
                            if (frameRows.length > 1) {
                                return Array.from(frameRows).slice(1).map(r => ({
                                    text: r.innerText,
                                    html: r.innerHTML.substring(0, 200)
                                }));
                            }
                        } catch(e) {}
                    }
                    return [];
                }
            """)
            print(f"Found {len(app_data)} rows via JS")
            if app_data:
                print("First few rows:")
                for row in app_data[:5]:
                    print(f"  {row['text'][:100]}")
        except Exception as e:
            print(f"JS evaluation error: {e}")

        screenshot(page, "04_before_app_list_extraction")

        # Navigate using the SF API approach - use the App Manager list view
        # SF Lightning App Manager is at /lightning/setup/NavigationMenus/home
        # Each app has an Edit link we need to find and click

        # Let's look at what's actually on the page
        page_content = page.content()
        print(f"Page content length: {len(page_content)}")

        # Look for app-related content
        if "NavigationMenu" in page_content or "App Manager" in page_content:
            print("Found App Manager content in page")

        # Try to find the app list by looking for the table iframe
        # SF Setup pages often load content in an iframe
        iframe_element = page.locator("iframe.setupcontent, iframe[name='setupFrame'], iframe").first
        if iframe_element.count() > 0:
            print("Found iframe, switching to it")
            frame = iframe_element.content_frame()
            if frame:
                frame_content = frame.content()
                print(f"iframe content length: {len(frame_content)}")
                screenshot(page, "05_iframe_content")

        # Use the direct SF approach - navigate to each app through the API
        # First let's get a list of apps by scraping the App Manager page properly
        print("\n=== Extracting App List ===")

        # Wait longer and retry
        time.sleep(5)
        screenshot(page, "06_after_wait")

        # Try clicking the App Manager table to load it
        try:
            # Look for any table headers or rows
            headers = page.locator("th, .dataCell, td").all()
            print(f"Found {len(headers)} table cells/headers")
        except Exception as e:
            print(f"Error finding table cells: {e}")

        # Scroll down to see if content loads
        page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        time.sleep(2)
        screenshot(page, "07_scrolled_down")

        # Try the direct Salesforce Tooling API approach via the browser
        # Navigate to get app list via SOQL through the browser
        print("\n=== Using Salesforce Setup UI directly ===")

        # Go back to app manager and try to interact with the table
        page.goto(APP_MANAGER_URL, timeout=TIMEOUT, wait_until="networkidle")
        time.sleep(8)
        screenshot(page, "08_app_manager_networkidle")

        # Print all visible text
        try:
            visible_text = page.evaluate("() => document.body.innerText")
            print(f"Page text preview (first 2000 chars):\n{visible_text[:2000]}")
        except:
            pass

        # Look for the app rows by their structure
        # In SF Lightning Setup, the App Manager table has specific classes
        app_rows_selectors = [
            "tr.uiScrollerTableRow",
            "tr[data-row-key-value]",
            ".setupcontent table tr",
            "table.slds-table tr",
            "tr",
        ]

        found_rows = False
        for selector in app_rows_selectors:
            try:
                rows = page.locator(selector).all()
                if len(rows) > 2:
                    print(f"Found {len(rows)} rows with selector: {selector}")
                    found_rows = True

                    # Extract app names and types
                    app_list = []
                    for row in rows[1:]:  # Skip header
                        try:
                            text = row.inner_text()
                            if text.strip():
                                app_list.append(text.strip())
                        except:
                            pass

                    print(f"App list ({len(app_list)} apps):")
                    for app in app_list[:20]:
                        print(f"  {app[:100]}")
                    break
            except Exception as e:
                pass

        if not found_rows:
            print("Could not find app rows with standard selectors")
            # Try JavaScript to find all visible text in tables
            try:
                table_content = page.evaluate("""
                    () => {
                        let tables = document.querySelectorAll('table');
                        let result = [];
                        tables.forEach((t, i) => {
                            result.push({
                                index: i,
                                rows: t.rows.length,
                                text: t.innerText.substring(0, 500)
                            });
                        });
                        return result;
                    }
                """)
                print(f"Tables on page: {json.dumps(table_content, indent=2)}")
            except Exception as e:
                print(f"Error: {e}")

        # The SF App Manager might be in a different URL format for Lightning
        # Let's try the classic setup approach or look for the right frame
        print("\n=== Checking all frame contents ===")
        for i, frame in enumerate(page.frames):
            try:
                frame_text = frame.evaluate("() => document.body.innerText")
                if "App" in frame_text and len(frame_text) > 100:
                    print(f"Frame {i} ({frame.url[:80]}):")
                    print(f"  Text preview: {frame_text[:300]}")
                    print()
            except:
                pass

        browser.close()

if __name__ == "__main__":
    main()
    print("\n=== RESULTS ===")
    print(json.dumps(results, indent=2))
