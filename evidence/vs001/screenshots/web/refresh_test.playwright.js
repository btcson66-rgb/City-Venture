const { chromium } = require('playwright');
(async () => {
  const out = __dirname + '/';
  const ctx = await chromium.launchPersistentContext('/tmp/pw-profile', {
    executablePath: '/opt/pw-browsers/chromium', headless: true, viewport: { width: 1280, height: 720 },
    args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = ctx.pages()[0] || await ctx.newPage();
  await page.goto('http://localhost:8765/index.html');
  await page.waitForTimeout(10000);
  await page.mouse.click(238, 281);   // New Game
  await page.waitForTimeout(2500);
  await page.mouse.click(1019, 661);  // Start in Aurelia
  for (let i = 0; i < 14; i++) { await page.waitForTimeout(1500); await page.mouse.click(640, 600); }
  await page.waitForTimeout(3000);
  await page.keyboard.down('KeyD'); await page.waitForTimeout(2150); await page.keyboard.up('KeyD');
  await page.keyboard.down('KeyS'); await page.waitForTimeout(3200); await page.keyboard.up('KeyS');
  await page.waitForTimeout(2500);
  await page.screenshot({ path: out + 'w5_outside.png' });
  // walk a bit along the street so the position differs from the door
  await page.keyboard.down('KeyD'); await page.waitForTimeout(1500); await page.keyboard.up('KeyD');
  await page.waitForTimeout(17000);   // > one periodic autosave interval
  await page.screenshot({ path: out + 'w6_before_refresh.png' });
  await page.reload();
  await page.waitForTimeout(11000);
  await page.screenshot({ path: out + 'w7_menu_after_refresh.png' });
  await page.mouse.click(238, 323);   // Continue
  await page.waitForTimeout(4000);
  await page.screenshot({ path: out + 'w8_continued.png' });
  await ctx.close();
})();
