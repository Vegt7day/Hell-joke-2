class_name MiniMap
extends Control
## 右上角缩略地图：21×21 格，展示玩家周围 10 格区域

const FONT_12: FontFile = preload("res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf")

const HALF_GRID := 10
const GRID_SIZE := HALF_GRID * 2 + 1

var _scan: Dictionary = {}
var _player_grid: Vector2i = Vector2i.ZERO
var _cell_px: float = 8.0

var _scene_name: String = ""
var _reveal_full: Dictionary = {}
var _reveal_dim: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	call_deferred("_init_scan")
	set_process(true)


func _on_mouse_entered() -> void:
	CursorManager._hovered_count += 1
	if CursorManager._hovered_count == 1:
		CursorManager._type_before_hover = CursorManager._current_type
	CursorManager.set_cursor_type(CursorManager.CursorType.HUD)
	CursorManager.set_frame_key("hud_hover")


func _on_mouse_exited() -> void:
	CursorManager._hovered_count = maxi(0, CursorManager._hovered_count - 1)
	if CursorManager._hovered_count == 0:
		CursorManager._restore_default_cursor()


func _init_scan() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene == null:
		return
	var scan := LevelMapScanner.scan_scene(scene)
	var pl := tree.get_first_node_in_group(&"player") as Node2D
	var ppos := pl.global_position if pl != null else Vector2.ZERO
	var scene_bn := ""
	if not scene.scene_file_path.is_empty():
		scene_bn = scene.scene_file_path.get_file().get_basename()
	_set_scan(scan, ppos, scene_bn)


func _process(_delta: float) -> void:
	var pl := get_tree().get_first_node_in_group(&"player") as Node2D
	if pl == null:
		return
	var g := _world_to_grid(pl.global_position)
	if g != _player_grid:
		_player_grid = g
		queue_redraw()


func _set_scan(scan: Dictionary, player_global: Vector2, scene_name: String = "") -> void:
	_scan = scan
	_scene_name = scene_name
	_player_grid = _world_to_grid(player_global)
	if scene_name.is_empty():
		_reveal_full.clear()
		_reveal_dim.clear()
	else:
		var game: Node = get_node_or_null("/root/Game") as Node
		if game != null and game.has_method(&"build_map_reveal_masks"):
			var masks: Dictionary = game.build_map_reveal_masks(scene_name)
			_reveal_full = masks.get(&"full", {}) as Dictionary
			_reveal_dim = masks.get(&"dim", {}) as Dictionary
	queue_redraw()


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var cs_var: Variant = _scan.get(&"cell_size", Vector2(16, 16))
	var cs := cs_var as Vector2
	if cs.x <= 0.001: cs.x = 16.0
	if cs.y <= 0.001: cs.y = 16.0
	return Vector2i(int(floor(world_pos.x / cs.x)), int(floor(world_pos.y / cs.y)))


func _gui_input(event: InputEvent) -> void:
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _reveal_tier_at(g: Vector2i) -> int:
	if _scene_name.is_empty():
		return 2
	var k := "%d_%d" % [g.x, g.y]
	if _reveal_full.get(k, false): return 2
	if _reveal_dim.get(k, false): return 1
	return 0


func _draw() -> void:
	var sz := size
	if sz.x <= 0 or sz.y <= 0:
		return

	var avail := minf(sz.x, sz.y)
	_cell_px = maxf(4.0, (avail - 4.0) / float(GRID_SIZE))

	var floor_col := Color(0.32, 0.55, 0.38, 0.92)
	var wall_col := Color(0.38, 0.38, 0.42, 0.95)
	var dim_col := Color(0.384, 0.333, 0.396, 0.6)

	var grid_px := float(GRID_SIZE) * _cell_px
	var ox := (sz.x - grid_px) * 0.5
	var oy := (sz.y - grid_px) * 0.5

	var gx := _player_grid.x - HALF_GRID
	var gy := _player_grid.y - HALF_GRID

	var cf: Dictionary = _scan.get(&"cells_floor", {}) as Dictionary
	var cw: Dictionary = _scan.get(&"cells_wall", {}) as Dictionary
	var use_legacy := cf.is_empty() and cw.is_empty()
	var cells_all: Dictionary = _scan.get(&"cells", {}) as Dictionary if use_legacy else {}

	# 构建机关查找表（含格子背景色）
	var mech_at: Dictionary = {}
	var mech_ofs: Variant = _scan.get(&"mechanisms", [])
	if mech_ofs is Array:
		for item in mech_ofs as Array:
			if item is Dictionary:
				var d := item as Dictionary
				var gv: Variant = d.get(&"g", Vector2i.ZERO)
				if gv is Vector2i:
					mech_at[gv as Vector2i] = d

	for row in GRID_SIZE:
		for col in GRID_SIZE:
			var gg := Vector2i(gx + col, gy + row)
			var px := ox + float(col) * _cell_px
			var py := oy + float(row) * _cell_px

			var tier := _reveal_tier_at(gg)
			var is_floor: bool = false
			var is_wall: bool = false
			if not use_legacy:
				is_floor = cf.has(gg)
				is_wall = cw.has(gg)
			else:
				is_floor = cells_all.has(gg)

			if not is_floor and not is_wall and not mech_at.has(gg):
				continue

			var rr := Rect2(px + 0.5, py + 0.5, _cell_px - 1.0, _cell_px - 1.0)

			# 机关格子用机关颜色覆盖，否则用地/墙色
			var mech_d: Variant = mech_at.get(gg, null)
			if mech_d != null and tier >= 1:
				var kind := str(mech_d.get(&"kind", ""))
				var mc := _mechanism_cell_color(kind, mech_d)
				draw_rect(rr, mc.fill)
				draw_rect(rr, mc.border, false, maxf(1.0, _cell_px * 0.08))
			elif tier <= 0:
				draw_rect(rr, dim_col)
			elif is_wall:
				draw_rect(rr, wall_col)
			else:
				draw_rect(rr, floor_col)

			# 格子文字（无机关时）
			if mech_d == null and tier >= 2 and _cell_px >= 6.0:
				var label: String = ""
				var label_col := Color(0.9, 0.9, 0.9, 0.7)
				if is_floor:
					label = "地"
					label_col = Color(0.88, 1.0, 0.93, 0.7)
				elif is_wall:
					label = "墙"
					label_col = Color(0.94, 0.94, 0.97, 0.7)
				if not label.is_empty():
					_draw_label(rr, label, label_col)

			# 机关文字标记
			_draw_mechanism_glyph(gg, rr)

	# 玩家位置
	var pr := Rect2(
		ox + float(HALF_GRID) * _cell_px + 0.5,
		oy + float(HALF_GRID) * _cell_px + 0.5,
		_cell_px - 1.0, _cell_px - 1.0
	)
	draw_rect(pr, Color(1, 1, 1, 0.3))
	draw_rect(pr, Color(0.95, 0.28, 0.22, 1.0), false, 2.0)
	draw_circle(pr.position + pr.size * 0.5, maxf(2.0, _cell_px * 0.15), Color(0.95, 0.28, 0.22, 1.0))


func _draw_label(rr: Rect2, text: String, color: Color) -> void:
	var fs := maxf(5.0, minf(_cell_px * 0.5, 10.0))
	var txt_sz := FONT_12.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	var bx := rr.position.x + (rr.size.x - txt_sz.x) * 0.5
	var ascent := FONT_12.get_ascent(fs)
	var descent := FONT_12.get_descent(fs)
	var by := rr.position.y + (rr.size.y + ascent - descent) * 0.5
	draw_string(FONT_12, Vector2(bx, by), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, color)


func _draw_mechanism_glyph(g: Vector2i, rr: Rect2) -> void:
	var mech_ofs: Variant = _scan.get(&"mechanisms", [])
	if not (mech_ofs is Array):
		return
	for item in mech_ofs as Array:
		if not (item is Dictionary):
			continue
		var d := item as Dictionary
		var gv: Variant = d.get(&"g", Vector2i.ZERO)
		if not (gv is Vector2i):
			continue
		var mg: Vector2i = gv
		if mg != g:
			continue
		var kind := str(d.get(&"kind", ""))
		var ch := _glyph(kind, d)
		var fs := maxf(5.0, _cell_px * 0.5)
		var col := Color(0.92, 0.88, 0.82, 1.0)
		match kind:
			"switch": col = Color(0.88, 0.92, 1.0, 1.0)
			"door": col = Color(0.85, 0.62, 0.38, 1.0)
			"save_point": col = Color(0.95, 0.32, 0.32, 1.0)
			"heart_blade": col = Color(0.92, 0.38, 0.44, 1.0)
		var txt_sz := FONT_12.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		var bx := rr.position.x + (rr.size.x - txt_sz.x) * 0.5
		var ascent := FONT_12.get_ascent(fs)
		var descent := FONT_12.get_descent(fs)
		var by := rr.position.y + (rr.size.y + ascent - descent) * 0.5
		draw_string(FONT_12, Vector2(bx, by), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
		return


static func _mechanism_cell_color(kind: String, d: Dictionary) -> Dictionary:
	match kind:
		"switch":
			if bool(d.get(&"switch_on", false)):
				return {"fill": Color(0.22, 0.38, 0.44, 0.96), "border": Color(0.45, 0.92, 1.0, 1.0)}
			return {"fill": Color(0.20, 0.26, 0.30, 0.96), "border": Color(0.52, 0.58, 0.64, 1.0)}
		"door":    return {"fill": Color(0.42, 0.32, 0.22, 0.96), "border": Color(0.85, 0.62, 0.38, 1.0)}
		"window":  return {"fill": Color(0.28, 0.34, 0.48, 0.96), "border": Color(0.55, 0.72, 0.95, 1.0)}
		"hole":    return {"fill": Color(0.32, 0.22, 0.38, 0.96), "border": Color(0.72, 0.48, 0.88, 1.0)}
		"bucket":  return {"fill": Color(0.44, 0.38, 0.22, 0.96), "border": Color(0.92, 0.82, 0.38, 1.0)}
		"save_point": return {"fill": Color(0.22, 0.42, 0.48, 0.96), "border": Color(0.52, 0.88, 0.95, 1.0)}
		"heart_blade": return {"fill": Color(0.40, 0.22, 0.26, 0.96), "border": Color(0.92, 0.38, 0.44, 1.0)}
		_:         return {"fill": Color(0.36, 0.34, 0.32, 0.96), "border": Color(0.78, 0.76, 0.72, 1.0)}


static func _glyph(kind: String, d: Dictionary) -> String:
	match kind:
		"switch": return "开" if bool(d.get(&"switch_on", false)) else "关"
		"door": return "门"
		"window": return "窗"
		"hole": return "洞"
		"bucket": return "桶"
		"save_point": return "存"
		"heart_blade": return "心"
		_: return "?"
