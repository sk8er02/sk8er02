const puppeteer = require('puppeteer');
const path = require('path');

async function render(htmlFile, outputFile, width, height) {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width, height, deviceScaleFactor: 2 });
  await page.goto('file://' + path.resolve(htmlFile), { waitUntil: 'networkidle0' });
  await page.screenshot({ path: outputFile, fullPage: false });
  await browser.close();
}

(async () => {
  await render('dashboard-mockup.html', 'dashboard.png', 440, 900);
  await render('alert-mockup.html', 'alert-state.png', 440, 900);
  await render('watch-mockup.html', 'watch-screens.png', 780, 340);
  console.log('Done rendering mockups');
})();
