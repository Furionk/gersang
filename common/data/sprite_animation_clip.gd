@tool
class_name SpriteAnimationClip
extends Resource
## 一個動作的呈現資料；不負責命中、傷害或施法時間。
@export_enum("待機 idle","移動 walk","普攻 attack","施法 cast","死亡 dead") var action: int=0
## 依播放順序選來源欄，0開始；可重複、倒序、不連續，長度不限於兩幀。
@export var columns: PackedInt32Array=PackedInt32Array([0])
## 原生SpriteFrames每秒幀數。受角色速度／施法倍率影響時仍由既有呈現規則處理。
@export_range(0.1,120.0,0.1) var fps: float=3.0
## true循環播放；只改外觀，不會自動重複傷害。
@export var loop: bool=false
## 每幀相對時間權重；留空全部1。例[1,2,1]讓中間一幀停留兩倍時間。
@export var frame_durations: PackedFloat32Array=PackedFloat32Array()
## 零前搖施法從哪一個播放幀開始（0開始）。可略過純待機／預備幀，避免頻繁立即施法只顯示站立。
@export_range(0,256,1) var instant_start_frame: int=0
@export_group("此動作方向覆蓋（留空沿用Layout）")
## 某些原圖的攻擊／施法列朝向與移動不同；按畫面右、右下、下、左下、左、左上、上、右上填8個來源列。
@export var direction_rows: PackedInt32Array=PackedInt32Array()
## 留空沿用Layout鏡像；填8項只影響此動作圖像，不改操作方向／命中。
@export var mirrored_directions: Array[bool]=[]
const STATES: Array[String]=["idle","walk","attack","cast","dead"]
func state_name() -> String:
	return STATES[action] if action>=0 and action<STATES.size() else ""
func issues(source_columns: int) -> PackedStringArray:
	var result: PackedStringArray=PackedStringArray()
	if state_name().is_empty(): result.append("動作類型無效。")
	if columns.is_empty(): result.append("動作至少需要一幀。")
	if instant_start_frame<0 or instant_start_frame>=columns.size(): result.append("立即施法起始幀超出播放幀範圍。")
	for column: int in columns:
		if column<0 or column>=source_columns: result.append("來源欄%d超出0至%d。"%[column,source_columns-1])
	if not is_finite(fps) or fps<=0: result.append("FPS必須是正數。")
	if not frame_durations.is_empty() and frame_durations.size()!=columns.size(): result.append("每幀時間權重數量須等於播放幀數。")
	for duration: float in frame_durations:
		if not is_finite(duration) or duration<=0: result.append("每幀時間權重必須是正數。")
	if not direction_rows.is_empty() and direction_rows.size()!=8: result.append("此動作方向覆蓋須留空或填8項。")
	if not mirrored_directions.is_empty() and mirrored_directions.size()!=8: result.append("此動作鏡像覆蓋須留空或填8項。")
	return result
