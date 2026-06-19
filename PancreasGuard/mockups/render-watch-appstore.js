const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 2000, height: 530, deviceScaleFactor: 2 });
  await page.goto('file://' + path.resolve('appstore-watch-screenshots.html'), { waitUntil: 'networkidle0' });

  const screenshots = await page.$$('.screenshot');
  const names = ['appstore-watch-1-dashboard', 'appstore-watch-2-alert', 'appstore-watch-3-quicklog', 'appstore-watch-4-complications'];

  for (let i = 0; i < screenshots.length; i++) {
    await screenshots[i].screenshot({ path: names[i] + '.png' });
    console.log('Rendered ' + names[i] + '.png');
  }

  await browser.close();
  console.log('Done rendering Apple Watch App Store screenshots');
})();
