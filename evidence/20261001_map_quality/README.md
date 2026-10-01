# 地圖品質批 · 2026-10-01

基底：Claude 分支 9145015af512ba98bc7560162c0de61a5ec01d70；獨立美術批，沒有修改 gameplay scripts/data/tests/autoload。

25 個素材各交原尺寸和 4×（50 PNG）：城市主圖、13 區域預覽、捷運底圖、世界主圖、8 區域預覽，以及目前沒有 runtime call site 的 world_map/world_map 備用背景。原圖尺寸、城市/世界點位與點擊座標保持不變。捷運底圖由 SVG 直接輸出兩種解析度；其他預覽各有獨立原始圖。主圖依既有位置重新生成，移除烘焙文字和空標籤底板。

## 證據
- before/screenshots 與 after/screenshots：相同 53 張實際遊戲巡禮。
- compare_city_map.png、compare_world_map.png：左為改前，右為改後，實際遊戲截圖。
- actual_maps/：英文原生 UI 選取驗收。
- actual_maps_zhTW/：繁體中文原生 UI 選取驗收，12 個城市街區、8 個世界區域、捷運；20 次真實 label button pressed signal 均核對選區狀態。未改座標，未製作假的標籤展示圖。
- city_map_review.png / world_map_review.png 在 source 目錄：素材檢視表，與遊戲實拍分開。
- logs/：命令輸出。

## 驗收
- Godot --headless --path game --import：exit 0，無 ERROR。
- Godot test_runner：251/251 tests passed in 15.5s
- --bot=shots：53 截圖 / 63 步驟，0 failures；50.7s，English audit 0。
- map_quality_gallery：20 actual label-button selections；英文與繁中均無錯誤。
- map_quality_check：25 native + 25 detail PNGs/imports；尺寸、opaque alpha、gameplay contract unchanged。
- map_label_check：OK。
- wiki_check：OK（最終數目見 logs/wiki.log）。
- pose_check：未動角色，N/A。
- 40–60 分鐘完整繁中劇情走查未執行；維持 Draft。

## Claude 接線
現有模態使用原尺寸，所以實拍已顯示新版美術，但仍是 logical resolution。4× 若要自動載入，須保留板458×305 / 600×255、city preview144×90 / world64×40的 UI 邏輯尺寸，TextureRect 設 EXPAND_IGNORE_SIZE 和適當 stretch，保持標籤/點擊轉換使用原座標。城市與世界主圖現在沒有 baked label panel；程式覆蓋仍正常。捷運原本已有固定220×124 viewport，路線和 station 點位勿乘4。world_map/world_map 和 city_map/i_metro 沒有目前 modal 的直接載入路徑，本批只交素材，不宣稱已開放新玩法。海外仍為 P2 規劃，狀態不變。

