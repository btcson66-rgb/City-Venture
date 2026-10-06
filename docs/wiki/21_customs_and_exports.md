# Chapters 13–14: export and customs systems (#31)

Implemented: ch13_first_order_abroad and ch14_customs follow ch12_regulation_scale. Year 9 Global Consolidation is active. Old season-one ending saves resume the export chapter without replaying completed receipts. Travel remains separate.

Chapter 13 reads Year 9 news, opens international banking with Marcus/teller at Nexus Bank, opens Northridge and saves local prices, ships an actual international order and converts a weekly payout. Its income card shows historical sale, platform fee, international freight including allocated pickup fee, exchange movement, bank spread and net receipt before stock/packing. No foreign sale or wallet movement is treated as home cash.

Ines Duarte (`ines`, conversation ines_customs) is in customs_house on weekdays 09:00–16:00, using uniform_officer as an interim outfit. The existing marble room opens to visitors; its notice becomes a permanent customs guide. A company-laptop copy offers an alternative when office hours do not match. Marcus has a separate marcus_global explanation before normal lending conversations.

Declarations are per company, region and listing: ddp prepays destination duty, ddu leaves duty to the buyer on arrival. Duty uses the actual product class and region rate. Product classes: electronics, household, textiles, general. DDP has a 2% refusal probability, DDU 12%, in addition to normal product return risks. Neither policy guarantees profit. Orders snapshot declarations; later edits do not change accepted promises.

customs_hold blocks wrong classifications or unpaid DDP before transit. The event has three meaningful choices: documents pay duty plus half the $25 fine and add 2 days; immediate payment pays duty plus the full fine; withdrawal restores goods without refunding freight. The documents/payment routes cover arrival duty so buyers are not charged twice. Seven unresolved days withdraw the goods automatically. Repeat checks cannot duplicate inventory or charges. Closed-company decisions are removed during liquidation.

Chapter 14 can recognize an earlier Ines conversation/guide, policy, correct code and actual deliveries. Its trial waits 3 days for scheduled returns to surface and uses the newest 10 qualifying deliveries and a return rate below 15%; after 14 days it uses 5 deliveries. Maya suggests lower local prices or ads. An explicit review/pause ends the chapter without setting the success flag or claiming sales; clearing storefront prices stops new orders and preserves containers for already accepted parcels and foreign balances. Company-bound closure skips impossible objectives honestly.

Glossary: ddp, ddu, tariff_code, duty, customs_hold; help: customs. Tests cover actual DDP/DDU money, declaration holds, document correction and withdrawal, both chapters already done and impossible, failed-trial alternatives, and lazy save compatibility. Dedicated art is Planned; no assets are modified.
