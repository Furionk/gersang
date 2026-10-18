# 少林寺強度分層（2026-10-10）

原生權威：`features/world/data/shaolin_temple.tscn` → `MonsterRegions`。

| 區域 | 隊數 | 等級 | 編成 |
|---|---:|---|---|
| front_patrol 前庭 | 10 | 12–22 | 普通鐵棍武僧、疾影棍僧、赤燈護法 |
| bronze_guardian 演武院 | 12 | 24–36 | 疾影統領、震地護法、銅人陣師與護衛 |
| rear_patrol 後院 | 6 | 38–48 | 金剛陣師、術士及高速統領 |
| inner_masters 核心 | 2 | 首領固定50；護衛42–48 | 金身羅漢、金剛護衛、疾影統領 |

全區30隊、約120–214名實際成員，8種可配置兵種。測試seed產生160名，
加權隨機可能使某種普通兵在單次出生中沒有出現；两名Lv50首領必定存在。
新副本強度不適合初期隊伍直接硬闖，前庭仍保留非主動巡值規則。

金身羅漢是真正Lv50：實際HP／攻擊／防禦由現有能力系統計算，不只是牌子。
擁有十八銅人陣、裂焰衝擊波及2–3倍機率暴擊；能召喚2–3名同級敵方金身銅人。
高速統領另有吸血，護法保留地震／衝擊波／火焰。敵方總存活容量60、
最多4批入場、原有MP與AI判斷間隔不變。

## 自行調整

選上述怪區，在Inspector調Party Count；Simple Party=false，展開
Habitat → Profile → Templates → Members，可改兵種、每隊人數、等級區間與權重。
單位數值與技能在 `features/units/data/enemies/shaolin_*.tres`。
新增：shaolin_iron_disciple、shaolin_shadow_captain、shaolin_thunder_warden、
shaolin_elite_copper、shaolin_grandmaster。沿用已存在的兵種美術與各自調色，
不是本輪另畫五套圖集。技能在 `features/skills/data/enemies/*.tres`。

## 舊存檔與證據

少林寺修訂4會在無活動遭遇時重建少林寺敵隊；玩家進度、金錢、經驗、
背包、裝備、已發獎勵、其他地圖及租霸豬不改。已在戰鬥中則先完成／回圖。
保存後重新F5；不必刪除進度。一次性strengthen_shaolin.gd不能重跑覆寫作者後續修改。

`tests/shaolin_strength_suite.tscn`實際渲染181通過／0失敗，包括30隊生成、
三十代表物、兩個真Lv50首領、實際召喚2–3名Lv50銅人、移動、遭遇、撤退、
原地形／入口不變、少林寺限定遷移及冪等。
證據：`artifacts/shaolin-strength-2026-10-10/results.json`／`test-final.log`，
`temple30.png`與`lv50-battle.png`為實際截圖。
更廣泛敵人擴充與舊全專案測試的基線更新不由此專項宣稱完成。
