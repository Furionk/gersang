# 圖層／遮擋：不用逐件調Z

## 放素材時

在2D選純Sprite → Inspector頂部「排序與腳底」：

| 選項 | 效果 |
|---|---|
| 沿用素材 | 同款裁切圖自動沿用共用Resource預設 |
| 貼地 | 落葉、草地、碎石貼片、橋面等，永遠在角色下面 |
| 立體 | 樹／山石／建築，按腳底與角色互相遮擋 |
| 前景 | 明確要永遠蓋住角色的上方遮罩，不是所有屋頂的通用設定 |

選項是這件的覆蓋；「沿用素材」清除覆蓋。原生Z欄位由這套規則管理，
不再用每幀畫面Y填Z。戰鬥與大地圖皆相同。

同一素材改一次：點下方Resource按鈕進入素材Inspector →「排序類型」。
多個使用者一起更新；單件覆蓋仍優先。Resource picker只管排序／hover樣式，
不會把Sprite的Texture、Region、Scale換掉。新PNG沒有預設時先按立體排序，
可以建立WorldSceneryDefinition放在features/world/data/scenery或指定自己的Resource。

這輪已實際看四張biome atlas，18個低矮地被／碎石／橋面預設設貼地。
不知道你想怎樣用的混合圖沒有猜成地面：69個保留立體並標「需要分件審閱」。
分類清單在artifacts/depth-sorting-2026-10-11/classification.json。

## 排序點不對時

選中物件會顯示黃色「腳底／排序點」。通常應放在樹根、石頭／建築接地處，
不是圖片中央、屋頂或人物頭頂。

「顯示裁切圖內的腳底（像素X／Y）」輸入新點，按「校準腳底（保持圖片原位）」。
系統同時移動原點並補償Offset；不跳圖、不加子節點。Ctrl+Z／Redo可恢復。
旋轉、縮放、鏡像仍保留。純Sprite可以這樣改；入口使用其Resource脚底，
不要移動邏輯落點來修屋頂圖片。

## 一張圖包含很多前後層次

一張PNG無法在同一時間一半在角色前、一半在角色後。建議用少量Sprite分件，
每件引用原圖Region、有自己的腳底。不要讓每個分類群組變成一張整體排序。

範本：features/world/authoring/templates/sorted_gate_parts.tscn。
拖入Scenery，近柱／遠柱獨立排序，上方橫樑明確設前景。仍用原props.png，
沒有重畫或分割圖片文件。這只是外觀示例，不提供入口或障礙功能。
根節點可以整組移動、旋轉、縮放；Ctrl+D每組取得獨立穩定ID，保存重開保留。
scenery_parts組只准放外觀，不能把Walkable／怪區／入口塞進去繞過校準。

仍然按Walkable／Blockers尋路。放山的圖片不會自动堵路；角色真的走進山牆，
請另檢查遮罩。也不要為了讓角色露出而把所有山樹改貼地。

## 範圍與限制

六張世界圖、五張戰場、F6和小／世界地圖共用排序。没有半透明／穿牆輪廓。
普通純Sprite仍一層；只有需要多個接地點的大物件才用分件場景。
本輪沒有重建地圖、改玩家進度、改原圖、改入口／出生／通行格。

[實測與限制](depth_sorting_validation.md) · [工程契約](../specs/depth_sorting.md)

工程查閱：tools/project_context.ps1 -Topic sorting。不要重跑classify工具覆寫Artist的後續分類。
