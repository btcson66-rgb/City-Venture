# #88 Touch / controller — development evidence

Stacked on Draft PR #101. Target fetched at a9124264. Final pre-merge gates remain pending under the user's updated continuous-work instruction.

- Godot 4.5.1: **283/283 unit tests passed in 16.0s** (five input tests).
- Native rendered short tour: **275 checks, 0 failures**, no runtime errors. Actual D-pad visits all enabled controls in 28 management modals, nine minigame intros and the character creator. B returns from closable screens; a mandatory event uses A to choose/acknowledge, insolvency uses A to rescue. It does not complete every business form or minigame play round.
- i18n: 3097 messages / missing 0; wiki_check OK (3830 assets / 191 ids).
- JPGs show 844×390 landscape, controller focus, and recorded Android-touch emulation in HeadlessChrome 149.0.7827.55, SwiftShader WebGL2. Chrome snapshots are frames from a recorded Playwright context, not a physical phone.
- Web audio analyser: output peak 0 before first touch, about 0.124 afterward; fullscreen entered successfully; no browser runtime errors. See chrome_result.json. First touch opens Settings. Context state alone was insufficient evidence: it was already running while output was silent.

## Self-review fixes

1. Reused collision-clearance navigation; unreachable points never teleport, manual movement cancels the route, and blocked routes time out.
2. Kept controller events after keyboard-map changes without duplicate bindings; prevented background HUD focus while walking.
3. Explicit neighbor wrapping, scroll-to-focus and primary-first focus keep enlarged controls reachable.
4. Enlarged targets broke fixed character creation rows: wrapped the existing page in two-axis scrolling and fixed its zero-sized root exposed by Chrome screenshots.
5. Prevented pinch-release from starting a walking route; clamped zoom and rejected nonfinite ratios; two-finger list motion scrolls without page zoom.
6. Converted Web audio players to stream playback after an actual silent-output reproduction with dynamically created buses. Audio now starts after the first gesture.
7. Localized pre-boot overlay labels after locale initialization and enabled full landscape width after touch.
8. Preferences and game-save fields are unchanged; ephemeral finger/path/focus state is not serialized. Controller Company OS retains terminal access checks and closed-company business logic is unchanged.

## Remaining gates

Physical iOS Safari, actual hardware gamepads, every business-state branch, long-press/map gestures on real devices, and full walkthrough remain unverified. The third-ticket full walkthrough is deferred to the pre-merge integration gate under the user's latest instruction. beta_audit.py is absent in this target; inherited #98 performance/coverage blockers remain. No target/main merge or deployment.
