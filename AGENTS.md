# CITY VENTURE: fun first

玩家是來玩遊戲的，不是來上班的。每次改動先問：這樣做，玩家有沒有更開心？

Read the issue and [engineering guide](docs/CODEX_GUIDE.md) before work. Existing R rules remain valid, including R4 traceable transactions, R15 no universally correct judgment answer, R16/R17 no numerical bonuses, balanced Ledger entries, old-save compatibility and no soft-locks. When an R rule conflicts with an F principle, **F takes priority**: regulatory processes may become one meaningful step or be delegated to an assistant. Preserve the economy's accounting integrity.

## F1–F8

- **F1 第一次一定教**：任何玩法首次出現都提供一步一步的練習；亮起現在要按的按鈕，其他操作暗掉。練習不計時、不計分、不會失敗；「?」隨時可以重看。
- **F2 預設沒有時間壓力**：倒數、客人離開及速度壓力僅限玩家主動選擇的挑戰模式。正常收入不依賴挑戰。
- **F3 只顯示現在用得到的**：未解鎖的功能、分頁、章節隱藏；最多預告下一個，灰色不可點，只列解鎖條件。
- **F4 一個畫面一個決定**：只留一個主要行動；進階選項收進「進階」摺疊區。
- **F5 雜事可以自動化**：補貨、繳費、排班、報稅、續約等重複管理有「交給助理／自動處理」。結果合理但不是最佳，可切回手動。
- **F6 字要少**：卡片最多兩行說明、三個數字；長說明放在「?」。
- **F7 失敗要溫和**：可以重試；懲罰不打斷遊玩，不會一次破產或卡關。
- **F8 視覺要安靜**：金色和強調色只留給現在真的需要處理的事；提示、說明、裝飾低調。

Apply these principles within the current ticket; do not use them to authorize unrelated whole-system redesigns. Phone messages, Company OS tab structure and other sessions' tickets stay outside this session's scope.

## Project skills (read the files even if skills are not automatically loaded)

## F9–F10

- **F9 每 2–5 分鐘一定有進展**：一個小目標完成、一個獎勵、一個新東西解鎖，或一個有趣的事件。以真實遊玩時間驗證，不能用遊戲日期或來源稽核代替。
- **F10 不用很真實**：真實感只在讓遊戲更好玩時才保留。等待、文書、扣款，能縮短就縮短。縮短等待仍跑真實交易與 Ledger，不以虛構收入換刺激。

設計與研究來源見 [docs/FUN_LOOP.md](docs/FUN_LOOP.md)。

- [.codex/skills/game-feel-review/SKILL.md](.codex/skills/game-feel-review/SKILL.md): run before and after gameplay/UI work; attach F1–F8 evidence.
- [.codex/skills/ui-calm-polish/SKILL.md](.codex/skills/ui-calm-polish/SKILL.md): check quiet UI, typography, touch targets and localization.
- [.codex/skills/playtest-capture/SKILL.md](.codex/skills/playtest-capture/SKILL.md): rendered walkthrough, before/after screenshots and novice experience.

## Delivery

One issue per branch and Draft PR; user-authorized stacks descend from the preceding branch and target `claude/exciting-bardeen-y71ixv`. Include `Closes #<issue>`. Do not merge or release. Before advancing, run all Godot unit tests, `python tools/i18n_extract.py --check` (zh_TW missing 0), `python tools/wiki_check.py`, `python tools/beta_audit.py`, and review old saves, Ledger balance and no soft-locks. Record unresolved gates honestly; rendered screenshots or passing tests alone do not establish the whole player experience.
