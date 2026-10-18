# 經典戰鬥UI與胜利流程驗證 — 2026-10-10

Godot 4.7.1，Compatibility。原生錨點／GridContainer／StyleBox接入現有素材及命令入口；呈現時計獨立於結算，見 [契約](../specs/battle_presentation.md)。

## 本輪結果

- 非headless `battle_presentation_suite.tscn`：42通過／0失敗，1280×720、1920×1080、800×450及GUI字體1.4倍；包含真實2＋3秒計時、卷軸後左鍵點HUD快速返回、同一結果只發一次、舊回呼無效。
- 正式怪隊→真正RTS→注入一次保存失敗：錯誤UI保留，沒有自動返回或發布收據；同candidate重試成功消耗同隊，迟到重複結果不改世界／再發獎。
- `artifacts/world/battle-presentation-render-results.json`及同名日志記錄執行結果；headless／完整回歸結果另記相應JSON，不把截图或hash當测试通过。
- 新HUD替換旧Header設定按鈕；原生點擊／縮放回歸改为點真正齒輪的global_rect，沒有绕过GUI或放寬「不能發地面指令」条件。

## 實際渲染

- `battle-classic-ui-1280x720.png`、`battle-classic-ui-1920x1080.png`、`battle-classic-ui-800x450.png`：新三段式dock及右上角色卡。
- `battle-classic-ui-large-font.png`：大字體增高面板、不和技能／預約列重疊。
- `battle-victory-scroll.png`：原生胜利卷軸；畫面中敵人已實際被傷害擊倒。

已觀看實際渲染，但不宣稱逐像素複製原作、美術素材完全相同或已由另一位玩家驗收手感。World Authoring本輪只核對代碼、配置和補教學，既有人工Editor閘門保持未驗；見 [製圖指南](artist_guide.md)。
