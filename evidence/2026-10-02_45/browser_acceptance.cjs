const fs = require('fs');
const {chromium} = require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root='C:/Users/User/.codex/tmp/cv45-webqa';
const html=root+'/index.html';
function args(extra=[]) { let text=fs.readFileSync(html,'utf8'); text=text.replace(/"args":\[[^\]]*\]/, '"args":'+JSON.stringify(['--','--bot=save_transfer','--lang=zh_TW','--out=user://web_transfer','--no-quit',...extra])); fs.writeFileSync(html,text); }
async function phase(page,name) { await page.waitForFunction(p=>window.cityVentureQA?.phase===p,name,{timeout:180000}); const state=await page.evaluate(()=>window.cityVentureQA); console.log(JSON.stringify(state)); if(state.failures.length) throw Error(JSON.stringify(state.failures)); return state; }
async function click(page,state) { const box=await page.locator('#canvas').boundingBox(); const dims=await page.locator('#canvas').evaluate(c=>({w:c.width,h:c.height})); await page.mouse.click(box.x+state.button.x*box.width/dims.w,box.y+state.button.y*box.height/dims.h); }
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Users/User/AppData/Local/ms-playwright/chromium-1234/chrome-win64/chrome.exe',headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:1280,height:720},acceptDownloads:true}); const page=await context.newPage(); const errors=[];
 page.on('console',m=>{if(m.type()==='error'||m.text().includes('BOT'))console.log(m.text()); if(m.text().includes('SCRIPT ERROR'))errors.push(m.text());}); page.on('pageerror',e=>errors.push(String(e)));
 args(); await page.goto('http://127.0.0.1:8825/index.html');
 let state=await phase(page,'export'); await page.screenshot({path:root+'/web_export.jpg',type:'jpeg',quality:85});
 const dp=page.waitForEvent('download'); await click(page,state); const download=await dp; const save=root+'/'+download.suggestedFilename(); await download.saveAs(save);
 state=await phase(page,'import'); const fp=page.waitForEvent('filechooser'); await click(page,state); await (await fp).setFiles(save);
 await phase(page,'finished'); await page.screenshot({path:root+'/web_import.jpg',type:'jpeg',quality:85}); await page.waitForTimeout(3000);
 args(['--verify-persisted']); await page.reload(); await phase(page,'finished'); await page.screenshot({path:root+'/web_refresh.jpg',type:'jpeg',quality:85});
 await context.close(); args(['--import-legacy','--check-updates']); const oldctx=await browser.newContext({viewport:{width:1280,height:720}}); const oldpage=await oldctx.newPage(); oldpage.on('console',m=>{if(m.type()==='error'||m.text().includes('BOT')) console.log(m.text());});
 await oldpage.goto('http://127.0.0.1:8825/index.html'); state=await phase(oldpage,'import'); const oldfp=oldpage.waitForEvent('filechooser'); await click(oldpage,state); await (await oldfp).setFiles('D:/City-Venture-39/game/tests/fixtures/saves/0.1.8-test8.1.cvsave'); state=await phase(oldpage,'updates'); await oldpage.screenshot({path:root+'/web_updates.jpg',type:'jpeg',quality:85}); await click(oldpage,state); await phase(oldpage,'finished'); await oldpage.screenshot({path:root+'/web_legacy.jpg',type:'jpeg',quality:85});
 await oldpage.waitForTimeout(3000); args(['--verify-persisted','--import-legacy','--check-updates']); await oldpage.reload(); await phase(oldpage,'finished'); await oldpage.screenshot({path:root+'/web_update_refresh.jpg',type:'jpeg',quality:85}); fs.writeFileSync(root+'/browser-result.json',JSON.stringify({failures:errors,download:save,roundtrip:true,persistence:true,legacy:true},null,2)); if(errors.length)throw Error(errors.join('\n')); 
 await oldctx.close();
 let tutorialResult='';const tutorialLogs=[];const snapshots=[];let snapCount=0;
 let text=fs.readFileSync(html,'utf8');text=text.replace(/"args":\[[^\]]*\]/,'"args":'+JSON.stringify(['--','--bot=tutorial','--lang=zh_TW','--out=user://beta_tutorial','--no-quit']));fs.writeFileSync(html,text);
 const tutctx=await browser.newContext({viewport:{width:1280,height:720}});const tutpage=await tutctx.newPage();
 tutpage.on('pageerror',e=>errors.push(String(e)));
 tutpage.on('console',m=>{const line=m.text();tutorialLogs.push(line);if(line.includes('SCRIPT ERROR'))errors.push(line);if(line.includes('BOT FINISHED')){tutorialResult=line;tutpage.evaluate(()=>window.__tutorialFinished=true).catch(()=>{});}
  if(line.includes('shot ')&&snapCount<30){snapCount++;snapshots.push(tutpage.screenshot({path:root+'/tutorial_'+String(snapCount).padStart(2,'0')+'.jpg',type:'jpeg',quality:80}).catch(e=>errors.push(String(e))));}});
 await tutpage.goto('http://127.0.0.1:8825/index.html');
 await tutpage.waitForFunction(()=>window.__tutorialFinished===true,null,{timeout:240000}).catch(()=>{});
 await Promise.all(snapshots);
 if(!tutorialResult.includes('0 failure(s)'))throw Error('Tutorial did not pass: '+tutorialResult);
 await tutpage.screenshot({path:root+'/tutorial_finished.jpg',type:'jpeg',quality:85});
 fs.writeFileSync(root+'/tutorial.log',tutorialLogs.join('\n'));
 fs.writeFileSync(root+'/browser-result.json',JSON.stringify({failures:errors,download:save,roundtrip:true,persistence:true,legacy:true,tutorial:tutorialResult,tutorialScreenshots:snapCount},null,2));
 if(errors.length)throw Error(errors.join('\n'));await browser.close();
 
})().catch(e=>{console.error(e);process.exit(1)});
