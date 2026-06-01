// Click a foreman CTA on the WO page and capture the resulting modal/page.
const { chromium } = require('playwright');
const { execSync } = require('child_process');

const ctaText = process.argv[2] || 'Log labor';
const shotName = process.argv[3] || 'cta-log-labor';
const woId = process.argv[4] || '0WOVu000006sntBOAQ';

(async () => {
  const orgInfo = JSON.parse(execSync('sf org display --target-org dispatch --json').toString()).result;
  const target = `/lightning/r/WorkOrder/${woId}/view`;
  const url = `${orgInfo.instanceUrl}/secur/frontdoor.jsp?sid=${orgInfo.accessToken}&retURL=${encodeURIComponent(target)}`;
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, ignoreHTTPSErrors: true });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(`pageerror: ${e.message}`));
  page.on('console', m => { if (m.type() === 'error') errors.push(`console.error: ${m.text()}`); });

  console.log(`Loading WO page ...`);
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(8000);

  console.log(`Clicking "${ctaText}" ...`);
  // The qa-item divs are inside a shadow DOM. Use text-based locator.
  const locator = page.getByText(ctaText, { exact: true }).first();
  await locator.waitFor({ timeout: 15000 });
  await locator.click();
  await page.waitForTimeout(5000);

  const out = `verification/screenshots/${shotName}.png`;
  await page.screenshot({ path: out, fullPage: true });
  console.log(`Screenshot: ${out}`);
  console.log(`URL: ${page.url()}`);
  console.log(`Title: ${await page.title()}`);
  if (errors.length) errors.forEach(e => console.log(e));
  else console.log('--- No errors ---');
  await browser.close();
})().catch(e => { console.error('FAIL:', e.message); process.exit(1); });
