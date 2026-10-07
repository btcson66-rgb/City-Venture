---
name: playtest-capture
description: Capture CITY VENTURE rendered walkthrough evidence before and after gameplay changes, with reproducible commands and a brief novice-experience review.
---

Read docs/CODEX_GUIDE.md and the bot code for supported arguments. Use a separate QA save/output location, never the player's existing saves. Record commit, engine version, locale, resolution, settings, bot and starting step. Keep screenshots under evidence/<date>_<issue>/before and after; JPG around quality 85, no more than 20 MB per ticket.

Linux example from the guide:

```sh
XDG_DATA_HOME=/tmp/cv_qa xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=walkthrough --lang=zh_TW --out=/tmp/cv_qa/out
```

Use `--from=ch10` only when that chapter actually covers the change. Use targeted `--bot=minigames`, `screens` or `tutorial` tours during development; update the walkthrough when the changed flow requires it. Final first-job acceptance starts from a new game and includes practice steps, formal work, payout and recovery. On Windows run the installed Godot console executable directly with the same game/bot arguments; xvfb-run is a Linux display wrapper, not a Windows dependency. Verify QA user-data isolation supported by the engine/project before launching.

Check walkthrough_result.json for failures and english_audit.json for new untranslated text. View the images, not only the exit code. Capture matching before/after states at desktop and mobile layouts when UI changes, including large text and both locales as required by the issue.

In five lines or fewer, describe what a novice saw, pressed, understood, enjoyed and found confusing. Add a separate experienced-player replay note. Report missing evidence explicitly; do not fabricate screenshots or convert mocks/source review into successful playtests.
