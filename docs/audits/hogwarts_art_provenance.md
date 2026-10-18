# 霍格愛茲原圖來源與初次裁切

2026-10-13，使用內建imagegen產生透明PNG，原輸出保留於：
`C:/Users/Furion Mashiou/.codex/generated_images/019f97b5-76f8-7151-a971-b4373a7ac730/`

下面是製作規格摘要，非逐字提示記錄。不是下載原遊戲模型／截取原遊戲圖集。

角色共通：古典等角RTS、寫實繪製/預渲染風格、透明背景、完整身體、6來源姿勢（站立、行走A/B、攻擊、施法、死亡）、8方向列。生成圖的方向與格界不可盲信；本輪已實際渲染並以native layout修裁切、腳底及三頭犬方向。

| 專案PNG（features/units/art/hogwarts） | 原始exec檔名 | 規格摘要 |
|---|---|---|
| school-dementor-v1.png | exec-e26d06cb-d1b2-4d35-bcfe-2b67310b0977.png | 黑色破碎兜帽袍、浮空亡魂、青綠吸魂施法 |
| school-dark-elf-v1.png | exec-d6669858-f055-45f4-8d1a-3f631449a848.png | 矮小尖耳妖靈、舊布衣、紫色傳送魔法 |
| school-gatekeeper-v1.png | exec-ccc4be4f-49d0-43e5-b467-0930900fe9ca.png | 大型石像騎士、沉重劍、金色斬擊 |
| school-basilisk-v1.png | exec-e4e1df31-e6d9-42ba-8de5-07638ed611a6.png | 巨大盤繞綠蛇、張口刺擊、石化綠光 |
| school-cerberus-v1.png | exec-99b9d959-2e95-4180-bcc3-63607315851d.png | 三頭黑紅巨犬、紅色能量與衝鋒 |
| voldemort-illusion-v1.png | exec-793bca96-9cca-4244-9692-c849bc189570.png | 蒼白禿頭黑袍黑法師、綠色魔杖咒光 |
| ganondorf-phantom-v1.png | exec-2d20046a-a995-4c62-b144-52f78c99b4d2.png | 紅髮黑金甲巨大劍士、紅色血月魔力 |

`art/terrain/hogwarts/school-props-v1.png`來自`exec-34dea8c9-d05e-4eb1-80b3-29ab43b51219.png`：4×2可分件等角哥德建築／城門／禮堂／兩向迴廊／石階／蛇像／魔法書／血月祭壇。各件以WorldSceneryDefinition的Atlas Region引用原圖。

## PNG SHA256

```text
school-dementor-v1.png 549D760A047C21F97E2C7256992916E31AEBB432BFCCCB4BB922B63F158EB10B
school-dark-elf-v1.png 50328ED45269DA67A2D7D4054BCC9D3D928EA33B604E7AC171A717FF4709ADF1
school-gatekeeper-v1.png D6AF9D4737337D7313E9B11FD6AAAEE7AC063BF2EEFAEE4D403B912DADAB3D11
school-basilisk-v1.png 3EE563D65FF8B207D1873C2C9F385EDF89C45DFF20EBA62A722BCCC80546A978
school-cerberus-v1.png DDEEF903BB937C9E38FF16D12B5F1FC50CB3CE517DE35A9AE1728D38BDA91FE1
voldemort-illusion-v1.png C9A8F23D1139224A040B2EE06799E8F9877FF218ED973213188EDD7DCE726C57
ganondorf-phantom-v1.png 30D8280BF00A166A692DCAFCF1FC6E9C84DA2C58451B141C1BBC72DBAABFF02B
school-props-v1.png 547EAED45B1795BAE225918A3EFFAD6A8FFB4BF2BA1269A459F47D693C8B9F83
```

## 原生資料與限制

`review_hogwarts_atlas.gd`只分析alpha連通塊產生裁切Rect與接地Pivot，**沒有重新寫PNG**。站立腳底作活體動作的固定接地參考；死亡有獨立身體底點。三頭犬Direction Rows改為`[2,1,0,7,6,5,4,3]`。生成形態的不一致不能只靠映射修掉；部分動作/方向仍是初版美術，沒有手工補畫中間幀。

48姿勢原生AtlasTexture實際渲染證據：`artifacts/tests/hogwarts/gallery/*.png`。各SheetLayout仍可在Godot Inspector編輯，無固定引擎幀数。禁止重新執行初始生成/切分工具覆蓋日後Artist修改。
