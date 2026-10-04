# Automotive and the Airport district

Implemented `automotive` (#68) in the new `airport` district, reached by metro M4 (Airport Line) from Financial. Buildings: `airport_terminal` (passenger flow display, drives rental demand), `gateway_car_rental` (rental counter, parking lot and showroom leases), `aurelia_auto_auction` (the Wednesday auction hall and the Auto Desk) and `cargo_terminal` (look and info only, reserved for #70). Dockside Motors in Harbor also buys used cars at 80 percent of market value, instantly, with no buyer risk.

NPCs: `frank_doyle` (auctioneer), `jun_ito` (technician, paid inspection and reconditioning advice) and `mara_quinn` (new car sales, franchise). Role `auto_mechanic` ($1,000 per week) cuts reconditioning and service costs by 20 percent, saves a workshop day and adds two dealership service bays.

## Opening and money
A registered company with a bank account pays a $400 dealer licence at the Auto Desk. Money only comes from traceable transactions: car sales, rentals, service tickets. Insurance, storage, floor-plan interest and rent are real expenses.

## 1. Used car flipping (stage 1)
- Every Wednesday 09:00-17:00 six lots open. Each car has exterior, mechanical, mileage and a hidden defect (40 percent of cars). Three AI bidders have private ceilings and eagerness; every polling tick is seeded, so bidding is deterministic and bounded by each ceiling. A 5 percent buyer fee applies.
- Jun Ito inspects a lot for $150 and 30 minutes and reveals the defect and the true value. An undisclosed defect later produces a warranty claim.
- Reconditioning (detail, service, repair a known defect) costs money and workshop days and raises the market value; cost is capitalised into the car.
- List between 80 and 130 percent of market value. The ratio sets the daily sale chance, and the screen shows the expected days to sell. Cars can also be wholesaled at Dockside Motors.

## 2. Rental fleet (stage 2, 10 cars and the counter)
Cars are Assets (depreciation, maintenance schedule, failure chance, insurance). Daily and weekly rate multipliers (70-140 percent of the standard rate) trade price against utilisation. Demand comes from airport passengers (seasonal, weekday), plus Aurelia hotel guests from the Hotel module and a small charger bonus from the Energy network. Damage, accident claims (deductible and cover by insurance level) and skipped maintenance (breakdown mid rental: tow, compensation voucher, bad review) are all simulated. The rating changes demand. Fleet cars count as operating assets for Bank lending, used and new stock counts at 60 percent of cost.

## 3. Dealership (stage 3)
Requires the fleet, 25 completed rentals, the showroom lease and cash for a $30,000 franchise deposit plus a first factory order. Choose Meridian Motors or Volt Electric (EV). Minimum stock of three cars per month or a shortfall fee; two missed months end the franchise and forfeit half of the deposit. New cars have thin margins (5.5-6.5 percent), steady walk-in volume that responds to the showroom discount, and after-sales service tickets. An EV franchise raises city EV adoption: it writes `data.automotive.ev_boost`, which the Energy module adds to its adoption rate.

## Crises
`automotive_flood` (a flood car at auction: disclose, repair or hide), `automotive_fuel` (fuel price rise: cut rates or hold), `automotive_claim` (accident dispute: pay, fight or settle) and `automotive_recall` (pull the cars or keep running). Every effect has a duration and decays. Closing the company auctions stock at 50 percent, settles the deposit and cancels all callbacks.

Numbers live in `economy/automotive.json`; the 120-day balance report is in `evidence/2026-10-02_68/`.
