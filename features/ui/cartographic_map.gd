class_name CartographicMap
extends Control
signal place_selected(logical: Vector2)
var director: GameDirector
var source: WorldMapProjection
var circular: bool = true
var zoom: float = 2.0
var focus: Vector2 = Vector2(0.5,0.5)
var map_image: TextureRect
var map_viewport: SubViewport
var shader_material: ShaderMaterial
var player_uv: Vector2 = Vector2.ZERO
var player_screen: Vector2 = Vector2.ZERO
var definition: WorldMapDefinition
var drawn_map_id: String = ""
var selected_point: Vector2
var selected_name: String = ""
var dragging: bool = false
var rendered_revision: int = -1
var rendered_transform: Transform2D
var label_bounds: Array[Rect2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if source == null:
		source = WorldMapProjection.new()
		add_child(source)
	map_viewport = SubViewport.new()
	map_viewport.name = "ProjectedMapCamera"
	map_viewport.disable_3d = true
	map_viewport.gui_disable_input = true
	map_viewport.transparent_bg = true
	map_viewport.world_2d = source.viewport.world_2d
	map_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(map_viewport)
	map_image = TextureRect.new()
	map_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_image.stretch_mode = TextureRect.STRETCH_SCALE
	map_image.texture = map_viewport.get_texture()
	map_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_image.show_behind_parent = true
	var shader: Shader = Shader.new()
	shader.code = """shader_type canvas_item;
uniform bool round_mask = true;
uniform vec2 control_size = vec2(196.0);
void fragment() {
	vec2 p = (UV - vec2(0.5)) * control_size;
	if (round_mask && length(p) > min(control_size.x, control_size.y) * 0.435) { discard; }
	vec4 scene = texture(TEXTURE, UV);
	COLOR = vec4(mix(vec3(0.035,0.045,0.05),scene.rgb,scene.a),1.0);
}"""
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	map_image.material = shader_material
	add_child(map_image)
	move_child(map_image,0)

func to_uv(point: Vector2) -> Vector2:
	return (Iso.project(point)-source.bounds.position)/source.bounds.size

func _scale() -> float:
	var fit: float = minf(size.x/source.bounds.size.x,size.y/source.bounds.size.y)
	# Local camera renders native tiles directly at the chosen zoom.
	return minf(size.x,size.y)/1200.0*zoom if circular else fit*zoom

func uv_to_screen(uv: Vector2) -> Vector2:
	return (uv-focus)*source.bounds.size*_scale()+size*0.5

func logical_to_screen(point: Vector2) -> Vector2:
	return uv_to_screen(to_uv(point))

func screen_to_logical(point: Vector2) -> Vector2:
	return Iso.unproject((point-size*0.5)/_scale()+source.bounds.position+focus*source.bounds.size)

func overview() -> void:
	zoom = 1.0
	focus = Vector2(0.5,0.5)
	selected_name = ""
	dragging = false
	refresh()

func locate(point: Vector2, title: String) -> void:
	selected_point = point
	selected_name = title
	zoom = 1.0
	focus = Vector2(0.5,0.5)
	refresh()

func refresh() -> void:
	if not is_node_ready() or director == null or director.world_hero == null or director.world_context == null: return
	definition = director.world_context.current_map()
	source.show_map(definition)
	if drawn_map_id != definition.map_id:
		drawn_map_id = definition.map_id
		focus = Vector2(0.5,0.5)
		selected_name = ""
		dragging = false
		if not circular: zoom = 1.0
	player_uv = to_uv(director.world_hero.position)
	if circular: focus = player_uv
	player_screen = uv_to_screen(player_uv)
	var density: float = maxf(1.0,get_global_transform().get_scale().abs().x)
	var extent: Vector2i = Vector2i((size*density).ceil()).max(Vector2i(2,2))
	var pixels: Vector2 = Vector2(extent)/size
	var factor: Vector2 = Vector2.ONE*_scale()*pixels
	var center: Vector2 = source.bounds.position+focus*source.bounds.size
	var transform: Transform2D = Transform2D(Vector2(factor.x,0),Vector2(0,factor.y),Vector2(extent)*0.5-center*factor)
	if rendered_revision != source.revision or rendered_transform != transform or map_viewport.size != extent:
		map_viewport.size = extent
		map_viewport.canvas_transform = transform
		map_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		rendered_transform = transform
		rendered_revision = source.revision
	shader_material.set_shader_parameter("round_mask",circular)
	shader_material.set_shader_parameter("control_size",size)
	queue_redraw()

func locations() -> Array[Dictionary]:
	var places: Array[Dictionary] = []
	if definition == null: return places
	for portal: Dictionary in definition.portals:
		var target: WorldMapDefinition = director.world_context.map_definitions.get(portal["target_map_id"])
		var destination: String = target.display_name if target != null else str(portal["target_map_id"])
		var title: String = "出入口 → "+destination
		for scenery: Dictionary in definition.scenery:
			if scenery.get("portal_id","")==portal["id"] and not str(scenery.get("name","")).is_empty():
				title = scenery["name"]
				break
		places.append({"name":title,"detail":"通往 "+destination,"point":portal["point"],"kind":"portal","portal_id":portal.id})
	for landmark: Dictionary in definition.landmarks:
		places.append({"name":landmark["name"],"detail":"地標","point":landmark["point"],"kind":"landmark"})
	for entry_id: String in definition.entries:
		var entry: Dictionary = definition.entries[entry_id]
		places.append({"name":str(entry.get("name","到達點 %d" % (definition.entries.keys().find(entry_id)+1))),"detail":"到達位置","point":entry["point"],"kind":"entry"})
	return places

func _inside(point: Vector2, margin: float = 0) -> bool:
	if circular: return point.distance_to(size*0.5)<=minf(size.x,size.y)*0.435-margin
	return Rect2(Vector2.ONE*margin,size-Vector2.ONE*margin*2).has_point(point)

func _marker(point: Vector2, title: String, kind: String, selected: bool = false) -> void:
	var at: Vector2 = logical_to_screen(point)
	if not _inside(at,7): return
	var color: Color = Color(0.4,0.87,1.0) if kind=="portal" else Color(0.94,0.75,0.39) if kind=="landmark" else Color(0.64,0.84,0.61)
	draw_circle(at,6 if kind=="portal" else 4,Color(0.025,0.035,0.04))
	if kind=="portal":
		draw_polyline(PackedVector2Array([at+Vector2(0,-5),at+Vector2(5,0),at+Vector2(0,5),at+Vector2(-5,0),at+Vector2(0,-5)]),color,2,true)
	else: draw_circle(at,2.8,color)
	if not circular and (kind!="entry" or selected) and not title.is_empty():
		var font: Font = get_theme_font("font")
		var width: float = font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		for offset: Vector2 in [Vector2(9,4),Vector2(9,-15),Vector2(9,23),Vector2(-width-9,4),Vector2(9,-34),Vector2(9,42)]:
			var text_at: Vector2 = at+offset
			var rect: Rect2 = Rect2(text_at-Vector2(3,14),Vector2(width+6,19))
			if not Rect2(Vector2.ZERO,size).encloses(rect): continue
			var overlaps: bool = false
			for occupied: Rect2 in label_bounds:
				if rect.intersects(occupied): overlaps = true; break
			if overlaps: continue
			label_bounds.append(rect)
			draw_string_outline(font,text_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,4,Color(0.02,0.03,0.04))
			draw_string(font,text_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
			break
	if selected:
		draw_arc(at,12,0,TAU,32,Color(1,0.95,0.45),2,true)
		draw_line(at-Vector2(18,0),at-Vector2(9,0),Color.WHITE,1)
		draw_line(at+Vector2(9,0),at+Vector2(18,0),Color.WHITE,1)

func _draw() -> void:
	if definition == null: return
	label_bounds.clear()
	if not circular:
		label_bounds.append(Rect2(player_screen+Vector2(-22,-29),Vector2(70,22)))
	var selection_drawn: bool = false
	for place: Dictionary in locations():
		if circular and place["kind"]=="entry": continue
		var selected: bool = not selected_name.is_empty() and selected_point==place["point"] and selected_name==place["name"]
		selection_drawn = selection_drawn or selected
		_marker(place["point"],place["name"],place["kind"],selected)
	if not selected_name.is_empty() and not selection_drawn: _marker(selected_point,selected_name,"portal",true)
	if _inside(player_screen,8):
		draw_circle(player_screen,7,Color(0.02,0.04,0.035))
		draw_circle(player_screen,4,Color(0.42,1,0.64))
		draw_arc(player_screen,7,0,TAU,24,Color.WHITE,1.5,true)
		if not circular:
			var font: Font = get_theme_font("font")
			var at: Vector2 = player_screen+Vector2(-18,-12)
			draw_string_outline(font,at,"你的位置",HORIZONTAL_ALIGNMENT_LEFT,-1,12,4,Color(0.02,0.03,0.04))
			draw_string(font,at,"你的位置",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.65,1,0.76))

func _gui_input(event: InputEvent) -> void:
	if definition == null: return
	if event is InputEventMouseMotion and dragging and not circular:
		focus -= event.relative/(_scale()*source.bounds.size)
		focus = focus.clamp(Vector2.ZERO,Vector2.ONE)
		refresh()
		accept_event()
	if not event is InputEventMouseButton: return
	if event.button_index==MOUSE_BUTTON_RIGHT and not circular:
		dragging = event.pressed
		accept_event()
		return
	if not event.pressed or not _inside(event.position): return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var before: Vector2 = to_uv(screen_to_logical(event.position))
		zoom = clampf(zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2),1,4)
		if not circular:
			focus = before-(event.position-size*0.5)/(_scale()*source.bounds.size)
			focus = focus.clamp(Vector2.ZERO,Vector2.ONE)
		refresh()
		accept_event()
	elif event.button_index==MOUSE_BUTTON_LEFT:
		var point: Vector2 = screen_to_logical(event.position)
		if not Rect2(Vector2.ZERO,definition.extent).has_point(point):
			accept_event()
			return
		for place: Dictionary in locations():
			if logical_to_screen(place["point"]).distance_to(event.position)<=10:
				selected_point = place["point"]
				selected_name = place["name"]
				place_selected.emit(selected_point)
				queue_redraw()
				accept_event()
				return
		selected_point = point
		selected_name = "選定位置"
		place_selected.emit(point)
		queue_redraw()
		accept_event()
