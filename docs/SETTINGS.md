# Device settings (#87)

The title screen and pause menu open the same five-page Settings modal. Changes apply immediately. `Preferences`
owns `user://settings.cfg`; it reloads the existing ConfigFile before each save, preserving language, guide settings
and unknown sections. No GameState field or save migration is added. Old `audio.music` and `audio.sfx` values load
when the new preference keys are absent. A failed write shows a storage warning; it is not reported as saved.

| Page | Values |
| --- | --- |
| Audio | Master, Music, SFX, Ambience: 0–100%; zero mutes the bus |
| Display | Windowed/fullscreen/borderless on desktop; UI scale 80–150%; four font sizes |
| Controls | Physical key assignments, conflict rejection, restore defaults; all assignments persist |
| Accessibility | Off/red-green/blue-yellow/high contrast palette assistance; reduced motion; subtitle delay 0–30 seconds; notifications 2–30 seconds |
| Game | Periodic autosave 5–120 seconds; launch speed 0.5–3 game minutes/real second; tutorial hints |

Subtitle delay zero means manual advance. Delays start after the complete line is revealed, stop while a modal is
open, and never choose an answer. Lifecycle and scene-change saves continue independently of the periodic interval.
Tutorial hints can be hidden without completing, resetting or deleting tutorial progress. Reduced motion disables
camera smoothing and animated toast repositioning; it does not stop gameplay timers or work animations.

`Preferences.BINDINGS` is the single default InputMap source. Actions include movement, run, interact, phone, map,
Company OS, pause, held fast-forward, confirm/cancel, bug report, numbered minigame choices and undo. Text typed in a
typing task remains actual text rather than an action binding. Esc cancels key capture. Confirmation/cancellation
also update Godot's `ui_accept`/`ui_cancel`. A malformed or conflicting persisted map restores the complete default
map, avoiding an unusable partial assignment. Company OS still requires approaching a terminal and respects its
existing access checks. Fast-forward doubles ordinary minute ticks only while held; release and every pause reason
stop the acceleration. It does not jump to a day or bypass a decision.

Font preferences scale from an original per-widget font size, including newly added controls, without repeated
multiplication. Main-menu content and all Modal-derived panels use scroll containers. Panels fit the current logical
viewport, including content scale changes; wide existing tables may need horizontal scrolling. This preserves their
columns without changing business calculations or story screens individually.

Color assistance is a presentation palette transform, not a medical color-vision simulation. Reports retain account
labels and signed money; settings toggles use ✓/✗ plus the available action. The Ambience bus is ready for ambient
players; this ticket does not add ambient audio assets (#97 remains a separate ticket).

## Development evidence

Run unit tests normally and the short `--bot=settings --lang=zh_TW --out=<absolute QA directory>` tour. It renders five
settings pages, extra-large Company OS, all three assisted-color monthly reports with a real Ledger expense, and an
extra-large 150% title screen. It scans all 28 concrete management modals plus nine minigame intro screens at 80%,
100% and 150%, with extra-large text. The scan checks panel containment and available scrolling, not every possible
business-state branch inside a modal. Full walkthrough and final integration checks remain pre-merge gates under
the user's updated continuous-work instruction. See `evidence/2026-10-02_87/README.md` for exact results.
