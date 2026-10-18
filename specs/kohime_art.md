# D33 湖衣姬形象

2026-10-11使用者提供三張形象參考，要求改善Sprite及畫像。形象為藍／青膚女性、黑髮長耳、琥珀眼與寶石、黑金甲冑、刃狀翼披風、月牙彎刃。替換D30／D31白衣人類妖術師外觀。

- 原創 kohime-v2.png 八方向6×8動作图集與 kohime-standee-v2.png 全身立繪。原素材保留；原生 kohime_v2_layout.tres 擁有切圖／接地點，Atlas使用實際來源尺寸1086×1448。
- 正式兵種與怪物版本共用新美術，定義路徑及ID保持原值。技能、能力、倉庫紀錄、經驗、裝備、碰撞及導航不改。
- 方向E／SE／S／SW／W／NW／N／NE使用來源列[0,1,2,3,0,7,6,7]，W／NW鏡像，避免來源圖左側方向仍朝右；只鏡像Sprite，不改邏輯方向。待機、走路兩幀、普攻、施法、死亡共48格。單格裁切排除外側微小鄰格殘片，保留主要披風、刀刃及施法尖刺；PNG本身不改。原生Atlas橫向錨點固定在各格中央，避免不對稱披風導致左右抖動。
- Portrait／Standee使用新版獨立立繪；新增可選eyes_texture原生Atlas提供隊伍列橫幅，未設定的其他兵种沿用原頭像流程。
- 工具 create_kohime_v2_layout.gd 為本輪來源記錄，禁止作啟動／日常重建。render_kohime_v2_review.gd 只渲染原生48格作視覺校驗。

Artist入口：features/units/data/mercenaries/kohime.tres、monsters/kohime_enemy.tres、layouts/kohime_v2_layout.tres；素材features/units/art/kohime-v2.png及kohime-standee-v2.png。

驗證：原生48格GPU檢視、倉庫／隊伍列實際渲染、new_units_suite、mercenary_storage_suite、roster_effects_polish_suite及all／實際MOVE；證據artifacts/kohime-art-2026-10-11/。
