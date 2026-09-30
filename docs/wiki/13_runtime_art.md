# 實際遊戲美術更新 · 2026-09-30

高解析素材透過 world_detail 接入現有場景；位置、碰撞及互動仍採原邏輯座標。

目前覆蓋：八個室內的主要家具與材質、預設主角走路、12 位具名 NPC 的三方向四表情、5 位排程坐姿、6 位室內顧客及 13 組對話頭像。

範圍限制：自訂主角造型、換裝、街道行人、僱員及建築外觀仍有原素材。坐姿目前為靜態姿勢，未提供四種坐姿表情；不代表全遊戲美術已完成。

來源與完整提示詞：../art_sources/runtime_20260930/sources.json；打包：tools/art/runtime_pack.py。

## 已接入素材

- world_detail/characters/npc_ana.png — (512, 576)
- world_detail/characters/npc_daniel.png — (512, 576)
- world_detail/characters/npc_daniel_sit.png — (512, 576)
- world_detail/characters/npc_dara.png — (512, 576)
- world_detail/characters/npc_elena.png — (512, 576)
- world_detail/characters/npc_elena_sit.png — (512, 576)
- world_detail/characters/npc_guest_0.png — (512, 576)
- world_detail/characters/npc_guest_0_sit.png — (512, 576)
- world_detail/characters/npc_guest_1.png — (512, 576)
- world_detail/characters/npc_guest_1_sit.png — (512, 576)
- world_detail/characters/npc_guest_2.png — (512, 576)
- world_detail/characters/npc_guest_2_sit.png — (512, 576)
- world_detail/characters/npc_guest_3.png — (512, 576)
- world_detail/characters/npc_guest_3_sit.png — (512, 576)
- world_detail/characters/npc_guest_4.png — (512, 576)
- world_detail/characters/npc_guest_4_sit.png — (512, 576)
- world_detail/characters/npc_guest_5.png — (512, 576)
- world_detail/characters/npc_guest_5_sit.png — (512, 576)
- world_detail/characters/npc_jun.png — (512, 576)
- world_detail/characters/npc_ken.png — (512, 576)
- world_detail/characters/npc_ken_sit.png — (512, 576)
- world_detail/characters/npc_lee.png — (512, 576)
- world_detail/characters/npc_marcus.png — (512, 576)
- world_detail/characters/npc_marcus_sit.png — (512, 576)
- world_detail/characters/npc_maya.png — (512, 576)
- world_detail/characters/npc_maya_sit.png — (512, 576)
- world_detail/characters/npc_priya.png — (512, 576)
- world_detail/characters/npc_sofia.png — (512, 576)
- world_detail/characters/npc_tom.png — (512, 576)
- world_detail/characters/player_default.png — (512, 576)
- world_detail/interiors/atm.png — (104, 168)
- world_detail/interiors/bank_counter.png — (576, 176)
- world_detail/interiors/bed.png — (208, 232)
- world_detail/interiors/bench_civic.png — (192, 80)
- world_detail/interiors/bookshelf.png — (136, 208)
- world_detail/interiors/brochure.png — (64, 120)
- world_detail/interiors/brochure_stand.png — (72, 120)
- world_detail/interiors/cafe_chair.png — (56, 88)
- world_detail/interiors/cafe_counter.png — (400, 176)
- world_detail/interiors/cafe_table.png — (104, 96)
- world_detail/interiors/chair.png — (88, 108)
- world_detail/interiors/civic_counter.png — (576, 176)
- world_detail/interiors/coffee_table.png — (136, 132)
- world_detail/interiors/community_table.png — (264, 176)
- world_detail/interiors/desk.png — (176, 148)
- world_detail/interiors/desk_laptop.png — (192, 164)
- world_detail/interiors/display_case.png — (168, 144)
- world_detail/interiors/exec_desk.png — (264, 172)
- world_detail/interiors/filing_cabinet.png — (80, 144)
- world_detail/interiors/floor_carpet_navy.png — (768, 768)
- world_detail/interiors/floor_concrete.png — (768, 768)
- world_detail/interiors/floor_marble.png — (768, 768)
- world_detail/interiors/floor_tile_white.png — (768, 768)
- world_detail/interiors/floor_wood_cafe.png — (768, 768)
- world_detail/interiors/floor_wood_dark.png — (768, 768)
- world_detail/interiors/floor_wood_warm.png — (768, 768)
- world_detail/interiors/fridge.png — (96, 184)
- world_detail/interiors/glass_wall.png — (272, 208)
- world_detail/interiors/hanging_light.png — (64, 120)
- world_detail/interiors/info_kiosk.png — (88, 144)
- world_detail/interiors/kitchen.png — (264, 184)
- world_detail/interiors/lounge_sofa.png — (232, 168)
- world_detail/interiors/menu_board.png — (264, 136)
- world_detail/interiors/monitor_desk.png — (264, 144)
- world_detail/interiors/office_chair.png — (72, 108)
- world_detail/interiors/packing_table.png — (192, 136)
- world_detail/interiors/parcel_shelf.png — (200, 184)
- world_detail/interiors/phone_booth.png — (112, 192)
- world_detail/interiors/plant.png — (72, 120)
- world_detail/interiors/plant_bank.png — (120, 176)
- world_detail/interiors/plant_big.png — (128, 176)
- world_detail/interiors/postpoint_counter.png — (320, 176)
- world_detail/interiors/printer.png — (104, 112)
- world_detail/interiors/rug.png — (256, 160)
- world_detail/interiors/rug_navy.png — (256, 160)
- world_detail/interiors/rug_small.png — (160, 96)
- world_detail/interiors/sconce.png — (40, 48)
- world_detail/interiors/sofa.png — (208, 136)
- world_detail/interiors/ticket_machine.png — (80, 144)
- world_detail/interiors/tv.png — (192, 160)
- world_detail/interiors/waiting_sofa.png — (208, 120)
- world_detail/interiors/wall_plaster.png — (512, 512)
- world_detail/interiors/wardrobe.png — (136, 216)
- world_detail/interiors/water_cooler.png — (56, 136)
- world_detail/interiors/whiteboard.png — (264, 172)
- world_detail/interiors/window_day.png — (208, 168)
- world_detail/interiors/window_night.png — (208, 168)
- world_detail/portraits/npc_ana.png — (1024, 256)
- world_detail/portraits/npc_daniel.png — (1024, 256)
- world_detail/portraits/npc_dara.png — (1024, 256)
- world_detail/portraits/npc_elena.png — (1024, 256)
- world_detail/portraits/npc_jun.png — (1024, 256)
- world_detail/portraits/npc_ken.png — (1024, 256)
- world_detail/portraits/npc_lee.png — (1024, 256)
- world_detail/portraits/npc_marcus.png — (1024, 256)
- world_detail/portraits/npc_maya.png — (1024, 256)
- world_detail/portraits/npc_priya.png — (1024, 256)
- world_detail/portraits/npc_sofia.png — (1024, 256)
- world_detail/portraits/npc_tom.png — (1024, 256)
- world_detail/portraits/player_default.png — (1024, 256)

## C10 素材 · 2026-09-30

美術：已交，尺寸依工單，附匯入檔。UI 章節卡與 DecisionModal 的實際載圖已驗收；章節與事件劇情仍待 Claude 線資料接入。現有 UI 使用原尺寸，4× 圖可供未來清晰顯示。

- `backdrops/chapter_10.png`
- `world_detail/backdrops/chapter_10.png`
- `backdrops/chapter_11.png`
- `world_detail/backdrops/chapter_11.png`
- `backdrops/chapter_12.png`
- `world_detail/backdrops/chapter_12.png`
- `events/rail_frozen.png`
- `world_detail/events/rail_frozen.png`
- `events/acquisition_offer.png`
- `world_detail/events/acquisition_offer.png`
