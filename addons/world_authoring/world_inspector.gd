@tool
extends EditorInspectorPlugin
var plugin: EditorPlugin
const LABELS: Dictionary = {"display_name":"顯示名稱","simple_party":"單一怪物隊伍","minimum_units":"每隊最少隻數","maximum_units":"每隊最多隻數","minimum_level":"最低等級","maximum_level":"最高等級","party_count":"怪隊總數","respawn_min_seconds":"重生最短（秒）","respawn_max_seconds":"重生最長（秒）","aggressive":"主動追擊玩家","trigger_radius":"入口觸發半徑","sorting_review_required":"需要分件審閱"}

func _parse_property(object: Object, type: Variant.Type, name: String, _hint: PropertyHint, hint_text: String, _usage: int, _wide: bool) -> bool:
	if object is WorldSceneryDefinition and name=="sorting_mode":
		var editor: EditorProperty = preload("res://addons/world_authoring/sorting_mode_property.gd").new()
		add_property_editor(name,editor,false,"排序類型")
		return true
	if object is Node and (ScenerySorting.is_scenery_sprite(object) or (object is WorldAuthorNode and object.sprite_definition!=null)) and name in ["z_index","z_as_relative","y_sort_enabled"]: return true
	if object is WorldAuthorNode and name in ["monster","target_map_id","target_entry_id"]:
		if name!="monster" and object.kind!=WorldAuthorNode.Kind.PORTAL: return true
		var editor: EditorProperty = preload("res://addons/world_authoring/choice_property.gd").new()
		editor.set("mode",name)
		editor.set("registry",plugin.get("registry"))
		add_property_editor(name,editor,false,"怪物種類" if name=="monster" else "目的地地圖" if name=="target_map_id" else "目的地落點")
		return true
	if (object is WorldAuthorNode or object is WorldSceneryDefinition) and LABELS.has(name):
		var editor: EditorProperty = preload("res://addons/world_authoring/scalar_property.gd").new()
		editor.configure(type,hint_text)
		add_property_editor(name,editor,false,LABELS[name])
		return true
	return false

func _can_handle(object: Object) -> bool:
	return object is WorldAuthorNode or object is WorldMap2D or object is WorldTileLayer or object is WorldRegionPolygon or object is WorldSceneryDefinition or (object is Node and ScenerySorting.is_scenery_sprite(object))

func _parse_begin(object: Object) -> void:
	if object is WorldSceneryDefinition:
		var note: Label = Label.new(); note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		note.text="排序預設由同款素材共用；單件可覆蓋。貼地不蓋人物，立體按腳底交錯；固定前景只供明確遮罩。排序不改通行／障礙。"
		add_custom_control(note)
		return
	if object is Node and (ScenerySorting.is_scenery_sprite(object) or (object is WorldAuthorNode and object.sprite_definition!=null)):
		var controls: VBoxContainer = preload("res://addons/world_authoring/sorting_controls.gd").new()
		controls.set("plugin",plugin); controls.set("item",object)
		add_custom_control(controls)
		if object is Sprite2D: return
	var help: Label = Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if object is WorldMonsterRegion:
		help.text = "① 選怪物及數量／等級  ② 選範圍，用上方原生 Polygon 頂點工具  ③ F6 試玩。\nSimple Party 關閉時使用 Habitat 的混合怪隊；原資料保留。"
		add_custom_control(help)
		for row: Array in [["出生範圍","SpawnArea"],["遊走範圍","RoamingArea"],["追擊範圍","PursuitArea"]]:
			var button: Button = Button.new()
			button.text = "編輯 "+row[0]
			button.pressed.connect(plugin.select_shape.bind(object,row[1]))
			add_custom_control(button)
	elif object is WorldTileLayer:
		help.text = "使用底部 Godot TileMap 面板畫／擦。地表用 Terrains；障礙與通行用 Tiles。分類父層保持原點。"
		add_custom_control(help)
	elif object is WorldRegionPolygon:
		help.text = "用 Godot 上方 Polygon 工具新增／移動頂點；Ctrl+Z 撤銷。子 Polygon 的 Is Hole 表示排除洞。只有選取的範圍會顯示。"
		add_custom_control(help)
	elif object is WorldAuthorNode:
		help.text = "直接在 2D 拖動。Sprite Definition 控制圖片／腳底／縮放；入口的 Target Map Id／Target Entry Id 控制連接。Ctrl+D 複製取得新 ID。"
		add_custom_control(help)
		if object.kind==WorldAuthorNode.Kind.PORTAL:
			var destination:Button=Button.new(); destination.text="開啟目的地Scene（保存後的地圖）"
			destination.disabled=object.target_map_id.is_empty()
			destination.pressed.connect(func()->void:
				WorldCatalog.initialize() # Saved scenes only, never compile a live editor/placeholder root.
				var target:WorldMapDefinition=WorldCatalog.definitions.get(object.target_map_id)
				if target!=null and not target.scene_path.is_empty(): EditorInterface.open_scene_from_path(target.scene_path))
			add_custom_control(destination)
			var meaning:Label=Label.new(); meaning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			meaning.text="Target Map Id＝目的地地圖ID；Target Entry Id＝目的地Entrances下ARRIVAL節點的Stable Id，不是入口名稱。只拖Artwork改外觀；拖入口父節點會移動觸發範圍。通行仍看Walkable／Obstacles。"
			add_custom_control(meaning)
	else:
		help.text = "Ground：鋪地　Scenery：建築／山體　Entrances：入口　MonsterRegions：配怪。\n拖入 authoring/templates 場景可新增物件。Project → Tools → 地圖 可檢查；F6 隔離試玩。"
		add_custom_control(help)
