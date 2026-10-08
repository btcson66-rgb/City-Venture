# #167 Web touch validation (in progress)

Actual build/web, Chromium touch events, portrait 390x844, landscape 844x390,
tablet 1024x768, normal/extra-large text, zh_TW/en.

The opt-in `?cv_smoke=1` browser probe observes controls and state only.
The smoke sends touches and scroll gestures, never calls game methods or edits saves.

Implemented: initial touch detection, readable physical text, scrollable tall portrait
modals, larger phone, input-transparent world decoration, safe in-tree UI retirement.
Company OS contents/industry text and mini_game.gd are unchanged.

Validation is still running. Only completed logs count as passed. The final PR/evidence
report will replace this pending status with exact full matrix and package results.
WebKit is not installed locally; Safari is NOT VERIFIED. These are emulated viewports,
not physical-device or public itch.io measurements.