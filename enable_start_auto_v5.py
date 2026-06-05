#!/usr/bin/env python3
"""
Enable 'Start Automatically' for 'Ask mcLOVIN'' utility bar item.
Simplified and more robust version.
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
SCREENSHOTS_DIR = "/home/user/Salesforce/screenshots"

os.makedirs(SCREENSHOTS_DIR, exist_ok=True)
screenshot_counter = [0]

def ss(page, name):
    screenshot_counter[0] += 1
    path = f"{SCREENSHOTS_DIR}/v5_{screenshot_counter[0]:03d}_{name}.png"
    try:
        page.screenshot(path=path)
        print(f"  [ss] {path}")
    except Exception as e:
        print(f"  [ss error] {e}")
    return path

def wait_sf(page, timeout=30000):
    """Wait for Salesforce page to stabilize."""
    try:
        page.wait_for_load_state("load", timeout=timeout)
    except Exception:
        pass
    try:
        page.wait_for_selector(".slds-spinner_container", state="hidden", timeout=8000)
    except Exception:
        pass
    time.sleep(2)

def get_creds():
    result = subprocess.run(
        ["sf", "org", "display", "--target-org", "dispatch", "--json"],
        capture_output=True, text=True, timeout=30
    )
    data = json.loads(result.stdout)
    r = data.get("result", {})
    return r.get("accessToken"), r.get("instanceUrl")

def login(browser, access_token, instance_url):
    """Create a new page and login via frontdoor."""
    page = browser.new_page()
    token = urllib.parse.quote(access_token)
    url = f"{instance_url}/secur/frontdoor.jsp?sid={token}"
    print(f"  Navigating to frontdoor...")
    try:
        page.goto(url, timeout=60000, wait_until="domcontentloaded")
    except Exception as e:
        print(f"  Frontdoor navigation: {e}")
    time.sleep(5)
    ss(page, "login")
    print(f"  URL after login: {page.url[:80]}")
    return page

def navigate_to_app_manager(page):
    """Navigate to App Manager and wait for table to load."""
    print(f"  Navigating to App Manager...")
    try:
        page.goto(APP_MANAGER_URL, timeout=60000, wait_until="domcontentloaded")
    except Exception as e:
        print(f"  Navigation: {e}")
    time.sleep(8)  # Give Salesforce time to fully load
    ss(page, "app_manager_raw")
    print(f"  URL: {page.url[:80]}")

def find_table_frame(page, max_wait=30):
    """Find the frame containing the app table."""
    print(f"  Looking for table frame...")
    deadline = time.time() + max_wait
    while time.time() < deadline:
        for frame in page.frames:
            try:
                rows = frame.query_selector_all("table tbody tr")
                if rows and len(rows) > 2:
                    print(f"  Found frame with {len(rows)} rows: {frame.url[:60]}")
                    return frame
            except Exception:
                pass
        time.sleep(1.5)
    print(f"  No table frame found after {max_wait}s")
    return None

def debug_all_frames(page):
    """Debug: print all frames and their content."""
    print(f"  All frames ({len(page.frames)}):")
    for i, frame in enumerate(page.frames):
        try:
            content_len = len(frame.content())
            row_count = len(frame.query_selector_all("table tbody tr"))
            print(f"    Frame {i}: url={frame.url[:60]} content={content_len}b rows={row_count}")
        except Exception as e:
            print(f"    Frame {i}: ERROR {e}")

def get_all_rows(frame):
    """Get all rows from the table."""
    return frame.evaluate("""() => {
        const rows = document.querySelectorAll('table tbody tr');
        const result = [];
        rows.forEach((row, idx) => {
            const tds = row.querySelectorAll('td');
            const cells = Array.from(tds).map(td => td.textContent.trim().replace(/\\s+/g, ' '));
            result.push({idx: idx, cells: cells});
        });
        return result;
    }""")

def find_app_row(frame, app_name):
    """Find row index for an app by its label."""
    return frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        for (let i = 0; i < rows.length; i++) {{
            const tds = rows[i].querySelectorAll('td');
            for (let j = 0; j < tds.length; j++) {{
                const text = tds[j].textContent.trim().replace(/\\s+/g, ' ');
                if (text === '{app_name}' || text.startsWith('{app_name}') || text.includes('{app_name}')) {{
                    // Make sure this is a label match (cell 0 or 1 typically)
                    return {{found: true, rowIndex: i, cellIndex: j, text: text.slice(0, 80)}};
                }}
            }}
        }}
        return {{found: false}};
    }}""")

def scroll_table_to_load_all(frame, page):
    """Scroll to load all lazy-loaded rows."""
    # Try to scroll the table container
    for attempt in range(8):
        prev_count = frame.evaluate("() => document.querySelectorAll('table tbody tr').length")
        frame.evaluate("""() => {
            const containers = [
                document.querySelector('.slds-card__body'),
                document.querySelector('.slds-scrollable_y'),
                document.querySelector('[class*="scrollable"]'),
                document.querySelector('tbody'),
                document.body
            ];
            for (const c of containers) {
                if (c) c.scrollTop += 1000;
            }
            window.scrollBy(0, 1000);
        }""")
        time.sleep(0.8)
        new_count = frame.evaluate("() => document.querySelectorAll('table tbody tr').length")
        if new_count == prev_count:
            break
        print(f"    Scrolled: {prev_count} -> {new_count} rows")

def click_app_dropdown_and_edit(frame, page, row_index, app_name):
    """Click dropdown button in app row and select Edit."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    print(f"  Clicking dropdown for row {row_index}...")

    # Scroll row into view
    frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        const row = rows[{row_index}];
        if (row) row.scrollIntoView({{block: 'center'}});
    }}""")
    time.sleep(0.5)

    # Click the last button in the row (dropdown arrow)
    clicked = frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        const row = rows[{row_index}];
        if (!row) return 'no_row';

        // Try buttons first
        const buttons = row.querySelectorAll('button');
        if (buttons.length > 0) {{
            buttons[buttons.length - 1].click();
            return 'clicked_button_' + buttons.length;
        }}

        // Try links
        const links = row.querySelectorAll('a[role="button"], a');
        if (links.length > 0) {{
            links[links.length - 1].click();
            return 'clicked_link_' + links.length;
        }}

        return 'no_clickable';
    }}""")
    print(f"    Dropdown click result: {clicked}")
    time.sleep(2)
    ss(page, f"{safe}_dropdown")

    # Find and click Edit option
    for ctx in [page, frame]:
        for sel in [
            "a:has-text('Edit')",
            "button:has-text('Edit')",
            "[title='Edit']",
            ".slds-dropdown a:has-text('Edit')",
        ]:
            try:
                el = ctx.locator(sel).first
                count = el.count()
                if count > 0:
                    visible = el.is_visible(timeout=2000)
                    if visible:
                        el.click(timeout=5000)
                        print(f"  Clicked Edit via '{sel}'")
                        time.sleep(5)
                        try:
                            page.wait_for_load_state("domcontentloaded", timeout=30000)
                        except Exception:
                            pass
                        time.sleep(3)
                        ss(page, f"{safe}_editor")
                        print(f"  Editor URL: {page.url[:80]}")
                        return True
            except Exception as e:
                pass

    # JS fallback
    for ctx in [page, frame]:
        try:
            result = ctx.evaluate("""() => {
                const elems = document.querySelectorAll('a, button');
                for (const el of elems) {
                    if (el.textContent.trim() === 'Edit' && el.getBoundingClientRect().width > 0) {
                        el.click();
                        return 'clicked';
                    }
                }
                // Also try dropdown items
                const items = document.querySelectorAll('[role="menuitem"], .slds-dropdown__item');
                for (const item of items) {
                    if (item.textContent.trim().includes('Edit')) {
                        item.click();
                        return 'clicked_menuitem';
                    }
                }
                return 'not_found';
            }""")
            if result.startswith('clicked'):
                print(f"  Clicked Edit via JS: {result}")
                time.sleep(5)
                try:
                    page.wait_for_load_state("domcontentloaded", timeout=30000)
                except Exception:
                    pass
                time.sleep(3)
                ss(page, f"{safe}_editor_js")
                return True
        except Exception as e:
            pass

    print(f"  Could not click Edit")
    ss(page, f"{safe}_no_edit")
    return False

def click_utility_items_tab(page, app_name):
    """Click Utility Items tab in editor."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    for sel in [
        "text=Utility Items (Desktop Only)",
        "text=Utility Items",
        "button:has-text('Utility Items')",
        "a:has-text('Utility Items')",
        "span:has-text('Utility Items')",
    ]:
        try:
            el = page.locator(sel).first
            if el.count() > 0 and el.is_visible(timeout=5000):
                el.click(timeout=5000)
                time.sleep(3)
                try:
                    page.wait_for_load_state("domcontentloaded", timeout=15000)
                except Exception:
                    pass
                time.sleep(2)
                ss(page, f"{safe}_utility_items")
                print(f"  Clicked 'Utility Items (Desktop Only)' tab")
                return True
        except Exception:
            continue

    ss(page, f"{safe}_no_utility_tab")
    print(f"  'Utility Items' tab not found")
    return False

def enable_start_automatically(page, app_name):
    """Find Ask mcLOVIN' and enable Start Automatically."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    content = page.content()
    has_mclovin = "mcLOVIN" in content or "mclovin" in content.lower()

    if not has_mclovin:
        ss(page, f"{safe}_no_mclovin")
        print(f"  'Ask mcLOVIN'' NOT found in utility items")
        return "not_found"

    print(f"  'Ask mcLOVIN'' IS in page content")

    # Click on Ask mcLOVIN item to expand
    for pat in ["Ask mcLOVIN'", "Ask mcLOVIN"]:
        try:
            el = page.locator(f"text={pat}").first
            if el.count() > 0 and el.is_visible(timeout=3000):
                el.scroll_into_view_if_needed()
                ss(page, f"{safe}_mclovin_before")
                el.click(timeout=5000)
                time.sleep(2)
                ss(page, f"{safe}_mclovin_after")
                print(f"  Clicked '{pat}'")
                break
        except Exception as e:
            print(f"  Click '{pat}' failed: {e}")

    # Wait for Start Automatically to appear
    content = page.content()
    if "Start Automatically" not in content:
        print(f"  'Start Automatically' not visible after click")
        ss(page, f"{safe}_no_start_auto")
        return "not_found"

    print(f"  'Start Automatically' found in page")

    # Find the checkbox using JS
    js_result = page.evaluate("""() => {
        // Look for text nodes that say "Start Automatically"
        function findTextNode(text) {
            const walker = document.createTreeWalker(
                document.body, NodeFilter.SHOW_TEXT, null, false
            );
            let node;
            while (node = walker.nextNode()) {
                if (node.textContent.trim() === text) {
                    return node.parentElement;
                }
            }
            return null;
        }

        const textEl = findTextNode('Start Automatically');
        if (textEl) {
            // Search upward for checkbox
            let el = textEl;
            for (let i = 0; i < 8; i++) {
                el = el.parentElement;
                if (!el) break;
                const cb = el.querySelector('input[type="checkbox"]');
                if (cb) {
                    return {found: true, id: cb.id, name: cb.name, checked: cb.checked, method: 'textWalker'};
                }
            }
        }

        // Strategy: find all labels
        for (const label of document.querySelectorAll('label')) {
            if (label.textContent.trim().includes('Start Automatically')) {
                const forId = label.getAttribute('for');
                if (forId) {
                    const cb = document.getElementById(forId);
                    if (cb) return {found: true, id: cb.id, name: cb.name, checked: cb.checked, method: 'label-for'};
                }
                // Look in parent
                const parent = label.parentElement;
                if (parent) {
                    const cb = parent.querySelector('input[type="checkbox"]');
                    if (cb) return {found: true, id: cb.id, name: cb.name, checked: cb.checked, method: 'label-parent'};
                }
            }
        }

        // Strategy: all checkboxes with context
        const all = [];
        document.querySelectorAll('input[type="checkbox"]').forEach(cb => {
            const container = cb.closest('div, li, article, section');
            const ctx = container ? container.textContent.trim().replace(/\\s+/g, ' ').slice(0, 200) : '';
            const label = document.querySelector(`label[for="${cb.id}"]`);
            all.push({
                id: cb.id, name: cb.name, checked: cb.checked,
                label: label ? label.textContent.trim() : '',
                context: ctx
            });
        });
        return {found: false, all: all};
    }""")

    print(f"  JS result: {json.dumps(js_result, indent=2)[:500]}")

    checkbox_id = None
    checkbox_name = None
    is_checked = None

    if js_result.get("found"):
        checkbox_id = js_result.get("id", "")
        checkbox_name = js_result.get("name", "")
        is_checked = js_result.get("checked", False)
        print(f"  Found checkbox: id='{checkbox_id}' checked={is_checked}")
    else:
        # Look through all checkboxes for one related to Start Automatically
        for cb in js_result.get("all", []):
            label = cb.get("label", "")
            ctx = cb.get("context", "")
            if "Start Automatically" in label or "Start Automatically" in ctx:
                checkbox_id = cb.get("id", "")
                checkbox_name = cb.get("name", "")
                is_checked = cb.get("checked", False)
                print(f"  Found via context: id='{checkbox_id}' checked={is_checked}")
                print(f"    context: {ctx[:100]}")
                break

        if checkbox_id is None and checkbox_name is None:
            print(f"  All checkboxes:")
            for cb in js_result.get("all", []):
                print(f"    id='{cb['id']}' name='{cb['name']}' checked={cb['checked']} label='{cb['label']}'")

    ss(page, f"{safe}_before_action")

    if checkbox_id is None and checkbox_name is None:
        print(f"  Could not locate Start Automatically checkbox")
        return "not_found"

    if is_checked:
        print(f"  Already enabled!")
        return "already_enabled"

    # Click to enable
    print(f"  Enabling Start Automatically...")

    # Try via Playwright locator
    if checkbox_id:
        checkbox = page.locator(f"#{checkbox_id}").first
    else:
        checkbox = page.locator(f'input[name="{checkbox_name}"]').first

    try:
        checkbox.scroll_into_view_if_needed(timeout=5000)
        checkbox.click(timeout=8000)
        time.sleep(1)
        ss(page, f"{safe}_enabled")
        # Verify
        try:
            new_state = checkbox.is_checked(timeout=3000)
            print(f"  New state: {'checked' if new_state else 'unchecked'}")
        except Exception:
            pass
        return "enabled"
    except Exception as e:
        print(f"  Click failed: {e}, trying JS...")
        # JS click
        try:
            sel = f'#{checkbox_id}' if checkbox_id else f'[name="{checkbox_name}"]'
            page.evaluate(f"""() => {{
                const el = document.querySelector('{sel}');
                if (el) el.click();
            }}""")
            ss(page, f"{safe}_js_enabled")
            return "enabled"
        except Exception as e2:
            print(f"  JS click failed: {e2}")
            return "error"

def save_app(page, app_name):
    """Click Save."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    for sel in [
        "button:has-text('Save')",
        "input[value='Save']",
        "button[title='Save']",
    ]:
        try:
            btn = page.locator(sel).first
            if btn.count() > 0 and btn.is_visible(timeout=5000):
                btn.click(timeout=8000)
                print(f"  Clicked Save")
                time.sleep(3)
                try:
                    page.wait_for_load_state("domcontentloaded", timeout=60000)
                except Exception:
                    pass
                time.sleep(3)
                ss(page, f"{safe}_saved")
                return True
        except Exception:
            continue

    print(f"  Save button not found")
    ss(page, f"{safe}_no_save")
    return False

def process_app(page, app_name, names_to_try):
    """Process one app."""
    # Navigate to App Manager
    navigate_to_app_manager(page)

    # Find table frame
    debug_all_frames(page)
    frame = find_table_frame(page)

    if not frame:
        print(f"  No table frame!")
        return None

    # Scroll to load all rows
    scroll_table_to_load_all(frame, page)

    # Get all rows for debugging
    all_rows = get_all_rows(frame)
    print(f"  Total rows in table: {len(all_rows)}")
    for row in all_rows[:5]:
        print(f"    Row {row['idx']}: {row['cells'][:3]}")
    print(f"  ...")
    for row in all_rows[-5:]:
        print(f"    Row {row['idx']}: {row['cells'][:3]}")

    ss(page, f"table_{app_name.replace(' ','_')[:15]}")

    # Find the app
    row_index = None
    for try_name in names_to_try:
        result = find_app_row(frame, try_name)
        if result.get("found"):
            row_index = result["rowIndex"]
            print(f"  Found '{try_name}' at row {row_index}: {result['text']}")
            break
        else:
            print(f"  '{try_name}' not found")

    if row_index is None:
        # Print all row data for debugging
        print(f"  All rows for debugging:")
        for row in all_rows:
            cells_str = ' | '.join(row['cells'][:3])
            if any(kw in cells_str.lower() for kw in ['outdoor', 'field', 'sales', 'success', 'loving', 'lightning']):
                print(f"    * Row {row['idx']}: {cells_str[:100]}")
        return None

    # Click Edit
    if not click_app_dropdown_and_edit(frame, page, row_index, app_name):
        return "error"

    # Click Utility Items
    if not click_utility_items_tab(page, app_name):
        return "no_utility_bar"

    # Enable Start Automatically
    result = enable_start_automatically(page, app_name)

    if result == "enabled":
        if not save_app(page, app_name):
            return "save_failed"

    return result

def main():
    results = {}
    access_token, instance_url = get_creds()
    print(f"Credentials: {instance_url}")

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            env={"DISPLAY": ":99"},
            args=[
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--window-size=1440,900',
                '--disable-extensions',
            ],
            slow_mo=50,
        )
        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )

        try:
            page = login(browser, access_token, instance_url)

            app_configs = [
                ("Outdoor Living", ["Outdoor Living"]),
                ("LOVING Field Service", ["LOVING Field Service", "Field Services", "LOVING Field Services"]),
                ("Lightning Sales Console", ["Lightning Sales Console"]),
                ("Customer Success", ["Customer Success"]),
            ]

            for app_name, names in app_configs:
                print(f"\n{'='*60}")
                print(f"PROCESSING: {app_name}")
                print("="*60)
                try:
                    result = process_app(page, app_name, names)
                    results[app_name] = result
                    print(f"  Final result: {result}")
                except Exception as e:
                    print(f"  EXCEPTION: {e}")
                    import traceback
                    traceback.print_exc()
                    results[app_name] = "error"
                    try:
                        ss(page, f"exception_{app_name.replace(' ','_')[:15]}")
                    except Exception:
                        pass

        except Exception as e:
            print(f"FATAL: {e}")
            import traceback
            traceback.print_exc()
        finally:
            try:
                browser.close()
            except Exception:
                pass

    print("\n" + "="*60)
    print("FINAL SUMMARY")
    print("="*60)
    status_map = {
        "enabled": "ENABLED (saved)",
        "already_enabled": "Already enabled (no change)",
        "not_found": "'Ask mcLOVIN'' not in utility items",
        "no_utility_bar": "No Utility Items tab",
        "save_failed": "Enabled but save FAILED",
        "error": "Error occurred",
        None: "App not found in App Manager",
    }
    for app, result in results.items():
        print(f"  {app}: {status_map.get(result, str(result))}")

if __name__ == "__main__":
    main()
