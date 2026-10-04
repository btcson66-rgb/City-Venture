"""Local exported Web audio unlock/graph smoke. Does not claim audible speaker or physical-device acceptance."""
import json,time
from pathlib import Path
from playwright.sync_api import sync_playwright
out=Path('C:/Users/User/.codex/tmp/cv97-web-smoke');out.mkdir(exist_ok=True)
with sync_playwright() as p:
 browser=p.chromium.launch(headless=True,args=['--autoplay-policy=user-gesture-required','--enable-unsafe-swiftshader'])
 page=browser.new_page(viewport={'width':1280,'height':720})
 errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.add_init_script("""window.__contexts=[];window.__connections=0;
 const Original=window.AudioContext; if(Original){function Tracked(...args){const c=new Original(...args);window.__contexts.push(c);return c;} Tracked.prototype=Original.prototype;Object.setPrototypeOf(Tracked,Original);window.AudioContext=Tracked;}
 const originalConnect=AudioNode.prototype.connect;AudioNode.prototype.connect=function(...args){window.__connections++;return originalConnect.apply(this,args);};""")
 page.goto('http://127.0.0.1:8776/index.html',wait_until='domcontentloaded')
 page.wait_for_timeout(18000)
 before=page.evaluate('window.__contexts.map(c=>c.state)')
 page.mouse.click(640,350)
 page.wait_for_timeout(4000)
 after=page.evaluate('window.__contexts.map(c=>c.state)')
 connections=page.evaluate('window.__connections')
 page.screenshot(path=str(out/'audio-unlock.jpg'),type='jpeg',quality=85)
 result={'before_gesture':before,'after_gesture':after,'audio_graph_connections':connections,'page_errors':errors,'passed':bool(after) and all(s=='running' for s in after) and connections>0 and not errors,'scope':'Chromium software WebGL; running WebAudio graph after real mouse gesture, no physical speaker/listener assertion.'}
 (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
 print(json.dumps(result))
 browser.close()
 assert result['passed']
