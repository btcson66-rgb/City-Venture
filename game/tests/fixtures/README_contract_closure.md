# 舊存檔 fixture

這兩份檔案由未修改的 e6accdb（本分支起點）以 Godot 4.5.1 的 SaveSystem.save_to() 產生，使用測試角色、固定種子與虛構公司。

- contracts_before_closure_pre36.json：公司仍在營業，有 offered、active、delivered 三張合約；已交貨發票尚未收款。
- contracts_closed_pre36.json：同一局在舊版 Insolvency.close_company() 後存檔。AR 已由原清算以 80% 回收，但舊合約狀態與 con.* 排程仍留著。

回歸測試驗證關閉前存檔讀回後可安全清算；已關閉存檔讀回只修正合約與排程，總帳分錄及餘額保持原樣（只沿用既有 seq 整數正規化）。再次 reconcile 不重複寫 history，不再收買方款項。
