# 物品 Debug 與編輯後台

## 馬上試用

停止舊遊戲再 F5。Debug build 畫面左上有「物品 Debug [F2]」，也可按 F2。

1. 左側選一名兵，再開 Debug；右上目標選單也可指定兵。多選時預設第一名永久兵。
2. 選分類及物品，按「取得至目標背包」；或裝備直接按「取得並立即裝備」。舊裝備保留在背包，不刪除。
3. Debug 預設忽略裝備等級，方便低級兵測試；可取消勾選恢復要求。負重及背包格數仍檢查，失敗會提示且不吞掉原物品。
4. 大補丸／經驗之書先按取得，再按「使用背包內道具」，或世界背包點擊使用。大補丸作用我方全隊（不含敵人），復活後各加500HP／500MP並 clamp 上限；經驗書只升指定兵1級，Lv.100不消耗。
5. 大世界取得、裝備、升級可保存；**戰鬥 Debug 只改本場副本**，回圖不保留臨時裝備或書造成的升級。不能修改保留中的永久隊伍／入場快照。倒數、載入、結算時拒絕操作。

未設定到期與交易；尚未有招募／商店。Debug按鈕不出現在 release build；不是正式商店。

## 物品內容與來源

六类各5件：護甲、刀劍、拐杖、槍矛、斧頭、火槍，共30件。食品首批5種（叉燒包、大麥、小麥、山楂、五色饅頭），**按使用者決定只收錄名稱／重量／圖片，不設定食用效果或飽食度**。原有 food/tea 留作舊原型測試道具，不是新導入的食品。

來源：[食品](https://www.52jushang.com/item/shiwu.asp)、[護甲](https://www.52jushang.com/item/kuijia.asp)、[刀劍](https://www.52jushang.com/item/dao.asp)、[拐杖](https://www.52jushang.com/item/jipangyi.asp)、[槍矛](https://www.52jushang.com/item/mao.asp)、[斧頭](https://www.52jushang.com/item/futou.asp)、[火槍](https://www.52jushang.com/item/huoqiang.asp)。重量保留來源斤數，映射專案負重單位；不是 kg 換算。各武器的原攻擊上下限是加在角色能力範圍上，不能當成角色最終總攻擊。

特攻服保留防禦20／敏捷20，武士服保留防禦10／力量5；訓練拐杖保留攻20–30／智力20，訓練巨漢斧保留攻30–50／力量25／智力25。原低畫素圖以相同內容轉成 Godot 可用的 PNG，沒有重繪或宣称是高清原創。

高級長劍爆雷擊和高級雙發鐵炮一擊必殺連接本作既有技能。技能公式、MP及時序仍是本作原型值，**未聲稱原版完全還原**。暗黑火焰／滿月舞尚未配置，只保留來源名稱並標明限制。大補丸／經驗書是使用者指定 Debug 道具，圖標為本作 SVG，不是假冒原版資料。

參考圖仍屬來源／原作權利方。本地試驗場可檢視；正式公開／商用發行需自行確認授權或替換，沒有宣稱下載即取得商用權利。

## Inspector 後台：正式權威

Godot FileSystem 開啟 `features/progression/data/items/source52/*.tres`；Debug面板可複製選取物品的 .tres 路徑。大補丸／書位於同目錄上一層。

- 識別／美術：id、名稱、category、icon、debug_only。
- 數值：weight、max_stack、required_level、allowed_roles（空陣列表示不限制本作兵種）、modifiers、power_bonus。
- modifiers 支援 strength／agility／intelligence／luck／vitality、attack、attack_min／max、defense、health／mana、speed、accuracy、evasion、magic_resistance。原始裝備資料未給出的數值不要標成原作。
- 技能：granted_skills 放 SkillDefinition 資源；裝備後進同一選兵技能欄／被動入口，卸下移除，不修改共用 UnitDefinition。新增未還原技能可先留 source_skill_names，再另做技能資源。
- 食用：use_effect、restore_health／mana、affects_party、revives、levels_granted。
- 來源：source_url、source_image_url、source_stats、source_skill_names、adaptation_notes。

保存資源並重啟試玩才重新載入資料庫。不要修改 items52.json 後期待每次開遊戲自動覆寫 .tres。

## JSON／CSV 審閱

`specs/sources/items52.json` 是初始選取來源紀錄；不是運行時權威。`tools/build_reference_items.gd` 只建立缺少的 .tres，不覆寫 Inspector 已修改檔案。

執行 `tools/export_item_review.gd` 可從目前原生資源輸出 `artifacts/world/items-review.json` 和 CSV，方便逐行比對名稱、等級、重量、攻擊區間、加成、技能、圖與路徑。這些是單向 review snapshot，不會反向覆寫設定。

## 驗證

`tests/items_suite.tscn` 包含144個來源／數值／圖、裝備加成、食品NONE、全隊復活、滿級、原子失敗、保存、新技能欄及戰鬥副本隔離檢查。完整入口加入 item suite 並保留所有 MOVE 保護；實際畫面已在1280×720／800×450渲染查看。證據見 `artifacts/world/items-results.json`、`items-full.log` 與 `items-debug-*.png`。
