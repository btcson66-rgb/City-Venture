# CITY VENTURE — Game Data Schema

### Economy balance overlays

`economy/balance.json` has `definitions: {products: {id: {numeric_field: value}}}`. DataDB applies these values after
loading the original definitions. Only existing numeric fields may be replaced; unknown ids or nonnumeric fields
produce an error. Saved inventory cost, orders, contracts, cash and ledger entries are never rewritten by an overlay.
`baseline_shipping_costs` stores the pre-tuning economy/express cost table for the headless `--baseline` experiment only.
The production simulation reads the current shipping table. New industry definitions are unaffected unless a designer
explicitly adds their numeric fields to a later overlay.

All content lives in `game/data/` as JSON, loaded by `DataDB` at boot.

Art keys keep their existing logical pixel contract (`#62`): a matching `assets/world_detail/<key>.png`
overrides the rendered image through `Art`, while native dimensions, sprite metadata, atlas coordinates,
map positions and collision alpha masks remain authoritative. No saved fields or format versions change.
Conventions:
- `id` is a `snake_case` string, unique within its folder.
- Money is a float in the entity's currency (Aurelia Dollar, `AUD$`, displayed as `$`).
- Time durations are in **game minutes** (`*_min`) or **days** (`*_days`).
- `status` on definitions: `active` (playable) or `planned` (retained data, hidden from player lists).
- Text shown to players lives in `text`/`lines` fields so it can be localised later.

`DataDB.validate()` checks everything marked **(ref)**.

---

## 1. Definitions (static content)

### 1.1 Businesses — `data/businesses/<id>.json`
```json
{
  "id": "ecommerce", "name": "Ecommerce", "status": "active", "module": "ecommerce",
  "tier": "p0", "pitch": "Buy wholesale, sell online. Inventory is cash sitting in boxes.",
  "starting_capital_min": 1500,
  "revenue_models": ["product_sales"],
  "cost_types": ["inventory", "ads", "shipping", "returns", "platform_fees"],
  "growth_paths": ["own_brand", "retail", "international"],
  "unlock": {"requires": []}
}
```

### 1.2 Products — `data/products/<id>.json`
```json
{
  "id": "wireless_earbuds", "name": "Wireless Earbuds", "category": "electronics",
  "ref_price": 42.0, "price_min": 20.0, "price_max": 80.0,
  "base_daily_demand": 2.4, "elasticity": 1.6,
  "return_base_rate": 0.06, "review_rate": 0.45,
  "ship_class": "small", "packaging_cost": 0.60,
  "sprite": "props/product_earbuds"
}
```

### 1.3 Suppliers — `data/suppliers/<id>.json`
```json
{
  "id": "tradelink_wholesale", "name": "TradeLink Wholesale", "region": "aurelia", "contact_npc": "ken_supplier",
  "offers": [
    {"product": "wireless_earbuds", "unit_cost": 18.0, "moq": 50, "lead_days": 3,
     "defect_rate": 0.05, "payment_terms": "prepay"}
  ],
  "net_terms_for_companies": {"days": 15, "requires": ["company_registered"]}
}
```
`product` (ref → products).

Optional supplier `returns` overrides: `cancel_window_hours`, `cancel_fee_rate`, `return_window_days`,
`restocking_fee_rate`. Defaults come from `data/economy/returns.json`: 24 hours, 5%, 14 days, 15%,
`return_ship_per_unit` 0.60 (times `World.shipping_index()`), `return_days` 3. Imports default to a 0-day
delivered-goods return window; an explicit supplier override takes precedence. Aurelia Makers waives both fees.
Windows are exclusive: elapsed time must be less than the configured window.

### 1.4 Marketplaces / Shipping — `data/economy/*.json`
```json
// marketplace.json
{"id":"shoplane","name":"ShopLane","fee_rate":0.10,"payout_weekday":1,"payout_hour":9,
 "payout_hold_days":2,"personal_seller_cap":2500,"return_window_days":7,
 "hourly_weights":[...24 floats...]}
// shipping.json
{"methods":[{"id":"economy","name":"Economy","cost":{"small":4.2,"medium":6.8},"transit_days":3},
            {"id":"express","name":"Express","cost":{"small":8.9,"medium":12.5},"transit_days":1}],
 "pickup":{"courier_fee_per_batch":6.0,"pickup_delay_min":120},
 "dropoff":{"location":"postpoint_riverside"}}
// living.json
{"start_cash":30000,"home_rent":1250,"rent_first_due_day":14,"daily_living":32,"reduced_daily_living":18,
 "overdraft_fee":35,"late_rent_fee":75,"low_cash_warning":1500}
```

### 1.5 Settlement methods — `data/economy/settlement_methods.json`
`{id, name, speed_days, fee_rate, fixed_fee, risks{technical, counterparty, regulatory}, available_from{year, flag}}`
The slice ships only `bank_transfer` and `marketplace_payout`. `stablecoin_*` rails are **Planned (P2)** and gated on `flag:clearing_crisis_started`.

### 1.6 Companies (NPC) — `data/companies/<id>.json`
```json
{"id":"harbor_point_fitness","name":"Harbor Point Fitness","kind":"npc","industry":"fitness",
 "negotiation":{"min_price_factor":0.9,"max_terms_days":45,"patience":2}}
```
The player's company is created at runtime as entity `co_<slug>` with the same shape plus `founded`, `type`, `address`.

### 1.7 NPCs — `data/npcs/<id>.json`
```json
{
  "id": "maya", "name": "Maya", "role": "friend",
  "appearance": {"presentation":"feminine","face":"oval","hair":"bob","hair_color":"#3b2a24", "...": "..."},
  "outfit": "startup_casual",
  "outfit_tints": {"top":"#c8843e","bottom":"#3a3c48"},
  "schedule": [
    {"days":"sat,sun","from":"10:00","to":"16:00","location":"interior:bloom_coffee","spot":"table_2","pose":"sit"}
  ],
  "dialogue": [{"when":["flag:ch1_started"],"conversation":"maya_cafe_weekend"}],
  "phone_contact": true
}
```
`location` is `interior:<building_id>` or `district:<district_id>`, and `spot` is a named marker in that layout.
`pose` (optional, default `idle`) is one of `CharacterRig.POSES` and only shows once the pose art exists.
`if` (optional) is a condition string (`scripts/sim/cond.gd`). The NPC only keeps that slot while it holds, e.g. Daniel
minds the Crestline floor on weekends only once `flag:big_contract_offered` is set.
`outfit_tints` multiply the tintable fabric layers.
A `dialogue` entry may carry `action`, a follow-up that opens once the conversation ends (`scripts/world/actions.gd`
`_talk`): `coffee`, `register_company`, `bank_counter`, `lease_office`, `lease_cafe` (Mr. Okafor: opens the corner café
lease), `loan_office`, `dropoff_parcels`, `clothing_shop`. Entries are tried in order and the first whose `when` holds wins.
Contacts without an `appearance` (`"phone_only": true`) may set `"logo": "<id>"`. Their avatar then uses
`assets/logos/<id>.png` when that file exists, and a UI icon otherwise.

### 1.8 Buildings — `data/buildings/<id>.json`
```json
{
  "id": "bloom_coffee", "name": "Bloom Coffee", "district": "riverside", "type": "cafe", "category": "Cafe",
  "hours": {"open":"07:00","close":"20:00","days":"all"},
  "exterior": {"sprite":"buildings/mixed_use_bloom","x":512,"y":160,"door":{"x":64,"y":142},"sign":"Bloom Coffee"},
  "interior": {
    "size":[26,16], "floor":"wood_warm", "wall":"cafe_brick", "window_view":"riverside",
    "spawns":{"door":[208,236]},
    "props":[{"sprite":"interiors/cafe_counter","x":40,"y":64,"solid":[0,20,96,20]}],
    "interactables":[
      {"id":"order_coffee","at":[80,110],"label":"Order Coffee","action":"buy_item","params":{"item":"coffee","price":4.5,"minutes":10}},
      {"id":"news_board","at":[300,90],"label":"Read News","action":"read_news"}
    ],
    "npc_spots":{"counter":[88,72],"table_2":[260,160]}
  }
}
```
`action` values form a closed vocabulary implemented by `scripts/world/actions.gd`: `open_company_os`, `sleep`, `change_outfit`, `clothing_shop`, `buy_item`, `look`, `read_news`, `business_board`, `pack_orders`, `dropoff_parcels`, `register_company`, `bank_counter`, `atm`, `lease_office`, `lease_property`, `rent_desk`, `talk`, `metro`, `exit`, `cafe_counter` (work your own café's counter: the barista minigame, then `Cafe.owner_shift`).

- `lease_property` opens `LeaseModal` for `params.property` (Pier 7's lettings desk). `params.unless_lease: <property>` hides an interactable once that lease is held; `params.requires: "lease:<property>"` locks one until it is (the packing bench and yard desk at Pier 7).
- `pack_orders` takes `params.location` (a stock location: a property id). `open_company_os` takes `params.terminal` (`pier7` is the yard office desk).
- A `talk` NPC dialogue entry may carry `action`: `lease_cafe`, `lease_office`, `buy_van` (opens `VanDealModal`), `dropoff_parcels`, ... run after the conversation.
- Building keys beyond the above: `closed_reason` (text): the door never opens and the toast says why (`SceneRouter.building_open`); the Customs House has one, and still needs an `interior` so tools can load it. Interior `stock_display {location, x, y, cols, per_box?, max?}` draws stacks of boxes for the units at that location (one box per `per_box` units, default 10, at most `max`, default 20). Interior `staff_spots {role: [[x,y], ...]}` places employees of that role while the lease named by `interior.property` is held.

- `buy_item` with `item: "coffee"` is the café flow. Any other `item` is a meal or purchase: `{item, name, price, minutes, category, flag?}`, paid from personal cash into `exp:<category>` (`dining` for Lantern Bistro).
- `clothing_shop` opens the store's rails (`ClothingShopModal`) for the building it sits in. `{npc, first?}`: needs the clerk present, and plays the `first` conversation until `met_<npc>` is set.
- `look` shows a line of text: `{text, icon?, alt: [{if, text}]}`. The first `alt` whose condition holds wins.
- Interactable `params` that lock or hide a spot: `requires` (`desk_access` or `lease:<property_id>`; the spot stays but
  reads as locked until you hold that pass or lease, e.g. the café till needs `lease:corner_cafe`) and `unless_lease`
  (`<property_id>`; the spot is not placed at all once that lease is yours: the TO LET notice in the café window).

Building keys added with Old Town:

- `exterior.fallback`: a facade id (a key of `assets/buildings/buildings_meta.json`) drawn while `exterior.sprite` has no
  art yet. The stand-in's own metadata (size, door, sign board) is used, so a fallback with no `sign` region shows no sign
  text. Once `buildings/<sprite>.png` exists the real facade takes over; re-run `python3 tools/gen_districts.py <district>`
  so the block is laid out from the real widths. `DataDB.validate()` accepts a building whose `sprite` is unknown as long as
  its `fallback` is known.
- `hours.always_if_lease`: a property id. Once that lease is yours the building is open around the clock (Suite 2B and the
  café unit); `hours` applies until then.
- `interior.property`: the lease this interior belongs to. Staff of a role whose `workplace` is that property show up here
  (`interior.refresh_named_npcs`).
- `interior.staff_spots`: `{role: [[x, y], ...]}` places working staff by role (`barista`: behind the counter). A role with
  no entry sits at the `desk` spots.
- New `type` values: `own_cafe` (the player's café: ambient customers follow `Cafe.expected_demand` while open),
  `lettings`, `flat_to_let` (the last two only pick a minimap icon).

`type` sets the minimap icon and how many ambient customers sit down: `cafe` 3, `restaurant` 4, `retail` 2 (on its sofas and benches), `coworking` 5, `bank` 2, `civic` 3, `parcel` 1.

`category` is a translated, player-facing building type (Restaurant, Clothing store, Bank, Office, Warehouse, etc.).
Doors and City Guide read it directly; adding a building requires its data and translation, not a UI list edit.
`BuildingInfo` derives activities from enabled interior interactables except `look`, and from actual present NPC
interactables in the live room. A room with no such activity explicitly says it is sightseeing-only. Guide tags
come from action kinds; station instructions come from the district's `metro` data. District status comes from
`data/districts/<id>.json` when supplied, otherwise the city district definition. Inactive districts have no guide
destinations or labels; active buildings are discovered by their `district`. Optional building `status` defaults to
`active`; `enterable` defaults to `true`. `planned` or explicit `enterable:false` retains the facade and interior data
but removes public entry and guide navigation. Changing only `status` to `active` enables completed future content.
An otherwise active room needs an unlocked non-look interactable or an NPC whose real schedule/condition matches
now. NPC-only rooms and unleased café premises have no public prompt until something can be done there. Existing
triggers for active buildings recheck this each frame, so NPC arrival restores entry without scene reload.
Loading an old save inside a hidden room returns to `district:building.district`, spawn `door_<building_id>`;
all saved finance, inventory, contracts and leases remain unchanged. Facades keep this street spawn even as scenery.
Inactive districts are plain map blocks with no labels/stations and are absent from guide lists.

Save data adds `building_visits: {building_id: count}` lazily on entry; the first two entries show a dismissible
four-second room introduction. Missing counts in older saves start at zero and existing `visited` flags are preserved.
`user://settings.cfg` stores `[general] interaction_markers` (boolean, default true), independent of saves.
`interior.interactables[].enabled` defaults to true. Marker offsets only affect drawing, never action coordinates.
All data actions must map to an existing icon in `BuildingInfo.ACTION_ICONS`; the unit test fails on unknown actions.
Phone destinations temporarily override the existing Tutorial resolver/arrow until the target interior is reached.

Prop keys (districts and interiors): `sprite`, `x`, `y` (top-left of the design footprint), `solid` (`false` or `[x,y,w,h]`), `wall`, `floor`, `glow`, `night`, `label`, `interact`, plus:

- `if`: a condition. The prop is only placed while it holds (the LED lamps on Crestline's display after `flag:big_contract_delivered`).
- `show`: `{days, from, to}`. Out only in that window, hidden and walk-through otherwise (weekend market stalls).
- `overhead`: drawn above people, no collision (string lights).
- `tint`: `#rrggbb` dye for a greyscale prop (Threadline's mannequins).
- `fallback`: the sprite to draw while `sprite` has no art yet. Data can name furniture that is still being drawn
  (Crestline's `retail_shelf`, Lantern Bistro's `dining_table`) and it swaps in when the file lands.
- `unless_art`: a texture key. The prop is skipped once that texture exists (the loose lamps on Crestline's stand-in
  display, which `lamp_display_stocked` draws itself).
- A `<sprite>_lights.png` next to the prop's image glows at night like building windows.

### 1.9 Districts — `data/districts/<id>.json`
```json
{
  "id":"riverside","name":"Riverside","size_tiles":[112,60],
  "ground":[{"type":"grass","rect":[0,0,112,60]},{"type":"road_h","rect":[0,30,112,4]}],
  "buildings":["riverside_apartment","bloom_coffee","postpoint_riverside"],
  "props":[{"sprite":"props/tree_round","x":300,"y":400}],
  "exits":[{"id":"to_startup_hub","rect":[1784,480,8,64],"to":"district:startup_hub","spawn":"from_riverside","walk_min":12}],
  "spawns":{"arrival":[640,520],"from_startup_hub":[1760,510]},
  "traffic":[{"lane":"h","y":492,"dir":1,"density":0.5}],
  "pedestrian_paths":[[[40,470],[1760,470]]],
  "metro":{"station":"riverside","at":[900,450]},
  "ambient_density":{"morning":8,"afternoon":10,"evening":9,"night":3},
  "ped_outfits":["luxury_citywear","casual_jacket","casual_tee"]
}
```
`fallback` (optional) on a `ground` entry or a `fillers` entry names what to draw while the real tile or facade is still
being drawn: a ground entry `{"type": "cobble_a", "fallback": "plaza", "rect": [...]}` paints `plaza` until `cobble_a` is in
`tiles/atlas.json`; a filler `{"sprite": "clock_tower", "x": 766, "fallback": "civic_annex"}` draws `civic_annex` until
`buildings/clock_tower.png` exists. Props use the same key (see 1.8). Old Town is built entirely this way.
`ped_outfits` (optional) is the pool passers-by dress from (Shopping Street leans to Luxury Citywear, Harbor to Logistics / Site).
A `ground` entry may carry `fallback`: the tile to paint while `type` is not in `assets/tiles/atlas.json` yet (Harbor's `quay_concrete`, `quay_edge` and `water_harbor`). `exits` may be empty: Harbor is reached only by metro (M3).
Building fronts, fillers and street dressing are laid out by `tools/gen_districts.py <district>` from real sprite widths.

### 1.10 City and Metro — `data/city/aurelia.json`
`{id, name, population, districts[{id, name, status, map_pos, blurb}], metro{lines[{id,name,color,stations[]}], travel_min{a->b}, fare}}`

### 1.11 Regions (World Map) — `data/regions/<id>.json`
`{id, name, archetype, industries[], strengths[], risks[], flight_hours_from_aurelia, shipping_days_from_aurelia, entry_requirement, status}`.
All 7 overseas markets are defined with `status: planned`.

### 1.12 Regulations — `data/regulations/<id>.json`
```json
{"id":"company_registration_aurelia","office":"city_hall","fee":300,"processing_min":45,
 "fields":["company_name","business_type","address"],
 "unlocks":["business_bank_account","office_lease","b2b_contracts","seller_cap_lifted","supplier_net_terms"]}
```

### 1.13 Events — `data/events/<id>.json`
```json
{
  "id":"supplier_price_increase","category":"supply","status":"active",
  "trigger":{"when":"daily","conditions":["stat:purchase_orders>=1","day>=6"],"chance":0.18,"cooldown_days":20,"once":false},
  "bind":{"supplier":"most_used","product":"best_seller"},
  "presentation":{"channel":"phone","speaker":"ken_supplier","lines":["Heads up.","Factory raised prices. {product} goes up 15% from Monday."]},
  "choices":[
    {"id":"accept","label":"Fine. Keep the order flowing.","effects":[{"op":"supplier_price_mod","mult":1.15,"days":30}]},
    {"id":"stock_up","label":"Lock in {moq} more at today's price","requires":["cash>={moq_cost}"],
     "effects":[{"op":"purchase","qty":"moq","price":"current"},{"op":"supplier_price_mod","mult":1.15,"days":30}]},
    {"id":"switch","label":"I'll look at other suppliers.","effects":[{"op":"supplier_price_mod","mult":1.15,"days":30},{"op":"set_flag","flag":"considering_new_supplier"}]}
  ]
}
```
Validator rule: every event must have at least one choice whose effects touch money, inventory or options (`cash`, `purchase`, `refund_order`, `inventory_delta`, `supplier_price_mod`, `create_contract_offer`, `listing_mod`, `ad_price_mod`, and from Chapters 10–12 `open_escrow`, `rail_choice`, `shipment_lost`, `acquisition`).

Later additions (Chapters 10–12): `presentation.tips: [glossary ids]` and a choice's `tip: <glossary id>` put a "!" badge (InfoTip)
on the decision; a choice's `detail` is the one-line plain-language note under it. `bind` selectors: `acquisition` (Hale
Group's price, `Acquisition.context()`), `import_po` (an import on the way). An event fired with no context (a story action
or a conversation) binds itself. Conditions may read the event's context: `ctx:<key>`. Effect ops: `open_escrow`,
`rail_choice {choice: wait|reroute|loan}`, `shipment_lost {choice: reship|refund}`, `acquisition {choice: accept|counter|decline}`.

### 1.14 Story — `data/story/chapters.json`, `data/dialogue/<id>.json`
```json
{"chapters":[{"id":"ch1_arrival","title":"CHAPTER 1 — ARRIVAL","objectives":[
  {"id":"ch1_check_phone","text":"Check your phone","complete_when":["flag:phone_opened"],
   "on_complete":[{"do":"start","objective":"ch1_go_outside"}]}
]}]}
```
Story recovery and saved receipts (#24):

Side-story infrastructure (#86, content integration Blocked on #64–#69): definitions load from
`data/story/side_stories/<id>.json` into `DataDB.story.side_stories`. Each definition has `id`, translated
`title`/`text`, `business` (must be active), `trigger: [Cond expressions]`, and `objectives` in the same
format as chapter objectives. Objective ids must be globally unique. Accepting requires a live registered
company. The phone's Opportunities app accepts eligible stories without replacing the main chapter.
`story.side_stories[id] = {company, status: active|completed|unavailable, skipped}` initializes lazily on
old saves. Steps advance sequentially; `on_skip` replaces a side step's success actions when it is impossible.
The story's `on_complete` runs once only when no step was skipped; otherwise `on_unavailable` runs once.
Closing/removing the bound company cancels its active steps and runs `on_unavailable`, never the reward.
There is no production side-story content in this change: each industry's real conditions, choices,
reward and tutorial require its implementation to be merged first.

Objectives accept optional `skip_when: [Cond expressions]` and `skip_text` (translated player text). When normal completion fails but all skip conditions hold, the engine sends the explanation and completes the step without claiming a successful task. `contract_closed:<tag>` means the contract's original seller entity has a `closed` field; it does not transfer money or rewrite the contract. `has_listed` means any listing exists, including a paused listing, or an order was already placed.

`data/economy/story_recovery.json`: `{loss_months: 2}` controls the Chapter 6 negative-cash month-end fallback. Runtime additions use existing lazy dictionaries: `stats.ch6_cash_loss_months`, `flags.ch6_cash_reviewed`, `flags.ch7_survived_losses`, `flags.news_read_y3`–`news_read_y8`. The legacy `news_read`, `ch6_month_in_black`, `ch7_month_profit` keys remain readable. `_migrate` derives only the saved era's news receipt from the old generic key; era changes clear the generic receipt. Contract receipts reconcile from saved statuses on load and story checks. Tutorial version 3 and step indices are unchanged.

Dialogue:
```json
{"id":"maya_intro","lines":[
  {"who":"maya","text":"So you actually quit?"},
  {"who":"player","choices":[{"text":"Yeah.","set":"maya_tone_direct","next":"a"},{"text":"...Maybe.","next":"b"}]}
]}
```

### 1.15 Vehicles — `data/vehicles/<id>.json` (Planned P1)
`{id, name, class: used_compact|sedan|suv|sports|luxury, price, running_cost_day, travel_time_factor, capacity, sprite}`

### 1.16 Properties — `data/properties/<id>.json`
`{id, name, district, kind: home|office|coworking_desk|shop|warehouse, monthly_rent, deposit_months, requires[], capacity{inventory_units, staff}}`
plus optional:
- `building`: the building id the lease belongs to.
- `requires_text`: what the lease modal and `Living.lease` say when a `requires` condition fails (default: "The landlord needs a registered company on the lease.").
- `agent`: who handles it (Tom for Suite 2B, Mr. Okafor for the café).
- `agent_line`: the line shown once the lease is yours (default: Tom's "It's all yours").
- `blurb`: the paragraph in the lease modal (default: the office pitch).
`kind` picks the expense line the monthly rent is booked to (`Living.rent_category`): `office` → `rent_office`, `shop` →
`rent_shop`, `warehouse` → `rent_warehouse`, otherwise `coworking`. The month-end report folds all premises rent into one
"Rent" line. Signing sets `flag:leased_<property_id>`. The lease modal shows Storage only when `inventory_units` > 0 and
Desks only for offices.
The slice uses `riverside_studio` (home), `nexus_cowork_desk`, `startup_hub_suite_2b` (small office, a lease id `suite_2b`)
and `corner_cafe` (`kind: shop`, Old Town). `warehouse` has a ledger line but no property yet (Harbor, Planned).
`{id, name, district, kind: home|office|shop|warehouse|coworking_desk, monthly_rent, deposit_months, building, requires[], requires_text, agent_line, blurb, capacity{inventory_units, staff}}`
The slice uses `riverside_studio` (home), `nexus_cowork_desk`, and `startup_hub_suite_2b` (small office). `corner_cafe` is a `shop`
(rent → `exp:rent_shop`); `pier7_warehouse` is a `warehouse` ($1,400/month, deposit 1 month, 5,000 units; rent →
`exp:rent_warehouse`). A leased `warehouse` is a stock location (`Ecommerce.stock_locations()`), so purchase orders can be
delivered to it and its packing bench packs its orders.

### 1.17 World economy — `data/world/years.json`
`{years:[{year:1,name:"The Opportunity",interest_rate:0.025,shipping_index:1.0,events:[...]},{year:5,name:"Clearing Crisis",...}]}`
Years 1–8 are active (Year 2 only as numbers, rolled into Chapter 7). Years 9–10 are Planned.

### 1.17b Eras, suppliers and settlement (Chapters 7–9)
`years.json` → per year: `interest_rate`, `shipping_index` (courier rates ×), `cost_mult` / `import_cost_mult` (supplier
prices ×), `lead_mult` / `import_lead_mult` (lead days ×), `rent_mult` (home rent ×), `packaging_levy` ($ per
plastic-padded parcel), `eco_demand_mult` (demand × for products with `eco: true`), `cross_border_delay` (imports wait
for their payment to land). Read only through `World` (`scripts/sim/world.gd`); story action `world_year` moves the era.
Suppliers: `region` ≠ "aurelia" = import; `shock_exempt` (era multipliers don't apply); `from_year`; `requires_flag`
(listed and buyable only once set). Products: `eco`, `icon_fallback` (stand-in picture until `icon` art exists).
`data/economy/settlement_methods.json` → methods with `cross_border: true` are the rails for imports in Year 5:
`fee_rate`, `fixed_fee`, `fee_min`, `clear_hours [min, max]`, `requires` (a Cond), `requires_text`, `from_year`, `desc`, `tip` (glossary id).

### 1.17c Digital rails, compliance and acquisition (Chapters 10–12)
`years.json` adds `wire_clear_mult` (wire clear hours ×; 0.6 from Year 6), `compliance: true` (Year 8: KYC, licence and monthly
cost apply), and for Year 7 `headlines_incident` / `headlines_after` (the news during and after the exploit; `headlines` is
the news before it). `World.wire_clear_mult()`, `World.compliance()`.
`settlement_methods.json` adds the method `escrow` (`escrow: true`) and `digital_rail: true` on both digital methods (the
ones the bridge exploit freezes).
`data/economy/rails.json`: `reliability{method: published on-time share}`, `reliability_gain` (share of the gap to 100%
closed per clean landing), `regular_after` / `regular_fee_mult` (fee discount for regulars), `exploit{delay_min,
fallback_days, freeze_days, recovery_ratio, reliability_hit}`, `shipment_lost{reship_days}`. Read through `Rails`.
`data/economy/compliance.json`: `kyc{threshold, fee_rate, fee_min, hours}`, `import_licence{fee, days, processing_hours,
renew_window_days}`, `monthly{base, per_employee}`. Read through `Compliance`.
`data/economy/acquisition.json`: `window_days`, `profit_multiple`, `revenue_multiple`, `stock_haircut`, `min_price`,
`counter_uplift`, `counter_upfront`, `earnout_days`, `earnout_floor`. Read through `Acquisition`.
NPC `victor` (Hale Group): schedule at `crestline_flagship` weekdays 11:00–16:00 once `objective_done:ch12_kyc`; dialogues by
outcome (`victor_offer`, `victor_sold`, `victor_earnout`, `victor_declined`, `victor_chat`).
Ledger: new asset accounts `escrow_held` and `frozen_funds`; new expense category `compliance` (Compliance) in
`Ledger.EXPENSE_CATEGORIES` / `OPEX_BUSINESS` / `CATEGORY_NAMES`.
Scheduler kinds: `rail.exploit`, `rail.unfreeze`, `cmp.licence`, `cmp.remind`, `cmp.expire`, `acq.earnout`.
Stats: `import_orders_y<year>`, `import_received_y<year>`, `escrow_orders`, `escrow_released`, `escrow_refunds`, `kyc_checks`,
`kyc_cleared`, `compliance_charges`. Flags: `escrow_open`, `escrow_declined`, `ch10_decided`, `rail_exploit`, `rail_decided`,
`rail_recovered`, `import_licence`, `offer_decided`, `offer_accepted`, `offer_countered`, `offer_declined`, `company_sold`,
`earnout_paid`, `earnout_missed`, `story_complete`.

### 1.18 Character creator options — `data/character/options.json`
`{presentations[], face_shapes[], hairstyles[], hair_colors[], skin_tones[], eye_shapes[], eye_colors[], eyebrows[], mouths[], outfits[], outfits_shop[]}`. Each option is `{id, name, layer?, color?}`. **No option has any gameplay field. The validator rejects keys like `bonus`, `stat` and `modifier`.**

`outfits` are the creator's starters. `outfits_shop` are sold in stores:
```json
{"id":"executive","name":"Executive","price":640,"store":"threadline_apparel","blurb":"...",
 "stand_in":{"outfit":"business_suit","tints":{"top":"#23263a","bottom":"#23263a"}},
 "npc_tops":["#9c6a44","#3a3a42"]}
```
`stand_in` is what the outfit draws as until `characters/outfit_<id>_<presentation>_top.png` (walk) or
`portraits/outfit_<id>.png` (portrait) exists, when the real art takes over by itself. `npc_tops` (optional) varies the
colour on passers-by.

### 1.19 Help cards and minigame texts — `data/help/help.json`, `data/minigames/typing.json`
`help.json`: `{key: {title, lines[]}}`. A Modal with `help_key` shows its card the first time it opens (not while the
guided first venture runs) and keeps a ? button in its header. Company OS uses `os_<tab>`.
`typing.json`: `{saas: {<idea_id>: [[line, ...], ...], _generic: [...]}, freelance: [[line, ...], ...]}`. Code and
spreadsheet formulas stay in English, as they would really be typed.

### 1.20 Staff roles — `data/economy/staff.json`
`{payroll_weekday, payroll_hour, work_hours[start,end], employer_registration_fee, job_ad_fee, applicant_delay_hours, applicants, severance_weeks, max_staff, morale_start, roles{<id>: {...}}}`.
A role is `{name, salary_week[min,max], needs_office, desc}` plus optional:
- `workplace`: the property id where this role works (default `suite_2b`, so office roles sit at Suite 2B). `barista` → `corner_cafe`.
  Staff only appear in an interior whose `property` matches.
- `work_days`: weekday numbers as `Clock.weekday` returns them, 0 = Sunday, 1 = Monday … 6 = Saturday (default `[1,2,3,4,5]`; barista `[1,2,3,4,5,6]`). `cafe.json` `open_days` uses the same numbers.
- `work_hours`: `[start_hour, end_hour)` overriding the file-wide `work_hours` (barista: `[7, 17]`).
- `needs_lease`: a property id. `Staff.hire_block` refuses to hire the role until that lease is yours.
- `needs_text`: what the People tab says while it is refused ("needs a café (lease the corner unit in Old Town)").
JSON numbers are floats, so code compares weekdays as ints (`Staff.is_working`, `Cafe.open_day`).

### 1.21 Café — `data/economy/cafe.json`
Everything the café module (`scripts/sim/cafe.gd`) reads; nothing is hard-coded in the module.
```json
{"property": "corner_cafe", "fitout_cost": 5800, "permit_fee": 280, "permit_hours": 48,
 "open_hour": 7, "close_hour": 17, "open_days": [1,2,3,4,5,6],
 "footfall_day": 240, "saturday_mult": 1.3, "hour_share": {"7": 0.12, "8": 0.17, "...": 0},
 "base_conversion": 0.3, "elasticity": 1.6,
 "items": {"coffee": {"name": "Coffee", "ref_price": 4.2, "unit_cost": 0.85, "min": 2.5, "max": 8.0},
           "pastry": {"name": "Pastry", "ref_price": 3.8, "unit_cost": 1.3, "min": 2.0, "max": 7.0, "attach": 0.35}},
 "supply_packs": [{"id": "small", "cups": 150, "cost": 135}, {"id": "large", "cups": 400, "cost": 320}],
 "supplies_max": 1200, "pastry_order_max": 80,
 "barista_cups_hour": 14, "owner_cups_hour": 16, "owner_shift_hours": 2,
 "card_fee": 0.019, "rating_start": 3.4, "rating_speed": 0.12, "ads": [0, 15, 40]}
```
- `property`: the lease (1.16) the café runs on. `fitout_cost` is paid once (booked to `exp:fitout`, ready a day later);
  `permit_fee` books to `exp:registration`, and the licence (`flag:food_permit`) is granted `permit_hours` later.
- Demand for hour `h`: `footfall_day × hour_share[h] × (saturday_mult on Saturdays) × base_conversion × price_factor × rating_factor × ads_factor`,
  where `price_factor = clamp((ref_price / price)^elasticity, 0.15, 1.9)`, `rating_factor = 0.55 + 0.13 × rating`, `ads_factor = 1 + 0.35 × (1 − e^(−ads/25))`.
  The hour is Poisson-sampled, then capped by counter capacity (`barista_cups_hour × Staff.output` per barista on shift, plus
  `owner_cups_hour` × the share of the hour you stood at the counter) and by cups in stock. `pastry.attach` is the share of
  customers who add a pastry (also scaled by its price factor).
- `supply_packs` ordered from supplier id `old_town_roasters` cost `cost × World.cost_mult` and arrive at 06:00 the next day
  (`supplies_max` counts stock plus what is on the way). `pastry_order_max` caps the daily bakery order; unsold pastries are binned at `close_hour`.
- `card_fee` is taken from each day's till at closing (`exp:platform_fees`). `ads` are the per-day flyer budgets on offer.
- `rating_start`/`rating_speed`: the star rating starts at `rating_start` and moves this fraction of the way to each day's target.
### 1.20 Logistics — `data/economy/logistics.json`
Read by `Logistics` (`scripts/sim/logistics.gd`). Every number of the delivery business lives here.
```json
{"property":"pier7_warehouse",
 "van":{"name","price":9800,"insurance_month":165,"resale":0.55,"capacity_parcels":40},
 "fuel":{"l_per_km":0.14,"price_l":2.1,"era_sensitivity":0.5,"upkeep_per_km":0.07},
 "own_van_shipping":{"km_per_parcel":4.5,"minutes_base":25,"minutes_per_parcel":12},
 "runs":{"post_hour":7,"per_day":[2,4],"max_open":8,"max_active":3,"stops":[4,6],"base_pay":32,"pay_per_stop":20,
         "score_pay":[0.9,0.2],"late_penalty":0.4,"cancel_after_hours":6,"speed_kmh":24,"load_minutes":30,"stop_minutes":12,
         "kinds":[{"id":"rush","name","weight","by_hour","day":0,"pay_mult"}]},
 "driver":{"start_hour":9,"score_base":0.66,"score_per_skill":0.04},
 "clients":[{"name"}],
 "map":{"size":[580,236],"km_per_px":0.045,"depot":{"name","x","y"},"river":[[x,y]...],"bridges":[[x,y]...]},
 "places":[{"id","name","district","x","y"}]}
```
`fuel_cost_per_km = l_per_km × price_l × (1 + era_sensitivity × (shipping_index − 1))`. `map` is the schematic city the route
minigame draws (and `minigames/route_map.png`, 580×236, replaces the drawn map when it exists: line `river`, `bridges` and `places`
up with the picture). The river runs top-right to bottom-left (x is a function of y); a leg between the two banks goes via
the bridge that makes it shortest. Route length in map pixels × `km_per_px` = kilometres. Run pay = (`base_pay` + `pay_per_stop` × stops) ×
kind `pay_mult` × a 0.92–1.12 client factor, paid × (`score_pay[0]` + `score_pay[1]` × route score), less `late_penalty` when late.

Staff role `driver` (`data/economy/staff.json`) uses the generic role keys `workplace` (property the role stands in),
`work_days`, `work_hours`, `needs_lease` (property that must be leased) and `needs_flag` (a flag that must be set: `van_owned`), with
`needs_text` as the reason shown.

---

## 2. Runtime state (save file)

Save transfer (#22) retains `SAVE_FORMAT = 1`: `.cvsave` has the same `{format, summary, data}` envelope as slots. Imports validate core records and reconciled ledger balances before adding missing historical fields. They never rewrite historical money or RNG state. Slots use atomic temporary-file replacement, three `slot_n.bak1..3` backups, and a separately copied `saves/replaced/` archive before explicit replacement. Invalid primaries remain visible for recovery; imports preserve the source `meta.version` for the subsequent update notice. No new mandatory saved keys are introduced.

Release notes (#23): `data/help/patch_notes.json` maps version strings to `{date: "YYYY-MM-DD", lines: [English player-facing strings]}`. DataDB reads this map. After `load_and_enter` completes its scene transition, notes with `saved < version <= installed` are sorted numerically and shown once. Closing the card atomically saves the installed `meta.version`; failure restores the earlier version in memory. Closing a card from a replaced game cannot modify the new game. `load_data` and imports retain source versions; new games already start at the installed version. Future entries remain hidden until that version is installed.

```
data.player            {name, appearance{presentation,face,hair,hair_color,skin,eye_shape,eye_color,brows,mouth},
                        outfit, wardrobe[outfit ids owned], home:"riverside_studio", location{kind,id,x,y,facing}, flags{}}
                        (saves without `wardrobe` get the three starter outfits plus the one being worn)
data.clock             {minutes: int (since 2031-06-01 00:00), speed: float}   (no fast-forward; speed is Slow 1.0 or Normal 1.5)
data.meta              {format, version, created_unix, playtime_s, slot}   (slot: the save slot this game lives and autosaves in,
                        1–6; 0 = a game from before 0.1.6. A loaded game keeps saving to the slot it came from)
data.tutorial          {v: 3, step, seen{}, off}   (the guided first venture; older versions restart at step 0 and skip
                        what's done. While it runs, the first stock, order, pickup and delivery come within minutes)
data.help_seen         {key: true}
data.world             {year, modifiers}   (the era: 1 at the start, 3/4/5/6/7/8 from Chapters 7–12)
data.rails             {reliability{method: 0..1}, settled{method: n}, exploit{state: none|frozen|recovered, at, until, ratio,
                        items[{po, amount, entity, src: escrow_held|inventory_in_transit, rerouted}], amount, decision}}   (created on first use)
data.compliance        {licence_until, licence_ready}   (created on first use; `licence_ready` is -1 when nothing is pending)
data.cap_table         {founder: 1.0, <investor>: share}   (`{hale_group: 1.0}` after the company is sold)
data.entities.<id>     {id, name, kind: person|company|npc_company, founded?, type?, address?, bank_account: bool,
                        properties[], seller_account{type: personal|business, month_gmv}}
data.ledger            {seq, journal:[{n, t, entity, memo, source{type,id}, lines:[{acct, dr, cr}]}]}
data.ecommerce         {listings{id:{product, price, photo, photo_q (your own shoot, 0..1), ad_budget, active, created, views, orders, rating_sum, rating_n}},
                        orders{id:{product, qty, unit_price, customer, placed, status, location, ship{method,cost,shipped,eta},
                                   delivered, payout_batch, return{reason, status}, review,
                                   pack_q, label_ok, damaged}},   (pack_q/label_ok from the packing minigame)
                        purchase_orders{id:{supplier, product, qty, unit_cost, total, placed, eta, location, status, terms, year,
                                   settlement{method, fee, clears, kyc?, kyc_until?}, escrow?, frozen?}},
                                   (status awaiting_payment → in_transit → delivered for imports in Year 5+; `escrow`: held → released |
                                   refunded | rerouted | switched; `frozen`: stuck on the bridge; `year`: the era it was placed in)
                                   (cancellation adds status cancelled, cancelled minute, cancel_fee; unpaid terms add
                                   payable_remaining, paid at original due date. Existing total is never overwritten.)
                                   (supplier returns lazily add returned_qty and returns:[{qty, refund, fee, shipping, t,
                                   due, entity, status: in_transit|refunded|sold_to_collector}]; eco.return_refund payload {po, return:index}.
                                   Refund becomes accounts_receivable at dispatch and cash after return_days. Stock leaves
                                   at average cost; positive cost/refund gap is exp:restocking, negative gap other_income.
                                   If the refund owner closes meanwhile, liquidation already sells the AR: no second refund.
                                   Missing arrived in old saves falls back to eta; missing return fields mean no returns.)
                        packaging: standard|recycled,
                        inventory{location:{product:{qty, avg_cost, defective}}},
                        parcels{location: [order_ids packed awaiting dropoff]},
                        supplier_mods[{supplier, product, mult, until}], counters{order_seq, po_seq}}
data.contracts.<id>    {buyer, seller, product, qty, unit_price, total, delivery_due, payment_terms_days,
                        penalty_rate, quality_req, currency, settlement, status, history[]}
                       Closure terminal states: offered → withdrawn; active → terminated; delivered → sold_to_collector.
                       History explains closure/AR sale. Closing cancels all seller's con.* reminders before the existing
                       80% receivables liquidation; ending the contracts never posts an extra journal or penalty.
                       Load reconciles these same states when entities[seller].closed exists, without repeating liquidation.
                       con.pay/early_payment reject closed sellers; delivery requires the current, open company as seller.
                       No original saved fields are removed or renamed; terminal status strings and history are additive.
data.logistics         {van{owned, bought, entity, ins_day, km}, jobs{id:{id, client, stops[place ids], kind, posted, by, pay, km_best,
                        est_min, status: open|active|driving|..., accepted?, driver?, driver_stats?}}, history[{id, client, stops,
                        pay, fuel, km, score, minutes, late, status: done|late|failed, t, who}] (last 40), seq, driver_day{staff id: day}}
                        (created on first use; flags `van_owned`, `first_delivery_run`, `leased_pier7_warehouse`; stats `van_runs`,
                        `van_runs_late`, `van_runs_failed`, `van_km`, `van_fuel_l`, `van_parcels`, `runs_accepted`, `vans_bought`;
                        an order shipped by your own van has `ship{method:"own_van", cost, mode:"van", van_eta, eta}`)
data.events            {queue[], active?, history[{id, t, choice}], cooldowns{id: until}}
data.story             {chapter, active[], done[], flags{}}
data.bank             {credit, loans{}, seq, no_loans_until?, appointment?}
                        `appointment` is an optional absolute minute, created only on booking. Existing saves need
                        no migration: missing means no booking. `bank.appointment {id:"lending"}` in `schedule` sends
                        the reminder; meeting Marcus removes both. Missed slots stay in phone Tasks with rebooking advice.
                        Loan records keep their existing fields and repayment schedule unchanged.

data.npcs.<id>         {met, relationship, convo_done[]}
data.timeline          [{t, text, kind}]
data.reports           {month_closes:[{period, entities:{id:{revenue, refunds, cogs, gross, opex{...}, rent, profit,
                                        cash_open, cash_close, ar, ap, inventory}}}]}
data.world             {year, macro{interest_rate, shipping_index}, modifiers[]}
data.rng               {seed, state}
data.cafe              {fit_ready, permit_ready (minute stamps, -1 = not started), supplies (cups), incoming (cups on the way),
                        pastries (in stock today), pastry_order, prices{coffee, pastry}, ads (per day), rating (1..5),
                        owner_from, owner_until (the window you stood at the counter), name ("" = "<Company> Café"),
                        first_sale, shut_warned, today{d, served, pastries, rev, demand, queue_lost, stock_lost, open_hours,
                        shut_hours, waste, owner_score?, owner_shifts?}, days[] (the last 60 closed days, same keys + rating)}
                        (created on first use by Cafe.S(); saves from before Old Town simply lack it)
data.living.leases     {<property_id>: {rent, day (of month), since, entity}}   (rent is charged monthly to `entity`)
```

Flags and stats the café sets: `met_okafor`, `leased_corner_cafe`, `food_permit`, `cafe_first_sale`; stats `cafe_customers`,
`cafe_days_open`, `cafe_owner_shifts`, `cafe_rating`. Ledger expense categories added with it: `rent_shop`, `rent_warehouse`,
`fitout` (`fuel`, `vehicle` and `insurance` are reserved for the logistics business; nothing posts to them yet).

## Overseas systems (#30)

`economy/fx.json`: home_currency; bank_spread (fraction); daily_volatility (fraction); mean_reversion (fraction); min_factor/max_factor (relative to start); history_days (days); seed_offset; era_volatility (year → multiplier); currencies (code → name, start_rate in home dollars/foreign unit). `FX.add_shock` stores temporary volatility and expiry day.

`economy/regions_market.json`: bank_open_fee (home dollars), population_reference (million), regions (id → currency, population_millions, demand_multiplier, product_multipliers by product category, unlock_year). `shipping.json` international methods add base_cost (home dollars), cost_per_day (home dollars/distance-day), days_factor, min_days/max_days.

Lazy save keys: fx {rates, history[code]: [{day,rate}], last_day, rng as signed integer string, shocks}; global_market.companies[entity] {bank, stores[region]: {prices[listing] in local units, revenue in local units}, balances[currency]: {receivable,wallet} in foreign units, auto_fx}. Overseas orders extend existing orders with region, currency, foreign_price, delivery_rate, foreign_due and global_paid. Book values remain in Ledger home dollars. No existing saved key is renamed.

## Duties and season-two chapter receipts (#31)

`economy/duties.json`: categories maps product category to one of codes; codes provide names. regions maps region → tariff code → rate fraction. refusal_rates maps ddp/ddu to probability; misclassification_fine (home dollars), document_fine_factor, document_delay_days, hold_timeout_days, target_units, fallback_units, target_return_rate, review_after_days, return_observation_days (days). Lazy customs save state has companies[entity][region:listing] {policy,code}, chapters[id] {entity,started minute}. Orders snapshot customs {policy,code,expected,duty_paid,penalty,cleared,held_at}; customs_refused marks duty-related refusal. pickup_fee_share allocates the courier batch fee for the income card. Existing saved keys remain intact.

## Trade RFQ preview (issue70)

`economy/trade.json` contains terms with origin/freight/insurance/duty payers, risk_transfer and insurance_required; goods keyed by product with tariff_code and regional local-unit price/capacity/demand; routes with freight_factor/default_risk; transport with base_fee/unit_fee/days/departure_weekday/loss_risk; payments with fee_rate/fixed_fee/days/default_multiplier. Other numeric keys tune quote expiry, handling, insurance, stress and warehouse rent. TradeQuote.sheet returns an immutable estimate with units and quoted_at/valid_until. No persistent trade state or executed job exists in this preview.
Customs decision choices may set `recommended: true`; only the first available explicitly recommended choice gets primary styling. An unavailable recommendation does not promote an unmarked choice.

## Overseas partners and forwards (#42)

`economy/overseas_partners.json` owns shock {currency,drop,days,volatility}, forward {fixed_fee,fee_rates by days,maximum_notional}, flight_fare/flight_days, distributor_units/wholesale_factor/delivery/payment days, home_invoice_price_factor/acceptance, warehouse opening/capacity/rent/shipping/delivery, transfer freight base/unit/days, clearance_after_days and comparison_units_90. All money is in home dollars except explicitly foreign notional and local prices.

Lazy `fx_forwards` = {items[id]{entity,currency,notional,days,rate,fee,collateral,status,opened,due,settled,spot,gain_loss,early},seq}. Lazy `overseas_partners` = {companies[entity]{warehouse{opened,last_month},transfers[{index,status,product,qty,unit_cost,cost,defect_rate,eta}],home_invoices,visiting,next_offer},chapters[id]{entity,started,month_closes},shock{currency,before,after,started,exposure_estimate}}. Optional distributor contract keys: type,region,invoice_currency,foreign_total,foreign_receivable,shipped,shipment_cost,eta,closure_written_off. Existing contracts keep their original lifecycle. `lumina_3pl:<entity>` inventory stays outside domestic stock locations. Orders use partner_channel=3pl. Month-close FX uses the existing fx_gain_loss account; no account rename/migration is needed.


## Industry framework state (#63)

- Every ledger journal source includes `segment`: industry id or `shared`. Old entries need not be rewritten.
- `jobs_service`: lazy `{seq, items}`. Each job has `id`, `entity`, `segment`, `client`, `scope`, `status`, `price` (AUD$), `work`/`progress` (caller-defined work units), `due`/`delivered`/`pay_due` (absolute game minutes), `terms` (0/30/60 days), `deposit` and `penalty_rate` (fractions), `deposit_paid` and `receivable` (AUD$). States: offered → active → delivered → invoiced → paid; company closure gives closed.
- `operating_assets`: lazy `{seq, items}`. Owned/rented assets retain price/book/deposit (AUD$), life_days/rent_days/maintenance_days (game days), bought/next_rent (absolute minutes), depreciation_day/maintenance_day (day index), failure_chance (daily probability when maintenance overdue), status working/broken/sold, and segment/entity. `legacy_expensed` marks logistics vans whose purchase was already charged to vehicle expense.
- `economy/industries.json`: asset service_hour, maintenance_days/cost, failure_chance and resale. Individual asset specifications can override these fields. Resale is clamped to 0.4–0.6.
- MonthClose adds `segments: {rows, totals, shared_pool}` without changing existing totals. Each row includes revenue, refunds, net_revenue, cogs, gross_profit, opex, allocated, other_income and operating_profit in AUD$. Shared expenses are allocated only to positive-revenue segments; exact cents are preserved.
- Industry registration fields: id, sim_class, prefixes, hour slot, optional actions. Tab descriptors: id, label, icon, order, render Callable or legacy method, optional start_label. Player-visible content still needs help/glossary/i18n.
# Manufacturing extension (#64)

`economy/manufacturing.json` configures RFQ price/quantity/due/quality terms, materials/MOQ/lead/capacity, machine purchase/rent/capacity/life/maintenance/failure, overtime, sampling/rework, crises, CNC and brand costs. `GameState.data.manufacturing` is lazy and save-compatible: entity, active, machines (Assets IDs), lots (qty/unit/quality), pos (cost/due/status), rfqs, orders (Jobs ID/produced/escaped/cost/refund), slots (start/end/machine/job/overtime/outsource/status), stage, inspection, quality history and recall deduplication. Scheduled prefixes: `mfg.arrival`, `mfg.outsource`, `mfg.brand`. Event effect `industry` routes a named crisis through the registry. District optional `traffic_types` chooses existing vehicle types without changing other districts.

# Real Estate extension (#65)

Shared properties may have `purchase_price`, `rooms`, investment_home kind and segment. `real_estate` lazy state contains active/entity/stage, mandates, clients, owned properties (book/base_price/uplift/rent/screen/tenant/renovation/mortgage/status), tenant invoices, project (budget/paid/units/milestones/due/delay/job/status), market (index/rate_shift/month/last_rate), seq/week. `real_estate_landmark` holds completed/name independently of company closure. Compliance.permits is `{id: {entity,status,due}}`; `cmp.property_permit` completes a paid process. Bank mortgage records keep existing loan fields plus type/property; rates reset each payment. Jobs direction=purchase uses accept_purchase/purchase_milestone, capitalizes costs and excludes incoming deposits/invoices/collateral. Scheduled `re.tenant/rent/collect/renovation/build` persist. Economy controls all permit/matching/rent/credit/renovation/development/market/crisis costs. Property equity is market minus the linked mortgage; unrealized market moves are disclosure, not income.

### Media (#66)
`economy/media.json` defines brief budgets/targets, creative card preferences, fees/time, staff skill multipliers, normalized channel mixes, CPM/audience/saturation, reputation, capacity, owned-media asset/inventory/upkeep and crises. `GameState.data.media` lazily stores entity/active, briefs, campaigns (mix, cumulative channel spend, daily report, status, KPI), reputation, completed count, radio asset/audience/inventory/day/offers and expiring per-industry demand boosts. Client jobs reference incoming Jobs; inventory asset uses Assets. Events have registry `industry:media` effects.

### Hotel (#67)
`economy/hotel.json` defines room types (market price/range, fit-out and renovation costs), the 12/30/50 room stages with their gates, demand (weekday, season, rating pull, price elasticity), channels (OTA tiers/commission, no-shows, overbooking), housekeeping, supplies, reviews (weights and formulas), city events, group blocks and crisis effects. `GameState.data.hotel` lazily stores active/entity/mode/stage, rooms (count, price, condition, asset ids, renovation end), channel settings, overbooking, breakfast, peak surcharge, temporary cleaners, city events, monthly demand trend, group blocks (Jobs ids), reviews (day/kind/weight/score), expiring modifiers, OTA accrual, history and stats. Properties `aster_inn` gives the lease; staff roles `housekeeper`/`front_desk` use `needs_flag: hotel_active`. Scheduled `hotel.reno` persists. Events use `industry:hotel` crisis kinds; old saves without hotel state initialise inactive.
### Energy (#69)
`economy/energy.json` holds tariffs (peak, off-peak, export, feed-in), panel kW/kg, orientation yield, roof kinds (grid size, load, usage, payback tolerance, terms, deposit), shade generation, margins, crew productivity, subsidy rates/quotas/fees/season, warranty, weather, EV adoption, charging types/spots/district traffic and crisis numbers. `GameState.data.energy` lazily stores active/entity/reputation/week, leads (roof grid, shade, layout, options), installs (Jobs id keyed: kW, materials, price, gross, grant, subsidy state, crew-days done, warranty end), warranty claims, subsidy year/used/applications, charging sites and deals (asset id, price, kWh/revenue/downtime), own rooftop arrays, decaying `mods` (materials, subsidy, tariff, security), weather and `ev_boost`. Scheduled `energy.decision/grant/open` persist. Optional hook: `GameState.data.automotive.ev_boost` raises EV adoption when present. Events use `industry:energy` effects; roles add `electrician`.

### Automotive (#68)
`economy/automotive.json` holds the licence, lot slots per stage, the auction (weekday, lots, bidder range, buyer fee, inspection), used car models and defects, reconditioning options, listing sale curve, airport passenger flow (base, season, weekday), rental classes with rates, damage, accident and insurance tables, service intervals, dealership brands (EV flag, margin, models), deposit, minimum stock and floor-plan interest, the four crisis settings and `hooks` for Hotel guests, Energy chargers and `ev_boost`. Events `automotive_*` use `op: industry`, `industry: automotive`.

## Consolidation and legacy (#43)

`economy/legacy.json` controls rival demand-share fraction/duration (days), strategy price/demand/elasticity factors, reviews/rating gates, campaign fee (home dollars)/duration, additional stock (units), comparison duration (days), revenue benchmark (home dollars/60 days), employee-share fraction, manager fee (home dollars/30 days) and daily parcel capacity. Lazy `legacy_story` retains market {entity,region,listing,branch,started,price,stock,strategy,responded,ad,purchase?,previous_offer,previous_offer_known,second_offer}, ending string, saved five cards, viewed count, manager {entity,next_fee,last_day,unpaid}, optional mentor_topic. `acquisition_receipt` records the actual entity/price/choice/time of a decided offer; older missing receipts use a disclosed current-valuation reference. Cap-table grants transfer existing shares; equity:employees is a credit-equity account, never revenue. No existing key is renamed or save format changed.

Acquisition receipts and delayed earn-out jobs bind to their company entity. New registrations reset current ownership to founder shares, retaining historical offer flags/receipts. Companies without a business account have no sale quote; personal savings never count as company assets. Legacy chapters set world years 9 and 10 on their first objective.

Growth: data/story/goals.json and achievements.json define id/title/metric/value/hint/unit/company. Save growth has completed and achievements dated entity receipts, three active IDs, reviewed optional goals, pending completion cards, company binding, journal sequence and cumulative cash history/overdrawn guard. Financial rewards are absent; existing ledger/report sources determine progress.

#92: data/legacy.json defines seven archetype formulas (metric/divisor/weight/cap), inheritance limits in home dollars, event category weights, and difficulty factors. Optional timeline metadata art/category/entity/npc preserves old row shapes. life_legacy holds immutable review snapshot, retired/shown flags. meta.previous_life stores prior slot/kind/review; difficulty increments per next life. paid_work_minutes, cafe_work_minutes, saas_work_minutes count actual clock minutes; gig_hours remains hours. New-life capital and inheritance are opening equity entries, never income. Separate slots preserve prior saves.

`capital_market`（#93，lazy）：公司 entity、route、具價格／盡調／期限／status 的 offers、獨立 NPC targets 與 owner、npc_mergers、integrations、ipo 階段與答案／定價／next_quarter、實際 quarter_reports、pressure 的 until／各員工實際 hit、reputation、last_vote。新公司重設股權事件狀態，原事件文字仍在 timeline；舊狀態不移植為新公司的營收或投資。


## Company portfolio and holding groups (#91)

`company` is an array of entity IDs; `active_company` selects the visible operational record. The legacy string becomes the first array item. `company_contexts[id]` stores operational states, entity-specific flags and credit/cooldown. Global bank loans retain entity IDs; new business scheduler payloads carry `company_context`. First registration transfers sole-proprietor schedules to the new operational view, retaining receivable owner IDs. Terminal records remain inspectable after closure; new firms receive fresh active modules.

`holding_groups` stores `basis`, `parents`, `loans`, `guarantees`, physical `trades`, stock/pending `margin` and timestamped `margin_events`, plus immutable month-end `reports`. Paired ledger accounts are `investment_in_subsidiary:<entity>`, `group_loan_receivable/payable:<loan>`, `group_interest_receivable/payable:<loan>`, `ic_revenue` and `ic_cost`. Goods orders carry optional internal margin metadata for delivery/refund elimination. City landmarks remain global; operating company state is separate. Configuration is `data/economy/holding_groups.json`.


## Moving homes (#32)

Every `kind: home` property provides `building`, `bed`, `bed_position`, `inventory_units`, and `monthly_rent` (capacity is also mirrored for existing ecommerce). `player.home` selects the home property. `Living.home/home_building/home_bed/home_rent` resolve location and era-adjusted rent; old saves default to Riverside. `living.housing` lazily stores actual per-property deposits, a cancellable notice reservation (`from/to/mode/ready/stage`), move count and receipts. Personal `home_deposit` is separate from business deposits, excluded from business asset contribution, and counted in personal net worth. New games record the configured pre-arrival deposit as opening equity; legacy saves never receive an invented deposit.

`home_letting` opens the in-world rental modal at Okafor Lettings. `requires: home:<property>` protects tenant equipment. Move completion transfers physical inventory and corresponding operational locations across company views, preserving cost, supplier refunds, scheduled jobs and unrealized internal markup; assets and income are not transferred to a different owner. Notice completion is hourly and persists after save/load; changed capacity/cash blocks execution with retry/cancel instead of displacing the player.

## Personal assets (#94)
`living.personal_assets` is global household state: homes keyed by property (status, historical book/base price, mortgage balance/months/paid_n/next/arrears, tenant, rent, actual invoices, optional leave notice); car (model/price/electric/luxury, location, energy, service due); style keyed by home; visits (npc/day/home); parking and insurance month. Old saves lazily start empty; company contexts never include this state. Owner home data has owner_purchase, tier, management_month, guests, metro_access_minutes plus #32 home fields. `economy/personal_assets` defines fees, travel/parking/energy, service, furniture/car options. Source-tagged Ledger transactions maintain personal property_assets, personal_vehicle, loan_payable and actual tenant AR.


### Café depth (#33)
`economy/cafe.json`: `locations` maps property to building and foot-traffic multiplier; `items` defines six `ref_price`, `unit_cost`, `materials` recipes and optional seasonal `months`; `materials` names bins; `material_packs` provides paid next-morning deliveries; `drink_shares`, `seasonal_demand_bonus`, `inspection` and `overtime` tune demand and consequences.
Saved `cafe` retains the old single-store keys and lazily adds `branches`, shared `roster` and `work_hours`. Each shop adds `materials`, `material_incoming`, `cleaned`, `inspection_next`, `inspection_until`, `inspection_pending`, optional `inspection_iid`/`inspection_deadline`, `inspections` and a per-premises branch `food_permit`. Old corner licences continue using the old flag. Daily records add `gross_margin` from actual posted costs. Events/scheduled deliveries include company and property ownership.

### Logistics depth (#34)
`economy/logistics.json.fleet` tunes two models, wear, condition-scaled breakdown chance, towing/repair, payment multiplier and 720-minute service restoring condition 90. `delivery_routes` defines clients, ninety days, weekly trips, fee, missed-trip penalty and negotiation tolerance.
`logistics.fleet.van1` uses the canonical old `logistics.van`; `van2` references an operating-asset id. Vehicles add model, condition, busy_until, service_until, costs, revenue and insurance deadline; assignments map current staff ids to unique vans. Delivery route contracts add type, place, internal, week_start/week_end and completed; jobs carry vehicle, route and route_week. Internal café work uses ic_cost/ic_revenue via ic_clearing; no cash or external revenue is invented.
