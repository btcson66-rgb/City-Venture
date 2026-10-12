from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    for args in [['--enable-gpu','--use-angle=d3d11'], ['--use-angle=swiftshader','--enable-unsafe-swiftshader']]:
        b=p.chromium.launch(headless=True,args=args)
        page=b.new_page()
        print(args, page.evaluate("() => {const gl=document.createElement('canvas').getContext('webgl2'); if(!gl)return null; const e=gl.getExtension('WEBGL_debug_renderer_info'); return [gl.getParameter(e.UNMASKED_VENDOR_WEBGL),gl.getParameter(e.UNMASKED_RENDERER_WEBGL)];}"), flush=True)
        b.close()
