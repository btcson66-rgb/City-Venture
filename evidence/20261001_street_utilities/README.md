# 街道公共設施美術實機驗收

起點：最新 Claude `9145015`，先 pull，獨立分支 `codex/art-street-utilities-quality`。不混入角色、車流或建築批。

本批 22 種公共設施／市集物件、48 個原尺寸與4× PNG及 import，包含數位廣告屏與串燈的獨立亮部光罩。原尺寸、原metadata及圖格位置不變。只動美術、工具、wiki與證據，没有動 scripts / data / tests。

before/after 各53張、63步，均0失敗，英文審核0。comparison_*.png 是未改內容的實機截圖並排；packed_preview是素材預覽，不當作實機。前後巡禮的隨機行人與車流位置可能不同。

Godot import exit0；251/251 tests passed in16.7s；更新後 BOT FINISHED — 0 failure(s) ·50.7s real。48PNG/import配對、4×、既有尺寸及獨立光罩檢查通過。wiki_check: OK (1638 assets,191 data ids)；map_label_check: OK。角色未修改，pose_check不適用。完整故事40–60分鐘walkthrough未執行，維持Draft。

告示牌、導引牌、菜單板、旗幟及地鐵識別板都留白，文字／識別符號需要程式疊字。這些入口沒有接線不得稱完整。三個攤位的屋頂、木框與販售物件保持可辨識；串燈實機使用既有overhead位置和獨立光罩。

全遊戲優化尚未全部完成。其他行人需要角色PR #46，車流在#49，建築與植栽在#50；本批不代表其他類別已合併或通過視覺驗收。未接線內容仍列為需接線。
