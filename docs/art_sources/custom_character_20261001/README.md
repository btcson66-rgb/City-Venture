# 可自訂角色 · 2026-10-01

原問題：預設造型讀 `player_default` 全圖；只改膚色便切回低解析分層角色，輪廓、頭像與細節一起改變。

本批採同一個可編輯邏輯骨架。`vectors/` 為分層 SVG 原稿，`render_jobs.json` 列出每張圖的原尺寸；每張另交 4× 版本。高解析是由向量和原始材質直接渲染，未將原尺寸 PNG 放大冒充原畫。

`hair_material.png`、`clothing_material.png`、`head_material.png` 使用內建 imagegen 生成；`components/` 是無重繪的格子裁切與可染色灰階轉換，裁切位置記於 `component_manifest.json`。完整提示詞見 `prompts.md`。

重建：

```
python tools/art/pack_custom_materials.py
python tools/art/custom_character_vectors.py
node tools/art/render_custom_character.cjs
godot --headless --path game --import
python tools/art/document_custom_character.py
```

Node renderer 依賴 sharp；環境可用 `CITY_SHARP` 指定安裝位置。Pillow 與 numpy 用於 atlas 格子裁切、灰階染色準備與驗收，SVG 由 sharp 渲染。

專屬 NPC 原画未修改。商店的五套服裝維持既有 stand_in 設計；本批提升被引用的服裝層，沒有更改商品資料或定價。原尺寸、logical key、碰撞和存檔欄位未改；sprite_meta / buildings_meta / tiles atlas 不需要尺寸調整。
