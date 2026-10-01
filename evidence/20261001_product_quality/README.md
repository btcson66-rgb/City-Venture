# 商品、特效與應用圖示輸出 · 2026-10-01

基底9145015af512ba98bc7560162c0de61a5ec01d70，從Claude最新分支fetch/pull後獨立批次，無gameplay scripts/data/tests/autoload修改。

六個16×16商品重新製作透明原畫，依alpha裁切留邊後輸出native16×16及detail64×64：咖啡杯、檯燈、耳機、包裹、手機架、水瓶。每個商品各有獨立原圖與提示詞。
六個既有程序特效改以SVG直接輸出native與4×；保留光暈色彩/強度、陰影低透明度，以及sparkle16×16×4、水面16×8×4的格位和順序。
兩個應用圖示原尺寸識別未改；256圖的4×使用既有1024來源，1024圖的4096輸出需插值，不宣稱額外原生細節。
本批26個PNG輸出（12native替換+14detail），全部遊戲資產有匯入檔，尺寸未變。

## 證據
- before/screenshots、after/screenshots：相同53張正常遊戲巡禮；compare_*為巡禮前後實拍。
- actual_after：7街區各日/夜，14張實際場景；QA暫時關閉介紹卡以看清水面、車燈和陰影，不改場景資料。
- qa_product_placements.png：在實際公寓內由QA用既有add_prop臨時放六個商品，驗證渲染器載detail64×64且scale=.25；此為QA擺放，不能視為遊戲本來就放六個商品的證據。
- compare_product_sprites.png：原尺寸商品放大對照，僅素材檢視，非遊戲截圖。
- logs：import/tests/capture/shots與驗證。
- 原始圖和完整提示詞：docs/art_sources/product_quality_20261001/generated_manifest.json，使用內建生成工具。

## 驗收
- import exit0，無ERROR。
- 251/251 tests passed in 16.3s。
- shots：53截圖/63步/0失敗，English audit0，50.6s。
- capture：14實際日夜場景，六商品existing add_prop載64×64/.25縮放；無錯誤。
- product_quality_check：14素材契約的尺寸/alpha/動畫/匯入；app identity/gameplay unchanged。
- wiki_check通過，數目見logs/wiki.log。
- pose/map_label：未動角色或地圖N/A。
- 完整40–60分鐘繁中故事流程尚未執行；維持Draft。

## Claude接線
- 街道/室內商品props已沿既有add_prop讀detail並縮放，保留16×16位置；QA確認載入。商品目錄資料中的icon欄位不等於目前UI會畫icon，尚未驗證所有目錄的實際商品圖。
- 現有glow、shadow與sparkle多仍讀native。若改detail，Sprite2D保留原logical尺寸、四格frame尺寸與alpha強度，不可放大光罩、陰影或水面閃光四倍。
- 應用圖示保持目前系統圖示指向，detail是尺寸配對輸出，不需要替换project圖示設定。


全批圖檔盤點：`docs/art_sources/product_quality_20261001/pending_batch_coverage.md` 和 JSON 讀取12個Draft的實際美術差異，1869個原尺寸PNG均有正確尺寸4×對應（1869/1869）。這是檔案覆蓋，不是已合併或全遊戲實機品質PASS。詳列 #46角色與NPC動畫、#56正式配色/暫代測試，以及各類高解析logical尺寸接線和完整故事走查缺口。
