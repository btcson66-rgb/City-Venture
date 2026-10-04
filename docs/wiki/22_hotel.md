# Hotel / Tourism and Luxury Heights

Implemented `hotel` (#67) in the now active `luxury_heights` district, reached by metro M5 (Loop Line). Buildings: `the_aster` (boutique hotel, the 12-room Aster Inn), `skyline_grand` (five-star rival, competitor rate check and OTA contact) and `observation_deck` (tourist gathering point and travel desk). A boutique shopping row (`boutique_row`, `gallery_row`) is decoration. All three buildings have furnished interiors; missing facades use `riverside_tower`, `glass_tower` and `civic_annex` as named fallbacks (see 90_codex_art_backlog.md).

NPCs: `henri_dubois` (former owner, tutorial, opens the Rate Board), `priya_nair` (Voyago OTA account manager), `owen_blake` (Blake Journeys travel agent, group blocks) and `vera_stone` (hotel critic who stays at random, review weight x5). Events `hotel_slump`, `hotel_review_storm`, `hotel_equipment_failure`, `hotel_event_cancelled`, `hotel_strike` and `hotel_vera_visit` each offer at least two real choices through the industry registry (`op: industry`, `industry: hotel`). Roles `housekeeper` ($700 per week) and `front_desk` ($800 per week) use standard employer registration, applicants and weekly payroll.

## Opening and money
Opening needs a registered company with a bank account, a visit to The Aster, and either $150,000 cash (take over: three room fit-out Assets are capitalised, depreciation, maintenance and failure apply) or $9,000 per month rent through property `aster_inn` plus rented fit-outs. A landlord pays property tax and building insurance, an owner pays the daily overhead.

## Rate Board (decision screen)
- 30-day demand calendar: weekday, season, a seeded monthly tourism trend and city events (Harbor Music Festival, Aurelia Trade Expo, City Marathon Weekend). The forecast is a pure expectation and consumes no random numbers.
- Prices for Standard (about $60-180), Deluxe ($100-280) and Suite ($160-450); optional peak-day surcharge up to 40%.
- Channels: direct (no commission, lower volume), OTA (standard 15% or featured 18% commission, more volume, share of rooms 0-100%), agency group blocks (25% off rack, deposit 20%, Net 30, rooms locked in advance).
- Overbooking 0-10%. Booked guests may not arrive; guests above the cleaned room count are walked, paid compensation (rate plus $90) and each leaves a low review.

## Daily operations
A 23:00 night audit sells rooms. Housekeeping capacity (owner 2 rooms plus about 4.5 per housekeeper scaled by skill and morale; a checkout needs 1 unit and a stayover 0.4) decides how many checkout rooms can be sold; temporary cleaners cost $30 per room. Variable costs (linen, laundry and breakfast) are cost of goods; breakfast can come from your own cafe kitchen at wholesale cost. Stage 2 adds a restaurant (Asset) with its own sales and ingredients. OTA nights are billed each week as a Jobs statement, the commission is deducted from that receivable (platform fees expense) and the remainder is paid Net 30. Group blocks are Jobs offers; each stay night is progress, the last night delivers and invoices.

## Reviews
Score 1-5 = 35% cleanliness + 35% service + 30% value. Cleanliness drops with housekeeping shortfall and tired rooms, service depends on front desk coverage, breakfast, restaurant and walks, value compares price against a fair price implied by quality. Only the last 60 days count; walked guests, review storms and Vera Stone write extra entries (Vera weighs five times). Rating changes direct share, OTA ranking and market pull.

## Equipment and growth
Each room type has Asset-backed equipment and a condition that wears with occupancy. Broken equipment takes the whole type off sale; servicing repairs it. Renovation costs per room, takes 6-10 days offline, is capitalised and restores condition. Three stages: Aster Inn 12 rooms, Brasserie expansion 30 rooms (restaurant), Aster Harbor Resort 50 rooms (a second site in Harbor, higher tourism demand, extra daily site cost). Each stage needs days operated, 30-day occupancy, rating, review count and staff, not only cash.

## Crises and decay
Every crisis modifier expires: slump demand multiplier (28 days) or promotion (14 days), storm reviews age out of the 60-day window, slow repairs take rooms off sale for six days, a strike cuts housekeeping capacity for 6-10 days, and a cancelled city event removes the event and refunds tied group deposits. Closing the company cancels scheduled renovation callbacks, refunds group deposits, auctions equipment and clears the hotel flags.

Numeric assumptions live in `economy/hotel.json`. The `hotel` flag `hotel_active` also lets the Media group campaign lift hotel demand.
