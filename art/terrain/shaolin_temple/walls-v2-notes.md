# 少林寺院牆修正 v2

新增美術：`res://art/terrain/shaolin_temple/walls-v2.png`，1536×1024 RGBA，內建 imagegen 生成，原 `props-v1.png` 保留。

圖集 3×2：東西直牆、南北直牆、南側凸角、北側內角、西側角、東側角。沿用原朱牆、灰瓦、石基風格。圖片接合点以 `sprite_basis` 校準到精確 2:1 等角軸；該矩陣只作用於圖片，編輯器與遊戲共用 `artwork_transform()`。

已更新 `res://features/world/data/shaolin_temple.tscn`：44 個原有直牆作者 ID 保留，按連續線段調整圖片中心與長度；新增四個完整轉角作者。門樓、地形、通行／障礙遮罩、怪物區域、入口／到達點保持原資料。13 份牆資源位於 `res://features/world/data/scenery/shaolin_walls_v2/`，可在原生 Inspector 調整。工具 `res://tools/repair_shaolin_walls.gd` 是一次性製作記錄，不在啟動時執行。

驗證：

- 保存／重新載入後，所有原生地形與遮罩 byte-for-byte 相同；入口路線及到達點相同。
- 實際 Compatibility 渲染與正式入口載入：228 通過、0 失敗，含可見直牆接縫的朱牆像素採樣。測試由 `main.tscn` 啟動，透過青嶺河灣原本的 `shaolin_door` 入口轉場，確認 WorldCatalog 載入原 `shaolin_temple.tscn` 與所有新牆件；不是直接指定测试替代地圖。
- `tests/run_all.gd -- --all`：109 個上層檢查通過，含 18 個舊測試場景與 headless 移動場景；0 失敗。
- 額外非 headless 移動場景：40 通過、0 失敗，含 30／120 FPS。
- 全部使用工作區內的隔離 APPDATA，沒有讀寫正式進度。圖片是實際隔離遊戲渲染，不是概念合成圖。
- 原場景／腳本備份與證據：`res://artifacts/shaolin-wall-repair-2026-10-10/`。
- 已檢查全院及四角渲染；未聲稱逐像素的重複紋理無縫驗收或人工滑鼠驗收。

## 完整生成提示詞

```text
Use case: stylized-concept. Asset type: production MODULAR WALL KIT transparent sprite atlas for a 2:1 isometric historical East Asian RPG.
Reference image is STYLE/MATERIAL reference only: match its weathered vermilion red plaster courtyard walls, dark gray Chinese roof tiles, small gray stone foundation courses. Do not copy its buildings, trees or standalone wall terminal ornaments.
Generate ONE 1536x1024 PNG on TRUE transparent alpha with STRICT 3 columns x 2 rows of six distinct modular pieces, each entirely inside its 512x512 cell, separated by at least 25px transparent padding. Uniform physical wall height/thickness, uniform brick and roof-tile size. Soft neutral upper-left lighting. Detailed hand-painted/pre-rendered RPG realism. ORTHOGRAPHIC 2:1 ISOMETRIC: every horizontal wall-foot and roof-ridge line slopes EXACTLY +/-0.5 in screen coordinates, never perspective.
Purpose: these pieces must connect into an enclosed rectangular temple courtyard, no cracks between adjacent sprites. Straight pieces are continuation modules, WITHOUT tall terminal posts, sculptures, finials, protruding edge stone caps, or decorative end ornaments. Ends are simple flush matching cut planes. Roof consists of continuous simple grey clay tile cap with small overhang, no oversized ornate pagoda eaves.
Cell order left-to-right, top-to-bottom:
TOP LEFT: one full straight segment along screen DOWN-RIGHT (\), about400px projected width and200px projected ground rise; complete rectangular red wall face, 3 courses of gray foundation, continuous tile roof. LEFT ground connection target near(56,210), RIGHT near(456,410) local cell.
TOP MIDDLE: matching straight segment along screen UP-RIGHT (/), same dimensions/materials/height. LEFT ground connection near(56,410), RIGHT near(456,210) local cell.
TOP RIGHT: FRONT convex L-corner shaped V in its ground plan. A structurally joined 90 degree wall corner with BOTH red wall faces visible from outside and continuous roof tiles wrapping seamlessly around the corner. Corner-foot target near(256,410); two ground arms extend up-left to(76,320) and up-right to(436,320).
BOTTOM LEFT: matching REAR concave L-corner shaped an upside-down V in its ground plan. Vertex-foot near(256,230), two arms extend down-left to(76,320) and down-right to(436,320); visible courtyard-side faces. Seamless joined red walls, stone footing and roof miter.
BOTTOM MIDDLE: matching LEFT L-corner shaped <, vertex-foot near(92,330), arms up-right to(272,240) and down-right to(272,420); seamless connected roof at the bend.
BOTTOM RIGHT: matching RIGHT L-corner shaped >, vertex-foot near(420,330), arms up-left to(240,240) and down-left to(240,420); seamless connected roof at the bend.
Each L corner has two legs roughly HALF a straight segment's length and the same wall height. All SIX pieces at IDENTICAL scale. No ground planes, grass, backdrop, text, labels, grids, outlines, watermark, people, glow, checkerboard. REAL TRANSPARENT alpha outside sprites. Keep every wall and roof completely visible inside its cell.
```

