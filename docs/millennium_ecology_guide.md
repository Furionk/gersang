# 千年湖配怪與湖衣姬強化入口

Godot 打開 features/world/data/millennium_lake.tscn，選 MonsterRegions 下怪區：原生 Inspector 設定怪種、等級上下限、怪隊數量；展開 SpawnArea／RoamingArea／PursuitArea 用原生 Polygon 頂點編輯。

現在 10 怪區／40 隊：中央龜守 1 隊，蟲 15 隊、鳥 12 隊、狼 12 隊。蟲 Lv30–70 分身＋吸血；鳥 Lv40–60 飛行＋遠距範圍火焰；狼 Lv50–80 實際衝鋒；中央龜守 Lv50 死亡進化為 Lv99 飛行湖主。

依使用者確認移除後加的 lake_guardian2（10 隊重複龜守）；中央原龜守保留。場景備份在 artifacts/millennium-ecology-2026-10-11/before-scene.tscn.txt，舊 Habitat 留在退休檔案以完成尚未結束的存檔戰局。沒有重設主角、裝備、背包、金錢或其他地圖進度。

數值：features/units/data/monsters/millennium_worm.tres、millennium_bird.tres、millennium_wolf.tres、millennium_lord.tres、lake_guardian.tres。技能：features/skills/data/lake_*.tres。新美術共享於 features/units/art/millennium_*-v1.png，切分／脚底用 data/layouts/millennium_*_layout.tres；原圖保留。

2026-10-11 狼／蟲切圖修正：原圖排距非等高，不能用高度÷8。兩份 layout.tres 已逐格保存96個原生裁切／脚底資料，放寬水平範圍以保留完整尾部並排除鄰姿勢碎片。蟲三個貼連姿勢的施法格沿用同方向完整攻擊格，不改技能傷害／觸發。可在 Inspector 編輯 Frame Rects／Source Pivots；修正工具已有完成標記，不能日常重跑覆寫 Artist。

湖衣姬 X 大地魔爪零魔力、零冷卻、無召喚數量上限，每次新按鍵施放一隻，存活 30 秒。智慧100 的爪 HP1620／防80；智慧200 HP2820／防160，採施法時快照。刺擊間隔0.45秒、智慧傷害；同一召喚者的地樁範圍內傷害1.75倍、攻速1.4倍，不重疊加乘。爪維持不可控制。

調整入口：skills/data/earth_claw.tres（召喚／生命防禦公式），units/data/summons/earth_claw.tres（基本能力），skills/data/claw_strike_empowered.tres（刺擊／地樁聯動），skills/data/earth_stakes.tres（主技）。敵方舊魔爪模板另外保留，沒有同步變成無限強化。

自然勝利現在先保留 2 秒可操作收尾，之後才發經驗與顯示勝利 UI，再 3 秒返回。收尾期間左擊仍為操作，不是跳過；勝利 UI 出現後左擊可立即回圖。
