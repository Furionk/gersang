# 河灣大地圖豐富化 — D22

## 方向與來源

使用者提供巨商大地圖／山林／河岸截圖並要求使用新增地形素材填滿、豐富大世界。這輪實作範圍為 `features/world/data/river_bay.tscn`，不覆寫千年湖、少林或兩層古井。

從附圖歸納的設計：地形以成群山林而非均勻單棵構成；河岸連續；生活物件靠近道路及入口；大塊環境夾出可辨識的空地。官方資料亦將入口依附地標、不同狩獵地區有明確分層：[靈魂之森入口](https://landing.mangot5.com/template/gs/event/230112_esplori/index.html)、[匡廬山地區列表](https://landing.mangot5.com/template/gs/event/240424_vekigo/index.html)。美術密度／擺放是附圖分析與本專案創作決策，不宣稱官方精確幾何。

## 已保存內容與資料所有權

- 原有174件可見地景，新建958件（含橋）；21件舊 agent 自動生成、錯放河道的山石保留在 Technical/OldRiverRockDecor，現在可見1111件。
- Scenery/RiverComposition 分 Riverbanks、Woodlands、Highlands、VillageLife、FieldEdges、GroundCover。分類父層原點／比例1、Y-sort enabled；每件是原生 WorldAuthorNode + owned Artwork，可移動、複製、刪除。
- 48個新增 biome 模組轉為腳底錨點 Resources，位於 features/world/data/scenery/river_biomes。原始 PNG 不改；素材来自 art/terrain/biomes_v1 及 expansion_v1，沒有下載／抽取巨商客戶端圖片。
- 地表 TileSet：features/world/data/tiles/river_bay_enriched.tres；來源1的五排為苔草、落葉、土徑、碎石、耕地，每排8變體。來源0保留舊地面／道路 Terrain。新增五類用原生 Tiles 畫筆；不冒稱新增了完整無縫自動 Terrain 過渡。
- 障礙 TileSet：river_bay_enriched_obstacles.tres；來源2只為既有長條河道換水面外觀，完整複製原碰撞形狀／alternative／custom data，不讓水域變可走。導出貼圖在 art/terrain/native_tiles/river_biome_details.png、river_channel_visual.png。
- 野外布局使用獨立 seed 20261010、限次 jittered grid、人工生活點及道路／入口／怪域中心留白。一次性保存為場景，不在啟動或每幀重新生成，不讀寫遊戲 RNG。
- 保留所有入口（包括 D20a 的 town_door 新位置）、到達點、地標、怪區形狀／人口／戰場與完整平面導航輪廓。不動正式進度、角色或戰鬥數值；D09手感不變。

## 編輯入口／安全限制

打開 river_bay.tscn → 2D → Scenery/RiverComposition 改物件；Ground 的原生 TileMapLayers 改地表。新素材的 sprite_scale／foot_anchor 在各自 Resource；單件修改用 Make Unique。工具 enrich_river_bay、refine_river_composition 僅是本輪一次性作者工具，不是日常 builder／啟動鉤子；不得對已有作者修改的場景直接重跑。

備份及證據：artifacts/river-enrichment-2026-10-10/river-before.tscn、composition.json、refinement.json、results.json、after-*.png。21件舊河石是可恢复 archived nodes，非刪除資產。

## 驗收

- RICH-01 保存原生地表完整24576格，沒有無效alternative／黑洞；導出Texture／TileSet不嵌入原始大PNG。
- RICH-02 四怪區、所有入口／地標、每個導航outer／hole完全一致，不以抽樣或容差放過幾何改動。
- RICH-03 >1000件地景、六個分類、原生scene owner、Y-sort、路／入口留白及保存重開。
- RICH-04 實際渲染全貌與四區，按可見構圖／留白／材質統一度評分，不以headless代替視覺驗收。
- RICH-05 完整既有回歸、非headless MOVE 30/120 FPS與編輯器API；機器／場景條件下的render benchmark，不預先宣稱普遍FPS。
- 手動鼠標／作者試用仍由人驗收；本輪不做NPC交易、任務、採集或泳行機制。村落物件只是環境，不假裝有未接線互動。

資料／視覺／測試實測見 docs/river_enrichment.md；Topic scenery 或 authoring 可查閱。
