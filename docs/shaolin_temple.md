# 少林寺：原創寺院地城與封閉圍牆

**目前人口／強度以 [shaolin_strength.md](shaolin_strength.md) 為準：30隊、8種兵種、最高固定Lv50；以下12隊段落為先前版本記錄，不應用來覆寫現行配置。**

本次新增「少林寺 · 禪武院」，以使用者提供的等角寺院圖作構圖／風格參考。灰瓦朱牆、大雄殿、山門、演武亭、古松碑林與香爐均為本次 image_gen 原創素材；沒有裁取原作地圖。

## 遊戲內試玩

F5 重新執行專案，在青嶺河灣、青嶺鎮南側新增「少林寺入口」，邏輯座標 (5184,2464)，點山門走近即可进入。千年湖入口仍保留。少林寺前院的山門可返回青嶺河灣，返回落點 (5152,2336) 位於觸發範圍外。

在 Godot 開啟 `features/world/data/shaolin_temple.tscn` 按 F6，可直接隔離試玩，保留正式進度。D23已擴充至前庭4隊／中庭5隊／後庭3隊，共12隊，每隊2–4名Lv6–12護院。D24改為火圈五秒倒數，附近怪隊可能走近加入，最多4批／60名。戰場擴為44×38格寺院石磚地面、道路、碑林及分批出生區，仍使用既有RTS／技能／原子結算。詳見monster_layout.md與multi_party_encounters.md。

## 圍牆與通行

地圖尺寸 2048×1536，但角色的通行範圍只在寺院圍牆內。原生外牆占地環繞 (192,192) 至 (1856,1344)，通行遮罩限制在 (256,256) 至 (1792,1280)。四面及牆角都是真實導航障礙，牆外空地與地圖邊界不是可走區；山門透過 Portal 換圖，不是讓角色走出外框。

內院分前院、大雄殿院及側面演武院。大殿前的横牆只在 x=736–928 留門洞；側面隔牆只在 y=832–1024 留門洞。尋路能經門洞繞行，不能直穿牆。大雄殿、亭子及碑林占地另有原生阻擋。可見圍牆 Sprite、原生障礙層和通行遮罩共同保存於 scene，不能只移走可見牆而留下錯位阻擋。

後續編輯地形請用 Ground_TileMap／Obstacles_TileMap／Walkable_Mask 原生筆刷。怪區在MonsterAreas，以原生Polygon2D的SpawnArea／RoamingArea／PursuitArea及孔洞編輯，設定人口／模板展開SpawnProfile。三區配置見docs/monster_layout.md；地圖代表Sprite不是額外一名戰鬥成員。

## 原生檔案與素材

| 內容 | 位置 |
|---|---|
| 地圖與圍牆／門洞／出生遮罩 | `features/world/data/shaolin_temple.tscn` |
| 遊戲內入口 | `features/world/data/river_bay.tscn`：shaolin_door／shaolin_return／shaolin_landmark |
| TileSet | `features/world/data/tiles/shaolin_temple_{terrain,masks}.tres` |
| 寺院建築 Sprite | `art/terrain/shaolin_temple/props-v1.png`；`features/world/data/scenery/shaolin_*.tres` |
| 四種原創材質／派生菱形 Atlas | `art/terrain/shaolin_temple/materials-v1.png`／`tiles-v1.png` |
| 怪物資料／48 格圖集／裁切 | `features/units/data/monsters/shaolin_guardian.tres`／`features/units/art/shaolin_guardian-v1.png`／`features/units/data/layouts/shaolin_guardian_layout.tres` |
| 獨立遇敵戰場 | `features/world/data/shaolin_temple_arena.tres` |

PNG alpha 保留。寺院大殿及建築採獨立裁切區域；棍棒攻擊姿勢超出原本等分格，採 256px 寬裁切保留棍端，方向鏡像只作用於 Sprite。TileSet 是 64×32 原生菱形，80 個材質變體，包含完整空白／地面／苔石鄰接組合。派生圖集是對生成材質作平面座標採樣；遊戲載入保存的 cells，不執行製作工具。

完整提示詞及實際尺寸在 `docs/shaolin_temple_art_manifest.json`。改動前的河灣 scene 備份在 `artifacts/shaolin-temple/river_bay-before.tscn`。`tools/build_shaolin_temple.gd` 是一次性製作工具，重用既有原生 TileSet 作者工具；現有少林寺 scene 存在時保留它，後續以原生資料編輯為準。`tools/polish_shaolin_temple.gd` 記錄本次渲染檢查後的亭位、山門及圖集調整。

## 驗證

`tests/world/shaolin_temple.tscn`：功能及實際渲染各 53 項通過，包含 174 個周界身體阻擋取樣、四角斜穿、牆外路徑拒絕、門洞與建築占地、真實滑鼠事件點擊牆外、入口往返、單怪戰鬥與撤退。這裡的滑鼠事件是程式注入真實 Godot 輸入管線，沒有冒充人手完整遊玩。

千年湖回歸 35 項通過；非 headless 移動 40 項通過，包含 30／120 FPS。完整舊系統回歸 120 項通過、零失敗，日誌為 `artifacts/shaolin-temple/full-regression.log`。本次所有測試使用隔離狀態；正式存檔未被重設或改寫。彙整結果見同資料夾的 `validation-summary.json`。

實際截圖：`temple-overview.png`、`main-courtyard.png`、`training-courtyard.png`、`entrance-in-game.png`、`guardian-battle.png`，與功能／渲染結果 JSON 均在 `artifacts/shaolin-temple/`。人工逐格筆刷編輯、撤銷及人手完整遊玩仍待使用者驗收。
