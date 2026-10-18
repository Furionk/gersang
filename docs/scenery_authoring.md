# 建築／山體 Sprite 與入口 Hover 製作

地面與道路用 TileMap。建築、山體、城門、地城入口則使用獨立 Sprite2D：每件物件可用一張圖，也可從圖集裁切；大型建築亦可拆成前／後景幾張圖以便遮擋。不要把所有有高度的物件壓成地表格。

## 自行放置及換圖

1. 開地圖 `.tscn`，拖入 `features/world/authoring/templates/scenery.tscn`，或 Project → Tools → 地圖 → **新增建築／山體 Sprite**。position 已是原生 2D canvas 腳底位置，直接在圖上拖動／Ctrl+D 複製／Delete 刪除；新 ID 自動生成。詳見 [人本製圖指南](human_authoring_guide.md)，不用舊 Dock。
2. 展開 **Sprite / Hover → sprite_definition**，可選 `features/world/data/scenery/` 的 tree／mountain／cave_rock／building。要自行修改，先在 Resource 選單 **Make Unique**，或另存新 `.tres`，避免改動所有共享同款圖的物件。
3. `texture` 換自己的透明 PNG；單張圖讓 `atlas_region` 保持空 Rect2，圖集則填裁切範圍。`foot_anchor` 是裁切後圖片內的腳底錨點；`sprite_scale` 控制比例，`tint` 控制色調。不要旋轉或縮放作者根節點來代替这些設定。
4. 圖片只是視覺：要令建築／山體擋路，另外在 **Ground/Obstacles_TileMap** 畫阻擋；入口直接拖動其原生 2D 作者節點。編譯器轉回平面位置，不要開啟等角 TileMap physics/nav。

## 城鎮／地城入口

入口仍是 PORTAL 作者節點，`stable_id`、`target_map_id`、`target_entry_id`、`trigger_radius` 由原有世界轉場使用。

配置 `sprite_definition` 後，鼠標移到非透明輪廓即亮起綠色 outline，旁邊有跟隨游標的半透明名稱／說明框；左鍵點圖片讓角色走近真實入口，再按現有權限／距離觸發轉場。透明邊角可以點穿，點 UI／開角色面板時不會亮起背景入口。

`display_name` 是該入口的名稱；`sprite_definition.description` 是說明。`alpha_threshold` 同時控制圖片裁切輪廓與 hover 命中；`outline_color`／`outline_pixels` 可調。不要只在提示文字寫「需要戰力9000」卻當成已加入權限檢查：目前權限仍由原有轉場邏輯決定。

現有城門／古井使用項目中的門樓素材，不是附圖建築的逐像素複製。可以換成你自行重繪的每座入口獨立 PNG，而毋須改控制器。

## 試玩與檢查

Ctrl+S → F6 隔離試玩；F5 使用正式進度。自動測試覆蓋 alpha 點穿、GUI 阻擋、走近入口、提示縮放、轉場清理；亦有實際渲染輪廓截圖。實機鼠標操作仍需你試用確認。

查閱入口：`tools/project_context.ps1 -Topic scenery`，契約在 `specs/scenery_interaction.md`。本輪沒有重置角色、背包或怪隊，也沒有把建築 sprite 當成額外戰鬥單位。
