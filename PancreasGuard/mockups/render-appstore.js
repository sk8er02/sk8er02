const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 2500, height: 960, deviceScaleFactor: 2 });
  await page.goto('file://' + path.resolve('appstore-screenshots.html'), { waitUntil: 'networkidle0' });

  const screenshots = await page.$$('.screenshot');
  const names = ['appstore-1-dashboard', 'appstore-2-alerts', 'appstore-3-food-scanner', 'appstore-4-symptom-log', 'appstore-5-trends'];

  for (let i = 0; i < screenshots.length; i++) {
    await screenshots[i].screenshot({ path: names[i] + '.png' });
    console.log('Rendered ' + names[i] + '.png');
  }

  await browser.close();
  console.log('Done rendering App Store screenshots');
})();
