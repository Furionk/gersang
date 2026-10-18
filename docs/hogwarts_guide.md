# 魔法學校・霍格愛茲：遊玩及編輯

在河灣找到「霍格愛茲・平行空間入口」，走近進入；地城入口可以返回河灣。這是一個完整大地城：庭院、迴廊、地窖、大禮堂共8個怪區、30隊怪。

| 怪物 | 等級 | 特性 |
|---|---:|---|
| 催狂魔 | 50–75 | 快速飛行、持續吸魂回血 |
| 黑暗妖靈 | 40–60 | 傳送近敵、遠距普攻 |
| 石像守門人 | 50–70 | 高HP、命中衝擊波 |
| 巨大蛇妖 | 80 | 1秒施法、範圍石化4秒 |
| 三頭犬 | 75 | 大型紅色直線衝鋒 |
| 佛地魔的幻象 | 90 | 25%威力Avada，三階段首領 |

首領第一次死亡變為加儂幻影，鏡頭展示2秒，切換血月戰場。敵我每3秒扣最大HP的1%。再次死亡出現五個半傷害幻影；清除全部後才正常收尾與結算。環境只套用一次，不會因五分身扣五倍血。

## 在Godot改哪裡

- **鋪地形／移景物**：開`features/world/data/hogwarts.tscn`。Ground內原生TileMapLayer可畫地形；Scenery的Sprite可自由拖放、Offset校腳。Walkable/Obstacles控制通行，景物不會偷偷製造阻擋。初始場景採開放通行；想把裝飾迴廊變成實牆，請明確畫Obstacles並檢查出入口與怪區。
- **怪區數量／等級**：MonsterRegions選怪區，改Monster、Party Count、Minimum/Maximum Level、Minimum/Maximum Units；Polygon2D編輯出生／活動／追擊範圍。
- **怪物屬性／配技**：`features/units/data/monsters/school_*.tres`或`voldemort_illusion.tres`。Skills直接拖入技能Resource，不由怪物名稱猜技能。
- **技能係數**：`features/skills/data/school_*.tres`、`illusion_avada.tres`、`blood_moon_wave.tres`。吸魂的Effect Data有持續、Tick Interval、回血比率、斷線距離；蛇妖Cast Time/Duration/Radius直接可改。
- **首領與血月**：`features/units/data/phases/voldemort_blood_moon.tres`改Pause Seconds、Hazard Interval=3、Max Health Fraction=0.01；Fixed Damage大於0改固定扣血。`ganondorf_final.tres`改最後出現數量。不要把下一形態設回自己造成循環。
- **戰鬥畫面**：開`features/battle/maps/hogwarts.tscn`與`hogwarts_blood_moon.tscn`。可改Ground、Scenery與SpawnZones；血月換景的Walkable/Blockers需與普通場景一致，不然安全拒絕換景。
- **SpriteSheet**：`features/units/data/layouts/*_layout.tres`有原圖、各幀Rects、Source Pivots與八方向對應。七張生成圖本輪為6來源姿勢×8列，不代表引擎固定幀數；仍可新增SpriteAnimationClip自訂动作幀序列。三頭犬已獨立方向重排。原PNG不要直接切碎覆蓋。

生成素材是本輪的初版遊戲美術；腳步／施法不是手工逐幀繪製的長動畫。可用Inspector切圖預覽及`tests/hogwarts_art_gallery.tscn`查看每方向、每姿勢；需要更多中間幀時另做新版本，不用重複幀冒充。

本輪改的是Godot專案；已部署的Web包仍是上一版，未自動匯出或上線。下一次Web匯出先重建資源白名單與中文字體子集。
