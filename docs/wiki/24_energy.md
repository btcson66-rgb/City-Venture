# Energy: solar, storage and EV charging (#69)

Implemented `energy` in the active Industrial district. New locations: `helio_supply` (panel and battery supplier, NPC `sunny_adeyemi`) and `helio_warehouse` (leasable warehouse office, property `helio_warehouse`, $2,600/month plus one month deposit, NPC `rafael_costa`). City Hall gains an Energy subsidy desk (action `energy_subsidy`, NPC `ms_okoro`, weekdays 09:00-17:00). Staff role `electrician` is hired through the standard employer flow at $1,050 a week and works weekdays at the warehouse.

## Roof Survey and installs
Weekly leads come from home, shop and workshop roofs in the city; every lead has a cell grid, orientation, load limit and per-cell shade from buildings and trees. The player places panels, chooses a battery size (after certification), a gross margin (18/24/30%) and whether to request a subsidy. Annual kWh, client savings (self-use, export price and battery shifting between peak and off-peak tariffs from `economy/energy.json`), payback and acceptance chance are shown before the quote is sent. A 5 kW home system quotes about $9k-$14k.

Accepted quotes become `Jobs`: deposit as a liability, materials bought from Helio Supply into stock when the install starts, crew-days progress each afternoon (owner 1.0 plus electricians, weekdays only; rain halves and storms stop work), delivery invoices the contract, stock moves to cost of goods, and late delivery pays the contract penalty. Warranty lasts a year: claims cost a share of the price and must be repaired or disputed (reputation and legal risk). Own-property leads (a player-owned `real_estate` unit) buy materials as a depreciating Asset and sell metered grid export at the feed-in price.

## Subsidy desk
Install grants are 20% of the quote up to $3,000 from a $60,000 yearly quota; charger grants are 25% up to $12,000 from a $40,000 quota. Applications cost $75, take four days, can be rejected (more likely on heavily shaded roofs), close after October and fail when the quota is gone. A rejected grant returns the client to full price and they may cancel with a deposit refund. Approved grants are paid by City Hall after delivery as revenue; charger grants reduce the capitalised asset cost. Policy events halve the rate and decay back over 90 days.

## Growth tiers
1. Installer: open with the warehouse lease and bank account.
2. Installer with storage: two completed installs plus the battery course unlock batteries and charging sites.
3. Charging network operator: five open stations; stations then cost 10% less and each extra station adds up to 10% network demand.

## EV charging network
Fourteen limited street spots across eight districts. Landlords want a fixed monthly fee or a revenue share (negotiation can fail and must be retried tomorrow); a leased Helio lot or a player-owned Maple Court unit needs no landlord. Destination chargers cost $9,000, fast hubs $45,000, financed with cash, a Nexus Bank loan or a capital grant. Stations are `Assets` with depreciation, maintenance and failure; a broken station earns nothing until serviced. Daily revenue is metered kWh x the chosen price ($0.35-$0.60); electricity at the commercial grid tariff is cost of goods. Demand = ports x kWh per port x city EV adoption / 6% x district traffic x (reference price / price)^1.8 x weather x network bonus, capped by port power. Adoption starts at 5% and rises 2.5 points a year; other modules may add a capped boost through `Energy.add_ev_boost()` or `automotive.ev_boost` saved state, both no-ops when absent. Open and building stations appear on the street of their district as `props/ev_charger` (cones while building, bollard fallback).

## Crises
Six events with two real answers each, all routed through the `industry` event op: `energy_shortage` (premium allocation vs shortage price), `energy_typhoon` (honour all claims vs triage), `energy_subsidy_cut` (rush filings vs accept), `energy_vandal` (repair vs repair with cameras), `energy_tariff` (hold vs pass the cost to drivers) and `energy_rule` (retrofit vs exemption). Price and policy shocks decay linearly back to normal.

Company OS, Business Board, glossary and help use the shared registry. See 90_codex_art_backlog.md for facade requests.
