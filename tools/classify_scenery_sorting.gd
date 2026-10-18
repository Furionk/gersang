extends SceneTree
## One-shot, append-only reviewed classifications. No scene rebuild or image edits.
const OUT: String = "res://artifacts/depth-sorting-2026-10-11/"
const GROUND: Array[String] = [
	"river_biomes/bridge.tres",
	"river_biomes/forest_fern_cover.tres","river_biomes/forest_fern_cover_0.5.tres","river_biomes/forest_fern_cover_0.6.tres","river_biomes/forest_fern_cover_0.7.tres",
	"river_biomes/forest_path_fringe.tres","river_biomes/forest_path_fringe_0.5.tres","river_biomes/forest_path_fringe_0.6.tres","river_biomes/forest_path_fringe_0.7.tres",
	"river_biomes/granite_valley_scree_fringe.tres",
	"river_biomes/granite_valley_pebble_transition.tres","river_biomes/granite_valley_pebble_transition_0.5.tres","river_biomes/granite_valley_pebble_transition_0.6.tres","river_biomes/granite_valley_pebble_transition_0.7.tres",
	"river_biomes/river_marsh_mud_fringe.tres","river_biomes/river_marsh_wet_grass.tres","river_biomes/river_marsh_pebble_transition.tres",
	"river_biomes/deadwood_wastes_ash_fringe.tres"
]
const MIXED_ATLASES: Array[String] = [
	"res://art/terrain/biomes_v1/forest/environment-atlas-v1.png",
	"res://art/terrain/biomes_v1/granite_valley/environment-atlas-v1.png",
	"res://art/terrain/biomes_v1/river_marsh/environment-atlas-v1.png",
	"res://art/terrain/biomes_v1/deadwood_wastes/environment-atlas-v1.png"
]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if FileAccess.file_exists(OUT+"classification.json"):
		push_error("Classification already finalized. Edit Resources in Inspector, never rerun over artist changes.")
		quit(1); return
	var records: Array[Dictionary] = []
	for path: String in ScenerySorting._files("res://features/world/data/scenery"):
		var relative: String = path.trim_prefix("res://features/world/data/scenery/")
		var source: String = FileAccess.get_file_as_string(path)
		if source.contains("sorting_mode =") or source.contains("sorting_note ="):
			push_error("Preexisting classification; refused overwrite: "+path); quit(1); return
		var preset: WorldSceneryDefinition = load(path)
		var mode: int = ScenerySorting.Mode.GROUND if relative in GROUND else ScenerySorting.Mode.DEPTH
		var review: bool = mode==ScenerySorting.Mode.DEPTH and preset.texture!=null and preset.texture.resource_path in MIXED_ATLASES
		var note: String = "已實際查看原圖：低矮地被／碎石貼片，固定在角色下方；需遮腳可設單件立體。" if mode==0 else "立體素材，腳底Y自動交錯；不產生障礙。"
		if review: note="混合山石／植被／地面的大圖只有一個排序點；先保留立體，精細遮擋請用分件場景。"
		if relative=="river_biomes/bridge.tres": note="橋面固定在角色下方。若需欄杆遮擋，另作Region分件；不改原圖或通行。"
		var before: String = FileAccess.get_sha256(path)
		var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
		if file==null: push_error("Cannot append classification: "+path); quit(1); return
		file.store_string(source+"\nsorting_mode = "+str(mode)+"\nsorting_review_required = "+str(review).to_lower()+"\nsorting_note = "+var_to_str(note)+"\n")
		file.close()
		records.append({"path":path,"mode":mode,"review":review,"reason":note,"before":before,"after":FileAccess.get_sha256(path)})
	var report: FileAccess = FileAccess.open(OUT+"classification.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"records":records,"ground":GROUND,"source_art":"unchanged","scenes":"not written","review":"manual atlas inspection; no PNG-name guessing"},"\t")); report.close()
	ScenerySorting.invalidate_catalog()
	print("SORT_CLASSIFICATION_RESULT presets=",records.size()," ground=",records.filter(func(r: Dictionary) -> bool: return r.mode==0).size()," mixed_review=",records.filter(func(r: Dictionary) -> bool: return r.review).size())
	quit()
