# #164 evidence

Implementation: `3e44260d`; stacked on #165 `ac017d50`; Godot 4.5.1 Windows, OpenGL3. All saves isolated using APPDATA in D:/cv164-qa/<run>/user.

[Every matched screen, before / after](GALLERY.md) · [Review and comparison](../../docs/FUN_AUDIT_ROUND2.md).

Before: detached #165 worktree D:/City-Venture-164-baseline, the recorded capture/bootstrap scripts in checks. After: game/tests/walkthrough/calm_screens_tour.gd and calm_active_tour.gd. Named fixtures use same seed and native setup. Mobile is a desktop-rendered 640×360 layout, not a physical device test.

Commands (PowerShell, from repository root; use the installed godot console executable):

```powershell
$env:APPDATA='D:/cv164-qa/<run>/user'
godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=calm_screens --lang=zh_TW --out=D:/cv164-qa/<run>
godot --path game --rendering-driver opengl3 --resolution 640x360 -- --bot=calm_screens --lang=en --calm-large --out=D:/cv164-qa/<run>
godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=calm_screens --lang=zh_TW --calm-guides --out=D:/cv164-qa/<run>
godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=calm_active --lang=zh_TW --out=D:/cv164-qa/<run>
godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=walkthrough --lang=zh_TW --checkpoint3=D:/cv164-qa/<run>/chapter3_actual.json --out=D:/cv164-qa/<run>
godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=walkthrough --lang=zh_TW --from=industries --out=D:/cv164-qa/<run>
godot --headless --path game res://tests/test_runner.tscn -- --junit=D:/cv164-unit-head.xml
python tools/i18n_extract.py --check
python tools/wiki_check.py
python tools/beta_audit.py
python tools/qa/map_adjacency_check.py
```

Full new-game main: 0 failures, 344 images, 6036.9 s. Includes all 24 real chapters and industry/personal/save tours. The post-ch24 actual compressed save has all 17 assistants enabled; its SHA256 and tasks are recorded in actual-story-manifest.json. It started before the final guide/guard/layout refinements; final-head all-industry and unit reruns are separate records. No claim of hot-reloaded GDScript.

Early all-industry diagnostic failed two energy clicks while layout was settling. Real-click/layout retry fixed this; targeted energy retry passed, and the final-head all-industry rerun supplies acceptance evidence. Diagnostics are described, not mislabeled passing.

English audit: main has 15 entries, all inherited person/company/brand names or the existing beta version token. Guide tour has existing beta. Calm-only zh screens have 0. Newly authored strings are fully translated (zh_TW 0 missing). Full names are intentionally kept English under CODEX_GUIDE.

Screens: original resolution JPG85, selected full-main scenes plus every matching calm screen in both languages and layouts. Physical phone, low-end/Web performance and Session G packaging/CI are not verified by this evidence.

Final-head acceptance: 1000/1000 units in 458.9s; 78 rendered industry images, 0 failures in 529.1s. Original packed-save fallback decompression diagnostics and exit RID/ObjectDB warnings remain in the unit log; no SCRIPT ERROR or Parse Error.
