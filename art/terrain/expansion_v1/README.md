# 地形與地景素材擴充 v1

位置：`res://art/terrain/expansion_v1/`

由內建 imagegen 依既有等角 RPG 美術生成。新增 3 張 1536×1024 透明物件圖集、1 張 1254×1254 地表來源圖集，共 22 種素材。原有 PNG 與地圖保留。

## 素材清單

物件圖集均由左至右、由上至下排列：

| 圖集 | 上排 | 下排 |
| --- | --- | --- |
| foliage-v1.png | 竹叢、秋楓、枯樹 | 花灌木、蘆葦與香蒲、苔木與蘑菇 |
| village-v1.png | 村落石井、雜貨攤、糧袋木車 | 柴火土灶、竹籬笆、木桶與陶罐 |
| ruins-v1.png | 殘破石拱門、守門石獅、古鐘架 | 倒塌石柱、古石祭台、石英晶簇 |
| surfaces-v1.png（2×2） | 沙地、乾裂土地 | 積雪、深色碎石 |

## Godot 使用

- **Sprite 地景**：World Authoring Dock 新增「Sprite 地景（建築／山體）」，把 `scenery/*.tres` 指定到 `sprite_definition`。每件已設定圖集區域、腳底錨點與起始比例；可再調整 `sprite_scale`。
- **地表**：`surfaces/*.tres` 是四個 627×627 的 AtlasTexture，可當 Texture2D 使用。這批是地表美術來源，尚未建立自動銜接 TileSet；建立 64×32 等角圖塊時沿用專案 D18 的 TileSet 流程。
- 地景圖片只提供外觀；建築阻擋、通行與入口路線仍按地圖原生遮罩設定。
- 精確區域與资源路徑見 `catalog.json`。圖集間距依實際透明輪廓檢查，請使用已附資源，避免把圖集硬切等分造成裁切。
- 地表未作無縫平鋪驗收；大面積重複前可先預覽接縫。

## 生成提示詞

完整使用的提示詞保存在 [generation-prompts.md](generation-prompts.md)，參考圖只用於風格與鏡頭一致性。

## 驗證記錄

- 三張物件圖集：透明 Alpha、輪廓完整、安全裁切間距通過。
- 18 份 WorldSceneryDefinition 與 4 份 AtlasTexture 成功儲存並重新載入。
- 20 份原有 PNG 的 SHA256 保持一致。第一次保存檢查時 26 份 PNG／地圖均一致；最終檢查發現 6 份地圖於 15:27:36–15:27:37 同期更新，本批保留現狀，沒有覆蓋或還原它們。90 項回歸檢查在該更新後執行並通過。
- `tests/run_all.gd` 在工作區內隔離 APPDATA 執行：90 通過、0 失敗。首次使用預設資料目錄時存檔重試失敗，導致後續 portal/token 檢查中止；指定可寫的隔離資料目錄後通過。
- `project_context.ps1 -Verify` 仍有兩份既有未分類文件：`docs/human_authoring_guide.md`、`specs/human_authoring.md`；本批沒有改動它們。
- 證據位於 `res://artifacts/terrain-expansion-2026-10-10/`。這批完成資源與匯入檢查，尚未放入正式地圖或作實機地圖佈置驗收。

