# Market, rivals and city news (#90)

Implemented in the current PR target: a seeded daily interest-rate/cycle/inflation process, two rivals per data-defined industry, weekly pricing/quality/advertising/expansion decisions, normalized market shares, staff recruitment offers, late-game rival acquisitions, Company OS Market and phone City news.

The optional `macro`, `rivals` and `city_news` sections contain plain saved JSON. RNG states are decimal strings, independent of the operating RNG. Daily numeric state is quantized and clamped for reproducible JSON round trips. Quotes for saves without these sections remain neutral; entering/playing the city initializes them lazily. Dates and last-processed day/week prevent repeated decisions after load. History/queues are bounded.

All tunable values live in `economy/macro.json` and `economy/rivals.json`. Interest rates mean-revert with bounded shocks. A shock expires after 12 days; replacement shocks may occur, but individual effects are never permanent. Four cycle phases use index/trend. Automotive and real-estate demand have stronger rate/cycle sensitivity than cafés. Existing `years.json` rates and supplier costs overlay this process; scripted years and story files are retained.

Rival state holds virtual operating cash and market weights, separate from player books. Weekly simulated trades record quantity, charged unit price and revenue; market share, industry demand and seeded variance determine the number of units sold. Advertising and locations consume rival cash. Insolvent firms exit, or a solvent same-industry rival buys their location. Shares include outside firms and the player; absent/closed operators have zero share. Café, ecommerce, SaaS, logistics and freelance demand use the macro/competition factors; supplier/fuel costs and new wage quotes use inflation. Existing employee contracts remain fixed unless the player agrees to a raise.

Staff offers have two concrete choices: match weekly salary (recurring payroll increases), or lose the employee's work capacity. Unanswered offers expire after three days, with no permanent pause. Offers cannot be answered twice. Closing a company clears its offers. Acquired rival presence costs company cash through Ledger, records an investment, affects competition and awards no automatic dividends or rival cash. The independent-company age gate is 180 days; a sold/closed company cannot buy. Closure writes off the acquisition asset once.

The City news feed publishes one macro headline plus up to two queued rival/event/achievement items per day. It persists cursor/day state, never duplicates a day's batch and caps stored history. Company OS renders market content through a separate `MarketView`, limiting overlap with the industry framework's tab changes. Navigation scrolls so 44-pixel buttons remain reachable.

## Dependency boundary

The specified PR target has five operating industries; the newer gifted branch has the industry framework and additional industry systems. Current rival data covers all 12 declared industry IDs without claiming seven planned businesses are playable. `Rivals.competitors(industry)` exposes dynamic price/quality/share snapshots, included in current contract and freelance offers. The RFQ/brief callers and fixed competitors are absent from this target and require integration on the newer branch before that acceptance line can pass. The shared acquisition entry is `Acquisition.buy_rival(id)`; it does not alter the story offer to sell the founder's company.

## Validation

Six unit tests cover seed/path reproduction, saved RNG resume, bounded rates/cycle, shock expiry, industry sensitivity, rival bounds/share sum/bankruptcy, staff choices/expiry, paid acquisition/closure, bounded 1–3 daily news and neutral legacy quotes. The related `--bot=market` tour uses the normal café policy for 120 days at seeds 90/91/92 and renders market/news/poaching. No fixture income or forced orders. See ticket evidence for measured gains and limitations. Three seeds illustrate variability; they do not prove a risk-free strategy or every industry is balanced.
