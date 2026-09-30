# CITY VENTURE — Story Implementation

This document turns the Master Handoff story (§4, §25–§28, §54–§67, §89) into implementable data: **Chapters → Missions (objectives) → Events → NPC / Dialogue / Business / World-event triggers.**

Writing rules (kickoff §31–§33):
- Lines are short, natural and modern. Characters have personality. Nobody lectures.
- Business lessons come from situations (the profit is on paper but the bank balance is small), not from definitions.
- Crypto never appears before the Year 5 Clearing Crisis. When it does, it arrives as a problem ("the payment still hasn't landed") before any option.

Condition DSL (shared by story and events): `flag:<f>`, `!flag:<f>`, `visited:<building|district>`, `stat:<name><op><n>`, `day<op><n>`, `cash<op><n>`, `company_registered`, `time_between:<hh:mm>-<hh:mm>`, `weekday:<mon..sun>`, and later `listed:`, `stock_units`, `world_year`, `loan_capacity>=n` (what Nexus Bank would lend today), `ctx:<key>` (a true value in the event's own context).

Action vocabulary (story `on_start` / `on_complete`): `dialogue:<id>`, `message:<npc>:<text>`, `set_flag`, `start:<objective>`, `complete_chapter`, `timeline:<text>`, `toast`, `unlock:<feature>`, `event:<id>`, and later `world_year`, `flag_reset`, `card` (a title band across the screen: the ending cards), `rail_exploit` (Chapter 11). Any action can carry `if: <condition>` and `delay_min`.

---

## 1. World story frame (Year 1–10)

| Year | Chapter window | World-event trigger (data/world/years.json) | Slice status |
|------|---------------|-----------------------------------------------|--------------|
| 1 The Opportunity | Ch1–Ch4 | low `interest_rate` 2.5%, startup boom news items | **Implemented** (news board, macro values) |
| 2 Growth Fever | Ch4–Ch6 | rent/wage index +8–12%, home & office rent renewals rise | Planned P1 |
| 3 Supply Shock | Ch7 | `shipping_index` ×1.6–2.2, supplier lead time ×1.4, logistics demand ↑ | Planned P1/P2 |
| 4 Green Shift | Ch8 | new energy policy, EV/solar opportunities on Business Board | Planned P3 |
| 5 Clearing Crisis | Ch9 | cross-border settlement delays; overseas suppliers demand prepay/alt rails; unlocks settlement comparison | Planned P2 |
| 6 Digital Finance Boom | Ch10 | new rails: escrow on delivery; wires recover to 3–5 days | **Implemented** (§9) |
| 7 Bridge Exploit | Ch11 | exploit event hits players using that rail; "We solved one trust problem and created another." | **Implemented** (§9) |
| 8 Regulation Wave | Ch12 | compliance cost & licences as operating conditions; the first acquisition offer | **Implemented** (§9) |
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
| 5 | Revenue isn't cash: open the cash forecast | `flag:cash_forecast_viewed` (retained if already viewed) | `Forecast.weekly` in Company OS → Finance |

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

## 8. Chapters 7–9 (Implemented, build 0.1.7)

Each chapter moves the world into its era (`World.set_year`, data in `data/world/years.json`). The calendar keeps
running day by day; the era is a story frame. Every chapter opens with the news board at Bloom Coffee (`read_news`,
an era-specific receipt `news_read_y3`–`news_read_y8`, retained when already read), then asks the player to use the chapter's new system for real.

### CHAPTER 7 — SUPPLY SHOCK ("The boxes are stuck at sea.") · Year 3
Era effects: courier rates ×1.8; local supplier prices +12% and lead times ×1.5; imports +25% and ×2; home rent +10%
(Year 2's Growth Fever rolls in here).

| # | Objective | Completes when | Systems |
|---|-----------|----------------|---------|
| 1 | Read the news | `flag:news_read` | Ken texts about the port |
| 2 | Talk to Ken (Nexus Co-work, Tue/Thu 10–15) or take his call | `flag:ch7_supply_plan` | `ken_supply_shock` → event `supply_shock_plan` (phone fallback after 2 days): **supply agreement** ($600, `supplier_price_mod` "cancel_era" for 60 days) · **local co-op** (unlocks `aurelia_makers`: `shock_exempt`, 1-day lead, pricier) · **stock up** (MOQ at today's price) |
| 3 | 100 units in hand or on the way | `stock_units>=100` | new Cond atom |
| 4 | Raise a price | `flag:repriced` (retained; set by `Ecommerce.set_price` on an increase) | |
| 5 | Close a month with a profit | `flag:ch7_month_profit` (month close during Chapter 7) | a loss month gets a message from Maya and the objective stays |

### CHAPTER 8 — THE GREEN SHIFT ("Aurelia goes electric.") · Year 4
Era effects: shipping ×1.3; Clean Packaging Act levy $0.40 per plastic-padded parcel; eco products' demand ×1.35;
Verdant Supply opens (`from_year: 4`).

| # | Objective | Completes when | Systems |
|---|-----------|----------------|---------|
| 1 | Read the news | `flag:news_read` | Ana texts about the levy and the grant |
| 2 | Switch to recycled packaging | `flag:packaging_green` | Company OS → Operations → Packaging (recycled: +$0.25/parcel, no levy, +5% demand) |
| 3 | List a green product | `listed:solar_lamp` | new product `solar_lamp` (eco), supplier `verdant_supply` |
| 4 | Apply for the Green Business Grant | `flag:green_grant` | Permits kiosk: `Company.claim_green_grant()` → $3,000 other income; checklist shows what's missing |

### CHAPTER 9 — CLEARING CRISIS ("The payment still hasn't landed.") · Year 5
Era effect: `cross_border_delay`. Buying from an importer (supplier region ≠ aurelia) opens the Settlement screen: the PO
is `awaiting_payment` until the money lands, then ships (`eco.po_cleared`). Rails (`data/economy/settlement_methods.json`):
**international wire** (1% + $25, 5–9 days) · **letter of credit** (1.5%, min $60, 2 days, needs the business account)
· **digital dollars** (stablecoin, simulated: 0.2% + $1, minutes, needs a verified exchange account; `from_year: 5`, so
crypto never appears earlier). A pending payment can be switched to a faster rail (Operations → Speed up).

| # | Objective | Completes when | Systems |
|---|-----------|----------------|---------|
| 1 | Read the news | `flag:news_read` | Marcus texts: talk to Lina Zhao |
| 2 | Order from Lumina Direct | `stat:import_orders>=1` | Settlement screen |
| 3 | Talk to Lina Zhao at Nexus Bank (weekdays 10–16, Year 5+) | `flag:met_lina` | `lina_intro`: explains the three rails; opening an exchange account verifies 4 h later (`set_flag` with `delay_min`) |
| 4 | Get the payment through | `stat:import_cleared>=1` | wait, or Speed up |
| 5 | Receive the import | `stat:import_received>=1` | then the $40k-a-month sandbox goal |

## 9. Chapters 10–12 (Implemented)

The last three chapters of the main story. Same shape as §8: each moves the world into its era (`World.set_year`, data in
`data/world/years.json`), opens with the news board at Bloom Coffee, and asks the player to use the new system for real.
They chain **ch9 → ch10 → ch11 → ch12 → an ending card → free play** (`goal_growth`, now "Grow {company}: $40,000 revenue
in a month"). A save that stopped after Chapter 9 carries on into Chapter 10. The tone rule holds: the rails are neither a
miracle nor a scam, and traditional finance is not the villain. Every new idea has a "!" badge (`data/help/glossary.json`).

### CHAPTER 10 — DIGITAL RAILS ("Money that moves when the goods do.") · Year 6
Era effects: wires recover to 3–5 days (`wire_clear_mult` 0.6), imports +3%, shipping index 1.1.
New settlement method **escrow on delivery** (`data/economy/settlement_methods.json`, `escrow: true`, `digital_rail: true`,
`from_year: 6`, needs `flag:escrow_open`): the payment is locked in a simulated smart contract (0.6%, $15 minimum, locks in
1–2 hours, no wire delay). The supplier ships once it sees the money locked; the contract pays the supplier on arrival.
If the supplier fails, the contract refunds (the fee is not returned).

| # | Objective | Completes when | Systems |
|---|-----------|----------------|---------|
| 1 | Read the news | `flag:news_read` | Lina and Ken text |
| 2 | Talk to Lina Zhao (Nexus Bank, weekdays 10–16), or take her call | `flag:ch10_decided` | `lina_rails` → event `escrow_offer` (phone fallback after 2 days): **open an escrow account** or **stay with wires and letters of credit** (never forced; Lina reopens the offer later if you declined) |
| 3 | Import from Lumina Direct, paying with escrow or the traditional way | `stat:import_orders_y6>=1` | Settlement screen lists fee, speed and each rail's **reliability** |
| 4 | Get the import delivered | `stat:import_received_y6>=1` | escrow released on arrival |

Money: escrow is booked as `escrow_held` (cash out, not yet stock, not yet the supplier's), then released to inventory on
arrival. The **rail reliability** stat is the share of payments landing on time, per rail: published starting values in
`data/economy/rails.json`, closed by 10% of the gap on every clean landing, knocked down by the exploit (Chapter 11). A
regular on the digital rails (two settled payments) pays 65% of the fee. After Chapter 10 the random event `shipment_lost`
can happen to an import on the way: escrow orders may take the refund, other orders can only ask for a re-ship.

### CHAPTER 11 — THE OTHER SIDE OF TRUST ("We solved one trust problem and created another.") · Year 7
Era effects: as Year 6 with wires still 3–5 days. The news changes with the story: before the exploit it reports record
bridge volumes, during the freeze it reports the exploit, afterwards the recovery (`headlines`, `headlines_incident`,
`headlines_after`).

| # | Objective | Completes when | Systems |
|---|-----------|----------------|---------|
| 1 | Read the news | `flag:news_read` | Lina: volumes tripled; Marcus: keep a wire route warm |
| 2 | Restock from Lumina Direct, paying the way you like | `stat:import_orders_y7>=1` | Completing it starts the exploit **20 minutes later** (a fallback fires it after 7 days) |
| 3 | Get through the freeze | `flag:rail_recovered` | the bridge stays frozen 6 days |
| 4 | Restock: get the import delivered | `stat:import_received_y7>=1` | |

The exploit freezes only what is still **crossing the bridge**: digital-rail payments (escrow or digital dollars) that
haven't landed yet (`awaiting_payment`). Their money moves to `frozen_funds` and the order is on hold; the digital rails
are closed to new payments until the bridge reopens. Then:
- **Money in flight** → event `rail_frozen` (Lina): **wait it out** (free; goods ship after the reopening; the payment lands
  at 90% and you cover the 10% gap so the supplier ships) · **pay again by wire** (fee 1% + $25, 3–5 days; needs the cash
  twice for a while; the frozen payment comes back at 90%) · **bridge loan from Nexus Bank** (`Bank.take_loan`, 3 months,
  the normal APR, then reroute; repay early with no penalty). Rerouting is also available later from Company OS →
  Operations → Reroute (wire or letter of credit).
- **Recovery, honestly**: after 6 days 90% of frozen balances are restored (`recovery_ratio`). The other 10% was drained
  before the freeze; operators' reserve and an insurance pool covered everyone else's share. The gap is booked as a loss
  (`exp:other`), whichever option you chose. Lina says so in a message.
- **Lighter path**: nobody who paid by wire or letter of credit has money crossing the bridge. They get a message (the
  supplier is on wires only for now), no decision, and carry on; the digital rails are just closed for a week.
The rails' reliability drops to 78% of its value and recovers with each clean settlement.

### CHAPTER 12 — REGULATION & SCALE ("Growing up means paperwork.") · Year 8
Era effects: `compliance: true`, base rate 5.5%, home rent ×1.18. Compliance becomes an operating cost:
- **KYC on large payments** (`data/economy/compliance.json`): a cross-border payment of $2,500 or more costs a fee (0.3%,
  at least $40, expense category `compliance`) and the check takes a day *before* the payment goes out over its rail.
  Speeding a payment up doesn't skip the check.
- **Import licence** at the City Hall permits kiosk (replaces the "Import permits & customs — Planned" row): $450 a year
  (expense `registration`), two days to process, valid 365 days, renewable in its last 60 days; reminders and expiry by
  message. Without a valid licence, imports are blocked in Year 8.
- **Monthly compliance cost**: $60 plus $8 per employee, charged on the 1st at 09:00 to a registered company (expense
  category `compliance`, its own line on the month-end report).

| # | Objective | Completes when | Systems |
|---|-----------|----------------|---------|
| 1 | Read the news | `flag:news_read` | Ana and Ken text about the Payments Integrity Act |
| 2 | Get an import licence at the permits kiosk | `flag:import_licence` | `Compliance.apply_licence` |
| 3 | Import in bulk: a payment over $2,500 goes through KYC | `stat:kyc_cleared>=1` | Settlement screen shows the KYC fee and delay |
| 4 | Meet Victor Hale at Crestline (weekdays 11–16), or wait for his call | `flag:offer_decided` | `victor_offer` → event `acquisition_offer` (phone fallback after 3 days) |

**Victor Hale** (Hale Group) is not a villain: tall, thin, no wasted words, he reads the books and says how he got to the
number. The **price comes from the company's own numbers** (`Acquisition.quote`, `data/economy/acquisition.json`): 3.5 ×
the last year's operating profit (extrapolated from the last 90 days; when profit is thin, 0.35 × yearly revenue instead),
plus cash, stock at 80% of cost and money owed to you, minus everything you owe, never below $5,000; investors (Elena's
share) take theirs. The event lays the arithmetic out. Choices:
- **Accept**: the founder's share is paid into personal cash; the company carries on under Hale Group with you as managing
  director. It belongs to Hale Group now (`company_sold`): no owner withdrawals or founder capital.
- **Counter**: 20% more, but only 60% now; the rest is an **earn-out** paid a year later only if revenue stays at 90% of
  the number at signing (`acq.earnout`; Victor's message says whether it paid).
- **Decline**: nothing changes; Victor says the door stays open.

Whichever is chosen, Chapter 12 ends with an **ending card** (`ENDING — A NEW OWNER` / `ON YOUR TERMS` / `STILL YOURS`,
`UIRoot.show_chapter_card`), `story_complete` is set, and free play continues with `goal_growth`.

## 10. Season 2 — Going Global (Planned, Chapters 13–18)

The main story (Chapters 1–12) ends in Year 8 with free play. Season 2 takes the company abroad: the World Map's seven
overseas regions (`data/regions/*.json`, all `planned` today) open one by one. Each chapter teaches one real thing about
selling across borders, and each one is playable with any business the player runs (ecommerce first; café and logistics
get their own beats). Tickets: GitHub issues labelled `season-2`.

| # | Chapter (Year) | What the player learns and does | NPCs | Systems it needs |
|---|---|---|---|---|
| 13 | **FIRST ORDER ABROAD** (Year 9, "Global Consolidation") | A Northridge shopper finds the store. Open an overseas storefront on ShopLane Global, set a price in their currency, ship the first international parcel (7–10 days) and get paid in NRD, converted at the bank's rate. Lesson: a sale abroad earns less than it looks after conversion and shipping. | Maya, Marcus | World Map unlock; per-region marketplace (demand, price in local currency); FX module (daily rates, bank spread); international shipping tiers |
| 14 | **CUSTOMS** (Year 9) | Ines Duarte, the customs officer, explains duties and paperwork. Choose **DDP** (you pay the duty up front, the buyer gets a clean price) or **DDU** (the buyer pays at the door, more refusals and returns). Classify a product (tariff code) correctly or pay a penalty. | Ines Duarte | duties by region and product category; DDP/DDU per listing; refusals/returns abroad; customs penalty event |
| 15 | **THE CURRENCY SWING** (Year 9) | The Auroria currency drops 12% in a week: overseas prices are suddenly too low. Options: reprice, lock a rate with a **forward contract** at Nexus Bank, or invoice B2B buyers in Aurelian dollars. Lesson: revenue in one currency and costs in another is a risk you manage, not a bet. | Marcus Reed | FX shock event; forward contracts (rate, notional, date, settlement P/L); invoice currency on contracts |
| 16 | **A PARTNER OVERSEAS** (Year 9) | Omar Haddad, a trader, offers two ways into Lumina: a **distributor** (they buy in bulk at a discount, they own the customer) or a **3PL warehouse** there (you keep margin and risk, stock sits abroad). Fly there (time passes, flight cost) to sign. | Omar Haddad | region travel (a trip scene); overseas stock location (3PL fees per unit per month); distributor contract type |
| 17 | **CONSOLIDATION** (Year 9–10) | Big players buy up small brands. A rival undercuts prices in the region you opened. Choose: niche (premium, smaller volume) or scale (lower prices, bigger stock). If Victor's offer was declined in Chapter 12, Hale Group is the rival; if accepted, you run the division that must hit targets. | Victor Hale, Kai Moreno (press) | rival pricing pressure on a market; brand/premium positioning; valuation reuse |
| 18 | **LEGACY** (Year 10, "Legacy") | Decide what the company becomes: keep it independent, sell, hand shares to the team (employee ownership), or step back and mentor founders at Nexus Co-work. An epilogue shows the city and the people you met, shaped by your choices. | Maya, everyone | ending choices and epilogue scenes; timeline recap; new game+ seed (Planned) |

Order of work: the systems of 13 (World Map unlock, regional marketplace, FX) come first; Chapters 13–14 ship
together, 15–16 next, 17–18 last. Art needs (chapter cards 13–18, Ines and Omar sheets, a customs office interior, an
airport scene, a Lumina warehouse) go into `docs/wiki/90_codex_art_backlog.md` when each ticket starts.

### After Season 2 (Planned)

| Year | Content | Systems it needs |
|------|---------|------------------|
| 10+ Legacy | sandbox and a Legacy generation (start again as someone you mentored) | save carry-over, family/succession |
| any | IPO path as an alternative to selling | listing rules, disclosure, share price |

Art for Chapters 7–12 is in `docs/wiki/90_codex_art_backlog.md`: the chapter cards `backdrops/chapter_10`–`chapter_12`
and the event pictures `events/rail_frozen` and `events/acquisition_offer` show up automatically once the files exist.

## 11. 防卡關原則（Implemented，#24）

- 每個 objective 啟動時立即檢查條件；檢查迴圈有重入防護，會連續處理已完成的步驟。接續章節從第一個未完成目標開始，整章已完成時只執行一次章節結束動作。
- 完成收據不因新步驟開始而清掉：財務預測、調價、訂單、採購、退貨及配送歷史均可提前完成。`has_listed` 接受曾經上架，之後下架不要求重做拍照上架。
- 新聞依年代保留 `news_read_y3`–`news_read_y8`，上一年的新聞不能代替新一年的新聞。舊存檔的 `news_read` 只遷移為該存檔年代的收據；換年代清掉舊的通用旗標，保留各年收據。
- Tagged contract 的 offered／accepted／decided／delivered／paid 收據可從舊合約狀態重建；拒絕、撤回、過期都算已決定。簽約公司已關閉時 `skip_when` 結束備貨、交貨及收款的等待，`skip_text` 明說原交易無法完成；不偽造交貨或收款。
- 第 6 章連續兩個負現金月結可繼續（`story_recovery.loss_months`），設定 `ch6_cash_reviewed`，不設定 `ch6_month_in_black`，也不發送恢復現金的稱讚。第 7 章既有兩個虧損月結路徑保留，新增 `ch7_survived_losses` 避免不實稱讚。
- 教學進入步驟前排空所有提前完成項目；已開始生意不因日票到期回到 reception，曾任職不因離職重做應徵。尚未做班就離職要重新應徵，教學文字及箭頭指向 Bloom Coffee 員工入口；商品下架後等待第一單會明說重新上架。第一單的舊 seen 紀錄不阻止新排程，但同時只允許一個排程。
- 箭頭跳過需要已失效日票或租約的電腦；可使用家中筆電。第 6 章資金橋接指向 Company OS，保留免費減支路徑，不把貸款當成唯一選擇。

長決策的內容放在捲動區中，結果確認留在視窗底部，避免繁中內容把確認按鈕推到畫面外；確認按鈕名稱為 `DecisionOK`。單元測試檢查最小尺寸，繁中截圖測試檢查實際位置並透過輸入關閉。

拒絕、撤回、過期和公司關閉的合約使用失效說明，不顯示未實際備貨／交貨／收款的成功提示；連續跳過相同交易的幾個步驟只通知一次。室內門口出生點須保留玩家碰撞間距；Pier 7 採用基底更新的家具布局，避免貨架覆蓋入口與出口路線。回歸測試檢查所有室內出生點，`--from=harbor` 可用獨立 fixture 快速檢查港區買車、租倉、送貨與存檔讀回，不能代替從新遊戲開始的完整驗收。

逐項 (a) 提前完成、(b) 失效與替代路徑、(c) 箭頭稽核：`evidence/2026-09-30_24/AUDIT.md`（55 個主線目標＋18 個教學步驟）。回歸測試：`test_no_softlocks.gd`；截圖：`--bot=softlocks --lang=zh_TW`。沒有刪除／更名既有存檔欄位，SAVE_FORMAT 仍為 1。
