# D35 千年湖怪物生態

使用者新增要求，湖衣姬D34工作仍須一起完成。千年湖主「久行」經使用者確認為「飛行」。

- 千年蟲Lv30–70，命中35%分身（同級，最多2隻、18秒，不遞迴分身、不發額外XP）與25%實際命中吸血。
- 千年鳥Lv40–60，飛行、360遠距、普攻命中留下半徑100／1.6秒火焰，每0.4秒攻擊×0.6魔法AoE。
- 千年狼Lv50–80，實際地面衝鋒750速度／最多700距離／95寬度／攻擊×3.2，每個地面敵人一次；地形與冰牆阻止，不瞬移。
- 千年龜守固定Lv50，致死時同一TacticalUnit及PersistentID進化Lv99飛行千年湖主，回滿新形態HP。湖主遠距380、真衝鋒1000速度／1100距離／150寬度／攻擊×4.2、45%吸血。地面牆不阻擋飛行，但不能出戰場邊界。
- 進化不發死亡／勝利／XP；最終死亡一次，完整兩階段獎勵6000XP由入場快照及SettlementService提交。分身不額外佔入場批次／收據，敵人總存活仍60上限；新機制保持敵隊持久ID、不插入重複玩家獎勵。
- 9個新原生WorldMonsterRegion：蟲3區（30–45／45–60／60–70，各5隊）、鳥3區（40–45／46–52／53–60，各4隊）、狼3區（50–60／61–70／71–80，各4隊）。使用者追加確認移除新增lake_guardian2怪區（原標「幽靈」實際10隊龜守），只有中間原龜守作王。總40隊／10區；Polygon2D可編輯，NAV／地景／入口保持原本。
- Map content_version3遷移只移除已確認退役的10隊及槽，更新中央舊龜守成員Lv50資料、保留其ID，新增39槽。其他地圖／玩家進度／收據／原剩餘槽計時不變。退役定義封存為retired_habitats，僅支持進行中的舊遭遇完成後安全清除，不生成新槽。遇怪／戰鬥時延後，不重建全世界。
- 原創worm/bird/wolf/lord圖集48格，各自Native Layout、頭像。原龜守圖集保留。

接口：UnitDefinition.death_evolution；GameDirector.evolve_unit；BattleSkillEffect.Kind.CHARGE固定tick實際Body移動；AbilityController.on_basic_damage_landed處理攻擊分身／火焰與吸血。新enum只尾部追加。

資料入口features/units/data/monsters/millennium_*.tres、lake_guardian.tres；features/skills/data/lake_*.tres；features/world/data/millennium_lake.tscn/MonsterRegions。一次性author工具禁止日常重跑覆寫Artist。

驗證入口：millennium_ecology_suite、kohime_strength_suite、單位／倉庫／戰鬥／冰牆／全套／GPU MOVE、原生場景與渲染檢視。完成證據見artifacts/millennium-ecology-2026-10-11/。

## 狼／蟲原生裁切修正 2026-10-11

八排美術非等高，逐格的 frame_rects/source_pivots 才是權威，禁止回復高度÷8固定切分。96格原生Atlas完整身體／統一脚底，狼保留越界尾部並排除鄰格殘片；蟲0/4/7排施法格引用同方向完整攻擊格，因原圖相鄰輪廓貼連不能只靠矩形獨立裁切。原PNG、世界布局、導航、怪物能力與進度未改。修正工具完成標記阻止日常重跑；通用分析器 primary_only 預設false，舊素材分析行为不變。獨立lake_atlas_suite及96格GPU渲染驗證，證據artifacts/lake-atlas-repair-2026-10-11/。
