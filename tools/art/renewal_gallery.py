"""Build the local art review gallery; images remain separate original files."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/art_sources/renewal_20260929'
NAMES = {
 'menu':'河岸 · 城市主視覺', 'apartment':'第一個家與第一筆訂單', 'office':'第一間辦公室',
 'bank':'Nexus Bank · 銀行大廳', 'cafe':'Bloom Coffee · 河岸咖啡館', 'cowork':'Nexus · 共享辦公室',
 'tech_cafe':'Bean & Byte · 夜色與咖啡', 'city_hall':'Aurelia · 市政登記', 'arrival':'抵達 Aurelia',
 'train':'第一章 · 新的開始', 'warehouse':'第五章 · 大訂單', 'night_office':'第六章 · 現金是氧氣',
 'wardrobe':'暖木更衣室', 'financial':'金融區', 'startup':'新創園區', 'fresh_start':'重新出發',
 'skyline_day':'天際線 · 白天', 'skyline_dusk':'天際線 · 黃昏', 'skyline_night':'天際線 · 夜晚',
}
entries = json.loads((SOURCE / 'sources.json').read_text(encoding='utf-8'))
items = []
for entry in entries:
    ident = entry['id']
    category = 'characters' if entry['layout'] != 'scene' else ('skyline' if ident.startswith('skyline_') else 'scenes')
    items.append({'id':ident,'title':NAMES.get(ident, ident.title()),'src':ident+'.png','category':category})
shots = ['01_main_menu','02_creator','03_arrival','08_district_startup_hub_nexus_cowork','26_riverside_dusk','27_riverside_night']
for ident in shots:
    items.append({'id':ident,'title':'遊戲實拍 · '+ident,'src':'../../../evidence/2026-09-29_art_renewal/after/screenshots/'+ident+'.png','category':'game'})
for ident in ['portraits_1','portraits_2','chapter_1','chapter_2','chapter_3','chapter_4','chapter_5','chapter_6']:
    items.append({'id':ident,'title':'引擎檢視 · '+ident,'src':'../../../evidence/2026-09-29_art_renewal/review/'+ident+'.png','category':'game'})
template = '''<!doctype html>
<html lang="zh-Hant"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CITY VENTURE — 美術更新</title>
<style>
:root{color-scheme:dark;--bg:#0d1927;--paper:#e8eff4;--muted:#a7bdca;--line:#304a5e;--blue:#89bfe7}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--paper);font:16px/1.65 system-ui,'Microsoft JhengHei',sans-serif}button,input,select{font:inherit}button,a{touch-action:manipulation}a{color:var(--blue)}
header{padding:36px max(24px,5vw) 24px;border-bottom:1px solid var(--line)}.eyebrow{font-size:12px;letter-spacing:.23em;color:var(--blue)}h1{font-size:clamp(28px,4vw,52px);letter-spacing:-.04em;margin:8px 0}h2{font-size:25px;margin:0 0 8px}p{color:var(--muted);max-width:900px;margin:8px 0}.count{display:flex;gap:24px;flex-wrap:wrap;margin-top:22px}.count span{font-size:13px;color:var(--muted)}.count b{font-size:28px;color:var(--paper);padding-right:6px;font-weight:500}
main{padding:28px max(24px,5vw) 64px}.toolbar{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:30px 0 20px}button,select{background:#172c3e;border:1px solid #47647a;border-radius:6px;color:var(--paper);padding:8px 16px;cursor:pointer}button[aria-pressed=true]{background:#35638b;border-color:#99c5e7}button:focus-visible,select:focus-visible,a:focus-visible,input:focus-visible{outline:3px solid #f3c575;outline-offset:4px}.pixel{margin-left:auto;font-size:14px;color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}.tile{margin:0;background:#152536;border:1px solid var(--line);border-radius:9px;overflow:hidden}.tile button{display:block;width:100%;padding:0;border:0;border-radius:0;background:#111f30}.tile img{display:block;width:100%;aspect-ratio:16/10;object-fit:contain}.tile figcaption{padding:12px 16px}.tile small{color:var(--muted)}.pixels img{image-rendering:pixelated}
.compare{background:#122334;border:1px solid var(--line);padding:20px;border-radius:10px}.compare-top{display:flex;align-items:center;justify-content:space-between;gap:20px;flex-wrap:wrap;margin-bottom:16px}.comparison{position:relative;aspect-ratio:16/9;overflow:hidden;max-width:1120px;margin:auto}.comparison img{position:absolute;width:100%;height:100%;object-fit:contain}.comparison .after{clip-path:inset(0 0 0 50%)}.compare input{display:block;width:min(1120px,100%);margin:20px auto 0;accent-color:#91c4ed}.tags{display:flex;justify-content:space-between;max-width:1120px;margin:auto;color:var(--muted);font-size:13px}
dialog{padding:18px;border:1px solid #66849a;border-radius:12px;background:#0b1723;color:var(--paper);width:96vw;max-width:1700px;max-height:96vh}dialog::backdrop{background:#000b}dialog img{display:block;max-width:100%;max-height:78vh;margin:14px auto;object-fit:contain}.modal-head{display:flex;justify-content:space-between;align-items:center;gap:15px}footer{margin-top:35px;padding-top:24px;border-top:1px solid var(--line);color:var(--muted);font-size:14px}.note{margin:20px 0;font-size:14px}.status{color:#9cdbb3} @media(max-width:1050px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:600px){.grid{grid-template-columns:1fr}.pixel{margin-left:0}main{padding:20px 16px}header{padding:28px 20px}}
</style>
<header><div class="eyebrow">CITY VENTURE / ART DIRECTION / 2026.09.29</div><h1>在這座城市，開始你的故事。</h1><p>藍色玻璃、暖木與光。依七張參考板及遊戲 wiki 重新設計的城市、室內、角色表情與章節畫面。</p><div class="count"><span><b>31</b>張生成原畫</span><span><b>12</b>位角色 · 48 個表情</span><span><b>6</b>章故事插畫</span><span><b>44</b>張遊戲用圖（含 7 張 UI）</span></div></header>
<main><section class="compare"><div class="compare-top"><div><h2>直接看遊戲裡的變化</h2><p>拖動滑桿比較本次更新前後的引擎截圖。</p></div><label>比較場景 <select id="scene"><option value="01_main_menu">主選單</option><option value="02_creator">角色建立</option><option value="03_arrival">抵達城市</option><option value="08_district_startup_hub_nexus_cowork">新創園區</option><option value="26_riverside_dusk">河岸黃昏</option><option value="27_riverside_night">河岸夜晚</option></select></label></div><div class="comparison"><img id="before" alt="更新前遊戲截圖"><img id="after" class="after" alt="更新後遊戲截圖"></div><div class="tags"><span>更新前</span><span>更新後</span></div><input id="slider" type="range" min="0" max="100" value="50" aria-label="前後對照分界"></section>
<nav class="toolbar" aria-label="作品分類"><button data-filter="all" aria-pressed="true">全部</button><button data-filter="scenes" aria-pressed="false">城市與室內</button><button data-filter="characters" aria-pressed="false">角色表情</button><button data-filter="skyline" aria-pressed="false">日夜天際線</button><button data-filter="game" aria-pressed="false">遊戲實拍</button><label class="pixel"><input id="pixels" type="checkbox">以像素方式顯示</label></nav><p id="result" aria-live="polite"></p><div id="grid" class="grid"></div>
<footer><p class="status">已驗證：67/67 單元測試、28 張截圖巡禮零失敗、48 個角色表情與 6 張章節圖載入零失敗。</p><p>原畫與遊戲用圖分開保存。室內原畫已用於地點卡與章節插畫；可互動家具、立面零件、人物走路動畫及地圖仍沿用既有系統，不代表這些類別已全數重製。</p><a href="ART_DIRECTION.md">美術方向</a> · <a href="sources.json">來源與生成提示詞</a> · <a href="../../../evidence/2026-09-29_art_renewal/README.md">交付與驗證紀錄</a></footer></main>
<dialog id="lightbox"><div class="modal-head"><strong id="caption"></strong><button id="close">關閉 ×</button></div><img id="full" alt=""><a id="original" target="_blank" rel="noopener">開啟原圖</a></dialog>
<script>
const items=__ITEMS__;const grid=document.querySelector('#grid'),box=document.querySelector('#lightbox');
function render(filter='all'){grid.replaceChildren();const shown=items.filter(x=>filter==='all'||x.category===filter);document.querySelector('#result').textContent=shown.length+' 件作品';for(const item of shown){const card=document.createElement('figure');card.className='tile';const btn=document.createElement('button');btn.setAttribute('aria-label','放大：'+item.title);const img=document.createElement('img');img.src=item.src;img.alt=item.title;img.loading='lazy';btn.append(img);btn.onclick=()=>{document.querySelector('#caption').textContent=item.title;document.querySelector('#full').src=item.src;document.querySelector('#full').alt=item.title;document.querySelector('#original').href=item.src;box.showModal()};const label=document.createElement('figcaption');label.textContent=item.title;card.append(btn,label);grid.append(card)}}
document.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>{document.querySelectorAll('[data-filter]').forEach(x=>x.setAttribute('aria-pressed',x===b));render(b.dataset.filter)});
document.querySelector('#close').onclick=()=>box.close();document.querySelector('#pixels').onchange=e=>document.body.classList.toggle('pixels',e.target.checked);
function compare(){const id=document.querySelector('#scene').value;for(const side of ['before','after'])document.querySelector('#'+side).src='../../../evidence/2026-09-29_art_renewal/'+side+'/screenshots/'+id+'.png'}
document.querySelector('#scene').onchange=compare;document.querySelector('#slider').oninput=e=>document.querySelector('#after').style.clipPath='inset(0 0 0 '+e.target.value+'%)';compare();render();
</script></html>'''
template = template.replace('<main>', '<main><p><a href="../runtime_20260930/gallery.html">最新：實際遊戲人物與室內更新</a></p>', 1)
(SOURCE / 'gallery.html').write_text(template.replace('__ITEMS__',json.dumps(items,ensure_ascii=False)),encoding='utf-8')
print('Gallery:', SOURCE / 'gallery.html')
