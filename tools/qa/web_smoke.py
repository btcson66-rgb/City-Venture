"""Touch-only UI smoke on the actual build/web export, with isolated browser storage.

The opt-in cv_smoke probe only reads rendered controls/state. Playwright sends
browser touch events; it never invokes Godot methods or writes game state.
"""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import hashlib
from pathlib import Path
import threading
import time
from playwright.sync_api import sync_playwright

VIEWPORTS = {'portrait': (390, 844), 'landscape': (844, 390), 'tablet': (1024, 768)}


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


class Flow:
    def __init__(self, page, out):
        self.page, self.out = page, out
        out.mkdir(parents=True, exist_ok=True)
        self.steps, self.errors, self.touches = [], [], 0
        page.on('console', lambda m: self.errors.append(m.text) if m.type == 'error' else None)
        page.on('pageerror', lambda e: self.errors.append(str(e)))

    def state(self):
        return self.page.evaluate('window.cvSmoke') or {}

    def until(self, predicate, label, timeout=30):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            state = self.state()
            if predicate(state):
                return state
            if self.errors:
                raise AssertionError(self.errors)
            self.page.wait_for_timeout(150)
        raise AssertionError(f'Timeout: {label}')

    def controls(self, name=None, text=None):
        return [c for c in self.state().get('controls', [])
                if not c['disabled'] and (name is None or c['name'] == name)
                and (text is None or text in c['text'])]

    def point(self, x, y):
        state = self.state()
        a, d, tx, ty = state['transform']
        canvas = self.page.locator('#canvas')
        box = canvas.bounding_box()
        width, height = canvas.evaluate('(c)=>[c.width,c.height]')
        return (box['x'] + (x * a + tx) * box['width'] / width,
                box['y'] + (y * d + ty) * box['height'] / height)

    def touch(self, x, y):
        self.page.touchscreen.tap(*self.point(x, y))
        self.touches += 1
        self.page.wait_for_timeout(800)

    def ground_touch(self, x, y):
        # Walk via exposed ground, as a player would, rather than tap through
        # a fixed HUD button that happens to cover the projected doorway.
        state = self.state()
        width,height = state['viewport']
        if y < 130 and (x < 240 or x > width-240):
            y = min(height-70,180)
        for control in state.get('controls', []):
            bx,by,bw,bh = control['visible']
            if bw and bh and bx-6 <= x <= bx+bw+6 and by-6 <= y <= by+bh+6:
                x = max(80,bx-16)
        self.touch(x,y)

    def drag(self, rectangle, dx=0, dy=-140):
        x, y, width, height = rectangle
        start = self.point(x + width * .5, y + height * .65)
        finish = self.point(x + width * .5 + dx, y + height * .65 + dy)
        # CDP dispatches real multi-frame touch drags. WebKit has no CDP;
        # its drag path is supplied by the touch DOM event fallback.
        if self.page.context.browser.browser_type.name == 'chromium':
            session = self.page.context.new_cdp_session(self.page)
            session.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': [{'x': start[0], 'y': start[1]}]})
            for i in range(1, 9):
                session.send('Input.dispatchTouchEvent', {'type': 'touchMove', 'touchPoints': [{'x': start[0]+(finish[0]-start[0])*i/8, 'y': start[1]+(finish[1]-start[1])*i/8}]})
                self.page.wait_for_timeout(35)
            session.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
            session.detach()
        else:
            self.page.evaluate('''([a,b])=>{const canvas=document.querySelector('#canvas');
                function fire(type,p){const t=new Touch({identifier:1,target:canvas,clientX:p[0],clientY:p[1],pageX:p[0],pageY:p[1]});
                canvas.dispatchEvent(new TouchEvent(type,{bubbles:true,cancelable:true,touches:type==='touchend'?[]:[t],changedTouches:[t]}));}
                fire('touchstart',a); for(let i=1;i<=8;i++)fire('touchmove',[a[0]+(b[0]-a[0])*i/8,a[1]+(b[1]-a[1])*i/8]);fire('touchend',b);}''', [start, finish])
        self.page.wait_for_timeout(700)

    def tap(self, name=None, text=None):
        label = name or text
        self.until(lambda _: bool(self.controls(name, text)), label)
        for _ in range(18):
            candidates = self.controls(name, text)
            if not candidates:
                raise AssertionError(f'Control disappeared: {label}')
            self.page.wait_for_timeout(250)  # let deferred font/container layout settle
            control = self.controls(name, text)[-1]
            x, y, width, height = control['visible']
            if width >= min(control["rect"][2],44)*.95 and height >= min(control["rect"][3],44)*.95:
                self.touch(x + width / 2, y + height / 2)
                return
            scroll = control['scroll']
            viewport = self.state()['viewport']
            for ancestor in control.get('scrolls', []):
                if scroll[0]+scroll[2] > viewport[0] or scroll[1]+scroll[3] > viewport[1]:
                    scroll = ancestor
            scroll = [max(0,scroll[0]),max(0,scroll[1]),
                      min(scroll[2],viewport[0]-max(0,scroll[0])),
                      min(scroll[3],viewport[1]-max(0,scroll[1]))]
            if scroll[2] == 0:
                raise AssertionError(f'Unreachable control: {label}: {control}')
            rect = control['rect']
            horizontal = -140 if rect[0]+rect[2] > scroll[0]+scroll[2] else (140 if rect[0]+rect[2] < scroll[0] else 0)
            vertical = -min(140,scroll[3]*.45) if rect[1]+rect[3] > scroll[1]+scroll[3] else min(140,scroll[3]*.45)
            self.drag(scroll, horizontal, 0 if horizontal else vertical)
        raise AssertionError(f'Could not scroll to {label}')

    def shot(self, label):
        self.page.wait_for_timeout(250)
        state = self.state()
        assert not self.errors, self.errors
        self.page.screenshot(path=str(self.out/f'{len(self.steps)+1:02d}_{label}.jpg'), type='jpeg', quality=85)
        self.steps.append({'step': label, 'world': state.get('world'), 'modal': state.get('modal'),
                           'font_size': state.get('font_size'), 'touch': state.get('touch')})
        print(self.out.name, label, flush=True)

    def dismiss_help(self):
        for _ in range(4):
            if self.controls('CloseInfo'):
                self.tap('CloseInfo')
            elif self.state().get('modal') in ('InfoModal', 'TrafficModal') and self.controls('Close'):
                self.tap('Close')
            else:
                break

    def close_modal(self, expected):
        # A rendered touch can be lost while the Web layout settles. Verify
        # the transition before trying to walk behind the still-open window.
        for _ in range(3):
            if self.state().get('modal') != expected:
                return
            self.tap('Close')
            try:
                self.until(lambda state: state.get('modal') != expected,
                           f'close {expected}', timeout=3)
                return
            except AssertionError:
                if self.errors:
                    raise
        raise AssertionError(f'Touch close did not dismiss {expected}')

    def walk_action(self, action, building=None, timeout=90):
        end = time.monotonic()+timeout
        while time.monotonic() < end:
            self.dismiss_help()
            state = self.state()
            actions = [a for a in state.get('actions', []) if a['action'] == action
                       and (building is None or a['params'].get('building') == building)]
            assert actions, f'No {action} / {building} in {state.get("world")}'
            target = actions[0]
            buttons = self.controls('TouchInteract')
            if state.get('focus') == action and buttons:
                x,y,width,height = buttons[-1]['visible']
                self.touch(x+width/2,y+height/2)
                if self.state().get('modal') or not self.state().get('can_move',True):
                    return
                continue
            x, y = target['point']
            width, height = state['viewport']
            self.ground_touch(max(80,min(width-80,x)),max(100,min(height-20,y+10)))
            self.page.wait_for_timeout(800)
        raise AssertionError(f'Walking to {action} failed')

    def door(self, building=None, timeout=90):
        source=self.state()['world']
        approaching = building is not None
        end=time.monotonic()+timeout
        while time.monotonic()<end:
            self.dismiss_help()
            state=self.state()
            if state.get('world') != source: return
            doors=[d for d in state.get('doors',[]) if d['exit'] == (building is None)
                   and (building is None or d['building'] == building)]
            assert doors, f'No door {building} in {source}'
            x,y=doors[0]['point']; width,height=state['viewport']
            if building is not None:
                # An off-screen facade projects behind the fixed HUD. Approach
                # along visible ground before tapping the actual doorway.
                if y < 20 or x < 80 or x > width-80:
                    self.ground_touch(max(80,min(width-80,x)),max(min(180,height*.55),min(height-70,y+40)))
                    self.page.wait_for_timeout(900)
                    continue
                px,py = state['player']
                if approaching and abs(px-x)<12 and abs(py-(y+40))<12:
                    approaching = False
                target_y = y+40 if approaching else y-6
                if not approaching and abs(px-x)<16 and abs(py-y)<20:
                    approaching = True  # leave/re-enter the trigger after a side approach
            else:
                target_y = y
            self.ground_touch(max(80,min(width-80,x)),max(20,min(height-8,target_y)))
            self.page.wait_for_timeout(900)
        raise AssertionError(f'Walking through door {building} failed')

    def run(self, url, large, locale):
        self.page.goto(url, wait_until='domcontentloaded')
        self.until(lambda s: bool(s.get('controls')), 'Godot load', timeout=180)
        self.tap('Lang_'+locale)
        self.until(lambda s: s.get('locale') == locale, 'locale')
        self.dismiss_help()
        if large:
            self.tap('Settings'); self.dismiss_help(); self.tap('SettingsPage_1')
            self.tap('Setting_font_size')
            state=self.until(lambda s: bool(s['popups']), 'font popup')
            popup=state['popups'][-1]
            x,y,width,height=popup['rect']
            self.touch(x+width/2,y+height*3.5/len(popup['items']))
            self.until(lambda s: s.get('font_size') == 3, 'extra large font')
            self.tap('SettingsDone')
            self.shot('large_text_setting')
        self.shot('title')
        self.tap('NewGame'); self.dismiss_help()
        self.tap('RunStory')  # real standard sandbox choice; first-use work practice still runs
        self.tap('CreateRunCharacter')
        self.until(lambda s: s.get('scene') == 'CharacterCreator', 'creator')
        next_option=next(c['name'] for c in self.controls() if c['name'].startswith('Next_'))
        self.tap(next_option)
        self.shot('character_creator')
        self.tap('Start')
        self.until(lambda s: s.get('world') == 'riverside_apartment', 'new game arrival', timeout=30)
        self.dismiss_help()
        self.shot('new_game')
        self.door()
        self.until(lambda s: s.get('world') == 'riverside', 'leave home')
        self.door('bloom_coffee')
        self.until(lambda s: s.get('world') == 'bloom_coffee', 'cafe')
        self.walk_action('work_shift')
        self.dismiss_help(); self.tap('ApplyJob'); self.tap('WorkShift')
        self.until(lambda s: s.get('mini', {}).get('practice'), 'first job practice')
        cash=self.state()['cash']
        self.shot('first_job_practice')
        self.tap('StartGame')
        for _ in range(45):
            state=self.state(); mini=state.get('mini', {})
            if mini.get('phase') == 'practice_ready': break
            target=mini.get('target')
            if target: self.tap(target)
            else: self.page.wait_for_timeout(200)
        self.until(lambda s: s.get('mini', {}).get('phase') == 'practice_ready', 'practice complete')
        assert self.state()['cash'] == cash and self.state()['shifts'] == 0
        self.shot('practice_ready')
        self.tap('StartFormalWork')
        self.until(lambda s: s.get('mini', {}).get('phase') == 'play', 'formal work')
        for _ in range(6):
            self.tap('ConfirmOrder')
            want=self.state()['mini']['want']
            for field in ('Size','Drink','Milk','Shots'):
                for attempt in range(3):
                    self.tap(field+'_'+str(want[field.lower()]))
                    if self.state()['mini']['want']['got'][field.lower()] == want[field.lower()]:
                        break
                assert self.state()['mini']['want']['got'][field.lower()] == want[field.lower()]
            self.tap('Serve'); self.tap('Deliver_'+str(int(want['destination']))); self.tap('CleanTable')
        self.shot('first_job_results')
        self.tap('FinishGame')
        self.until(lambda s: s.get('shifts') == 1 and s.get('cash',0)>cash, 'actual payout')
        self.shot('first_job_paid')
        self.walk_action('open_company_os')
        self.dismiss_help()
        self.until(lambda s: s.get('modal') == 'CompanyOS', 'Company OS')
        self.shot('company_os')
        self.close_modal('CompanyOS')
        self.door()
        self.door('riverside_apartment')
        self.walk_action('sleep')
        self.dismiss_help(); self.tap('Sleep')
        self.until(lambda s: s.get('modal') == '', 'sleep completes', timeout=40)
        self.door()
        self.walk_action('metro')
        self.dismiss_help(); self.tap('Go_financial')
        self.until(lambda s: s.get('world') == 'financial', 'metro arrival', timeout=40)
        self.until(lambda s: s.get('bank_open'), 'bank opening in real game time', timeout=360)
        self.door('nexus_bank')
        self.walk_action('loans_info')
        self.dismiss_help(); self.tap('BookLoanAppointment'); self.dismiss_help()
        self.tap('Close')
        self.tap('HUD_phone'); self.tap('App_messages')
        self.shot('notifications')
        destination = next(c['name'] for c in self.controls() if c['name'].startswith('NotificationGo_'))
        self.tap(destination)
        self.dismiss_help()
        self.until(lambda s: s.get('modal') == 'CityMapModal', 'notification destination')
        self.shot('notification_go')
        self.tap('Close')
        self.tap('HUD_phone'); self.tap('App_save'); self.tap('SaveNow')
        saved = self.state()
        assert saved['balanced']
        self.shot('saved')
        self.page.wait_for_timeout(2500)  # allow the export's IndexedDB sync to finish
        self.page.reload(wait_until='domcontentloaded')
        self.until(lambda s: s.get('scene') == 'MainMenu', 'reloaded title', timeout=180)
        self.tap('Continue')
        loaded = self.until(lambda s: s.get('world') == saved['world'], 'load saved game', timeout=40)
        for key in ('name', 'cash', 'shifts', 'slot'):
            assert loaded[key] == saved[key], f'{key}: {loaded[key]} != {saved[key]}'
        assert loaded['balanced'] and loaded['font_size'] == saved['font_size']
        self.shot('reload_loaded')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export-dir', type=Path, default=Path('build/web'))
    parser.add_argument('--out', type=Path, default=Path('qa-output/web-smoke'))
    parser.add_argument('--viewports', nargs='+', choices=VIEWPORTS, default=list(VIEWPORTS))
    parser.add_argument('--locales', nargs='+', default=['zh_TW','en'])
    parser.add_argument('--sizes', nargs='+', choices=['default','large'], default=['default','large'])
    args=parser.parse_args()
    assert (args.export_dir/'index.pck').is_file(), 'Build the actual Web export first'
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(args.export_dir.resolve())))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    args.out.mkdir(parents=True,exist_ok=True)
    export_hash = hashlib.sha256((args.export_dir/'index.pck').read_bytes()).hexdigest()
    results=[]
    with sync_playwright() as pw:
        engines=[pw.chromium]
        webkit_available=Path(pw.webkit.executable_path).is_file()
        if webkit_available: engines.append(pw.webkit)
        for engine in engines:
            options={'headless':True}
            if engine.name=='chromium': options['args']=['--use-angle=swiftshader','--enable-unsafe-swiftshader']
            browser=engine.launch(**options)
            for viewport in args.viewports:
                for size in args.sizes:
                    for locale in args.locales:
                        width,height=VIEWPORTS[viewport]
                        name=f'{engine.name}-{viewport}-{size}-{locale}'
                        context=browser.new_context(viewport={'width':width,'height':height},device_scale_factor=1,is_mobile=True,has_touch=True)
                        flow=Flow(context.new_page(),args.out/name)
                        result={'name':name,'browser_version':browser.version,'viewport':[width,height],'size':size,'locale':locale,'status':'FAIL'}
                        try:
                            flow.run(f'http://127.0.0.1:{server.server_port}/index.html?cv_smoke=1',size=='large',locale)
                            result['status']='PASS'
                        except Exception as error:
                            result['failure']=str(error)
                            flow.page.screenshot(path=str(flow.out/'failure.jpg'),type='jpeg',quality=85)
                            (flow.out/'failure_state.json').write_text(json.dumps(flow.state(),ensure_ascii=False,indent=2),encoding='utf-8')
                        result.update(steps=flow.steps,console_errors=flow.errors,touches=flow.touches)
                        results.append(result)
                        (flow.out/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
                        context.close()
                        print(json.dumps(result,ensure_ascii=False),flush=True)
            browser.close()
        report={'export':str(args.export_dir.resolve()),'pck_sha256':export_hash,'webkit':'RUN' if webkit_available else 'NOT INSTALLED - Safari representative NOT VERIFIED','results':results}
        (args.out/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    server.shutdown()
    return int(any(r['status']!='PASS' or r['console_errors'] for r in results))


if __name__=='__main__':
    raise SystemExit(main())
