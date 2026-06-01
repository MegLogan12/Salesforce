// Headless visual verification of the LOVING Salesforce UI using existing sf CLI token.
// Usage: node verify-ui.js <relative-path-or-url> [screenshot-name]
const { chromium } = require('playwright');
const { execSync } = require('child_process');

const target = process.argv[2] || '/lightning/page/home';
const shotName = process.argv[3] || 'home';

(async () => {
  const orgInfo = JSON.parse(execSync('sf org display --target-org loving-prod --json').toString()).result;
  const url = target.startsWith('http')
    ? target
    : `${orgInfo.instanceUrl}/secur/frontdoor.jsp?sid=${orgInfo.accessToken}&retURL=${encodeURIComponent(target)}`;

  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, ignoreHTTPSErrors: true });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(`pageerror: ${e.message}`));
  page.on('console', m => { if (m.type() === 'error') errors.push(`console.error: ${m.text()}`); });

  console.log(`Navigating to ${target} ...`);
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  await page.waitForTimeout(8000); // let Lightning render
  const out = `verification/screenshots/${shotName}.png`;
  await page.screenshot({ path: out, fullPage: true });
  console.log(`Screenshot saved: ${out}`);
  console.log(`Page title: ${await page.title()}`);
  console.log(`URL: ${page.url()}`);
  if (errors.length) {
    console.log('--- Browser errors ---');
    errors.forEach(e => console.log(e));
  } else {
    console.log('--- No browser errors ---');
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
