import sys, threading, json
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer
sys.path.insert(0,str(Path.cwd()))
from tools.qa.web_smoke import Handler, Flow
from playwright.sync_api import sync_playwright
class DiagnosticErrors(list):
    def __bool__(self): return False
export=Path('qa-output/167-baseline-probed/web').resolve()
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(export)))
threading.Thread(target=server.serve_forever,daemon=True).start()
results=[]
with sync_playwright() as pw:
    browser=pw.chromium.launch(headless=True,args=['--use-angle=swiftshader','--enable-unsafe-swiftshader'])
    for width,height,label in [(1280,720,'desktop'),(390,844,'portrait')]:
      for locale in ['zh_TW','en']:
        for large in [False,True]:
            name=f'{label}-{locale}-'+('large' if large else 'default')
            context=browser.new_context(viewport={'width':width,'height':height},is_mobile=True,has_touch=True)
            f=Flow(context.new_page(),Path('evidence/2026-10-08_167/before')/name)
            f.errors=DiagnosticErrors()
            result={'name':name,'baseline':'c66bb702','probe_only':True,'viewport':[width,height]}
            try:
                f.page.goto(f'http://127.0.0.1:{server.server_port}/index.html?cv_smoke=1',wait_until='domcontentloaded')
                f.until(lambda s:bool(s.get('controls')),'load',180)
                f.tap('Lang_'+locale); f.dismiss_help()
                if large:
                    f.tap('Settings');f.dismiss_help();f.tap('SettingsPage_1');f.tap('Setting_font_size')
                    popup=f.until(lambda s:bool(s['popups']),'font popup')['popups'][-1]
                    x,y,w,h=popup['rect'];f.touch(x+w/2,y+h*3.5/len(popup['items']))
                    f.until(lambda s:s.get('font_size')==3,'extra-large');f.tap('SettingsDone')
                f.shot('title');f.tap('NewGame');f.dismiss_help();f.tap('RunStory');f.tap('CreateRunCharacter')
                f.until(lambda s:s.get('scene')=='CharacterCreator','creator');f.shot('creator');f.tap('Start')
                f.until(lambda s:s.get('world')=='riverside_apartment','arrival');f.dismiss_help();f.shot('new_game')
            except Exception as error:
                result['capture_failure']=str(error)
                f.page.screenshot(path=str(f.out/'diagnostic_failure.jpg'),type='jpeg',quality=85)
            result['steps']=f.steps;result['console_errors']=list(f.errors)
            results.append(result)
            context.close()
    browser.close()
server.shutdown()
Path('evidence/2026-10-08_167/before/results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
