# 原生戰場場景契約

座標校準不可回退：80×40 Diamond Down 的 map_to_local(0,0) 自帶中心(40,20)，層原點須為(-40,0)，使每個 native cell center 等於 Iso.project((cell+0.5)*40)。不得以(0,20)造成固定畫面(40,20)偏移；blocker碰撞四角亦須與原生菱形四角完全相等。導航外擴一格是另行保留的安全邊距，不是座標偏移。

本輪使用者要求取代程式生成戰場，以 Godot Scene 編輯所有戰場內容。五個主位置供我方及最多四批敵人隨機分配；目前一批我方，不擴張友軍增援流程。

- features/battle/maps 下五張 .tscn 是正式布局來源。Ground 原生80×40等角 TileMap；Walkable／Blockers 為可畫的邏輯遮罩；Scenery 保存原生 Sprite；SpawnZones 保存可拖動 Marker2D。
- 畫面座標只用 Iso.project/unproject；沿用現有平面地面／飛行導航、碰撞與動態冰牆占格。不得啟用投影 TileMap 物理／導航。
- 每次釋放使用 battle RNG，最多五個互不重複主位置。Marker 的 team eligibility、容量與半徑由 Inspector 調整。實際單位只放區域內合法格；整批配置先驗證，不得以 safe_spawn 把不同批擠回同一處。
- 場景／出生區無效時給可定位原因，拒絕入場並回復遭遇保留，不吞掉怪隊、MP、進度。場景改動重新執行生效，不能在 boot 重生成或覆寫 artist 修改。
- F6 為隔離試玩，不載入／修改正式玩家存檔。原生編輯 Undo/Redo、保存重開和視覺驗證分開報告，Editor API 不冒充人工滑鼠驗收。
- 一次性遷移工具只在目標不存在時建立初始五圖與圖集；源世界場景、音樂和圖片保留。舊程序生成僅為未指定場景的測試 fixture 相容，不作正式戰場權威。

驗收：五圖原生 ownership、筆刷變更實際生效、walkable holes／blockers、五區随机與相同 seed 重現、不同批不重疊、最多12對60、冰牆／飛行／清理、技能與移動回歸、F6 隔離、真編輯器 API。
