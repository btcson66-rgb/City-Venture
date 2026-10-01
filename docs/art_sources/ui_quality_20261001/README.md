# UI 向量與解析度品質批 · 2026-10-01

43 個既有語意圖示延續城市藍、象牙白、成功綠、目標金及風險珊瑚紅，以可編輯 SVG 直接輸出 16×16 和 64×64。圖示語意、名稱、atlas 順序維持原 A7；sleep 改為床的圖形，圖檔不畫字母。沒有用 native 點陣放大充當高解析來源。

23 個面板／按鈕／頁籤／輸入框／進度條／手機和頭像外框使用同一套海軍藍表面、左上亮框及右下暗框；原尺寸、既有內容開口與 9-slice 使用介面不改。panel_glass 保持輕微透明。兩張既有 app icon 身分圖沒有改動。

共 66 SVG，另以43圖示拼合固定格位 atlas；67 native + 67 detail PNG/import。重建：python tools/art/ui_quality_vectors.py → node tools/art/render_ui_quality.cjs → Godot import → python tools/qa/ui_quality_check.py。工具只讀圖片的尺寸，不用 Pillow 畫圖；所有美術由 SVG 幾何構成。

實機：既有 renderer 讀新 native UI，按鈕、面板和圖示替換立即可見。4× 圖示可在固定 logical rect 中讀取，4× stylebox 則必須處理 physical texture margin 與 logical 邊框／內容尺寸，不可只替換貼圖。phone_frame 150×250、portrait_frame 72×72 的顯示矩形仍不變。高解析接線由 Claude 維持；本批不動程式、資料、測試或字型。

`icon_review.png` 是4×來源檢視；`evidence/20261001_ui_quality/actual_states/` 是真正 UIK StyleBox 的21狀態實機畫面。另有完整巡禮 before/after。QA 按 atlas 位置比 alpha 與 premultiplied RGB；合成時允許 1/255 四捨五入誤差，不把透明底色誤判為位置錯誤。
