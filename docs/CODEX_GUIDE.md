# Engineering guide for Codex tickets

This is the working agreement for implementing GitHub issues labelled `codex`. Claude writes the tickets and reviews
every pull request before it merges. Read this file, the ticket, and the files the ticket names before you start.

## Branches and pull requests

- Start from the latest `claude/exciting-bardeen-y71ixv`: `git fetch origin && git checkout -b codex/<ticket-number>-<short-name> origin/claude/exciting-bardeen-y71ixv`.
- One ticket per branch and per **Draft** pull request, based on `claude/exciting-bardeen-y71ixv`. Put `Closes #<n>` in the PR body.
- Never push to `claude/exciting-bardeen-y71ixv` or to `main`. Never force-push a branch someone else pushed to.
- Keep a PR to its ticket. If you find a separate bug, open an issue with steps to reproduce instead of widening the PR.
- Paste the delivery checklist (end of this file) into the PR body and tick what you did. Say plainly what you did not do.

## The game in one paragraph

CITY VENTURE is a Godot 4.5.1 pixel-art business-life RPG (`game/`). Everything the player can do is data in
`game/data/**.json` read by `DataDB` (autoload), simulated by static modules in `game/scripts/sim/*.gd` (state lives in
`GameState.data[...]`, money moves only through `Ledger.post()` double-entry), and reached by walking to an interactable
in the world (`game/scripts/world/actions.gd`) or through a modal (`game/scripts/ui/modals/*.gd`). Time is a continuous
clock (`Clock`); modules hook `Sim.on_hour` and `Sim.schedule(t, "<module>.<kind>", payload)`. Company OS
(`company_os.gd`) is the in-game computer with one tab per business area.

Read these before touching an area:
- `docs/ARCHITECTURE.md`, `docs/GAME_DATA_SCHEMA.md` (every data field), `docs/STORY_IMPLEMENTATION.md` (chapters 1–12).
- `docs/wiki/` (world, districts, buildings, characters, core loop); `docs/wiki/13_core_loop_and_work.md` for the businesses.
- Existing modules as patterns: `scripts/sim/cafe.gd` (a business module), `scripts/sim/logistics.gd`,
  `scripts/sim/rails.gd` (story systems), `scripts/ui/minigames/route_game.gd` (a minigame).

## Code rules

- GDScript 4, tabs, static typing, short `##` doc comments on anything non-obvious. Match the code around you.
- Numbers that designers would tune live in JSON (`game/data/economy/*.json`), not in code.
- Every money movement goes through `Ledger.post()` / `Ledger.expense()` and keeps `Ledger.check_balanced()` true.
  Use existing accounts and expense categories (`Ledger.EXPENSE_CATEGORIES`); add a category only with a
  `CATEGORY_NAMES` entry.
- JSON numbers are floats: compare ids/weekdays read from JSON with `int(...)`, never `x in [1, 2]` on raw arrays.
- Old saves must keep loading. New state is created lazily (`static func S()` pattern) or added to
  `GameState.template()`; `SaveSystem._migrate` fills missing keys. Never rename or delete a saved key without a
  migration and a test that loads a save made before your change.
- Every release must add a save actually played in that version to `game/tests/fixtures/saves/`, with its source commit and capture log.
- Player-facing honesty: if a feature is a stand-in or planned, the text says so. Status words in docs:
  Implemented / Mocked / Placeholder / Planned / Blocked.
- New business ideas the player meets get a "!" explanation badge: `UIK.tip("<id>")` or `UIK.label_tip(text, "<id>")`,
  text in `game/data/help/glossary.json` as `{title, what, why}`. A new screen gets a help card in
  `game/data/help/help.json` (the `help_key` of the modal).
- Every new interactive button gets a stable `name` (e.g. `ReturnPO_<id>`) so the bots can click it.
- Don't edit `game/assets/` or `tools/art/` unless the ticket is an art ticket. Art arrives by file name; code checks
  `Art.has_tex()` / `Art.opt_tex()` and keeps a stand-in until the file exists.
- Never put AI model names or identifiers in code, commits, docs or PR text.

## Translation (zh_TW is required)

The game ships in English and Traditional Chinese. Every new player-visible English string needs a zh_TW translation.

1. Write the English in code wrapped in `I18n.t("...")` (UIK labels and buttons translate automatically), or in a
   data key the extractor reads (`DATA_KEYS` in `tools/i18n_extract.py`; add a key there if you invent one).
2. Add `"English": "中文"` to `tools/i18n/zh_TW.json` (load and dump it with Python `json`, `ensure_ascii=False, indent=0`).
3. Run `python3 tools/i18n_extract.py` until it prints `missing 0`. It regenerates `game/i18n/*.po`.

Style: natural Traditional Chinese, short and concrete. Keep person and brand names in English ("Okafor 先生",
"Dockside Motors"). No real crypto names or logos anywhere; say 數位美元 / digital dollars.

## Tests and bots (all must pass before a PR leaves draft)

```bash
cd game
godot --headless --path . --import                                   # once after pulling or adding files
godot --headless --path . res://tests/test_runner.tscn               # unit tests: all pass
cd ..
python3 tools/wiki_check.py                                          # docs mention every data id and asset
python3 tools/i18n_extract.py                                        # missing 0
```

- Add unit tests in `game/tests/unit/test_<area>.gd` (see `test_cafe.gd`): the rules, the money, the edge cases, and
  `Ledger.check_balanced()`.
- Walkthrough bot (the whole game in Chinese, 40–60 minutes of real time; run it in the background):
  ```bash
  XDG_DATA_HOME=/tmp/cv_walk xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
    --resolution 1280x720 -- --bot=walkthrough --lang=zh_TW --out=/tmp/cv_walk/out
  ```
  `--from=ch10` skips to chapter 10 for a quick rerun. If your ticket changes a flow the walkthrough plays, update
  `game/tests/walkthrough/walkthrough.gd`; if it adds a flow worth guarding, add a step there. Result:
  `out/walkthrough_result.json` must list 0 failures, and `out/english_audit.json` must not list your new text.
- Screenshot tours: `--bot=shots`, `--bot=screens`, `--bot=minigames`, `--bot=tutorial`, `--bot=harbor`.
  Attach the screenshots that show your change to the PR (under `evidence/<date>_<ticket>/` with a short README).
  Keep evidence small: JPG (quality ~85) for screenshots, at most 20 MB per ticket. Don't commit large 4× masters or
  intermediate renders under `docs/art_sources/`; keep prompts, SVGs and one reference image per asset. Every MB stays in git history.

## Delivery checklist (paste into the PR)

```
- [ ] Branch from the latest claude/exciting-bardeen-y71ixv; Draft PR; "Closes #<n>"
- [ ] Only the ticket's scope; no assets changed unless it is an art ticket
- [ ] Unit tests added/updated; godot test_runner: all pass (paste the last line)
- [ ] Walkthrough (zh_TW): 0 failures (paste the last line); english_audit clean for new text
- [ ] python3 tools/i18n_extract.py: missing 0; python3 tools/wiki_check.py: OK
- [ ] Old saves still load (test or manual check described)
- [ ] New ideas have "!" badges (glossary) and new screens have a help card
- [ ] Docs updated (GAME_DATA_SCHEMA, wiki page, STORY_IMPLEMENTATION if story)
- [ ] Screenshots of the change in evidence/<date>_<ticket>/
- [ ] Anything not done or uncertain is listed in the PR body
```

## New industry checklist (#64 onwards, including #71)

- 收入只能來自可追溯的交易（訂單、合約、客流 × 單價），不准有「每日 +$X」（規格 R4）。
- 核心玩法要真的不同：每個產業有自己的決策畫面或小遊戲，至少 3 個有取捨的經營參數，以及至少 2 種危機事件（`data/events/`）。
- 參數都放在 `data/economy/<id>.json`。`data/businesses/<id>.json` 的 `status` 改成 `active`。
- 有地點：建築、室內、NPC、對話，Company OS 分頁，`!` 說明、help 卡，按鈕都有穩定的 `name`。
- 能和既有系統互動：貸款額度要算進該產業的資產和應收、員工角色、事件、Timeline、存讀檔（舊存檔要能讀）。
- 成長路線至少 3 階（例如「小 → 中 → 大」），每階有解鎖條件和實際差異。
- 測試：`tests/unit/test_<id>.gd` 涵蓋開業門檻、一個完整營運循環、ledger 平衡、危機事件、關閉公司。walkthrough bot 要加 `_<id>` 段落，從開業跑到第一筆收入。
- 美術：列出需要的檔名，用 `Art.has_tex()` 加既有素材做 fallback，畫面不能出現破圖或「planned」字樣。附美術需求清單 `docs/wiki/90_codex_art_backlog.md`。
- 繁中翻譯：`python3 tools/i18n_extract.py` 要顯示 missing 0。`python3 tools/wiki_check.py` 要通過。
- 平衡：用 `tools/qa/` 的 bot 模擬 120 天，三種策略（保守、一般、激進）都不能穩賺不賠。報表放在 evidence。


- Before continuing the stack, self-review save/load, closed-company guards and edge cases.
- The 120-day balance report must retain all three strategies and downside outcomes; segment totals must equal the company total.
- Inspect JPG evidence for every new screen and district: units on numbers, no overflowing or untranslated text, ✓/✗ plus next step for boolean prerequisites, and the primary button is the next action.
- Keep each ticket’s evidence at most 20 MB. Stacked Draft PRs follow the user-authorized dependency order.

## Continuous mode (two sessions, stacked branches)

When Claude asks for continuous mode, work through your session's list in `docs/ROADMAP.md` without waiting for reviews.
- If the previous ticket's PR is not merged yet, branch the next one from it: `git checkout -b codex/<n>-<name> codex/<previous>`.
  Open each PR as a Draft against `claude/exciting-bardeen-y71ixv`; first line "Stacked on #<previous PR>, merge in order", then `Closes #<n>`.
- Before starting and before opening a PR, fetch and merge (never rebase) the latest `claude/exciting-bardeen-y71ixv`.
  Conflicts: regenerate `game/i18n/*.po` with `python3 tools/i18n_extract.py`; keep both sides' keys in `tools/i18n/*.json`, `data/**/*.json`
  and `docs/wiki/*.md`; keep both behaviours in code (registry entries are separate list items).
- Put new translations in `tools/i18n/zh_TW_<topic>.json` to keep merges small.

Self-review before the next ticket (all must hold):
1. Unit tests green; `i18n_extract --check` missing 0; `wiki_check` OK; `tools/beta_audit.py` 0 hits.
2. While developing run unit tests plus the ticket's short tour; run the full rendered walkthrough only every third ticket
   (it takes over an hour without a GPU).
3. Every spec line done, or explained in the PR. Numbers carry units: `Fmt.money` for unit prices, fees and memos, `money0` only for large
   totals. Yes/no conditions show ✓/✗ plus the next step, never 0/1. At most one primary button per screen, and it is the player's next
   sensible step; decisions mark one only when the data says `recommended: true`.
4. Revenue only from traceable trades (R4): never book income for something that did not happen; savings reduce a cost that was really paid.
5. Crisis effects decay; paused flows resume or time out; every event has at least two real choices; every chapter and side story has
   "already done" and "no longer possible" tests (no soft-locks).
6. Balance bot: at least one sensible strategy profits on average, none is risk-free.
7. Re-read your diff for save/load, old saves, edge values and company closure. Evidence as JPG, at most 20 MB per ticket.
At the end, report a table: PR link, test count, issues your self-review fixed, open doubts.
