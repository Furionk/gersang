# 箭魂、重新配點與怪物圖集修正 — 2026-10-09

## 現行契約（D14）

- POLISH-01：測試只用隔離進度。此輪不搬檔、不改世界導航、鏡頭、插值、移速、手動施法確認或技能冷卻。
- POLISH-02：大地圖選兵後按 S，能力頁新增「重新配點」及確認／取消。免費退還此角色全部已花的力量／敏捷／智力／幸運點數；不動經驗、等級、背包、裝備或基礎屬性。HP／MP只截到新上限，不回滿，死亡仍為0。一次 changed 訊號沿用現有保存／重算。未配點時按鈕禁用。
- POLISH-03：忠臣箭魂按**成功釋放瞬間**的召喚者派生能力快照強化攻擊與命中。初始調試配置為原生攻擊20 + `agility*2`、原生命中100 + `agility*2`；之後仍走既有 CombatStats／普攻命中與減傷，不把命中值當命中百分比。係數是可調預設，不宣稱原作數值。
- POLISH-04：山豬 `beast`、石井／古井鬼衛代表 `elite`、主角 `merchant` 採原生逐格 region／pivot 資源，不再假設整張PNG平均八排。原PNG不改；48格有固定224×224虛擬畫布和腳底(112,198)。共享AtlasTexture的filter_clip防止鄰格採樣；大地圖／戰鬥共用SpriteAtlas。其他兵種仍用原來6×8布局和比例。
- POLISH-05：確認綁定打開時的persistent ID；選取已變或非探索狀態拒絕重配。不讓過期確認作用到另一名角色。
- POLISH-06：兩方進戰建立完全部成員後，初始朝向是 `Iso.unproject(Vector2.DOWN).normalized()`，即畫面朝下（圖集row2），立即套idle首幀。後續走位／索敵正常改變方向，不鎖死朝向。

## Inspector 與資料入口

| 修改內容 | 唯一入口 |
|---|---|
| 箭魂基礎攻擊／命中／射程 | `features/units/data/summons/spirit.tres` |
| 敏捷攻擊／命中加成公式 | `features/skills/data/summon.tres` → effect_data →「召喚者能力加成（施法快照）」兩欄 |
| 召喚存活時間／MP | 同一技能Resource，不改CD0／每施法者一隻限制 |
| 派生數值與命中對抗 | `features/progression/data/stat_rules.tres`、CombatStats／CombatMath |
| 非均勻圖集／方向 | `features/units/data/layouts/beast_layout.tres`、`elite_layout.tres`、`merchant_layout.tres`；UnitDefinition.sprite_layout引用 |

公式沿用集中DamageFormula（中文別名、英文變數、四則括號）。未知變數／除零等錯誤在驗證階段拒絕，不扣MP、不覆蓋原命令。SummonScaling深複製召喚定義，絕不改共享藍圖。每次召喚独立；既有箭魂不因施法者之後配點／能力變化重新縮放。角色技能說明的攻擊／命中範圍與運行時共用求值／派生算法。

`agility=100` 的例子：原生攻擊220，±10%後198–242；原生命中300，加箭魂自身敏捷／幸運後360，±5%後342–378，實際命中率仍與敵人閃避及既有上下限對抗。HP、壽命20秒及永久七人編隊不變。

圖集腳底pivot每方向以原始待機姿勢的腳底建立，同方向所有姿勢保持固定錨點；死亡姿勢可低於該腳底而不拉伸。SpriteAtlas快取鍵包含region／pivot／畫布，避免同圖不同切分互相污染。這不是重新生成八方向素材，也不會把sprite改為靜態滑動。

## 斜向圖片回歸契約（D15）

- DIR-01：測試必須隔離存檔，使用真正大地圖UnitView與WorldPartyView，不以小尺寸待機接觸表代替行走驗收。
- DIR-02：主角／鬼衛均有完整48格布局。裁切以**整張原PNG上的完整輪廓**為界，不先限制在181×181格內再找主輪廓；跨格的頭盔／武器須保留。
- DIR-03/04：左上／左下的兩個行走幀完整、源pivot加margin等於固定腳底。轉向不拉動碰撞／位置；不以位移補償修畫面。
- DIR-05/07：輸出方向仍為E／SE／S／SW／W／NW／N／NE（0..7）。`direction_rows`選來源排，`mirrored_directions`只翻AnimatedSprite2D圖像，不翻整個UnitView或邏輯facing。主角NW輸出5→來源NE排7＋鏡像；鬼衛SW輸出3→來源SE排1＋鏡像；其他方向不變。原圖主角排5向右、鬼衛排3背向右，不能重新當正確左向圖。
- DIR-06：30／120 FPS下兩個行走幀都必須出現，不能每幀重新開始而只停首幀；速度、導航、鏡頭／插值及D09閘門不變。

上述來源排修正沿用所有姿勢，避免走路正確但待機／攻擊突然朝錯。Inspector可直接檢視／調整方向排及鏡像；改圖集來源／排對應時需要重跑斜向測試，不能只刷新雜湊。

裁切与方向輸出快取由SpriteAtlas統一；來源排是快取鍵一部分。切換方向後鏡像重新計算，避免上一方向的flip_h留在下一方向。

## 必跑驗收

`tests/party_polish_suite.tscn`（headless＋實際渲染）、`tests/world_direction_regression.tscn`（headless＋實際渲染）、`tests/sprite_layout_capture.tscn`（實際渲染）、`tests/run_all.gd -- --all`、非headless `tests/world/movement_regression.tscn`、Godot editor import、context路由驗證。渲染圖與測試JSON在artifacts/world；記錄見 [驗證報告](../docs/party_polish_validation.md)。
