/**
 * Rigenera gli screenshot per App Store Connect (formato 6.9", 1320x2868 px) a partire dal sito
 * di produzione. Usa solo pagine pubbliche (home + lista pubblica di esempio): nessun login,
 * nessuna credenziale coinvolta.
 *
 * Uso:
 *   npm install playwright
 *   npx playwright install chromium
 *   node generate-screenshots.js
 */
const { chromium } = require('playwright');

const VIEWPORT = { width: 440, height: 956 }; // punti CSS iPhone Pro Max
const SCALE = 3; // deviceScaleFactor 3 => 1320x2868 px fisici

const PAGES = [
  { url: 'https://www.tabato.it/', out: '01-home.png' },
  // Sostituire con il link di una lista pubblica di esempio aggiornata, se questa scade/cambia.
  { url: 'https://www.tabato.it/l/GBF4SPN8DC', out: '02-lista-pubblica.png' }
];

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: SCALE,
    isMobile: true,
    hasTouch: true,
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'
  });
  const page = await context.newPage();

  for (const { url, out } of PAGES) {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(500);

    const acceptBtn = page.getByRole('button', { name: /^Accetta$/i });
    if (await acceptBtn.count()) {
      await acceptBtn.first().click();
      await page.waitForTimeout(300);
    }

    await page.screenshot({ path: out, fullPage: false });
    console.log('saved', out);
  }

  await browser.close();
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
