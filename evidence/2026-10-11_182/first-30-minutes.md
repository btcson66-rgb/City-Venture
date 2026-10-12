# 前 30 分鐘：實際 rendered bot 時間軸

Godot 4.5.1 / zh_TW / 1280×720 / seed 12345。新遊戲的真實單調時鐘；觀察 1800.0 秒。Bot 路線、已知路徑、固定品質小遊戲，不是人類盲測。

| 真實分鐘 | 當分鐘正在做什麼 | 已收到的進展收據 |
|---|---|---|
| 0–1 | Walk east to Startup Hub | objective:ch1_phone、objective:ch1_outside、objective:ch1_coffee |
| 1–2 | Home to wait for stock | objective:ch1_cowork、objective:ch1_board、objective:ch2_supplier、objective:ch2_stock |
| 2–3 | First customer issue | objective:ch2_listing、objective:ch2_order、objective:ch2_ship、objective:ch2_first_dollar、achievement:first_money、achievement:first_delivery、achievement:first_return |
| 3–4 | First customer issue | 此分鐘無新收據 |
| 4–5 | Chapter 3 — wait for a weekday morning | objective:ch2_issue、achievement:return_resolved |
| 5–6 | Metro to Civic Center → City Hall | achievement:founder、objective:ch3_register |
| 6–7 | Metro to Startup Hub → lease Suite 2B | achievement:company_bank、objective:ch3_bank |
| 7–8 | Two real products unlock Chapter 4 without waiting for month-end | objective:ch3_workspace、objective:ch3_os、objective:goal_month |
| 8–9 | Chapter 4 — register as an employer at City Hall | 此分鐘無新收據 |
| 9–10 | Chapter 4 — post a job, hire, first payroll | objective:ch4_employer、objective:ch4_post |
| 10–11 | Chapter 5 — borrow from Marcus Reed at Nexus Bank | achievement:first_hire、objective:ch4_hire、achievement:paid_out、achievement:reviewed、objective:ch4_payroll、objective:ch4_forecast、objective:ch5_meet、objective:ch5_decide |
| 11–12 | Chapter 5 — order the lamps and deliver | 此分鐘無新收據 |
| 12–13 | Chapter 6 — forecast, early payment, month in the black | objective:ch5_stock、objective:ch5_deliver、objective:ch6_forecast、objective:ch6_bridge、objective:ch6_collect |
| 13–14 | Shopping Street — compare Crestline shelf prices | achievement:never_overdrawn、objective:ch6_close |
| 14–15 | Chapter 7 — the news, and Ken's options | objective:ch7_news |
| 15–16 | Chapter 7 — order from the co-op, raise a price | objective:ch7_ken、objective:ch7_stock、objective:ch7_price |
| 16–17 | Chapter 7 — order from the co-op, raise a price | 此分鐘無新收據 |
| 17–18 | Chapter 8 — the Green Shift | achievement:supply_survived、objective:ch7_close、objective:ch8_news |
| 18–19 | Chapter 8 — the Green Business Grant at City Hall | objective:ch8_pack、objective:ch8_product |
| 19–20 | Chapter 9 — the Clearing Crisis: an import stuck on the wire | objective:ch8_grant、objective:ch9_news |
| 20–21 | Chapter 9 — Lina Zhao at Nexus Bank | objective:ch9_import |
| 21–22 | Chapter 9 — Lina Zhao at Nexus Bank | objective:ch9_lina |
| 22–23 | Chapter 9 — Lina Zhao at Nexus Bank | achievement:customs、objective:ch9_settle、achievement:imported、objective:ch9_arrive |
| 23–24 | Old Town — lease the corner café from Mr. Okafor | achievement:popup_first_sale |
| 24–25 | Old Town — lease the corner café from Mr. Okafor | 此分鐘無新收據 |
| 25–26 | Old Town — the food licence at City Hall (walking via Shopping Street) | 此分鐘無新收據 |
| 26–27 | Old Town — the food licence at City Hall (walking via Shopping Street) | 此分鐘無新收據 |
| 27–28 | Old Town — opening day behind your own counter | achievement:cafe_licensed |
| 28–29 | Old Town — opening day behind your own counter | 此分鐘無新收據 |
| 29–30 | Harbor — metro to the docks, a used van from Sam, and Pier 7 | 此分鐘無新收據 |

## 每個進展時刻的實際間隔

| 真實秒 | 收據 | 距前一個時刻（秒） |
|---|---|---|
| 24.9 | objective:ch1_phone | 24.9 |
| 36.6 | objective:ch1_outside | 11.7 |
| 49.0 | objective:ch1_coffee | 12.4 |
| 74.6 | objective:ch1_cowork | 25.6 |
| 92.5 | objective:ch1_board | 17.9 |
| 107.0 | objective:ch2_supplier | 14.5 |
| 107.0 | objective:ch2_stock | 0.0 |
| 153.3 | objective:ch2_listing | 46.3 |
| 153.3 | objective:ch2_order | 0.0 |
| 154.0 | objective:ch2_ship | 0.7 |
| 154.0 | objective:ch2_first_dollar | 0.0 |
| 154.0 | achievement:first_money | 0.0 |
| 154.0 | achievement:first_delivery | 0.0 |
| 158.2 | achievement:first_return | 4.2 |
| 279.4 | objective:ch2_issue | 121.2 |
| 279.5 | achievement:return_resolved | 0.1 |
| 354.2 | achievement:founder | 74.7 |
| 354.2 | objective:ch3_register | 0.0 |
| 389.0 | achievement:company_bank | 34.8 |
| 389.0 | objective:ch3_bank | 0.0 |
| 421.4 | objective:ch3_workspace | 32.4 |
| 424.2 | objective:ch3_os | 2.8 |
| 424.3 | objective:goal_month | 0.1 |
| 548.9 | objective:ch4_employer | 124.6 |
| 584.9 | objective:ch4_post | 36.0 |
| 604.8 | achievement:first_hire | 19.9 |
| 605.1 | objective:ch4_hire | 0.3 |
| 616.7 | achievement:paid_out | 11.6 |
| 617.1 | achievement:reviewed | 0.4 |
| 621.1 | objective:ch4_payroll | 4.0 |
| 621.1 | objective:ch4_forecast | 0.0 |
| 638.8 | objective:ch5_meet | 17.7 |
| 654.7 | objective:ch5_decide | 15.9 |
| 742.1 | objective:ch5_stock | 87.4 |
| 742.1 | objective:ch5_deliver | 0.0 |
| 751.6 | objective:ch6_forecast | 9.5 |
| 751.6 | objective:ch6_bridge | 0.0 |
| 753.0 | objective:ch6_collect | 1.4 |
| 792.3 | achievement:never_overdrawn | 39.3 |
| 792.5 | objective:ch6_close | 0.2 |
| 885.1 | objective:ch7_news | 92.6 |
| 903.8 | objective:ch7_ken | 18.7 |
| 904.1 | objective:ch7_stock | 0.3 |
| 915.3 | objective:ch7_price | 11.2 |
| 1065.0 | achievement:supply_survived | 149.7 |
| 1065.3 | objective:ch7_close | 0.3 |
| 1078.7 | objective:ch8_news | 13.4 |
| 1092.6 | objective:ch8_pack | 13.9 |
| 1123.6 | objective:ch8_product | 31.0 |
| 1165.3 | objective:ch8_grant | 41.7 |
| 1197.3 | objective:ch9_news | 32.0 |
| 1212.2 | objective:ch9_import | 14.9 |
| 1266.4 | objective:ch9_lina | 54.2 |
| 1322.1 | achievement:customs | 55.7 |
| 1322.1 | objective:ch9_settle | 0.0 |
| 1375.7 | achievement:imported | 53.6 |
| 1375.7 | objective:ch9_arrive | 0.0 |
| 1399.4 | achievement:popup_first_sale | 23.7 |
| 1662.7 | achievement:cafe_licensed | 263.3 |

包含開始與觀察尾端，最長無進展間隔 **263.3 秒**。超過 300 秒：**0，PASS（此 bot 路線）**。
收入飄字未額外算作 receipt；只統計實際目標、首次成就、升遷與工作回饋。真正首次玩家找路與閱讀耗時尚未驗證。
