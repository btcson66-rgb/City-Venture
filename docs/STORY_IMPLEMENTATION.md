# CITY VENTURE — Story Implementation

This document turns the Master Handoff story (§4, §25–§28, §54–§67, §89) into implementable data: **Chapters → Missions (objectives) → Events → NPC / Dialogue / Business / World-event triggers.**

Writing rules (kickoff §31–§33):
- Lines are short, natural and modern. Characters have personality. Nobody lectures.
- Business lessons come from situations (the profit is on paper but the bank balance is small), not from definitions.
- Crypto never appears before the Year 5 Clearing Crisis. When it does, it arrives as a problem ("the payment still hasn't landed") before any option.

Condition DSL (shared by story and events): `flag:<f>`, `!flag:<f>`, `visited:<building|district>`, `stat:<name><op><n>`, `day<op><n>`, `cash<op><n>`, `company_registered`, `time_between:<hh:mm>-<hh:mm>`, `weekday:<mon..sun>`.

Action vocabulary (story `on_start` / `on_complete`): `dialogue:<id>`, `message:<npc>:<text>`, `set_flag`, `start:<objective>`, `complete_chapter`, `timeline:<text>`, `toast`, `unlock:<feature>`, `event:<id>`.

---

## 1. World story frame (Year 1–10)

| Year | Chapter window | World-event trigger (data/world/years.json) | Slice status |
|------|---------------|-----------------------------------------------|--------------|
| 1 The Opportunity | Ch1–Ch4 | low `interest_rate` 2.5%, startup boom news items | **Implemented** (news board, macro values) |
| 2 Growth Fever | Ch4–Ch6 | rent/wage index +8–12%, home & office rent renewals rise | Planned P1 |
| 3 Supply Shock | Ch7 | `shipping_index` ×1.6–2.2, supplier lead time ×1.4, logistics demand ↑ | Planned P1/P2 |
| 4 Green Shift | Ch8 | new energy policy, EV/solar opportunities on Business Board | Planned P3 |
| 5 Clearing Crisis | Ch9 | cross-border settlement delays; overseas suppliers demand prepay/alt rails; unlocks settlement comparison | Planned P2 |
| 6 Digital Finance Boom | Ch10 | new rails, digital assets; scam events | Planned P2 |
| 7 Bridge Exploit | Ch11 | exploit event hits players using that rail; "We solved one trust problem and created another." | Planned P2 |
| 8 Regulation Wave | Ch12 | compliance cost & licences as operating conditions | Planned P2/P3 |
| 9 Global Consolidation | — | M&A offers, IPO option | Planned P3 |
| 10 Legacy | — | sandbox + Legacy generation | Planned P3 |

---

## 2. Vertical Slice chapters (Implemented in P0)

### CHAPTER 1 — ARRIVAL

| # | Objective id | Player-facing text | Complete when | On complete |
|---|--------------|--------------------|---------------|-------------|
| 1 | `ch1_arrive` | — (cutscene) | Arrival sequence ends | spawn Apartment; `message:maya` ×2 |
| 2 | `ch1_phone` | Check your phone | `flag:phone_opened` + Maya conversation done | `dialogue:maya_intro` (choice sets tone flag only) |
| 3 | `ch1_outside` | Go outside and look around Riverside | `visited:riverside` | toast "Riverside" |
| 4 | `ch1_coffee` | Grab a coffee at Bloom Coffee | `flag:bought_coffee_bloom_coffee` | Jun mentions the Business Board at Nexus Co-work |
| 5 | `ch1_cowork` | Visit Nexus Co-work in Startup Hub | `visited:nexus_cowork` | Priya greets |
| 6 | `ch1_board` | Check the Business Board | `flag:business_chosen` | timeline "Started an ecommerce side business"; `complete_chapter` |

The Business Board lists all six P0 industries. **Ecommerce** is selectable. SaaS, Cafe, Logistics, Manufacturing and Real Estate are shown with their pitch and a clear *"Not in this build (Planned)"* lock. Choosing sets `flag:business_ecommerce` and `flag:business_chosen`. No stat or buff is involved.

**Dialogue (examples, final text in `data/dialogue/`):**
```
maya_intro
  Maya:   So you actually quit?
  Player: [Yeah.] / [...Kind of.]
  Maya:   Okay. So... now what?
  Player: [I'm starting a company.] [Looking around first.] [Gonna build something.] [No idea, honestly.]
  Maya:   (varies)  "Bold." / "Smart." / "Of course you are." / "Honest."
  Maya:   Bloom Coffee's right downstairs. Go see your city.
```
```
jun_first
  Jun:    New face. Flat white?
  Jun:    You look like you're plotting something.
  Jun:    Co-work in Startup Hub has a board. Gigs, suppliers, whatever. Half my regulars found work there.
```

### CHAPTER 2 — FIRST CUSTOMER (Ecommerce variant)

Main objective (HUD): **Earn Your First Dollar**

| # | Objective id | Text | Complete when | Notes |
|---|--------------|------|---------------|-------|
| 1 | `ch2_supplier` | Find a supplier and buy your first stock | `stat:purchase_orders>=1` | Company OS → Operations → Suppliers. Available on the apartment laptop, a co-work desk (day pass) or the office desk. |
| 2 | `ch2_stock_arrives` | Wait for your stock to arrive | `stat:stock_received>=1` | lead_days. Boxes appear in the apartment. Ken texts. |
| 3 | `ch2_listing` | Photograph your product and create a listing | `stat:listings_active>=1` | photo choice: self (1 h) vs Studio Lumen ($120) |
| 4 | `ch2_first_order` | Wait for your first order | `stat:orders_placed>=1` | ShopLane notification |
| 5 | `ch2_ship` | Pack and ship the order | `stat:orders_shipped>=1` | pack at the inventory location; courier pickup vs PostPoint drop-off |
| 6 | `ch2_first_dollar` | Earn Your First Dollar | `stat:orders_delivered>=1` | toast shows units × price, and "payout Monday". Timeline "First sale". Maya: "Wait. Someone actually bought one??" |
| 7 | `ch2_issue` | Deal with an unhappy customer | `flag:first_issue_resolved` | forced event `customer_return_first` 1 day after first delivery |

Parallel tracked goal: `goal_rent` **Cover next month's rent ($1,250 gross profit)** (Handoff §4, second goal).

### CHAPTER 3 — OPEN FOR BUSINESS

| # | Objective id | Text | Complete when | Notes |
|---|--------------|------|---------------|-------|
| 1 | `ch3_decide` | Decide whether to register your business | `flag:ch3_decided` | Triggered by the ShopLane seller-cap notice and Maya/Priya lines. The player may say "not yet": the objective stays and the seller cap still binds. |
| 2 | `ch3_register` | Register your company at City Hall (Civic Center) | `company_registered` | Form: Company Name, Business Type, Address, $300 fee, 45 min. Company name appears everywhere. |
| 3 | `ch3_bank` | Open a business account at Nexus Bank | `flag:business_account_opened` | capital injection choice; inventory and marketplace balance transfer in kind |
| 4 | `ch3_workspace` | Find a place to run the company | `flag:workspace_chosen` | options: keep working from home, co-work desk ($350/mo), Small Office Suite 2B ($1,600/mo, deposit). Leasing puts the company name on the office sign. |
| 5 | `ch3_os` | Open Company OS as <Company> | `flag:company_os_opened_as_company` | `complete_chapter` → "CHAPTER 3 COMPLETE" card, timeline |

After Ch3 the slice continues as a sandbox until Month Close (June 30 → July 1), and random and dated events keep firing.

---

## 3. Dated beats (Handoff §89 typical rhythm → implemented as triggers)

| Day | Beat | Implementation |
|-----|------|----------------|
| 1 | Arrival | Ch1 |
| 2–3 | Discover wholesale / buy first inventory | Ch2 obj 1. If still not done by day 4 morning, Maya texts: "Did you buy anything yet or just coffee?" |
| 4–5 | Listing, first order | demand model |
| 7± | Return / complaint | `customer_return_first` (story-forced once), then stochastic `customer_return` |
| 10 | Need more inventory | `low_stock` notice when stock ≤ 20% of initial (Ken texts) |
| 14 | Rent due | `LivingCosts` posts rent; insufficient cash → late fee + landlord message; `SolvencyMonitor` warning |
| ≥12 | Supplier price increase | `supplier_price_increase` (chance, cooldown) |
| ~20 | Large order opportunity | `unexpected_large_order` (Harbor Point Fitness). Requires company. If not registered: "We need an invoice from a registered company." (cannot accept) |
| 30 | Month close | Clock `month_ended` → Month Close modal + Company OS → Finance |

---

## 4. Event catalogue (slice)

| Event id | Category | Trigger | Choices → effects (money / inventory / options) |
|----------|----------|---------|-----------------------------------------------|
| `customer_return_first` | customer | story, 1 day after first delivery | **Refund + take it back** (refund, unit returns defective → write-off, rating neutral) · **Send a replacement** (−1 unit, shipping cost, rating ↑) · **Partial refund 30%** (cash −30%, rating slight ↓) · **Refuse** (no cost now, rating ↓↓, chance of platform dispute fee) |
| `customer_return` | customer | on return request (sim) | same set, bound to that order |
| `supplier_price_increase` | supply | daily, day ≥ 12, has PO, 18%, cooldown 20 | Accept (+15% cost 30 days) · Stock up now at the old price (MOQ purchase) · Look elsewhere (flag; alt supplier highlighted) |
| `unexpected_large_order` | customer | daily, day ≥ 18, 35%, once | B2B contract offer 120 × water bottle @ $21, Net 30, deliver in 7 days, 5% late penalty. **Accept / Counter (price or 50% upfront or Net 15) / Reject**. Accepting may require buying stock. Revenue booked on delivery, but cash arrives in 30 days (Profit ≠ Cash). |
| `ad_cost_spike` | market | daily, has ads, 12%, cooldown 15 | ShopLane ad prices +40% for 7 days: Keep budget (fewer clicks) · Raise budget · Pause ads |
| `viral_mention` | market | daily, rating ≥ 4.2, 8%, once | Demand ×3 for 3 days: Rush-order stock (express, +20% cost, 1-day lead) · Raise price 15% · Ride it out |
| `low_cash_warning` | finance | SolvencyMonitor when cash < threshold or cash < upcoming obligations | Sell inventory to liquidator (40% of cost) · Reduce spending (pause ads, cheaper living) · Continue |

---

## 5. NPC triggers

| NPC | Role | Where / when (schedule) | Triggers |
|-----|------|------------------------|----------|
| Maya | old friend | phone; Bloom Coffee Sat–Sun 10:00–16:00 | intro, first sale reaction, day-4 nudge, registration nudge, month-close text |
| Jun | barista | Bloom Coffee 07:00–20:00 | first coffee chat → points to the Business Board; later small talk by state |
| Priya | co-work community manager | Nexus Co-work 08:00–20:00 | day pass / desk rental, business board tips, registration nudge |
| Ken | TradeLink Wholesale rep | phone; Nexus Co-work Tue/Thu 10:00–15:00 | delivery texts, low-stock text, price increase event speaker |
| Ana | City Hall clerk | City Hall weekdays 09:00–17:00 | company registration |
| Sofia | Nexus Bank banker | Nexus Bank weekdays 09:00–16:00 | business account, capital transfer |
| Marcus Reed | bank executive | Nexus Bank weekdays 13:00–16:00 | loans: "Bring me three months of statements." (Loans Planned P1) |
| Tom | leasing agent | Small Office building weekdays 09:00–18:00 | office tour, lease |
| Dara | PostPoint clerk | PostPoint 08:00–21:00 | parcel drop-off |
| Daniel Wong | retail buyer | Nexus Co-work Thu 17:00–19:00 (networking night) | cameo: "Call me when you can do volume." (sets `flag:met_daniel` for Ch5, P1) |
| Ambient | pedestrians | all districts, density by day part | life; some have one-line barks |

## 6. Business triggers → story

| Sim signal | Story / event effect |
|-----------|---------------------|
| first PO placed | Ch2 obj1 complete |
| PO delivered | Ch2 obj2 complete; Ken text |
| first listing active | Ch2 obj3 |
| first order placed / shipped / delivered | Ch2 obj4–6; timeline "First sale" |
| first return request | forces `customer_return_first` if not yet run |
| monthly sales reach 80% / 100% of seller cap | ShopLane notices → Ch3 `ch3_decide` |
| company registered | timeline "Founded <Company>"; unlock B2B events, supplier net terms |
| month ended | Month Close modal; timeline "First month closed: profit $X, cash $Y" |
| cash < warning | `low_cash_warning` |

## 7. Chapters 4–6 (Implemented, build 0.1.3)

The June sandbox goal (`goal_month`) starts Chapter 4 when the first month close runs. Saves that already finished
June are bridged into Chapter 4 automatically. The chapters are data in `data/story/chapters.json`, and every
objective has a guide-arrow `target`.

### CHAPTER 4 — GROWING PAINS ("Too many orders. Not enough hours.")
| # | Objective | Completes when | Systems |
|---|-----------|----------------|---------|
| 1 | Register as an employer at the City Hall permits kiosk | `flag:employer_registered` | `PermitsModal`, `Staff.register_employer` ($150) |
| 2 | Post a job ad (Company OS → People) | `stat:jobs_posted>=1` | `Staff.post_job` ($40). 3 applicants arrive about 18 h later |
| 3 | Hire the first employee | `stat:hires>=1` | Applicants carry skill, salary ask and a trait. The hire starts the next day at 9:00 |
| 4 | First payroll (Friday 17:00) | `stat:payrolls_run>=1` | A missed payroll becomes `wages_payable` and hurts morale. Three missed payrolls in a row mean insolvency |
| 5 | Revenue isn't cash: open the cash forecast | `flag:cash_forecast_viewed` (reset when the step starts) | `Forecast.weekly` in Company OS → Finance |

### CHAPTER 5 — THE BIG CONTRACT ("Daniel buys by the pallet.")
Daniel Wong texts, then waits at Nexus Co-work on Thursdays 17:00–20:00 (`daniel_big_deal`). If the player doesn't
come, the offer arrives by phone after 6 days (`crestline_big_offer`, a one-off story event guarded against
double-firing). The contract is tagged `big_contract`: **800 LED desk lamps at $28 = $22,400, delivery in 21 days,
Net 60, 10% late penalty.** The handoff's example was $420,000; the order is scaled to the slice economy, where it
is still more than a month of revenue.

| # | Objective | Completes when |
|---|-----------|----------------|
| 1 | Meet Daniel | `flag:big_contract_offered` |
| 2 | Accept, counter or decline | `flag:big_contract_decided` (accepting, declining or letting it expire) |
| 3 | Get 800 lamps in stock or on the way (cash, supplier terms, bank loan, investor) | `contract_ready:big_contract \|\| flag:big_contract_declined` |
| 4 | Deliver before the deadline | `flag:big_contract_delivered \|\| flag:big_contract_declined` |

The pressure is real. Home stores 600 units and Suite 2B 1,500, so the order can ship from several locations. The
lamps cost about $9,200 up front and the money comes back 60 days later. The contract screen offers a one-click
"Order the missing units" (cheapest supplier, location with space, optional supplier terms).

### CHAPTER 6 — CASH IS OXYGEN ("Profit on paper. Payroll on Friday.")
| # | Objective | Completes when |
|---|-----------|----------------|
| 1 | Check the forecast | `flag:forecast_checked_ch6` |
| 2 | Bridge the gap | `flag:loan_taken \|\| flag:investor_elena \|\| flag:costs_cut \|\| flag:early_payment_agreed \|\| forecast_ok` |
| 3 | Collect from Crestline | `flag:big_contract_paid \|\| flag:big_contract_declined` |
| 4 | Close a month with cash in the bank | `flag:ch6_month_in_black` (set by the month close during Chapter 6) |

The options are real systems. **Marcus Reed** (Nexus Bank, weekdays 13–16) lends on cash flow and collateral
(`Bank`). **Elena Park** offers $40,000 for 20% (`elena_offer`, which dilutes the cap table). **Cut costs** pauses ads
and cuts living costs. **Early payment** discounts the Crestline invoice by 3% for cash now. After Chapter 6 the
sandbox goal is $40,000 revenue in a month.

## 8. Chapters beyond (Planned)

| Chapter | Key content | Phase |
|---------|-------------|-------|
| Ch7 Supply Shock | Year 3 world event, industry-specific impacts | P1–P2 |
| Ch8 Green Shift | opt-in energy opportunities | P3 |
| Ch9 Clearing Crisis | "Payment still pending." First settlement comparison (Lina Zhao) | P2 |
| Ch10 Digital Rails | stablecoin, smart contract escrow, optional | P2 |
| Ch11 The Other Side of Trust | bridge exploit | P2 |
| Ch12 Regulation & Scale | compliance, governance, M&A | P2–P3 |
