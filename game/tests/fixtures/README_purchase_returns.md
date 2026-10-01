# 進貨退貨相容性 fixture

purchase_returns_pre21.json 由未修改的 e6accdb（本分支起點）用 Godot 4.5.1 / SaveSystem.save_to() 產生。
角色為 Test Founder、種子 12345；只放一張 TradeLink 無線耳機預付進貨單，尚未到貨。存檔沒有 returns、returned_qty、cancel_fee、payable_remaining 等新欄位。

回歸測試把這份原始存檔讀入 SaveSystem，使用設計資料的預設政策取消原進貨單，並核對退款與總帳平衡。另有新存檔測試涵蓋退貨排程存讀、公司開戶後庫存歸屬與退款應收款原持有人。
