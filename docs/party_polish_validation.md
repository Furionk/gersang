# 箭魂／配點／朝向／圖集驗證 — 2026-10-09

引擎：Godot 4.7.1.stable.official.a13da4feb，Compatibility；測試不讀寫正式玩家存檔。

## 修正與操作

1. 忠臣箭魂攻擊及命中額外加召喚者 `agility*2`，按釋放時快照。技能說明同步顯示公式、攻擊／命中範圍；可在召喚技能effect_data的Inspector調整。參數／所有權見 [契約](../specs/party_polish.md)。
2. 大地圖選角色 → S → 立繪下方「重新配點」→ 確認退還。未花點數禁用；取消無改動；保留等級／物品，不回滿、不復活。
3. 雙方進場初始向畫面下方；行動後可正常轉向。
4. 山豬、石卫及主角原PNG保留；非均勻逐格裁切、固定腳底。大地圖／戰鬥共享工廠，沒有改移動資料或動畫節奏。

## 本輪追加：大地圖斜向圖片

前輪圖集修正仍以等分格內找主輪廓，漏掉鬼衛跨格的武器／頭盔；主角仍是平均切格。大尺寸實際AnimatedSprite2D接觸表亦確認主角NW圖朝右、鬼衛SW圖背向右，不是路徑速度錯誤。

- 完整來源轮廓重建elite／merchant48格，原PNG未變；腳底由待機全輪廓建立。
- Native Resource `direction_rows`／`mirrored_directions`修正藝術方向。主角NW用原NE鏡像、鬼衛SW用原SE鏡像。只翻sprite，不翻HP條／名稱／碰撞／世界方向。
- `world-direction-render-results.json`：33通過／0失敗，真正世界主角／鬼衛代表物在30／120FPS左右斜向兩個行走幀及鏡像切換均通過。
- `world-directions-before.png`／`world-directions-after.png`：實際Godot渲染、大尺寸待機／行走A／B，已觀看比較；不是原PNG重繪。
- `merchant-layout-render.png`／`elite-layout-render.png`：八方向六姿勢的更新圖集。

附圖比較及新規則已登記D15／DIR-01..07，完整回歸和移動渲染結果以本輪JSON為準。

本輪全套回歸113／0，移動渲染40／0，editor import exit0。全套回歸後再收窄石衛朝下死亡幀左緣，移除鄰格法術的綠色殘片；已重新觀看圖集並重跑全部布局／召喚／重配檢查142／0。這一格不改行走、方向、碰撞或計時。

## 執行證據

| 執行 | 結果／證據 |
|---|---|
| 新增功能測試，headless | 142通過／0失敗；`artifacts/world/party-polish-headless-results.json`，涵蓋重配／保存、能力快照、加成命中、錯誤公式、48格布局、原生確認輸入與兩方朝向 |
| 同套測試，非headless | 142通過／0失敗；`party-polish-render-results.json`與實際畫面 |
| 完整 `--all` 回歸 | 113主檢查通過／0失敗；`results.json`含12套子場景＋世界移動場景的執行結果，不把子場景退出碼當作個別断言數 |
| 非headless移動 | 40通過／0失敗；`movement-results-rendered.json`。30／120 FPS實際sprite／camera抽樣，世界速度130.003、戰鬥130.0，無垂直側向偏移 |
| 兩張8方向×6姿勢圖集 | 實際渲染並逐排觀看，兩個PNG；不是headless代替視覺檢查 |
| editor import | exit0，`party-polish-final-import.log`，無SCRIPT ERROR／ERROR |
| context檢索 | 18 topics／37分類文件，0 issues；路由18通過／0失敗，新增重配／圖集直接入口及當輪證據 |

首輪擴充測試曾誤用不存在的 `validate_skill` 方法，改為真實接口 `validate_skill_target` 後重跑通過；這是新增測試腳本的錯誤，不以增加timeout或放寬断言掩蓋。

箭魂例子已實際建立節點驗證：施法者敏捷100 → 原生攻擊220、派生命中360；施法者之後改成20時，已建立箭魂維持原快照。另驗證重配不復活Runtime主角、即時重算其派生移速；沒有修改移速係數或導航算法。

## 實際渲染

- `artifacts/world/beast-layout-render.png`、`elite-layout-render.png`：Godot實際繪製，已觀看8方向×6姿勢，無鄰排人物／武器殘片；腳底標記固定。
- `party-polish-confirm.png`、`party-polish-respec.png`：原生GUI輸入測試的確認／取消／重配。
- `party-polish-entry.png`：兩方入場姿勢。
- `party-polish-spirit.png`：真實召喚節點。

上述是程式注入原生輸入及實際畫面渲染，不冒充人工鼠標／完整實機遊玩驗收。測試用停止physics截取初始朝向，普通戰鬥繼續60Hz邏輯。既有World Authoring人工驗收狀態不變。

AtlasTexture region／margin／filter_clip採 [Godot官方接口](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html)，没有改原始圖片。
