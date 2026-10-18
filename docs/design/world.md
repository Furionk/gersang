# 世界、怪區與戰場：資料入口

目前開放示例地區不是完整四國世界。製圖操作先讀 [artist guide](../artist_guide.md)，控制／保存契約查 `specs/decisions.md`；原始49KB文案只在需要特定生命週期章節時擴展閱讀。

| 類型 | 名稱／ID | 權威檔案 |
|---|---|---|
| 探索外域 | 青嶺河灣 river_bay | `features/world/data/river_bay.tscn` |
| 安全城內 | 青嶺鎮 qingling_town | `features/world/data/qingling_town.tscn` |
| 地城樓層 | 古井 well_1 / well_2 | 同資料夾 `well_1.tscn` / `well_2.tscn` |
| 千年湖地城 | millennium_lake | `features/world/data/millennium_lake.tscn`；[素材與試玩](../millennium_lake.md) |
| 少林寺地城 | shaolin_temple | `features/world/data/shaolin_temple.tscn`；[圍牆與試玩](../shaolin_temple.md) |
| RTS戰場 | meadow / mountain / cave | 同資料夾 `.tres`，由ArenaDefinition接入 |

外域6144×4096、22隊是已配置基線，不是把所有世界設計坐標／數值抄到此頁。青嶺鎮、河灣道路／橋、石槌山口、農田／林道、古井等地標用scene與atlas映射共同登錄。地城是分樓層地圖；其他區的願景不是可抵达場景。

**內容權威**：`.tscn`根節點Definition與作者節點。外框／孔洞／障礙／安全區／怪區／Portal／ArrivalPoint／裝飾由 `WorldMap2D.compile_definition()`編譯。WorldCatalog初始化有fallback，再由作者scene覆蓋。修改現有地形不只改fallback。

**怪隊設計**：WorldHabitat → SpawnProfile／PartyTemplate／MemberRule／EncounterRules／ArenaPool。這些可能作為scene子資源存在，不能因没有同名獨立.tres就以為資料不存在。

**執行管線**：WorldSession → WorldContext／MonsterBrain／NavigationService → EncounterService → GameDirector真實戰鬥快照 → SettlementService → SaveService →返回同世界。主動／被動、返巢、人口、重生與穩定成員依該管線；圖上的代表物不是額外成員。

**新地區**：用World Authoring複製scene為新map_id，設定真正通行區、入口落點和双向Portal、atlas對位，保存後再启动。不是隨便新增地名文字；驗證、隔離預覽和實際走訪需分開做。

來源快照保持不變；D09受保護移動優先於來源初版四向路徑。作者插件的人工拖點／Undo／保存重開驗收仍有待項目，不因headless地圖验证通過而稱為已驗。
