# Touch and controller input

Implemented by InputAccess, using #87 Preferences/InputMap. No persistent game-state keys are added.

- First touch enables the landscape HUD and full viewport width. Portrait devices show a rotate hint. Nearby interactables expose TouchInteract; terminal access rules still apply.
- Ground taps plan through the pedestrian clearance grid. Keyboard/stick input or a blocking modal cancels walking. A stalled route stops after one second; unreachable taps show the next action.
- BaseButton and interactive fields keep at least 44×44 logical pixels. Main menu, character creator, modals and phone lists scroll; focus follows controls into view. Long press opens existing tooltip/help content. Two fingers zoom maps between 75% and 250%; list gestures pan the innermost scroll area.
- Left stick moves; A interacts/confirms, B returns, Y opens phone, X requests the nearby Company OS terminal, Start pauses. D-pad wraps enabled controls and begins at the primary action. Rebinding keyboard controls preserves controller events.
- Web audio queues music until a touch/key/mouse gesture. Players use stream playback to retain dynamically created audio buses in Godot 4.5.1 Web. Browser canvas disables page gestures; the HTML fullscreen control requests standard or WebKit fullscreen when available. Mobile texture compression is included.

Run --bot=input --lang=zh_TW --out=<absolute QA directory> for the related short tour. Evidence and explicit unverified device/integration cases are in evidence/2026-10-02_88/README.md. Physical Safari and hardware-pad acceptance remain pre-merge checks.
