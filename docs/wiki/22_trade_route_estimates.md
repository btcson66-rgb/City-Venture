# International trade route estimates — issue70

Status: active registered brokerage using shared Industries, Jobs, Staff, Bank and Ledger. Preview remains available without owning stock.

World Map regional cards expose Compare trade route. The preview needs neither owned goods nor a registered company; no inventory, contract, revenue or cash is created. Eight regional supply and demand tables are in economy/trade.json. Current FX quotes and Customs category tariffs are reused. The designer parameters are local-unit product prices, regional capacity/demand, route freight/default exposure, weekly sea departure, air speed/cost, banking fees, quote life, insurance coverage and daily hold warehouse rent.

EXW assigns collection/onward costs to the buyer. FOB has seller-paid origin handling and buyer-paid main carriage, transferring cargo risk at vessel loading. CIF additionally pays carriage and required insurance but retains FOB's loading risk transfer. DDP assigns costs, import duty and delivery risk to the seller. FOB/CIF reject air. Deal Sheet separates seller margin from buyer landed cost and demand ceiling; all costs carry home-dollar units, while buyer quote carries its currency. A 15% foreign-receipt drop plus seller cargo exposure is a labelled stress scenario, not a forecast. Insurance and L/C reduce distinct risks at a cost; no result is guaranteed.

Product ids: wireless_earbuds and desk_lamp. Terms: EXW, FOB, CIF, DDP. Transport: sea, air. Payments: tt_prepaid, tt_delivery, lc, open_account. Glossary: trade_terms, trade_rfq. Help: trade_quote. Stable controls: TradeSource, TradeDestination, TradeProduct, TradeQuantity, TradeTerm, TradeTransport, TradePayment, TradeInsurance, TradeRefreshRFQ and TradeRoute_<region>.

Trade acceptance includes actual supplier purchases, Jobs invoices, document-backed L/C settlement, customs rent, recurring contracts, agency/warehouse inventory, staff, collateralized FX hedges, and temporary crises. The 120-day three-strategy report includes operating costs and real cargo/credit losses. Full rendered walkthrough results are reported separately from the targeted trade tour.


## Trade execution

`meridian_trade_desk` in Financial is the registered brokerage office; lease `meridian_trade_office`. Customs House provides the registration desk. Active trade projects buy paid supplier cargo and bind an actual shared Jobs buyer contract, shipping papers, customs receipt, delivered quantities, bank documents and realized exchange settlement. Current execution tests cover missing-paper holds, daily warehouse rent, supplier returns, LC settlement, regional capacity and closed-company callbacks. These workflows use the shared simulation and ordinary payroll; already completed and impossible/closed flows have no-soft-lock coverage.

The registered brokerage can lease `meridian_bonded_warehouse` at Customs House after three collected trades. Repeat contracts create three new shared Jobs, one per thirty days, at refreshed RFQ prices. Insufficient funds or a noncompetitive route pauses the contract; resume and end remain available. Agency registration requires the paid warehouse lease and an actual application fee.

Freight forwarder `ingrid_solberg` explains shipping at `cargo_terminal` (`ingrid_freight`); Omar Haddad handles introductions at Customs House. Marcus Reed shares Nexus Bank's trade finance desk. `FXForward` is the shared #42 cash-settled module: contract-backed receipts are included in exposure, open hedges subtract from it, fees and worst-case collateral are real cash, and company closure settles open hedges. Air rerouting pays a real additional freight charge; waiting resumes after three days and elevated freight expires after seven days. Agency purchases into the leased bonded warehouse feed the existing ecommerce stock and record inventory, never external sales.

Events `trade_port_strike` and `trade_fx_volatility` are triggered only by actual booked cargo and contracted foreign receipts. Their wait/reroute and spot/forward alternatives change real schedules, expenses and exposure. The `trade_coordinator` staff role works at the leased Meridian office, processes paid cargo papers and bank documents during working hours, and uses ordinary weekly payroll. Bank lending includes paid trade cargo and its shared receivables.
