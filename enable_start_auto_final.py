#!/usr/bin/env python3
"""
Enable 'Start Automatically' for 'Ask mcLOVIN'' utility bar item.
Final version with all fixes.
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
    path = f"{SCREENSHOTS_DIR}/final_{screenshot_counter[0]:03d}_{name}.png"
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
    try:
        page.goto(url, timeout=60000, wait_until="domcontentloaded")
    except Exception as e:
        print(f"  Frontdoor: {e}")
    time.sleep(5)
    ss(page, "login")
    print(f"  Logged in: {page.url[:80]}")
    return page

def navigate_to_app_manager(page):
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
    """Scroll to load all rows."""
    print("  Loading all rows...")
    for attempt in range(20):
        prev = frame.evaluate("() => document.querySelectorAll('table tbody tr').length")
        frame.evaluate("""() => {
            // Try all possible scrollable containers
            const table = document.querySelector('table');
            if (!table) return;
            let el = table;
            for (let i = 0; i < 20; i++) {
                el = el.parentElement;
                if (!el) break;
                const cs = window.getComputedStyle(el);
                if (cs.overflowY === 'auto' || cs.overflowY === 'scroll' ||
                    cs.overflow === 'auto' || cs.overflow === 'scroll') {
                    el.scrollTop = el.scrollHeight;
                }
            }
            window.scrollTo(0, document.body.scrollHeight);
        }""")
        time.sleep(0.8)
        curr = frame.evaluate("() => document.querySelectorAll('table tbody tr').length")
        if curr == prev and attempt > 3:
            break
    final = frame.evaluate("() => document.querySelectorAll('table tbody tr').length")
    print(f"  Total rows: {final}")
    return final

def find_app_row(frame, search_terms):
    """Find app row by searching all cells for any of the search terms."""
    return frame.evaluate(f"""(terms) => {{
        const rows = document.querySelectorAll('table tbody tr');
        for (let i = 0; i < rows.length; i++) {{
            const rowText = rows[i].textContent.trim().replace(/\\s+/g, ' ').toLowerCase();
            for (const term of terms) {{
                const t = term.toLowerCase();
                if (rowText.includes(t)) {{
                    const tds = rows[i].querySelectorAll('td');
                    const cells = Array.from(tds).map(td => td.textContent.trim().replace(/\\s+/g, ' '));
                    return {{found: true, rowIndex: i, cells: cells, matchedTerm: term}};
                }}
            }}
        }}
        return {{found: false}};
    }}""", search_terms)

def click_edit(frame, page, row_index, safe_name):
    """Click dropdown and Edit for a row."""
    # Scroll into view
    frame.evaluate(f"""() => {{
        const row = document.querySelectorAll('table tbody tr')[{row_index}];
        if (row) row.scrollIntoView({{block: 'center'}});
    }}""")
    time.sleep(0.5)
    ss(page, f"{safe_name}_row")

    # Click dropdown button
    result = frame.evaluate(f"""() => {{
        const row = document.querySelectorAll('table tbody tr')[{row_index}];
        if (!row) return 'no_row';
        const btns = row.querySelectorAll('button');
        if (btns.length > 0) {{ btns[btns.length-1].click(); return 'btn_' + btns.length; }}
        const links = row.querySelectorAll('a');
        if (links.length > 0) {{ links[links.length-1].click(); return 'link_' + links.length; }}
        return 'none';
    }}""")
    print(f"  Dropdown: {result}")
    time.sleep(2)
    ss(page, f"{safe_name}_dropdown")

    # Click Edit
    for ctx in [page, frame]:
        for sel in ["a:has-text('Edit')", "button:has-text('Edit')", "[title='Edit']"]:
            try:
                el = ctx.locator(sel).first
                if el.count() > 0 and el.is_visible(timeout=2000):
                    el.click(timeout=5000)
                    print(f"  Clicked Edit")
                    time.sleep(6)
                    try:
                        page.wait_for_load_state("domcontentloaded", timeout=30000)
                    except Exception:
                        pass
                    time.sleep(3)
                    ss(page, f"{safe_name}_editor")
                    print(f"  Editor: {page.url[:80]}")
                    return True
            except Exception:
                pass

    # JS fallback
    for ctx in [page, frame]:
        try:
            r = ctx.evaluate("""() => {
                for (const el of document.querySelectorAll('a, button, [role="menuitem"]')) {
                    if (el.textContent.trim() === 'Edit' && el.getBoundingClientRect().width > 0) {
                        el.click(); return 'ok:' + el.tagName;
                    }
                }
                return 'not_found';
            }""")
            if r.startswith('ok'):
                print(f"  Edit via JS: {r}")
                time.sleep(6)
                try:
                    page.wait_for_load_state("domcontentloaded", timeout=30000)
                except Exception:
                    pass
                time.sleep(3)
                ss(page, f"{safe_name}_editor_js")
                return True
        except Exception:
            pass

    ss(page, f"{safe_name}_no_edit")
    print(f"  Could not click Edit")
    return False

def click_utility_items_tab(page, safe_name):
    """Click the Utility Items tab."""
    for sel in [
        "text=Utility Items (Desktop Only)",
        "text=Utility Items",
        "button:has-text('Utility Items')",
        "a:has-text('Utility Items')",
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
                ss(page, f"{safe_name}_utility_items")
                print(f"  Clicked Utility Items tab")
                return True
        except Exception:
            continue

    ss(page, f"{safe_name}_no_utility_tab")
    print(f"  Utility Items tab not found")
    return False

def check_and_enable_start_auto(page, safe_name, app_name):
    """Find Ask mcLOVIN' and enable Start automatically (case-insensitive)."""
    content = page.content()
    mclovin_variants = ["mcLOVIN", "mclovin", "Ask mcLOVIN"]
    has_mclovin = any(v.lower() in content.lower() for v in mclovin_variants)

    if not has_mclovin:
        ss(page, f"{safe_name}_no_mclovin")
        print(f"  'Ask mcLOVIN'' NOT found in utility items")
        return "not_found"

    print(f"  'Ask mcLOVIN'' IS found!")
    ss(page, f"{safe_name}_mclovin_page")

    # Click on Ask mcLOVIN to expand (it may already be expanded)
    for pat in ["Ask mcLOVIN'", "Ask mcLOVIN"]:
        try:
            el = page.locator(f"text={pat}").first
            if el.count() > 0 and el.is_visible(timeout=3000):
                el.scroll_into_view_if_needed()
                el.click(timeout=5000)
                time.sleep(2)
                ss(page, f"{safe_name}_mclovin_clicked")
                print(f"  Clicked '{pat}'")
                break
        except Exception as e:
            pass

    # Check for "Start automatically" (case-insensitive)
    content = page.content()
    has_start_auto = "start automatically" in content.lower()

    if not has_start_auto:
        # Try to click mcLOVIN again and wait
        print(f"  'Start automatically' not yet visible, waiting...")
        time.sleep(2)
        content = page.content()
        has_start_auto = "start automatically" in content.lower()

    if not has_start_auto:
        ss(page, f"{safe_name}_no_start_auto")
        print(f"  'Start automatically' NOT in page")
        return "not_found"

    print(f"  'Start automatically' FOUND!")
    ss(page, f"{safe_name}_start_auto_found")

    # Find the checkbox via JS (case-insensitive search)
    js_result = page.evaluate("""() => {
        // Find text nodes containing 'start automatically' (case-insensitive)
        function findCb() {
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let node;
            while ((node = walker.nextNode())) {
                if (node.textContent.trim().toLowerCase() === 'start automatically') {
                    let ancestor = node.parentElement;
                    for (let i = 0; i < 10; i++) {
                        if (!ancestor) break;
                        const cb = ancestor.querySelector('input[type="checkbox"]');
                        if (cb) return {found: true, id: cb.id, name: cb.name, checked: cb.checked};
                        ancestor = ancestor.parentElement;
                    }
                }
            }
            return null;
        }

        let r = findCb();
        if (r) return r;

        // Check labels
        for (const label of document.querySelectorAll('label')) {
            if (label.textContent.trim().toLowerCase().includes('start automatically')) {
                const forId = label.getAttribute('for');
                if (forId) {
                    const cb = document.getElementById(forId);
                    if (cb) return {found: true, id: cb.id, name: cb.name, checked: cb.checked};
                }
                const cb = label.parentElement?.querySelector('input[type="checkbox"]');
                if (cb) return {found: true, id: cb.id, name: cb.name, checked: cb.checked};
            }
        }

        // All checkboxes for debugging
        const all = [];
        document.querySelectorAll('input[type="checkbox"]').forEach(cb => {
            const label = document.querySelector(`label[for="${cb.id}"]`);
            all.push({
                id: cb.id, name: cb.name, checked: cb.checked,
                label: label ? label.textContent.trim() : '',
                ariaLabel: cb.getAttribute('aria-label') || ''
            });
        });
        return {found: false, all: all};
    }""")

    print(f"  Checkbox result: {json.dumps(js_result)[:400]}")

    checkbox_id = None
    checkbox_name = None
    is_checked = None

    if js_result.get("found"):
        checkbox_id = js_result.get("id", "")
        checkbox_name = js_result.get("name", "")
        is_checked = js_result.get("checked", False)
        print(f"  Found checkbox: id='{checkbox_id}' checked={is_checked}")
    else:
        for cb in js_result.get("all", []):
            label = cb.get("label", "").lower()
            aria = cb.get("ariaLabel", "").lower()
            if "start" in label or "start" in aria:
                checkbox_id = cb.get("id", "")
                checkbox_name = cb.get("name", "")
                is_checked = cb.get("checked", False)
                print(f"  Checkbox from label search: id='{checkbox_id}' checked={is_checked}")
                break

    ss(page, f"{safe_name}_pre_action")

    if checkbox_id is None and checkbox_name is None:
        print(f"  Cannot find checkbox!")
        return "not_found"

    if is_checked:
        print(f"  'Start automatically' ALREADY ENABLED for '{app_name}'")
        return "already_enabled"

    # Click to enable
    print(f"  Enabling 'Start automatically'...")
    sel = f"#{checkbox_id}" if checkbox_id else f'input[name="{checkbox_name}"]'
    try:
        cb_el = page.locator(sel).first
        cb_el.scroll_into_view_if_needed(timeout=5000)
        cb_el.click(timeout=8000)
        time.sleep(1)
        # Verify
        try:
            new = cb_el.is_checked(timeout=3000)
            print(f"  New state: {'checked' if new else 'unchecked'}")
        except Exception:
            pass
        ss(page, f"{safe_name}_enabled")
        return "enabled"
    except Exception as e:
        print(f"  Click failed: {e}, trying JS...")
        try:
            page.evaluate(f"""() => {{
                const el = document.querySelector('{sel}');
                if (el) el.click();
            }}""")
            ss(page, f"{safe_name}_js_enabled")
            return "enabled"
        except Exception as e2:
            print(f"  JS click failed: {e2}")
            return "error"

def save_app(page, safe_name):
    """Click Save."""
    for sel in ["button:has-text('Save')", "input[value='Save']", "button[title='Save']"]:
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
                ss(page, f"{safe_name}_saved")
                return True
        except Exception:
            continue

    print(f"  Save button not found")
    ss(page, f"{safe_name}_no_save")
    return False

def process_app(page, app_name, search_terms):
    """Full process for one app."""
    safe = app_name.replace(' ','_').replace("'",'').replace('/',' ')[:20]

    navigate_to_app_manager(page)

    frame = find_table_frame(page)
    if not frame:
        print(f"  No table frame found!")
        return None

    load_all_rows(frame, page)

    # Find the app
    result = find_app_row(frame, search_terms)
    if not result.get("found"):
        print(f"  App not found with terms: {search_terms}")
        print(f"  Checking all rows for partial match...")
        # Show rows that might match
        all_rows = frame.evaluate(f"""() => {{
            const rows = document.querySelectorAll('table tbody tr');
            const matches = [];
            const terms = {json.dumps([t.lower() for t in search_terms])};
            rows.forEach((row, i) => {{
                const text = row.textContent.toLowerCase();
                for (const t of terms) {{
                    // Check individual words
                    const words = t.split(' ');
                    if (words.some(w => w.length > 4 && text.includes(w))) {{
                        const tds = row.querySelectorAll('td');
                        matches.push({{
                            idx: i,
                            cells: Array.from(tds).map(td => td.textContent.trim().slice(0, 40))
                        }});
                        break;
                    }}
                }}
            }});
            return matches;
        }}""")
        print(f"  Partial matches: {all_rows}")
        return None

    row_index = result["rowIndex"]
    matched_term = result.get("matchedTerm", "")
    print(f"  Found app at row {row_index} (matched: '{matched_term}')")
    print(f"  Row cells: {result['cells']}")

    if not click_edit(frame, page, row_index, safe):
        return "error"

    if not click_utility_items_tab(page, safe):
        return "no_utility_bar"

    result_status = check_and_enable_start_auto(page, safe, app_name)

    if result_status == "enabled":
        if not save_app(page, safe):
            return "save_failed"

    return result_status

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

            # App configs: (display_name, search_terms)
            # search_terms are searched case-insensitively in all cell text
            app_configs = [
                ("Outdoor Living", ["Outdoor Living", "Outdoor_Living"]),
                ("LOVING Field Service",
                 ["LOVING Field Service", "Field_Service_Console", "Field Service Console",
                  "Loving Field Service", "Field Services"]),
                ("Lightning Sales Console",
                 ["Lightning Sales Console", "LightningSalesConsole"]),
                ("Customer Success",
                 ["Customer Success", "Customer_Success", "Success_Manager",
                  "Customer Success Service Console"]),
            ]

            for app_name, search_terms in app_configs:
                print(f"\n{'='*60}")
                print(f"PROCESSING: {app_name}")
                print("="*60)
                try:
                    result = process_app(page, app_name, search_terms)
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
        "enabled": "ENABLED 'Start automatically' (saved)",
        "already_enabled": "Already enabled (no change needed)",
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
