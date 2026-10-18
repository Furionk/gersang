# 內容製作：從現有兵種開始

這是現行入口；舊指南中的「七人、Lv1招募、同種多名」已被D38取代。先關閉遊戲，用Godot FileSystem双擊`.tres`，原生Inspector保存資料，F6測場景；不是在F2修改永久模板。這輪不重平衡數值，不自動部署Web。

## 先找對文件

| 我要改 | 原生來源／例子 |
|---|---|
| 城鎮／地城入口 | `features/world/data/river_bay.tscn` → Entrances → 入口父節點 |
| 可走／阻擋／地面 | 同一Scene的Ground → Walkable_Mask、Obstacles_TileMap、Ground_TileMap |
| 少林寺怪區 | `features/world/data/shaolin_temple.tscn` → MonsterRegions |
| 兵種 | `features/units/data/mercenaries/ninja.tres`、`kohime.tres`、`malfory.tres` |
| 怪物 | `features/units/data/monsters/millennium_wolf.tres`等 |
| 技能 | `features/skills/data/ninja_chain.tres`、`earth_stakes.tres`等；由兵種Skills直接開啟 |
| 召喚／tick／特效 | 技能的Effect Data；Inspector有「開啟效果細節」 |
| 成長規則 | 兵種Stat Rules；空白則用`features/progression/data/stat_rules.tres` |
| 頭像／隊伍橫幅／立繪 | 兵種Portrait Texture／Eyes Texture／Standee Texture |
| 動作與切圖 | 兵種Sprite Layout；例`features/units/data/layouts/ninja_layout.tres` |
| 物品 | `features/progression/data/items/`；例`debug_medicine.tres` |
| 新遊戲出戰／倉庫 | `features/progression/data/demo_setup.tres` |
| 本場試兵配對 | `features/progression/data/additional_mercenaries.tres` → Trials |
| 正式戰場 | `features/battle/maps/*.tscn`，不是世界Scene的怪區 |

在兵種Inspector，上方可以直接開啟切圖、派生規則、每個技能及美術Resource。下方「八方向／動作／切圖預覽」展開即可，不用找新Tab。

## 修改一個現有兵種

以忍者為例：雙擊`mercenaries/ninja.tres`，改Damage、Attack Interval、HP/MP、Strength/Agility/Intelligence等，按Ctrl+S。Inspector的「等級試算」可切Lv1/25/50，使用真正CombatStats計算；不改模板等級、存檔、裝備或配點。

不要混淆三種等級：Unit Definition的Level是模板；傭兵Level由經驗存檔決定；世界怪物等級由怪區Member Rule的Min/Max決定。展示版傭兵初始Lv25由Demo Setup決定，改Unit的Level不會讓已存檔角色變成Lv50。

Base Power／Level Power Growth只是世界戰力評分，不是傷害。Attack Interval是普攻間隔；動畫FPS是外觀速度；AI Attempt Interval是怪物重新決策間隔；Cooldown是施法冷卻。它們不可互當替代欄位。

預設HP成長來自力量和等級，MP來自智力和等級；體質目前不直接增加HP，只供技能公式使用。這是現行遊戲設計，不是Godot規定。本輪不暗改它。只改一種兵的成長，可先把Stat Rules「Make Unique」或保存成另一外部Resource再配入。

### 配技能

Skills是`SkillDefinition`引用清單。拖入技能即讓此兵擁有它；裝備另可由Granted Skills提供技能。共享一個技能表示共同使用其設定，不是每兵自動複製。

- 全部使用者都要強化：改原技能Resource。
- 只強化忍者：複製技能並保存為新`.tres`，改獨立Id和手動Action，再替換忍者Skills中的引用。
- Damage Formula是每次命中／tick的基礎值，Effect Data决定tick間隔、持續、串連、召喚等。
- 手動技能Default Key可改；遊戲内曾覆蓋時選「跟隨資源」。多兵同時選控的按鍵衝突需另檢查，不能用一個鍵默默選錯技能。
- 敵人要主動施放，設Ai Enabled、嘗試間隔、機率；被動技設Trigger/Proc Chance。0CD不表示AI每幀施法。

新數值／組合可以用既有Effect；**全新機制**仍需要程式實作相應效果，單改文字／公式不會自動產生新玩法。命中、傷害、消耗及結算的權威仍是戰鬥系統，不交給動畫發獎。

## 頭像共用同張原圖

Portrait Texture、Eyes Texture、Standee Texture可用原生AtlasTexture。新建AtlasTexture，Atlas拖入同張立繪或SpriteSheet，Region選要顯示的矩形。Margin可加透明留白，避免整張圖為了UI另裁PNG。三欄可共用同一Atlas原圖，但用不同Region。

Texture欄有值時優先於舊Portrait/Standee Path；舊Illustration Index只給舊七人 fallback。戰鬥Sprite與UI頭像是不同用途，但不用把美術分「敵人Art／我方Art」。要偏移畫面用原生Region/Margin或Sprite Offset，不要移動邏輯腳底／碰撞來配頭像。

## Review SpriteSheet：看哪個動作、哪一幀

1. 選兵種，展開「八方向／動作／切圖預覽」。
2. 選待機、移動、普攻、施法、死亡；方向是**畫面方向**，不是原始邏輯XY。
3. 拖幀滑桿逐格看；綠十字是接地點。下方原圖的黃框显示此幀來自哪裡。
4. 文字會列出播放第幾幀、來源列／欄、裁切Rect、FPS、時間權重及是否鏡像。
5. 原圖切漏／帶到邻格：改Frame Rects；腳底跳動：改对应Source Pivots；方向錯：改Direction Rows／Mirrored Directions。

| 畫面方向 | 右 | 右下 | 下 | 左下 | 左 | 左上 | 上 | 右上 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 方向索引 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |

Rects索引=`來源列×Columns＋來源欄`。例如Columns=12、來源列2、來源欄5，改Rects/Pivots第29項。Rect是原PNG的像素座標；Pivot是該Rect內的腳底，不是原PNG全圖座標。Frame Size是共同透明畫布，Foot Point是共同腳底，AtlasTexture Margin把每格對齊到此腳底。

### 不再固定幀數

Sprite Layout → Animations新增`SpriteAnimationClip`：Action選動作、Columns填播放來源欄、FPS填速度、Loop選循環。每個動作只放一個Clip。Columns可重複／倒序／不連續；Frame Durations留空時每幀權重1，[1,2,1]讓中間幀停留兩倍時間。

例如一張每列12個姿勢的圖：待機[0]、移動[1,2,3,4,5,6]、攻擊[7,8,9]、施法[10,9,8,9,10]、死亡[11]。這是示例，不能直接套到你的PNG；來源欄要按實際美術選。

未指定Clip的動作沿用舊規則；已有6×8圖不需重切。Rows可少於8，由Direction Rows重用來源列，必要時鏡像；輸出依然是八方向，與既有等角控兵一致。

2026-10-13集中修正後，26套在用圖集都已有五個Clip。每個Clip可展開「此動作方向覆蓋」；留空沿用Layout，填8項只改該動作。例如移動朝左正確、但射擊朝右，就改普攻Clip的Direction Rows／Mirrored Directions，不必讓待機也跟着變。

轉向會保留動作相位，普攻／施法每次重新出招會重播；移動立即打斷視覺收尾。幀數與速度仍可自訂，不改命中或技能前搖。多數現有原圖僅兩種踏步：播放順序加入待機作經過姿勢，並不等於補畫。要真正更流暢，應補不同腿部／羽翼姿勢，再更新Rects、Pivots及Columns。詳見[逐圖審視報告](audits/sprite_motion_2026-10-13.md)。

已補畫鐵炮手／銅人／千年鳥，各有四幅真正不同的移動姿勢，Clip的Walk Columns=[1,2,3,4]。千年鳥新版真實原圖只有7來源列，Layout Rows=7仍可映射8方向；不要為了湊8列把留白切成怪物。Instant Start Frame只指定零前搖技能從哪個播放幀開始，本輪Cast設1以直接出招；正常有前搖仍從0開始，Skill.cast_time不受影響。

新空白Layout可拖入Source Texture，填Columns/Rows，按「初始化等分裁切」。只在Rects空白時可用，不會重切現有Artist資料；初估腳底仍需逐格校準。非規則圖直接用手工Rects，不應勉強等分。Source Texture優先於兵種舊Sprite Path。

動畫幀数不改傷害次數。Preview是美術播放；實戰还会按移速／施法倍率調整呈現，最後仍要F6／正式戰鬥檢查節奏，不能只看一張待機截圖。

## 新增兵種與怪物

先複製最接近的UnitDefinition到`mercenaries/`或`monsters/`，改獨立Id、名稱、能力、Skills與圖像；不要為每種新兵再寫一套腳本。現有角色與怪使用同格式，控兵旗標、AI技能及怪區配置决定不同用途。

新原圖放共用Art位置，建立SpriteSheetLayout與Clip，按上節Review。新兵明確填Battle Sprite Scale（常用0.4），不要拿Role改圖像大小；-1保留舊資料相容。World Sprite Scale只管世界怪隊代表圖，Visual Scale繼續管戰鬥外觀倍率，均不改通行。

先試兵：在Additional Mercenaries → Trials新增`UnitTrialEntry`，Friendly拖兵種，Enemy拖敵方變體（可留空）。F2 → 道具 → 進階測試 → 試兵；只在戰鬥有效，本場1500MP，回圖不保存。**檔名可以與Id不同**，不必再造`名字_enemy.tres`猜測引用。

要成為新遊戲正式成員，再把兵種拖入Demo Setup的Active或Reserve。主角固定Active第0位；Active最多10人、同種一名。這不改已存檔名單；舊進度要新增成員需另定保存／遷移策略，不應偷偷Reset。

要在世界出怪：打開世界Scene → MonsterRegions，复制怪區或拖入`authoring/templates/monster_region.tscn`。單一配怪選Monster、每隊數量、等級、Party Count及出生／遊走／追擊Polygon；混合隊伍在Habitat → Profile → Templates → Members逐一引用兵種。圖上代表一個怪隊，不是只一隻。用Walkable/Blockers檢查合法範圍，不靠Sprite判阻擋。

既有存檔怪隊可能保留生成時快照；先用F6隔離／新生怪隊確認新資料。不要隨便提升Content Revision當刷新按鈕，它會影響相容檢查。

## 入口、物品、新地形

**入口**：選Entrances下PORTAL父節點。Target Map Id是目的地Map Id；Target Entry Id是目的地ARRIVAL節點Stable Id，不是顯示名稱。可按「開啟目的地Scene」。移父節點會改觸發位置，移Artwork只改圖片。新入口可由`authoring/templates/portal.tscn`或Project→Tools→地圖新增。先保存、驗證，再F6；不要用瞬移或擴大可走域掩蓋問題。

**物品**：複製同類`.tres`改獨立Id／名稱／Icon。裝備設定Slot、Modifiers、Granted Skills；食用設定Use Effect、Restore HP/MP、Affects Party／Revives。Description只是說明。Max Stack、Weight、格數是背包規則，別與療效混淆。

**平面地形**：使用Godot TileSet Atlas新增素材tile，按原有80×40等角地表規格及Terrain連接方式配置；在Ground_TileMap用原生Tiles/Terrains畫。不要更動既有校準Transform。山／房子則放Sprite2D於Scenery，以腳底排序；實際阻擋另畫Obstacles或Walkable。地形外觀、通行、怪域、出入口各有來源，不能一張PNG代替四種設定。

新增地圖從最接近的WorldMap Scene另存新檔，改Map Id及獨立入口ID，設定ARRIVAL和至少一條回程；WorldCatalog從保存Scene發現地圖。新增戰場另用`features/battle/maps/`原生Scene及SpawnZones，不要從世界怪域猜出生點。兩者先驗證合法落點及容量。

## 發佈前最後一步

新增Resource/PNG後，先生成匯出白名單，再匯出，避免Editor有、Web缺：

```powershell
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/prepare_web_export.gd -- --write-preset
```

不加`--write-preset`只檢查，不寫設定。工具保留無BGM排除、測試／插件／生成證據不打包，不會刪素材。再次Export後須實際瀏覽器測試，不能把F6當Web驗證。指南的來源契約在[D39](../specs/content_authoring.md)，審視結論與限制在[架構審視](audits/content_authoring_audit.md)。
