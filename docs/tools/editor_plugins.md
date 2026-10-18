# Editor插件與製作工具

D28更新：[工作流指南](../editor_workflow_guide.md)。Skill Inspector新增中文鍵選擇器，公式試算預設折疊；純Scenery直接Sprite2D。資料分類搬移已按使用者後續要求完成（舊Audit「不搬檔」只適用當時文檔整理）；原美術、歷史文案／備份不搬。

`project.godot [editor_plugins]`目前啟用兩個專案插件，配置在addons。沒有Godot版PlayMaker外掛。

| 插件 | 位置／入口 | 功能與資料 |
|---|---|---|
| Skill Formula Preview v2 | `addons/skill_authoring/plugin.cfg`、plugin.gd、formula_inspector.gd | SkillDefinition Inspector公式／能力預覽；實際公式仍用DamageFormula |
| World Authoring v2 | `addons/world_authoring/plugin.cfg`、plugin.gd | 輕量原生 Inspector／目的地下拉／Tools驗證；沒有常駐Dock或自製滑鼠編輯；模板在features/world/authoring/templates |

查公式先讀 `common/data/skill_definition.gd`／damage_formula，再讀formula_inspector；不要將Inspector顯示數字複製回另一套算法。查製圖先讀 [artist guide](../artist_guide.md)與要編輯的scene；插件是EditorUI，不是正式世界狀態所有者。

World Authoring 的 build／驗證使用遞迴 `WorldAuthoringSnapshot` 複製未保存的原生資料到離樹驗證副本，避免對 placeholder 呼叫方法。若仍保留舊版本，停遊戲，在 Plugins 停用／重啟 World Authoring；不需刪除地圖、TileMap 或存檔。錯誤草稿阻止試玩，Project → Tools → 地圖 → 驗證可看原因；[目前操作](../human_authoring_guide.md)。

| 工具 | 範圍／寫入風險 |
|---|---|
| `project_context.ps1`／`spec_context.ps1` | 只讀路由、路徑、雜湊及證據；找資料從這裡開始 |
| `export_item_review.gd` | 原生資料→artifacts/world CSV/JSON；生成匯出，不改原生設定 |
| `build_reference_items.gd` | 根據來源建立缺失物品；會寫入原生Resource，不是查資料工具 |
| `import_item_icons.ps1` | 導入／轉換圖檔的寫入工具；不能為Audit執行 |
| `build_demo_world.gd`／`decorate_demo_world.gd` | 會生成／裝飾world scene；重建前要確認覆寫範圍與保留作者修改 |
| `tests/*capture*` | 隔離真實渲染並輸出圖片；不是正式存檔操作 |

**不要做**：為了找地圖設計而跑builder；為文檔Audit實例化@tool scene；把Editor預覽當正式WorldSession；修改插件就順手重排資源路径。現有Scene與Resource內res://引用不少，此輪完全不搬檔。

真實Editor圖形操作（Undo/Redo、拖點、保存重開）與headless資料測試的驗收標記分離。GUI項目未做不能由索引或匯入成功自動改為passed。
