# 兵種與成長：資料入口

這是內容導航，不是另一份數值表。首次兵種分析應讀這頁、要改的 `.tres`、`common/data/unit_definition.gd`；不先讀整個战鬥／UI協調器。

2026-10-11分類：七名角色在 data/mercenaries；敵人表的短檔名在 data/monsters；spirit及copper_reinforcement在data/summons。圖像仍共用features/units/art。詳見[工作流指南](../editor_workflow_guide.md)，不要按舊root data路徑新建另一份兵種。

| 類別 | 角色 | 原生定義 |
|---|---|---|
| 主角 | 行旅商人 | `features/units/data/mercenaries/merchant.tres` |
| 永久傭兵 | 鐵衛／火銃手／雷術師 | `guard.tres` / `gunner.tres` / `mage.tres`（同資料夾） |
| 永久傭兵 | 醫術師／道術師／符咒師 | `healer.tres` / `supplier.tres` / `controller.tres` |
| 敵人 | 山野妖獸／山寨弓兵 | `beast.tres` / `archer.tres` |
| 敵人 | 黑甲石衛／赤魂獄使 | `elite.tres` / `boss.tres` |
| 召喚 | 忠臣箭魂 | `spirit.tres`（不是永久招募位） |

首次註冊七人隊／四種敵人在 `common/data/catalog.gd` 的PARTY_PATHS／ENEMY_PATHS；箭魂由SkillEffectDefinition引用。展示名不是persistent ID，不能改名時重抽世界成員。

- 初始能力、生命、MP、普攻射程／間隔、移速、偵測、模型、技能清單：兵種 `.tres`。
- 技能MP／公式／目標／效果：`features/skills/data/*.tres`，schema在common/data。操作以D11/D12與 [現行契約](../../specs/combat_controls.md)為準，不照舊V2施法操作。
- 派生係數：`features/progression/data/stat_rules.tres`，算法 `combat_stats.gd`／`combat_math.gd`。
- 升級門檻：`features/progression/data/experience_curve.tres`；每角色Runtime在CharacterRecord，Lv100、四屬性配點、裝備獨立。
- 裝備提供技能由granted_skills聯集，不在兵種硬編碼。界面立繪／肖像與戰鬥sprite是不同字段。
- 箭魂攻擊／命中按召喚者敏捷快照加成、免費重配點及非均勻山豬／石衛圖集：見 [D14契約](../../specs/party_polish.md)。召喚公式在summon.tres.effect_data，裁切在units/data/layouts，不能直接覆寫PNG或共用UnitDefinition。
- 世界怪隊成員／等級／穩定ID由PartyBuilder固定生成；數量、活動區、等級範圍看 [世界內容](world.md)，不要改圖上代表sprite當作新增隊員。

**未完成**：招募、轉職、完整兵種培育分支／多人交易。不把UI預留容量或設計願景列成已實作。將來加兵種設計卡只存定位／設計意圖與Resource鏈接，數字不複寫；配套驗收與狀態另登記。
