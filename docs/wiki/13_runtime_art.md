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

## B3 老城（2026-09-30）

原尺寸／4× 素材、發光層與 metadata 已交：詳見 `docs/art_sources/b3_20260930/manifest.json`。室內與 Okafor 由現有高解析渲染路徑自動讀入。建築外觀及地磚現有程式仍讀原尺寸；4× 資產已備妥，渲染接線待 Claude 線處理。咖啡機 `espresso_machine_pro` 沒有現有資料位置，尚待接線。改前／改後實機證據位於 `evidence/2026-09-30_b3_old_town/`。
## B2 港區美術 · 2026-09-30

美術：已交原尺寸、4×與匯入檔。港區玩法仍規劃中，渲染預覽不代表街區開放。立面與工作燈交 emission-only 光罩。NPC 為三方向四表情；走路與坐姿動畫未新增。貨車白色車身灰階可染色，輪胎、車窗、車燈留在 detail 層。

- `backdrops/skyline_harbor_day.png`
- `backdrops/skyline_harbor_night.png`
- `buildings/cold_store.png`
- `buildings/cold_store_lights.png`
- `buildings/container_stack.png`
- `buildings/container_stack_lights.png`
- `buildings/customs_house.png`
- `buildings/customs_house_lights.png`
- `buildings/dockside_motors.png`
- `buildings/dockside_motors_lights.png`
- `buildings/harbor_point_fitness.png`
- `buildings/harbor_point_fitness_lights.png`
- `buildings/pier7_warehouse.png`
- `buildings/pier7_warehouse_lights.png`
- `buildings/warehouse_shed.png`
- `buildings/warehouse_shed_lights.png`
- `cards/dockside_motors.png`
- `cards/harbor.png`
- `cards/pier7_warehouse.png`
- `characters/npc_ines.png`
- `characters/npc_rosa.png`
- `characters/npc_sam.png`
- `interiors/floor_harbor_concrete.png`
- `interiors/forklift_parked.png`
- `interiors/key_board.png`
- `interiors/loading_dock_door.png`
- `interiors/packing_bench_large.png`
- `interiors/pallet_rack.png`
- `interiors/sales_desk.png`
- `minigames/route_map.png`
- `portraits/npc_ines.png`
- `portraits/npc_rosa.png`
- `portraits/npc_sam.png`
- `props/container_blue.png`
- `props/container_green.png`
- `props/container_red.png`
- `props/crane_gantry.png`
- `props/crate.png`
- `props/forklift.png`
- `props/harbor_lamp.png`
- `props/harbor_lamp_lights.png`
- `props/life_ring.png`
- `props/mooring_bollard.png`
- `props/pallet_stack.png`
- `props/rope_coil.png`
- `tiles/quay_concrete.png`
- `tiles/quay_edge.png`
- `tiles/water_harbor.png`
- `vehicles/van_player_back_body.png`
- `vehicles/van_player_back_detail.png`
- `vehicles/van_player_front_body.png`
- `vehicles/van_player_front_detail.png`
- `vehicles/van_player_side_body.png`
- `vehicles/van_player_side_detail.png`
- `world_detail/backdrops/skyline_harbor_day.png`
- `world_detail/backdrops/skyline_harbor_night.png`
- `world_detail/buildings/cold_store.png`
- `world_detail/buildings/cold_store_lights.png`
- `world_detail/buildings/container_stack.png`
- `world_detail/buildings/container_stack_lights.png`
- `world_detail/buildings/customs_house.png`
- `world_detail/buildings/customs_house_lights.png`
- `world_detail/buildings/dockside_motors.png`
- `world_detail/buildings/dockside_motors_lights.png`
- `world_detail/buildings/harbor_point_fitness.png`
- `world_detail/buildings/harbor_point_fitness_lights.png`
- `world_detail/buildings/pier7_warehouse.png`
- `world_detail/buildings/pier7_warehouse_lights.png`
- `world_detail/buildings/warehouse_shed.png`
- `world_detail/buildings/warehouse_shed_lights.png`
- `world_detail/cards/dockside_motors.png`
- `world_detail/cards/harbor.png`
- `world_detail/cards/pier7_warehouse.png`
- `world_detail/characters/npc_ines.png`
- `world_detail/characters/npc_rosa.png`
- `world_detail/characters/npc_sam.png`
- `world_detail/interiors/floor_harbor_concrete.png`
- `world_detail/interiors/forklift_parked.png`
- `world_detail/interiors/key_board.png`
- `world_detail/interiors/loading_dock_door.png`
- `world_detail/interiors/packing_bench_large.png`
- `world_detail/interiors/pallet_rack.png`
- `world_detail/interiors/sales_desk.png`
- `world_detail/minigames/route_map.png`
- `world_detail/portraits/npc_ines.png`
- `world_detail/portraits/npc_rosa.png`
- `world_detail/portraits/npc_sam.png`
- `world_detail/props/container_blue.png`
- `world_detail/props/container_green.png`
- `world_detail/props/container_red.png`
- `world_detail/props/crane_gantry.png`
- `world_detail/props/crate.png`
- `world_detail/props/forklift.png`
- `world_detail/props/harbor_lamp.png`
- `world_detail/props/harbor_lamp_lights.png`
- `world_detail/props/life_ring.png`
- `world_detail/props/mooring_bollard.png`
- `world_detail/props/pallet_stack.png`
- `world_detail/props/rope_coil.png`
- `world_detail/tiles/atlas.png`
- `world_detail/tiles/quay_concrete.png`
- `world_detail/tiles/quay_edge.png`
- `world_detail/tiles/water_harbor.png`
- `world_detail/vehicles/van_player_back_body.png`
- `world_detail/vehicles/van_player_back_detail.png`
- `world_detail/vehicles/van_player_front_body.png`
- `world_detail/vehicles/van_player_front_detail.png`
- `world_detail/vehicles/van_player_side_body.png`
- `world_detail/vehicles/van_player_side_detail.png`
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

## Interior completion quality · 2026-10-01

美術：25 種室內物件及 8 種地板已交原尺寸、4× PNG 與 import。家具、窗景經既有 world_detail 入口自動載入；七種地板重複拼接原材質，修正配對尺寸而保留既有紋理比例。假人使用中性材質。

程式接線：六個招牌保留空白文字區，需 Claude 疊在地點招牌上；箱堆的獨立 Art.tex 入口仍使用原尺寸。新 server_rack_lights 提供機櫃指示燈。不是完整遊戲或所有室內的最終驗收。

- interiors/checkout_counter: game/assets/interiors/checkout_counter.png + game/assets/world_detail/interiors/checkout_counter.png
- interiors/clothing_rack: game/assets/interiors/clothing_rack.png + game/assets/world_detail/interiors/clothing_rack.png
- interiors/fitting_room: game/assets/interiors/fitting_room.png + game/assets/world_detail/interiors/fitting_room.png
- interiors/lockers: game/assets/interiors/lockers.png + game/assets/world_detail/interiors/lockers.png
- interiors/mannequin: game/assets/interiors/mannequin.png + game/assets/world_detail/interiors/mannequin.png
- interiors/mirror_full: game/assets/interiors/mirror_full.png + game/assets/world_detail/interiors/mirror_full.png
- interiors/queue_barrier: game/assets/interiors/queue_barrier.png + game/assets/world_detail/interiors/queue_barrier.png
- interiors/shoe_shelf: game/assets/interiors/shoe_shelf.png + game/assets/world_detail/interiors/shoe_shelf.png
- interiors/server_rack: game/assets/interiors/server_rack.png + game/assets/world_detail/interiors/server_rack.png
- interiors/server_rack_lights: game/assets/interiors/server_rack_lights.png + game/assets/world_detail/interiors/server_rack_lights.png
- interiors/armchair: game/assets/interiors/armchair.png + game/assets/world_detail/interiors/armchair.png
- interiors/box: game/assets/interiors/box.png + game/assets/world_detail/interiors/box.png
- interiors/cork_board: game/assets/interiors/cork_board.png + game/assets/world_detail/interiors/cork_board.png
- interiors/door_mat: game/assets/interiors/door_mat.png + game/assets/world_detail/interiors/door_mat.png
- interiors/framed_art: game/assets/interiors/framed_art.png + game/assets/world_detail/interiors/framed_art.png
- interiors/framed_art_b: game/assets/interiors/framed_art_b.png + game/assets/world_detail/interiors/framed_art_b.png
- interiors/stool: game/assets/interiors/stool.png + game/assets/world_detail/interiors/stool.png
- interiors/window_wide_day: game/assets/interiors/window_wide_day.png + game/assets/world_detail/interiors/window_wide_day.png
- interiors/window_wide_night: game/assets/interiors/window_wide_night.png + game/assets/world_detail/interiors/window_wide_night.png
- interiors/logo_bloom: game/assets/interiors/logo_bloom.png + game/assets/world_detail/interiors/logo_bloom.png
- interiors/logo_bytebean: game/assets/interiors/logo_bytebean.png + game/assets/world_detail/interiors/logo_bytebean.png
- interiors/logo_city_hall: game/assets/interiors/logo_city_hall.png + game/assets/world_detail/interiors/logo_city_hall.png
- interiors/logo_cowork: game/assets/interiors/logo_cowork.png + game/assets/world_detail/interiors/logo_cowork.png
- interiors/logo_nexus_bank: game/assets/interiors/logo_nexus_bank.png + game/assets/world_detail/interiors/logo_nexus_bank.png
- interiors/logo_postpoint: game/assets/interiors/logo_postpoint.png + game/assets/world_detail/interiors/logo_postpoint.png
- interiors/seal: game/assets/interiors/seal.png + game/assets/world_detail/interiors/seal.png
- interiors/floor_carpet_navy: game/assets/interiors/floor_carpet_navy.png + game/assets/world_detail/interiors/floor_carpet_navy.png
- interiors/floor_concrete: game/assets/interiors/floor_concrete.png + game/assets/world_detail/interiors/floor_concrete.png
- interiors/floor_marble: game/assets/interiors/floor_marble.png + game/assets/world_detail/interiors/floor_marble.png
- interiors/floor_tile_white: game/assets/interiors/floor_tile_white.png + game/assets/world_detail/interiors/floor_tile_white.png
- interiors/floor_wood_cafe: game/assets/interiors/floor_wood_cafe.png + game/assets/world_detail/interiors/floor_wood_cafe.png
- interiors/floor_wood_dark: game/assets/interiors/floor_wood_dark.png + game/assets/world_detail/interiors/floor_wood_dark.png
- interiors/floor_wood_warm: game/assets/interiors/floor_wood_warm.png + game/assets/world_detail/interiors/floor_wood_warm.png
- interiors/floor_checker: game/assets/interiors/floor_checker.png + game/assets/world_detail/interiors/floor_checker.png
