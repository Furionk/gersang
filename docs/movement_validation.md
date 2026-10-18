# 大世界移動修正與防回退

## 原因及修正

等角畫面的垂直方向在邏輯 XY 是對角線。舊四向 Manhattan 路徑把一次合法直行改成兩軸繞行；格路點／方向變化又重啟方向動畫。世界另硬編碼 180，未使用戰鬥的派生移速。最後，角色直接讀 60 Hz 位置、鏡頭按呈現幀率平滑，兩者不同步。

現在：合法空地直接走經半徑 capsule 驗證的直線；阻擋時使用八向禁止切角格路徑，平滑每段也重新驗證。世界主角與戰鬥共用速度／轉向算術及動畫速度比例。完全反向不能卡在舊面朝方向。

WorldVisualPose 僅供角色與鏡頭顯示插值；模擬、碰撞、遭遇及保存仍讀真實 tick 位置。使用 [Godot Engine 的物理插值比例](https://docs.godotengine.org/en/4.7/classes/class_engine.html#class-engine-method-get-physics-interpolation-fraction)，鏡頭採時間一致的指數跟隨；換圖／傳送重置 pose。

## 實測

Godot 4.7.1；原問題有實際失敗測試（movement-before.log，1 通過／19 失敗）。相同空地垂直目標：

| 指標 | 修正前 | 修正後 |
|---|---:|---:|
| 邏輯路長 | 576 | 407.294（直線長度） |
| 路徑橫向偏移 | 288 | 0 |
| 不必要方向轉折 | 1 | 0 |
| 世界／同單位戰鬥速度 | 180／130 | 130／130 |

實際非 headless OpenGL 渲染：40 項通過；30／120 FPS 上限兩輪速度均約 130，均無逆向顯示幀，浮點橫向偏差小於 0.024 world units。GPU 報告為 NVIDIA RTX PRO 6000 Blackwell Workstation Edition。這是此場景的運動驗證，不是所有硬體的 FPS 保證。

資料檢查 33 項涵蓋八方向直線、派生移速、半徑繞障礙、反向轉身、跨路點剩餘距離、呈現插值／換圖重置、30/60/120/144 呈現節奏不改權威移動。實際場景另外驗證 sprite／camera 接線與動畫比例。headless 場景 38 項通過，不計無法渲染的 MOVE-18。

完整回歸為 **108 通過、0 失敗**，包含原世界／結算／存檔檢查、MOVE 契約、7 組既有回歸和新實際移動場景。既有戰鬥、技能、養成、選兵、縮放及冰牆 AI 沒有失敗。證據：

實際進戰／撤退／城門與上下樓整合再跑 **27 通過、0 失敗**，包含真正換圖後 pose 重置。

- artifacts/world/movement-before.log：修正前重現。
- artifacts/world/movement-render-final.log、movement-results-rendered.json：實際渲染。
- artifacts/world/movement-scene-engine.log：headless 場景。
- artifacts/world/movement-full-final.log、results.json：完整入口。

## 之後的保護

AGENTS.md、specs/movement_feel.md 及決策 D09 明確禁止為其他修正任意回退。預設 tests/run_all.gd 必跑 MOVE 資料檢查；--all 必跑實際 sprite／camera／30/120 場景。渲染改動另跑非 headless 場景。可調參數仍可由使用者校準；需要改契約時須記錄新的使用者決策，不得放寬測試掩蓋退步。

請停止目前舊執行個體再 F5。整體世界美術、人工製圖工具驗收仍依原報告保持待驗，本修正不聲稱完成它們。
