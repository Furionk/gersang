# 內容製作架構審視（2026-10-12）

## 結論

保留原生Resource＋Scene的分工是合適方向；主要瓶頸是硬限制、難追引用、版本過時指南和缺少視覺／資料驗證，不是再建立一個巨大的自製數值Tab。Godot原生[Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)、[SpriteFrames](https://docs.godotengine.org/en/stable/classes/class_spriteframes.html)與[Inspector插件](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/inspector_plugins.html)支持這個方向。

RTS沒有一個統一的「巨商最佳公式」。可參照成熟開源RTS的模板分層，例如[0 A.D.單位模板](https://github.com/0ad/0ad/blob/master/binaries/data/mods/public/simulation/templates/template_unit.xml)將生命、移動、選控、AI、視覺等分開；這支持資料／運行狀態分離的工程原則，並不表示要把其數值或尋路移植進巨商式小隊遊戲。

## 本輪處理

- 原SpriteSheetLayout.valid_for寫死6×8，SpriteAtlas.PATTERNS固定動畫幀。現在用可選Typed Clip擴展；既有裁切、透視、方向映射及腳底保持，不重生美術。
- 兵種Inspector可直達切圖、技能、成長規則、介面圖像；實際SpriteAtlas輸出可逐幀看八方向／來源黃框／腳底。不是靠PNG檔名猜動作。
- 等級試算使用真正CombatStats，不另造一套展示公式。配置問題與快捷鍵衝突提示是建議，不改存檔或直接發獎。
- F2試兵先前依id拼資料夾和_enemy檔名；改成原生UnitTrialEntry引用。來源庫允許任意檔名，避免顯示ID等於路徑的隱藏規則。
- 動態資料發現改ResourceLoader.list_directory；新增內容有顯式Web白名單生成步驟，避免只在Editor看得到。
- 舊七人／永久招募指南標為過時；現行入口指向D38/D39，不移檔或覆寫原始來源。

## 值得長期保留的界線

模板只讀可共享，當前HP／隊伍物品／CD獨立；技能採釋放快照。通行以平面Walkable/Blockers，Sprite排序與碰撞分開。UI/動畫不能成為技能消耗、傷害、召喚上限、經驗或保存的第二權威。動畫可以多幀，但命中時刻與tick仍由戰鬥系統管理。

普攻間隔、前搖、技能冷卻、AI嘗試間隔、遭遇增援機率應分開。戰力評分不是DPS。Inspector中的Lv試算不等於玩家裝備／配點後數值，也不代表完整平衡。體質目前不參與基礎HP；百分比最大HP技能可致死和无限魔爪是既有使用者指定玩法，本輪沒有暗削弱。

## 仍需後續工作，不冒充完成

1. SkillEffectDefinition仍是按Kind分派的共用結構，Inspector有非當前機制使用的欄位；未全面拆為專用子Resource。全新機制仍需程式與專項測試。
2. Catalog原七人／前三種戰場等保留舊fixture入口，Role圖像縮放及舊UI圖集保留fallback。新增作者內容可不依靠它們，但本輪不是「全工程零hardcode」。
3. 舊存檔怪隊可能含生成快照；修改模板不應偷偷改已保存怪隊身份／進度。正式遷移需專門策略。
4. 無上限召喚的性能、極端智力秒殺、AI多隊混戰需要實際戰鬥資料與性能／平衡場次。抽象DPS表不能代替勝率與可操作性測試，本輪不宣稱數值已平衡。
5. 全套已有11項失敗，不能以專項通過代替全綠。原生EditorAPI/Undo回歸不等於所有物理滑鼠工作流已驗收。
