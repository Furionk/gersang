# 庭園捕猴：Meshy 主角與五件裝備

2026-10-18。使用者提供六張設計參考，批准 Meshy T2.5 Smart Topology 六件帶貼圖生成（90 credits）及主角綁骨（5 credits）。總額 95 credits，未另外購買動畫、重拓撲或轉檔。主角四視圖經 imagegen 整理為單人 T pose 後輸入 Meshy。

## 交付位置

- 遊戲 GLB：`features/monkey/assets/meshy/`，主角 1024 貼圖、道具各 512 貼圖。
- 原始 Meshy GLB、完整貼圖：`artifacts/monkey-meshy/raw/`，不覆寫。
- 可編輯 Blender：`artifacts/monkey-meshy/hero-animated.blend` 及五件道具 `.blend`。
- 參考及任務 ID：`artifacts/monkey-meshy/references/`、`jobs.json`。綁骨任務 `01a14aaa-c4d0-72a5-b1f9-fff1d7234ac0`。
- 重建工具：`tools/prepare_meshy_hero.py`、`tools/prepare_meshy_props.py`。Blender 4.5、`--factory-startup`。

## 動畫與裝備

主角具有 Idle、NetAttack、FlyerHold、Walk、Run。Walk／Run 來自 Meshy 綁骨附送動作；其餘為本地製作並烘焙的骨架動作。NetAttack 長度 0.5 秒，配合既有 0.12 秒起手、0.16 秒有效及收招。FlyerHold 雙手上舉，裝備根節點跟隨雙手中心，Rotor 獨立旋轉。呼拉圈位於腰部。手持道具跟隨 RightHand 骨骼位置。

控制、碰撞、捕捉距離、猴子 AI 和結算仍由原有邏輯管理。`meshy_presentation.gd` 僅管理外觀；網袋使用裁切網孔 shader，避免建造大量網線。角色是 24 骨的輕量骨架，沒有獨立手指骨或臉部表情 rig。

## 實際模型預算

| 模型 | 三角面 | GLB bytes |
|---|---:|---:|
| 主角 | 6,285 | 見 hero-report.json |
| 網 | 1,395 | 見 props-report.json |
| 棒 | 808 | 見 props-report.json |
| 雷達 | 1,225 | 見 props-report.json |
| 螺旋槳 | 1,232 | 見 props-report.json |
| 呼拉圈 | 1,050 | 見 props-report.json |

Meshy 輸出面數是目標附近，並非嚴格等於請求數。原始圖片和來源模型不納入 Web 匯出；遊戲使用壓縮後 GLB。

## 驗證

原生 `monkey_meshy_suite` 驗證五動畫片段、雙手骨骼、獨立 Rotor、揮網時長及裝備可見性，失敗數 0。既有捕猴核心 18/0、遭遇結算 27/0 通過。遊戲內六個姿勢截圖位於 `artifacts/monkey-meshy/game-*.png`。

Web 建置及實際瀏覽器結果另記於 `artifacts/monkey-meshy/validation.md`，不能將原生截圖當成 Web 驗證。

新版 Web `a970c8451fadef8554b9bb97` 已實測入口、成功捕捉、五件換裝、螺旋槳升空與呼拉圈加速。1280×720 最近五段 10 秒平均 59.91–60 FPS，控制台無 error。使用內嵌瀏覽器鏡頭替代模式；本次沒有重跑完整五猴勝利路線。
