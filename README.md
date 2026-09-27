# CITY VENTURE

A modern pixel-art business-life RPG. Build · Live · Connect · Grow.

- **Product baseline:** [`docs/reference/CITY_VENTURE_MASTER_HANDOFF_FOR_CLAUDE_CODE.md`](docs/reference/CITY_VENTURE_MASTER_HANDOFF_FOR_CLAUDE_CODE.md)
- **Spec readback:** [`docs/CITY_VENTURE_SPEC_READBACK.md`](docs/CITY_VENTURE_SPEC_READBACK.md)
- **Audit:** [`docs/CURRENT_PROJECT_AUDIT.md`](docs/CURRENT_PROJECT_AUDIT.md)
- **Architecture:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Roadmap:** [`docs/ROADMAP.md`](docs/ROADMAP.md)
- **Engine decision & store path:** [`docs/ENGINE_DECISION.md`](docs/ENGINE_DECISION.md) · **QA:** [`docs/QA_REPORT.md`](docs/QA_REPORT.md)
- **Data schema:** [`docs/GAME_DATA_SCHEMA.md`](docs/GAME_DATA_SCHEMA.md) · **Art manifest:** [`docs/ART_ASSET_MANIFEST.md`](docs/ART_ASSET_MANIFEST.md) · **Story:** [`docs/STORY_IMPLEMENTATION.md`](docs/STORY_IMPLEMENTATION.md)

Engine: Godot 4.5.x (project in `game/`).

## Run

```bash
godot --path game                       # play (1280×720 window, 640×360 pixel canvas)
```

Languages: English · 繁體中文 · 简体中文. Switch them on the main menu or in the pause menu (Esc), or start with
`godot --path game -- --lang=zh_TW`. Translations are in `tools/i18n/zh_TW.json`; run `python3 tools/i18n_extract.py --check`.

Controls: WASD/arrows walk (Shift run) · E/Space interact · Tab phone · M city map · hold T fast-forward · Esc pause/close.

## Build, test, evidence

```bash
pip install -r tools/requirements.txt   # numpy, pillow, opencv (art conversion)
tools/build.sh                          # art → district layout → import → unit tests → Windows + Linux export
godot --headless --path game res://tests/test_runner.tscn                  # unit tests
godot --headless --path game -- --bot=walkthrough --out=/tmp/wt            # full slice played by real input
```

- QA report: [`docs/QA_REPORT.md`](docs/QA_REPORT.md) · evidence: [`evidence/vs001/`](evidence/vs001/)
- Art is generated/converted by code in `tools/art/` (`concepts.py` converts the approved concept boards in
  `docs/reference/concept_boards/` into game-ready sprites; see the art manifest for what is converted vs generated).
