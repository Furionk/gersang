# 新兵種與傭兵倉庫

D34魔爪強化：X零MP、零CD、無召喚數量上限，每隻30秒。體力額外智慧×12、防禦智慧×0.8，刺擊40＋智慧×2.8、間隔0.45秒。地樁半徑160、每0.5秒25＋智慧×0.65；自己的魔爪在區內攻速1.4倍，對區內敵人刺擊1.75倍。原單隻限制已被取代。調整earth_claw.tres的Summon Health／Defense Bonus Formula及Summon Limit；claw_strike_empowered.tres控制配合倍率。

D33：湖衣姬已改為藍膚、黑金甲冑、翼狀披風與月牙彎刃形象。新版動作圖集 `features/units/art/kohime-v2.png`，立繪 `kohime-standee-v2.png`；切圖／方向／接地點在 `features/units/data/layouts/kohime_v2_layout.tres`，頭像與隊伍列眼部裁切在兵種Resource的 Portrait Texture／Eyes Texture。

**現行使用（D38）：在大地圖按 F2 →「隊伍」**。初始十人出戰、鐵炮手在倉庫，主角Lv1其餘Lv25，每種一名。可單獨存入／取出或交換完整角色；主角固定、最多十人。不再提供永久招募／同種複製。每人初始大補丸50、經驗書25，使用會扣除，换兵不補貨。詳細製作與新增見[內容製作指南](content_authoring_guide.md)。

編隊變更只允許探索時進行，遇怪倒數／戰鬥期間鎖定。保存失敗不發布變更，可重試。展示版採獨立存檔，不讀取／覆寫舊七人存檔；未知版本仍受保護。

進入戰鬥 → **F2** →「道具」→ 展開「進階測試」→「新兵試玩（僅本場）」。按鈕名單及敵方版本由Additional Mercenaries的Trials明確引用，新增兵不必猜檔名。可控兵自動選中，1500MP供測試；回圖不保存，不替換正式十人，世界畫面禁用。

| 兵種 | 技能 |
|---|---|
| 湖衣姬 | Z地樁（左鍵範圍），X魔爪（立即） |
| 忍者 | J迷蹤、K火徑（按鍵／圖示立即），C導雷（左鍵敵人） |
| 鐵炮手 | N狙擊、P三段（左鍵確認），O雙鐵炮（左鍵地面） |

圖示hover看介紹／公式。魔爪不能選控，召喚鐵炮可右鍵指令。三段攻擊×3、攻速×1.5，重施刷新不堆疊。

D32：忍者火徑改為寫實8幀火焰；雷擊術改為8幀落雷，傷害仍即時。猛擊火龍波R後可左鍵指定全場方向，衝擊波依戰場Scene尺寸貫穿。大地魔爪採新黑曜石紫晶怪物圖集，外觀1.8倍，每次刺擊在目標周圍冒出地樁尖刺。

Artist可改：`dragon.tres` 的 Battlefield Range；`summons/earth_claw.tres` 的 Visual Scale（只改外觀）；`earth_claw_v2_layout.tres` 的 Attack Columns／Attack Fps；`ninja_fire_trail.tres`、`lightning.tres`、`claw_strike.tres` 的 Effect Data／Sprite Path。雷擊的 Sprite Grounded／Sprite Foot Ratio 校準接地點。新素材位於 features/skills/art/fire-trail-v2.png、lightning-v2.png、features/units/art/earth-claw-v2.png。

## 修改入口

- 兵：features/units/data/mercenaries/kohime.tres、ninja.tres、teppo.tres。
- 怪：features/units/data/monsters/kohime_enemy.tres（湖衣妖姬）、ninja_enemy.tres（湖畔影忍）、teppo_enemy.tres（流亡鐵炮兵）、earth_claw_enemy.tres（湖底石魔爪）。世界Scene選MonsterRegions怪區→怪物種類，先F6試配置；舊怪隊不強制重抽。
- 召喚：features/units/data/summons/earth_claw.tres、teppo_companion.tres。
- 技能：features/skills/data/earth_stakes.tres、earth_claw.tres、ninja_*.tres、teppo_*.tres；敵方同目錄enemy_earth_*／enemy_ninja_*／enemy_teppo_*。
- Effect Data可調持續／tick、範圍、串連數／跳距、倍率、召喚數／上限及成長公式。AI機率／嘗試間隔不是CD。Default Key改鍵，有覆蓋時在設定按「跟隨資源」。欄位hover有中文說明。
- 圖像：features/units/art/{kohime,ninja,teppo,earth_claw}.png；切圖／方向在features/units/data/layouts/*_layout.tres；地樁features/skills/art/earth_stakes.png。正式三兵獨立立繪為 features/units/art/{kohime,ninja,teppo}-standee-v1.png；頭像由同張大圖的 AtlasTexture Region 裁取，可在原生 Inspector 調整。

直接改原生Resource，不重跑一次性build_new_units／link_new_unit_resources覆寫Artist修改。

機制參考[風魔小太郎](https://war3nobu.wltw.org/cp_d02)、[雜賀孫市](https://war3nobu.wltw.org/cp_d01)；本專案以使用者要求優先。未複製網站美術。內建imagegen的完整prompt／路徑保存在artifacts/new-units-2026-10-11/image-prompts.json。數值是可調初始預設，尚非完整平衡結論。
