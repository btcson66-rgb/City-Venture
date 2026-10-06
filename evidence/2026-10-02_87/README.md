# #87 Settings / accessibility — development evidence

Stacked on Draft PR #100 (#98); target `claude/exciting-bardeen-y71ixv`. Fetched target remains `a9124264`.
The user's latest instruction permits advancing through the stack, with final checks before merging.

- Godot 4.5.1: **278/278 unit tests passed in 16.2s**. Five new preference tests and a revised held-fast-forward test.
- Short native OpenGL tour: **112 checks, 0 failures**, no runtime errors. 28 management modals and nine minigame
  intro screens × three UI scales (80/100/150%) at extra-large font, plus a usable title scroll check.
- i18n: **3094 msgids, zh_TW missing 0**. wiki_check: **OK, 3830 assets / 191 data ids**.
- Ten JPGs: five settings pages, extra-large Company OS, three color-assisted reports with a -$55.25 Ledger expense,
  and extra-large 150% title screen. Generated save files and temporary cfg files are not committed.
- Full walkthrough / final integration review are deferred to pre-merge under the user's updated instruction.
- `tools/beta_audit.py` is absent in the fetched target. Inherited #98 performance/coverage gates remain blocked;
  neither parent nor this stacked PR is ready to merge. No target/main merge or deployment performed.

## Self-review fixes

1. Preserved cfg language/unknown sections and migrated legacy audio defaults without adding game-save fields.
2. Rejected conflicting, malformed and nonfinite settings; default key reset persists and does not duplicate events.
3. Fixed repeated font multiplication for newly created controls, and deferred callbacks to already freed nodes.
4. Made the title scroll area use actual viewport dimensions; corrected its empty layout and oversized heading.
5. Kept all modal content reachable through scrolling at extra-large fonts; recentered notifications using viewport size.
6. Subtitle delay never chooses answers or counts time while Settings is open; tested manual and paused behavior.
7. Fast-forward returns to normal on release and respects pause reasons; Company OS retains terminal access checks.
8. Updated live HUD key hints and migrated numbered minigame choices/undo to InputMap.
9. Regenerated PO files with LF endings, using a separate zh_TW_settings fragment to reduce shared-file conflicts.

## Acceptance limits / pre-merge checks

The automated scan proves panel bounds and scrolling, not every business-state branch or every minigame play/results
screen. Those remain targeted review candidates in #89 and the final walkthrough. The color modes assist palettes;
medical effectiveness and every color-vision profile are not claimed. Reduced motion covers camera smoothing and toast
repositioning. Native window modes are implemented; browser mode intentionally hides them. Ambience has a bus but
ambient players/assets belong to #97. Settings write failures display a warning and remain an explicit storage error.
Economy/crisis/company-closure logic is unchanged; all existing save/ledger/company tests remain green.
