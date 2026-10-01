# 街道環境品質實機證據

起點：pull 最新 Claude 分支 `a57c87a9`。獨立分支 `codex/art-street-environment-quality`；本批沒有混入角色 PR #46 或車流 PR #49，也沒有修改 scripts / data / tests。

完成 7 種立面、13 種公共物件，共 58 個 PNG 與匯入檔，含原尺寸、正確 4× 與 emission-only 光罩。原尺寸全部保持；門、空白招牌、路燈 glow metadata 與新圖對齊。發光層只取檢查過的窗內光源／燈罩暖色亮部，不包含整面外牆或路燈金屬柱。

before/after 是兩套實際 Godot 截圖巡禮，各 53 張、63 步、0 失敗。comparison_*.png 只是並排原始截圖。day_night/ 是現有 District 渲染器的三街區日夜六張實拍；測試腳本放 tools/qa，不改遊戲邏輯。packed_preview 是素材尺寸預覽，不是遊戲截圖。

驗收：Godot import exit 0；228/228 tests passed in 17.0s；更新後巡禮 0 failure(s)，51.6s，英文審核 0。58 PNG/import 配對、4×、原尺寸、door/sign邊界與 emission-only 檢查通過。wiki_check: OK (1644 assets, 191 data ids)。map_label_check: OK。角色圖未修改，pose_check 不適用。

第一次乾淨工作樹 import 在 PixelifySans 字型匯入階段提早結束；保留首次與重試原始輸出。重試以及素材更新後正式匯入都成功。完整故事 40–60 分鐘 walkthrough 未執行，保持 Draft。

限制：建築原尺寸已替換實機；4× 建築尚需 Claude 接線。路邊 props 走現有高解析入口，獨立燈罩由现有發光入口使用。未變更地磚或所有街區物件，未將本批算成全遊戲完成。行人提升需角色 PR #46 合併並再檢查；車流提升在 PR #49。
