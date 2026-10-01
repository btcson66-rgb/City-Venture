# 背景與地點卡品質批 · 2026-10-01

基底：Claude 分支 9145015af512ba98bc7560162c0de61a5ec01d70，先 fetch/pull，獨立美術分支。未修改 gameplay scripts/data/tests/autoload。

上一輪已生成的19張原畫保留在 docs/art_sources/renewal_20260929。原本遊戲 PNG 在裁切時縮成192色，造成漸層和光影資訊損失。本批直接從原畫輸出13張背景與12張地點卡，取消192色壓縮，交付原尺寸和4×，共50PNG。保留同一套構圖、光源、角色與調色盤，不宣稱這25個場景是新畫的。

來源及雜湊、尺寸、4×插值比例見 docs/art_sources/backdrop_quality_20261001/manifest.json。地點卡的768×432輸出小於原畫1672×941，可直接保留更多來源細節。部分背景4×輸出比原畫大，需插值；這是完整色彩的來源重輸出，不代表憑空增加原畫像素細節。三張天際線5200×1280特別記錄比例2.394。未改 chapter7–12、港区或老城素材。

## 實拍證據
- before/screenshots / after/screenshots：相同53張遊戲巡禮。
- actual_before / actual_after：各18張原生選單、建角衣櫥、抵達背景、6個章節標題卡、重新出發卡、8個地點介紹卡，均繁體中文。
- compare_*.png：同一原生 UI 的改前/改後；不把原畫展示當實拍。
- source_review.png 仅素材總覽，在source目錄。
- 章節卡是呼叫現有UIRoot.show_chapter_card、地點卡是UIRoot.show_location_card，驗收圖片及文字排版；沒有冒充完成六章劇情走查。

## 驗收
- import exit0，無ERROR。
- 單元測試最後一行：251/251 tests passed in 16.4s。
- 實拍巡禮結果見 logs/after-shots.log：53張/63步/0失敗，English audit0。
- backdrop_quality_gallery：18種原生UI展示，繁中；前後無錯誤。
- backdrop_quality_check：25 source-linked full-color exports；尺寸、匯入、來源雜湊與不修改gameplay檢查通過。
- wiki_check通過，最終資產數見logs/wiki.log。
- pose/map_label：此批未動角色或地圖，N/A。
- 完整40–60分鐘繁中故事流程未執行；維持Draft。

## Claude 接線
native版本已自動改善完整色彩。大部分現有UI仍載native，4×載入由Claude線負責：
1. 章節卡已有640×360 logical viewport及EXPAND_IGNORE_SIZE，可在保持布局的前提下選detail。
2. Backdrop.make與天際線繪製使用texture physical dimensions，切detail時需保留原寬/高與平移範圍，避免4倍的pan裁切或背景比例。
3. CharacterCreator衣櫥維持200×250邏輯尺寸；地點卡維持192×108，需EXPAND_IGNORE_SIZE才不撐大UI。
4. 這批只改善現有圖片，沒有改建築家具或角色的遊戲設計。

