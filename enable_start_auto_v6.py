#!/usr/bin/env python3
"""
Enable 'Start Automatically' for 'Ask mcLOVIN'' utility bar item.
v6 - Proper table scrolling to find all apps.
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
    path = f"{SCREENSHOTS_DIR}/v6_{screenshot_counter[0]:03d}_{name}.png"
    try:
        page.screenshot(path=path)
        print(f"  [ss] {path}")
    except Exception as e:
        print(f"  [ss error] {e}")
    return path

def wait_sf(page, timeout=30000):
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

def login(context, access_token, instance_url):
    page = context.new_page()
    token = urllib.parse.quote(access_token)
    url = f"{instance_url}/secur/frontdoor.jsp?sid={token}"
    print(f"  Navigating to frontdoor...")
    try:
        page.goto(url, timeout=60000, wait_until="domcontentloaded")
    except Exception as e:
        print(f"  Frontdoor: {e}")
    time.sleep(5)
    ss(page, "login")
    print(f"  Logged in: {page.url[:80]}")
    return page

def navigate_to_app_manager(page):
    print(f"  Navigating to App Manager...")
    try:
        page.goto(APP_MANAGER_URL, timeout=60000, wait_until="domcontentloaded")
    except Exception as e:
        print(f"  Navigate: {e}")
    time.sleep(6)
    ss(page, "app_manager")
    print(f"  URL: {page.url[:80]}")

def find_table_frame(page, max_wait=25):
    deadline = time.time() + max_wait
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

def load_all_rows(frame, page):
    """Scroll the table container to load all rows."""
    print("  Loading all table rows...")

    # First, find the scrollable container for the table
    scroll_info = frame.evaluate("""() => {
        const table = document.querySelector('table');
        if (!table) return {found: false};

        // Walk up to find scrollable container
        let el = table;
        const containers = [];
        for (let i = 0; i < 15; i++) {
            el = el.parentElement;
            if (!el) break;
            const style = window.getComputedStyle(el);
            const overflow = style.overflow + ' ' + style.overflowY;
            containers.push({
                tag: el.tagName,
                className: el.className.slice(0, 50),
                overflow: overflow,
                scrollHeight: el.scrollHeight,
                clientHeight: el.clientHeight,
                scrollTop: el.scrollTop
            });
        }
        return {found: true, containers: containers};
    }""")

    if scroll_info.get('found'):
        for c in scroll_info.get('containers', []):
            if c['scrollHeight'] > c['clientHeight'] + 10:
                print(f"  Scrollable container: {c['tag']} class={c['className'][:30]} overflow={c['overflow']}")

    # Now try scrolling various ways
    prev_count = 0
    for attempt in range(20):
        count = frame.evaluate("() => document.querySelectorAll('table tbody tr').length")
        if count == prev_count and attempt > 2:
            break
        prev_count = count

        # Try multiple scroll strategies
        frame.evaluate("""() => {
            const table = document.querySelector('table');
            if (!table) return;

            // Strategy 1: scroll the table's scrollable parent
            let el = table;
            for (let i = 0; i < 15; i++) {
                el = el.parentElement;
                if (!el) break;
                const style = window.getComputedStyle(el);
                const overflow = style.overflow + style.overflowY;
                if (overflow.includes('auto') || overflow.includes('scroll')) {
                    el.scrollTop = el.scrollHeight;
                    break;
                }
            }

            // Strategy 2: scroll the window
            window.scrollTo(0, document.body.scrollHeight);

            // Strategy 3: scroll the table body
            const tbody = document.querySelector('table tbody');
            if (tbody) tbody.scrollTop = tbody.scrollHeight;
        }""")
        time.sleep(0.8)

    final_count = frame.evaluate("() => document.querySelectorAll('table tbody tr').length")
    print(f"  Rows after scrolling: {final_count}")
    return final_count

def get_all_app_names(frame):
    """Extract all app labels from the table."""
    # Column 1 (index 1) is the App Name Label in App Manager
    # Column 0 is the checkbox
    return frame.evaluate("""() => {
        const rows = document.querySelectorAll('table tbody tr');
        const apps = [];
        rows.forEach((row, idx) => {
            const tds = row.querySelectorAll('td');
            // Try to find the app name - it's typically in the 2nd td (index 1)
            // But could also be an 'a' link
            let name = '';
            let devName = '';

            if (tds.length >= 2) {
                // tds[0] = checkbox, tds[1] = App Name
                name = tds[1] ? tds[1].textContent.trim().replace(/\\s+/g, ' ') : '';
                devName = tds[2] ? tds[2].textContent.trim().replace(/\\s+/g, ' ') : '';
            }

            if (name || devName) {
                apps.push({idx: idx, name: name, devName: devName});
            }
        });
        return apps;
    }""")

def find_app_by_name(frame, app_name):
    """Find the row index for an app by its label name."""
    result = frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        for (let i = 0; i < rows.length; i++) {{
            const tds = rows[i].querySelectorAll('td');
            if (tds.length >= 2) {{
                // tds[1] is the App Name column
                const nameText = tds[1] ? tds[1].textContent.trim().replace(/\\s+/g, ' ') : '';
                const devText = tds[2] ? tds[2].textContent.trim().replace(/\\s+/g, ' ') : '';

                if (nameText === '{app_name}' || nameText.includes('{app_name}') ||
                    devText === '{app_name}' || devText.includes('{app_name}')) {{
                    return {{found: true, rowIndex: i, name: nameText, devName: devText}};
                }}
            }}
        }}
        return {{found: false}};
    }}""")
    return result

def click_edit_for_app(frame, page, row_index, app_name):
    """Click the dropdown and Edit for an app row."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    # Scroll row into view
    frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        if (rows[{row_index}]) rows[{row_index}].scrollIntoView({{block: 'center'}});
    }}""")
    time.sleep(0.5)
    ss(page, f"{safe}_row_visible")

    # Click the dropdown button (last button in row)
    result = frame.evaluate(f"""() => {{
        const rows = document.querySelectorAll('table tbody tr');
        const row = rows[{row_index}];
        if (!row) return 'no_row';
        const buttons = row.querySelectorAll('button');
        if (buttons.length > 0) {{
            const btn = buttons[buttons.length - 1];
            btn.scrollIntoView({{block: 'nearest'}});
            btn.click();
            return 'clicked ' + buttons.length + ' buttons';
        }}
        const links = row.querySelectorAll('a');
        if (links.length > 0) {{
            links[links.length - 1].click();
            return 'clicked link';
        }}
        return 'no clickable';
    }}""")
    print(f"  Dropdown: {result}")
    time.sleep(2)
    ss(page, f"{safe}_dropdown")

    # Now look for Edit option anywhere on the page
    for ctx in [page, frame]:
        for sel in [
            "a:has-text('Edit')",
            "button:has-text('Edit')",
            "[title='Edit']",
            ".slds-dropdown__item:has-text('Edit') a",
            "li:has-text('Edit') a",
            "[role='menuitem']:has-text('Edit')",
        ]:
            try:
                el = ctx.locator(sel).first
                if el.count() > 0 and el.is_visible(timeout=2000):
                    el.click(timeout=5000)
                    print(f"  Clicked Edit: {sel}")
                    time.sleep(6)
                    try:
                        page.wait_for_load_state("domcontentloaded", timeout=30000)
                    except Exception:
                        pass
                    time.sleep(3)
                    ss(page, f"{safe}_editor")
                    print(f"  Editor: {page.url[:80]}")
                    return True
            except Exception:
                pass

    # JS fallback - click visible Edit element
    for ctx in [page, frame]:
        try:
            r = ctx.evaluate("""() => {
                // Find any visible element with text 'Edit'
                const allEls = document.querySelectorAll('a, button, li, [role="menuitem"]');
                for (const el of allEls) {
                    if (el.textContent.trim() === 'Edit') {
                        const rect = el.getBoundingClientRect();
                        if (rect.width > 0 && rect.height > 0) {
                            el.click();
                            return 'clicked: ' + el.tagName + ' ' + el.className;
                        }
                    }
                }
                return 'not found';
            }""")
            if 'clicked' in r:
                print(f"  Edit via JS: {r}")
                time.sleep(6)
                try:
                    page.wait_for_load_state("domcontentloaded", timeout=30000)
                except Exception:
                    pass
                time.sleep(3)
                ss(page, f"{safe}_editor_js")
                return True
        except Exception:
            pass

    print(f"  Could not click Edit")
    ss(page, f"{safe}_no_edit")
    return False

def click_utility_items(page, app_name):
    """Click Utility Items tab in the app editor."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    # Wait for the editor to fully load
    time.sleep(2)

    # Check what navigation items are available
    nav_items = page.evaluate("""() => {
        const items = document.querySelectorAll('nav a, nav button, nav li, .setupNavigationItem, [role="tab"]');
        return Array.from(items).map(el => el.textContent.trim().slice(0, 60)).filter(t => t.length > 0);
    }""")
    print(f"  Nav items found: {nav_items[:10]}")

    for sel in [
        "text=Utility Items (Desktop Only)",
        "text=Utility Items",
        "button:has-text('Utility Items')",
        "a:has-text('Utility Items')",
        "li:has-text('Utility Items (Desktop Only)')",
        "[title='Utility Items (Desktop Only)']",
        "[title='Utility Items']",
    ]:
        try:
            el = page.locator(sel).first
            if el.count() > 0 and el.is_visible(timeout=4000):
                el.click(timeout=5000)
                time.sleep(3)
                try:
                    page.wait_for_load_state("domcontentloaded", timeout=15000)
                except Exception:
                    pass
                time.sleep(2)
                ss(page, f"{safe}_utility_items")
                print(f"  Clicked Utility Items tab")
                return True
        except Exception:
            continue

    ss(page, f"{safe}_no_utility_tab")
    print(f"  'Utility Items' tab not found")
    return False

def enable_start_auto(page, app_name):
    """Find Ask mcLOVIN' and enable Start Automatically."""
    safe = app_name.replace(' ','_').replace("'",'')[:20]

    content = page.content()
    if "mcLOVIN" not in content:
        ss(page, f"{safe}_no_mclovin")
        print(f"  'Ask mcLOVIN'' NOT found in utility items")
        return "not_found"

    print(f"  'Ask mcLOVIN'' IS found in utility items!")
    ss(page, f"{safe}_mclovin_page")

    # Click on Ask mcLOVIN to expand its properties
    clicked = False
    for pat in ["Ask mcLOVIN'", "Ask mcLOVIN"]:
        try:
            el = page.locator(f"text={pat}").first
            if el.count() > 0 and el.is_visible(timeout=3000):
                el.scroll_into_view_if_needed()
                el.click(timeout=5000)
                time.sleep(2)
                ss(page, f"{safe}_mclovin_expanded")
                print(f"  Clicked '{pat}'")
                clicked = True
                break
        except Exception as e:
            print(f"  Click '{pat}': {e}")

    if not clicked:
        # Try JS click
        try:
            r = page.evaluate("""() => {
                const els = document.querySelectorAll('*');
                for (const el of els) {
                    if (el.textContent.trim() === "Ask mcLOVIN'" || el.textContent.trim() === "Ask mcLOVIN") {
                        if (el.children.length === 0 || el.tagName === 'SPAN' || el.tagName === 'A') {
                            el.click();
                            return el.tagName + ': ' + el.textContent.trim();
                        }
                    }
                }
                return 'not found';
            }""")
            print(f"  mcLOVIN JS click: {r}")
            time.sleep(2)
        except Exception as e:
            print(f"  JS click error: {e}")

    # Check for Start Automatically
    content = page.content()
    if "Start Automatically" not in content:
        print(f"  'Start Automatically' NOT in page after expanding mcLOVIN")
        ss(page, f"{safe}_no_start_auto")
        return "not_found"

    print(f"  'Start Automatically' FOUND in page!")
    ss(page, f"{safe}_start_auto_visible")

    # Find the checkbox
    js_result = page.evaluate("""() => {
        // Walk DOM to find 'Start Automatically' text and nearby checkbox
        function findByTextWalker(text) {
            const walker = document.createTreeWalker(
                document.body, NodeFilter.SHOW_TEXT, null
            );
            let node;
            while ((node = walker.nextNode())) {
                if (node.textContent.trim() === text) {
                    // Found the text! Now look for checkbox in ancestors
                    let ancestor = node.parentElement;
                    for (let i = 0; i < 10; i++) {
                        if (!ancestor) break;
                        const cb = ancestor.querySelector('input[type="checkbox"]');
                        if (cb) {
                            return {
                                found: true, id: cb.id, name: cb.name,
                                checked: cb.checked, method: 'textWalker'
                            };
                        }
                        ancestor = ancestor.parentElement;
                    }
                }
            }
            return null;
        }

        let result = findByTextWalker('Start Automatically');
        if (result) return result;

        // Try label approach
        for (const label of document.querySelectorAll('label')) {
            if (label.textContent.trim().includes('Start Automatically')) {
                const forId = label.getAttribute('for');
                if (forId) {
                    const cb = document.getElementById(forId);
                    if (cb) return {found: true, id: cb.id, name: cb.name, checked: cb.checked, method: 'label'};
                }
                const cb = label.parentElement?.querySelector('input[type="checkbox"]');
                if (cb) return {found: true, id: cb.id, name: cb.name, checked: cb.checked, method: 'label-parent'};
            }
        }

        // Try lightning-input
        for (const li of document.querySelectorAll('lightning-input')) {
            const label = li.getAttribute('label') || '';
            if (label.includes('Start Automatically')) {
                const cb = li.querySelector('input[type="checkbox"]');
                if (cb) return {found: true, id: cb.id, name: cb.name, checked: cb.checked, method: 'lightning-input'};
            }
        }

        // Fallback: list all checkboxes
        const all = [];
        document.querySelectorAll('input[type="checkbox"]').forEach(cb => {
            const label = document.querySelector(`label[for="${cb.id}"]`);
            const container = cb.closest('[class*="item"], [class*="row"], div');
            all.push({
                id: cb.id, name: cb.name, checked: cb.checked,
                label: label ? label.textContent.trim() : '',
                context: container ? container.textContent.trim().replace(/\\s+/g, ' ').slice(0, 150) : ''
            });
        });
        return {found: false, all: all};
    }""")

    print(f"  Checkbox JS result: {json.dumps(js_result)[:500]}")

    checkbox_id = None
    checkbox_name = None
    is_checked = None

    if js_result.get("found"):
        checkbox_id = js_result.get("id", "")
        checkbox_name = js_result.get("name", "")
        is_checked = js_result.get("checked", False)
        print(f"  Checkbox: id='{checkbox_id}' checked={is_checked} via {js_result.get('method')}")
    else:
        for cb in js_result.get("all", []):
            ctx = cb.get("context", "")
            lbl = cb.get("label", "")
            if "Start Automatically" in ctx or "Start Automatically" in lbl:
                checkbox_id = cb.get("id", "")
                checkbox_name = cb.get("name", "")
                is_checked = cb.get("checked", False)
                print(f"  Checkbox from context: id='{checkbox_id}' checked={is_checked}")
                break

        if checkbox_id is None:
            print(f"  All checkboxes ({len(js_result.get('all', []))}):")
            for cb in js_result.get("all", []):
                print(f"    id='{cb['id']}' label='{cb['label']}' ctx='{cb['context'][:80]}'")

    ss(page, f"{safe}_pre_action")

    if checkbox_id is None and checkbox_name is None:
        print(f"  Cannot find Start Automatically checkbox!")
        return "not_found"

    if is_checked:
        print(f"  Already enabled!")
        return "already_enabled"

    # Click to enable
    print(f"  Enabling Start Automatically...")

    sel = f"#{checkbox_id}" if checkbox_id else f'input[name="{checkbox_name}"]'
    try:
        cb_el = page.locator(sel).first
        cb_el.scroll_into_view_if_needed(timeout=5000)
        cb_el.click(timeout=8000)
        time.sleep(1)
        ss(page, f"{safe}_enabled")
        # Verify
        try:
            new_state = cb_el.is_checked(timeout=3000)
            print(f"  New state: {'checked' if new_state else 'unchecked'}")
        except Exception:
            pass
        return "enabled"
    except Exception as e:
        print(f"  Playwright click failed: {e}, trying JS...")
        try:
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
                time.sleep(5)
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
    """Full process for one app."""
    # Navigate to App Manager
    navigate_to_app_manager(page)

    # Find table
    frame = find_table_frame(page)
    if not frame:
        print(f"  No table found!")
        return None

    # Load all rows by scrolling
    load_all_rows(frame, page)

    # Get all apps for debugging
    apps = get_all_app_names(frame)
    print(f"  All apps in table ({len(apps)}):")
    for app in apps:
        print(f"    [{app['idx']}] '{app['name']}' / '{app['devName'][:30]}'")

    ss(page, f"full_table_{app_name.replace(' ','_')[:15]}")

    # Find our target app
    row_index = None
    for try_name in names_to_try:
        result = find_app_by_name(frame, try_name)
        if result.get("found"):
            row_index = result["rowIndex"]
            print(f"  Found '{try_name}' at row {row_index}")
            break
        else:
            print(f"  '{try_name}' not found in table")

    if row_index is None:
        print(f"  App '{app_name}' not found")
        return None

    # Click Edit
    if not click_edit_for_app(frame, page, row_index, app_name):
        return "error"

    # Click Utility Items tab
    if not click_utility_items(page, app_name):
        return "no_utility_bar"

    # Enable Start Automatically
    result = enable_start_auto(page, app_name)

    if result == "enabled":
        if not save_app(page, app_name):
            return "save_failed"

    return result

def main():
    results = {}
    access_token, instance_url = get_creds()
    print(f"Credentials OK: {instance_url}")

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            env={"DISPLAY": ":99"},
            args=[
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--window-size=1440,900',
                '--ignore-certificate-errors',
                '--ignore-ssl-errors',
            ],
            slow_mo=50,
        )
        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )

        try:
            page = login(context, access_token, instance_url)

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
                    print(f"  => Result: {result}")
                except Exception as e:
                    print(f"  EXCEPTION: {e}")
                    import traceback
                    traceback.print_exc()
                    results[app_name] = "error"
                    try:
                        ss(page, f"err_{app_name.replace(' ','_')[:15]}")
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
