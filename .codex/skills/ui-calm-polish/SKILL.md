---
name: ui-calm-polish
description: Polish CITY VENTURE UI for calm focus, readable bilingual layouts and touch accessibility using the existing UIK and Art design constants.
---

Read AGENTS.md, the issue and the relevant UI. Keep one primary next-action button per screen. Use gold only for something that requires attention now; explanation, help, unread information and decoration use neutral C_DIM/C_MUTED/C_SKY tones. Hover may gently brighten an information icon.

Use UIK/Art spacing, fonts and palette constants, and Fmt.money for money. Preserve stable button names for bots. Small visual icons must retain at least a 24px touch target, readable focus and accessible tooltip/label. Do not reduce input hit areas to match tiny glyphs.

Capture the relevant rendered walkthrough screen at 1280×720 and the project's mobile layout. Check English and zh_TW, default and large-text settings. Inspect the images for clipped text, crowding, excessive emphasis and whether the main action is obvious. Record actual dimensions/settings; desktop screenshots are not proof of a physical phone test.

Attach concise findings and images. If a required layout has not been rendered, mark it NOT VERIFIED and describe why. Preserve Company OS tab structure and unrelated systems unless this ticket explicitly owns them.
