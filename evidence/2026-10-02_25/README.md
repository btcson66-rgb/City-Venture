# #25 review evidence

The 80 JPGs cover both languages: nine Company OS tabs, empty/occupied packing, banking, loan prerequisites and an offer, registration permits, future-era permits, current month books and event choices. Open explanation cards appear beside the source label. The historical books are loaded from the genuinely played 0.1.8 fixture; screenshot-only future-era permits use an explicit year-8 fixture.

## Self review

- Reused existing glossary IDs, added 28 specific English/Traditional Chinese entries, and scanned literal badge IDs and event choice IDs in unit tests. Freelance explains invoices, avoiding implying its one-off work has recurring subscription income.
- Found legacy English ledger memos in the Traditional Chinese bank/finance views. Added display-only template translation; tests cover every memo in four genuine legacy saves without rewriting their books.
- Fixed missing stock caption translation, added units and whole-dollar amounts, moved supplier terms to a separate line to keep purchase controls inside the panel.
- First feasible actions receive the primary style; blocked packing/account creation/purchase/fit-out actions cannot be primary. Display-only purchase checks cover MOQ, availability, storage, licences and settlement costs without posting money.
- The English walkthrough attempted another purchase after consuming the available budget. It now waits for the next business day when the actual purchase control is unavailable; no money or chapter state is injected.
- Removed chapter-card occlusion in the screen tour, and explicitly captured the contracts tab. Both language screen tours finish with zero failures. All changed panels and opened cards were visually inspected.

See the PR for the final command results. macOS/Linux packages are exported, but physical play on those operating systems is not claimed.
