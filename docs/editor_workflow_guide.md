# 編輯資料與場景：快速指南

最新完整入口：[D39內容製作指南](content_authoring_guide.md)，包括八方向可變動作幀、逐格預覽及新增內容。兵種名單以D38十人＋倉庫配置為準。

## 技能快捷鍵

開 `features/skills/data/blast.tres`，Inspector 的「預設快捷鍵」直接選字母；
保存後重新開始遊戲。你目前保存的是 T，這輪沒有改回 I。
若遊戲內曾自訂按鍵，設定頁該技能按「跟隨資源」即可取消單項覆蓋。
舊版把所有預設鍵也寫進設定檔，無法區分「自動保存的I」與「刻意固定I」。
本輪把等於舊預設的技能鍵視作跟隨資源；如你原本特意固定它，需在設定頁重設一次。
多個已選兵種技能共用一個键會提示衝突；可改鍵，或點技能圖示。
目前 T 也用於雷擊術；同時選到兩種技能時不會擅自決定施放哪個。

主要技能、效果、兵種、遭遇及出生欄位的名稱 hover 有中文說明，描述秒／
毫秒、機率、每次命中／tick 及共享資源意義。不是所有 Godot 內建欄位翻譯。
只想改某一兵種的技能：複製技能 Resource、改 ID/action，再配入該兵種 Skills；
直接改共用技能會影響所有引用它的兵種。

## 兵種數據在哪裡

| 資料 | 位置 |
|---|---|
| 主角／傭兵模板（名單由Demo Setup決定） | features/units/data/mercenaries/*.tres |
| 怪物 | features/units/data/monsters/*.tres |
| 箭魂／助戰銅人 | features/units/data/summons/*.tres |
| 動画切片布局 | features/units/data/layouts/*.tres |
| 共用角色圖像 | features/units/art/，沒有搬動 |

舊存檔已知路徑自動換成新路徑；不重抽怪隊、不改經驗、配點、裝備或收據。
未知資料仍提示錯誤，不靜默重置存檔。

## 倒數時附近怪會怎樣加入

5秒內世界繼續走動；真正戰鬥時世界凍結。每1秒重新找附近候選。
怪物 Resource 的「Reinforcement Approach Chance」是走近機率；
「Reinforcement Join Chance」是到達後真正參戰機率。0永不，1必定，-1沿用怪區。
怪區 Habitat → Profile → Rules 設預設機率、半徑、判定間隔及到達距離。

感嘆號只代表正走近／猶豫，不代表已參戰。必須走合法路徑抵達，才抽加入機率。
沒抽中可在下一秒再試；倒數完未加入者留在世界。最多4批、總敵人60。
已參戰的成員／ID／戰力與戰場一致，不把圖上代表物另算一名敵人。

## 裝飾現在只用一層 Sprite

純樹木、建築、山石在 Scenery 下直接選 Sprite2D；改 Texture、Region、Scale、
Rotation、Hframes／Vframes／Frame Coords 和 Offset。移動軸放腳底；Offset 改圖片位置，不要把腳底軸移到圖中央。
可用原生 Ctrl+D／Delete／Undo。也可由 Project → Tools → 地圖 → 新增建築／山體。
Metadata 的 world_scenery_definition 只保留說明／outline 樣式，圖像以 Sprite 為準。

有出入口功能的物件仍是作者節點＋Artwork，保留目的地／半徑等設定，
不能當純裝飾刪去邏輯。怪區仍用 Polygon2D；地形／通行／障礙仍畫 TileMap。
放山的圖片不會自动堵路；需要在 Obstacles 另畫阻擋。

進／出戰鬥會保留上一個完成畫面，到新地圖和鏡頭就緒才顯示，避免閃出原點。
千年湖 Position_3 只改 Capacity54，出生圈、Blockers 與位置保留。

工程入口：`tools/project_context.ps1 -Topic editor_workflow`；
[契約](../specs/editor_workflow.md)／[實測與限制](editor_workflow_validation.md)。
