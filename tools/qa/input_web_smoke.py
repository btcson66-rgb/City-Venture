from pathlib import Path
from playwright.sync_api import sync_playwright
import json,time,threading,argparse,hashlib
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from functools import partial
parser=argparse.ArgumentParser(description="Chrome mobile touch/audio/fullscreen smoke against a local Godot export")
parser.add_argument("--export-dir",required=True)
parser.add_argument("--out",required=True)
args=parser.parse_args()
server=ThreadingHTTPServer(("127.0.0.1",18888),partial(SimpleHTTPRequestHandler,directory=args.export_dir))
threading.Thread(target=server.serve_forever,daemon=True).start()
out=Path(args.out);out.mkdir(exist_ok=True)
with sync_playwright() as pw:
 browser=pw.chromium.launch(headless=True,args=['--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=user-gesture-required'])
 context=browser.new_context(viewport={'width':844,'height':390},device_scale_factor=1,is_mobile=True,has_touch=True,record_video_dir=str(out/'video'),record_video_size={'width':844,'height':390},user_agent='Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Mobile Safari/537.36')
 context.add_init_script("""window.cvAnalysers=[];const realConnect=AudioNode.prototype.connect;AudioNode.prototype.connect=function(...args){if(args[0]===this.context.destination){const a=this.context.createAnalyser();a.fftSize=2048;realConnect.call(this,a);realConnect.call(a,args[0]);window.cvAnalysers.push(a);return args[0];}return realConnect.apply(this,args);};window.cvAudioContexts=[];for(const key of ['AudioContext','webkitAudioContext']) { if(window[key]) {const Original=window[key];window[key]=new Proxy(Original,{construct(target,args){const ctx=Reflect.construct(target,args);window.cvAudioContexts.push(ctx);return ctx;}});}}""")
 page=context.new_page();messages=[]
 page.on('console',lambda msg: messages.append({'type':msg.type,'text':msg.text}))
 page.on('pageerror',lambda error: messages.append({'type':'pageerror','text':str(error)}))
 response=page.goto('http://127.0.0.1:18888/index.html',wait_until='domcontentloaded',timeout=60000)
 assert response.status == 200
 page.wait_for_function("document.querySelector('#status') === null",timeout=180000)
 page.wait_for_timeout(3000)
 before=page.evaluate("window.cvAudioContexts.map(c=>c.state)")
 sample="window.cvAnalysers.map(a=>{const b=new Float32Array(a.fftSize);a.getFloatTimeDomainData(b);return Math.max(...b.map(Math.abs));})"
 level_before=page.evaluate(sample)
 page.screenshot(path=str(out/'01_mobile_title.jpg'),type='jpeg',quality=85)
 cdp=context.new_cdp_session(page);version=cdp.send('Browser.getVersion')
 (out/'baseline.json').write_text(json.dumps({'version':version,'audio_before':before,'level_before':level_before,'messages':messages},ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({'version':version['product'],'audio_before':before,'messages':messages[-4:]},ensure_ascii=False),flush=True)
 cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':410,'y':285,'id':0}]})
 cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
 page.wait_for_timeout(2000)
 page.screenshot(path=str(out/'02_after_touch.jpg'),type='jpeg',quality=85)
 after=page.evaluate("window.cvAudioContexts.map(c=>c.state)")
 level_after=page.evaluate(sample)
 page.locator("#cv-fullscreen").click()
 page.wait_for_timeout(500)
 fullscreen=page.evaluate("!!document.fullscreenElement")
 print(json.dumps({"level_before":level_before,"level_after":level_after,"fullscreen":fullscreen}),flush=True)
 print(json.dumps({'audio_after':after,'messages':messages[-4:]},ensure_ascii=False),flush=True)
 (out/'result.json').write_text(json.dumps({'version':version,'audio_before':before,'audio_after':after,'level_before':level_before,'level_after':level_after,'fullscreen':fullscreen,'messages':messages},ensure_ascii=False,indent=2),encoding='utf-8')
 page.evaluate("document.exitFullscreen ? document.exitFullscreen() : null")
 page.wait_for_timeout(500)
 cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':690,'y':54,'id':0}]})
 cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
 page.wait_for_timeout(500)
 cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':410,'y':128,'id':0}]})
 cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
 page.wait_for_timeout(3000)
 cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':710,'y':250,'id':0},{'x':760,'y':250,'id':1}]})
 cdp.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':710,'y':170,'id':0},{'x':760,'y':170,'id':1}]})
 cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
 page.wait_for_timeout(300)
 page.screenshot(path=str(out/'03_touch_creator.jpg'),type='jpeg',quality=85)
 page.set_viewport_size({'width':390,'height':844})
 page.wait_for_timeout(3000)
 page.screenshot(path=str(out/'04_portrait_hint.jpg'),type='jpeg',quality=85)
 print(json.dumps({'end_messages':messages[-15:]},ensure_ascii=False),flush=True)
 context.close();browser.close()

assert not any(m["type"] in ["error", "pageerror"] for m in messages), messages
assert max(level_before,default=0)==0 and max(level_after,default=0)>0, "first touch must unlock audible output"
assert fullscreen, "Chrome fullscreen must enter"
