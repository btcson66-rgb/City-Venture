# 戶外地面材質品質批 · 2026-10-01

28 格戶外材質重新製作：道路、路緣、停車與人孔蓋、人行道和廣場、河面與港區水面、綠地、花園、木步道、老城石板、碼頭鋪面及邊緣。43 個 atlas 名稱與座標保持原样，15 格室內和 5 格未使用區域的像素保持原樣。

原畫：asphalt、stone、water、grass 各自生成一張獨立材質，提示詞見 prompts.json。每張材質由 SVG 控制實際投影、低對比表面層和路線幾何，再直接輸出 16×16 native cell 和 64×64 detail cell。4× 的變動區域不是原尺寸點陣放大。boards、garden、manhole 及各種路標使用可編輯的幾何組合。沒有文字、數字或品牌。

第一版四向鏡像組合雖然對向邊完全相同，但實拍有棋盤紋，因此未交鏡像版；改成完整材質以低對比表面層控制接縫。ground_material_check 量測對向邊最大 RGB 差不超過 12／255，並產生多格平鋪檢視；此數值只作為低對比邊界檢查，不代表所有紋理重複感已完全消失。另附真實街區日夜畫面檢查。

重建：python tools/art/ground_material_vectors.py → node tools/art/render_ground_materials.cjs → Godot import → python tools/qa/ground_material_check.py。原 atlas 快照封存於此，render 只覆蓋 manifest 中的 28 格。PNG/import 同時交原尺寸及 world_detail；atlas.json 不需更新，因為尺寸及座標均未變。

實機邊界：WorldScene.tileset 目前以 16×16 region 讀 native atlas，替換會直接可見。4× atlas 的 logical projection 需要 Claude 接線；不能直接把 region 當成 16 去讀 4×，否則格位會錯。這批沒有修改任何遊戲程式、碰撞、導航或區域內容。
