# Overseas markets — implemented systems (#30)

ShopLane Global shares domestic ecommerce listings, stock and packing tables. Overseas travel and chapters 13–14 are separate work (#31); markets currently unlock in World year 9 or `global_markets_open` / `region_unlocked:<region>`.

| Region | Currency | Start home dollars / foreign unit | Population (million) |
| --- | --- | ---: | ---: |
| northridge | NRD | 1.10 | 12 |
| auroria | AUR | 0.85 | 16 |
| lumina | LUM | 0.15 | 24 |
| zenkai | ZEN | 0.55 | 9 |
| almeria | ALM | 0.40 | 14 |
| solterra | SOL | 0.65 | 11 |
| karu | KAR | 0.22 | 18 |

A registered live company first opens domestic banking, then pays the one-time international account fee of $150 at Nexus Bank. Company OS → Sales → Overseas opens a storefront and saves local-currency prices for existing listings. Unsaved prices take no orders. Regional population and product-category multipliers adjust the existing demand model; prices remain within the product's home-equivalent bounds when saved.

Economy couriers use international_economy (7–14 days); express uses international_express (7–10 days). Shipping cost is (base fee + region distance in days × cost per day) × shipping index. Domestic vans cannot deliver overseas. Existing packing, courier pickup, returns and disputes continue to apply.

Delivery books foreign receipts at the day's quote. The existing two-day hold and weekly payout move foreign units into a wallet, without realizing exchange gains. Finance permits keeping foreign units or converting them at the current quote less 1.5% spread; automatic conversion runs after weekly payouts. FX can improve or erase a sale's margin. Refunds reverse historical revenue; buying new foreign currency to cover a refund realizes a difference. Closure converts foreign assets once and cancels pending overseas parcels before liquidation.

Glossary: fx_rate, fx_spread, fx_gain_loss, international_shipping, overseas_storefront. Help card: global_markets. Region cards display currency, quote, delivery days, industries and the company's gross regional revenue; locked markets explain Chapter 13.

Daily quotes use a separate saved random stream, mean reversion and bounded rates. Temporary volatility shocks expire. JSON roundtrip preserves the path with sorted currency keys.

Validation: test_global.gd covers seeded quotes, account/store repeat actions, unavailable markets, full order/FX cycle, automatic exchange losses, refunds, shared receivables, boundaries, closure and old-save initialization. The global_markets short tour uses fixtures for company/stock/customer/time; its banking, store, price, packing, courier and conversion buttons use real input. It is not a full chapter walkthrough.
