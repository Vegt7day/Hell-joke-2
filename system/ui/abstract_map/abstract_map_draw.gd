class_name AbstractMapDraw
extends Control
## 抽象平面图：地区 / 墙分层着色；机关标签；左键拖拽平移；滚轮缩放（以光标为中心）。

signal zoom_normalized_changed(t: float)
signal teleport_save_pick_requested(save_point_id: String, world_pos: Vector2)

const FONT_12: FontFile = preload("res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf")

const _ZOOM_MUL_MIN := 0.2
const _ZOOM_MUL_MAX := 10.0
const _CELL_PX_HARD_MIN := 2.0
const _CELL_PX_HARD_MAX := 128.0
const _PAD := 8.0

var _scan: Dictionary = {}
var _player_world: Vector2 = Vector2.ZERO

var _min_g := Vector2i(0, 0)
var _max_g := Vector2i(0, 0)

var _fit_px: float = 8.0
var _zoom_mul: float = 1.0
var _cell_px: float = 8.0
var _map_origin: Vector2 = Vector2.ZERO

var _dragging := false
var _teleport_pick_mode: bool = false
var _drag_pixel_accum: float = 0.0

## 详图外一环（Game 矩形扩张）：仅灰块无字，外形随地形更新
const _CELL_DIM := Color(0.46, 0.46, 0.49, 0.93)

var _scene_name: String = ""
var _reveal_full: Dictionary = {}
var _reveal_dim: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_teleport_pick_mode(on: bool) -> void:
	_teleport_pick_mode = on
	queue_redraw()


func set_scan(scan: Dictionary, player_global: Vector2, scene_name: String = "") -> void:
	_scan = scan
	_player_world = player_global
	_scene_name = scene_name
	if scene_name.is_empty():
		_reveal_full.clear()
		_reveal_dim.clear()
	else:
		var game: Node = get_node_or_null("/root/Game") as Node
		var masks: Dictionary = {}
		if game != null and game.has_method(&"build_map_reveal_masks"):
			masks = game.build_map_reveal_masks(scene_name)
		_reveal_full = masks.get(&"full", {}) as Dictionary
		_reveal_dim = masks.get(&"dim", {}) as Dictionary
	_zoom_mul = 1.0
	_dragging = false
	_recompute_base_fit()
	_center_map_in_view()
	queue_redraw()
	zoom_normalized_changed.emit(get_zoom_normalized())


func get_zoom_normalized() -> float:
	var denom := _ZOOM_MUL_MAX - _ZOOM_MUL_MIN
	if denom <= 0.0001:
		return 0.5
	return clampf((_zoom_mul - _ZOOM_MUL_MIN) / denom, 0.0, 1.0)


func apply_zoom_normalized(t: float) -> void:
	var tt := clampf(t, 0.0, 1.0)
	var pivot := size * 0.5
	var world_g := _screen_to_grid_f(pivot)
	_zoom_mul = lerpf(_ZOOM_MUL_MIN, _ZOOM_MUL_MAX, tt)
	_cell_px = _effective_cell_px()
	_map_origin = pivot - (world_g - Vector2(_min_g)) * _cell_px
	queue_redraw()
	zoom_normalized_changed.emit(get_zoom_normalized())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var anchor := _screen_to_grid_f(size * 0.5)
		_recompute_base_fit()
		_cell_px = _effective_cell_px()
		var mid := size * 0.5
		_map_origin = mid - (anchor - Vector2(_min_g)) * _cell_px
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_pixel_accum = 0.0
			else:
				if _teleport_pick_mode and _drag_pixel_accum < 14.0:
					_try_pick_known_save(mb.position)
				_dragging = false
				_drag_pixel_accum = 0.0
			accept_event()
		elif mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(mb.position, 1.12)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(mb.position, 1.0 / 1.12)
				accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			_drag_pixel_accum += mm.relative.length()
			_map_origin += mm.relative
			queue_redraw()
			accept_event()


func _try_pick_known_save(local_px: Vector2) -> void:
	if not _teleport_pick_mode or _scene_name.is_empty():
		return
	var game: Node = _static_game_node()
	if game == null or not game.has_method(&"is_save_point_known"):
		return
	var gf := _screen_to_grid_f(local_px)
	var gi := Vector2i(int(floor(gf.x)), int(floor(gf.y)))
	var mech: Variant = _scan.get(&"mechanisms", [])
	if mech is Array:
		for item in mech as Array:
			if item is Dictionary:
				var d := item as Dictionary
				if str(d.get(&"kind", "")) != "save_point":
					continue
				var gv: Variant = d.get(&"g", Vector2i.ZERO)
				if not (gv is Vector2i):
					continue
				var gg: Vector2i = gv
				if gg != gi:
					continue
				var sid := str(d.get(&"save_point_id", ""))
				if not game.is_save_point_known(_scene_name, sid):
					continue
				if _reveal_tier_at(gg) < 2:
					continue
				var wp: Variant = d.get(&"world_px", Vector2.ZERO)
				var world_pos := wp as Vector2
				teleport_save_pick_requested.emit(sid, world_pos)
				return


static func _static_game_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath("Game")) as Node


func _zoom_at(local_mouse: Vector2, factor: float) -> void:
	var world_g := _screen_to_grid_f(local_mouse)
	_zoom_mul = clampf(_zoom_mul * factor, _ZOOM_MUL_MIN, _ZOOM_MUL_MAX)
	_cell_px = _effective_cell_px()
	_map_origin = local_mouse - (world_g - Vector2(_min_g)) * _cell_px
	queue_redraw()
	zoom_normalized_changed.emit(get_zoom_normalized())


func _effective_cell_px() -> float:
	return clampf(_fit_px * _zoom_mul, _CELL_PX_HARD_MIN, _CELL_PX_HARD_MAX)


func _recompute_base_fit() -> void:
	_compute_bounds()
	var gw := maxi(1, _max_g.x - _min_g.x + 1)
	var gh := maxi(1, _max_g.y - _min_g.y + 1)
	var avail_x := maxf(1.0, size.x - _PAD * 2.0)
	var avail_y := maxf(1.0, size.y - _PAD * 2.0)
	_fit_px = minf(avail_x / float(gw), avail_y / float(gh))
	if _fit_px <= 0.001:
		_fit_px = 8.0


func _center_map_in_view() -> void:
	var gw := maxi(1, _max_g.x - _min_g.x + 1)
	var gh := maxi(1, _max_g.y - _min_g.y + 1)
	var avail_x := maxf(1.0, size.x - _PAD * 2.0)
	var avail_y := maxf(1.0, size.y - _PAD * 2.0)
	_cell_px = _effective_cell_px()
	_map_origin.x = _PAD + (avail_x - float(gw) * _cell_px) * 0.5
	_map_origin.y = _PAD + (avail_y - float(gh) * _cell_px) * 0.5


func _exploration_active() -> bool:
	return not _scene_name.is_empty()


func _reveal_tier_at(g: Vector2i) -> int:
	if not _exploration_active():
		return 2
	var k := "%d_%d" % [g.x, g.y]
	if _reveal_full.get(k, false):
		return 2
	if _reveal_dim.get(k, false):
		return 1
	return 0


func _compute_bounds() -> void:
	var cs_var: Variant = _scan.get(&"cell_size", Vector2(16, 16))
	var cs := cs_var as Vector2
	if cs.x <= 0.001:
		cs.x = 16.0
	if cs.y <= 0.001:
		cs.y = 16.0
	var pg := Vector2i(int(floor(_player_world.x / cs.x)), int(floor(_player_world.y / cs.y)))
	if _exploration_active():
		_compute_bounds_exploration(pg)
	else:
		_compute_bounds_full(pg)


func _compute_bounds_exploration(pg: Vector2i) -> void:
	var min_x := 2147483647
	var min_y := 2147483647
	var max_x := -2147483648
	var max_y := -2147483648
	var any := false

	var cf: Dictionary = _scan.get(&"cells_floor", {}) as Dictionary
	for k in cf.keys():
		if k is Vector2i:
			var g: Vector2i = k
			if _reveal_tier_at(g) <= 0:
				continue
			min_x = mini(min_x, g.x)
			min_y = mini(min_y, g.y)
			max_x = maxi(max_x, g.x)
			max_y = maxi(max_y, g.y)
			any = true

	var cw: Dictionary = _scan.get(&"cells_wall", {}) as Dictionary
	for k in cw.keys():
		if k is Vector2i:
			var g2: Vector2i = k
			if _reveal_tier_at(g2) <= 0:
				continue
			min_x = mini(min_x, g2.x)
			min_y = mini(min_y, g2.y)
			max_x = maxi(max_x, g2.x)
			max_y = maxi(max_y, g2.y)
			any = true

	var mech: Variant = _scan.get(&"mechanisms", [])
	if mech is Array:
		for item in mech as Array:
			if item is Dictionary:
				var gv: Variant = (item as Dictionary).get(&"g", null)
				if gv is Vector2i:
					var g3: Vector2i = gv
					if _reveal_tier_at(g3) <= 0:
						continue
					min_x = mini(min_x, g3.x)
					min_y = mini(min_y, g3.y)
					max_x = maxi(max_x, g3.x)
					max_y = maxi(max_y, g3.y)
					any = true

	min_x = mini(min_x, pg.x)
	min_y = mini(min_y, pg.y)
	max_x = maxi(max_x, pg.x)
	max_y = maxi(max_y, pg.y)

	if not any:
		_min_g = pg
		_max_g = pg
	else:
		_min_g = Vector2i(min_x, min_y)
		_max_g = Vector2i(max_x, max_y)


func _compute_bounds_full(pg: Vector2i) -> void:
	var min_x := 2147483647
	var min_y := 2147483647
	var max_x := -2147483648
	var max_y := -2147483648
	var any := false

	for key in [&"cells_floor", &"cells_wall", &"cells"]:
		var d2: Variant = _scan.get(key, {})
		if d2 is Dictionary:
			for k in (d2 as Dictionary).keys():
				if k is Vector2i:
					var g: Vector2i = k
					min_x = mini(min_x, g.x)
					min_y = mini(min_y, g.y)
					max_x = maxi(max_x, g.x)
					max_y = maxi(max_y, g.y)
					any = true

	var mech: Variant = _scan.get(&"mechanisms", [])
	if mech is Array:
		for item in mech as Array:
			if item is Dictionary:
				var gv: Variant = (item as Dictionary).get(&"g", null)
				if gv is Vector2i:
					var g2: Vector2i = gv
					min_x = mini(min_x, g2.x)
					min_y = mini(min_y, g2.y)
					max_x = maxi(max_x, g2.x)
					max_y = maxi(max_y, g2.y)
					any = true

	min_x = mini(min_x, pg.x)
	min_y = mini(min_y, pg.y)
	max_x = maxi(max_x, pg.x)
	max_y = maxi(max_y, pg.y)
	any = true

	if not any:
		_min_g = Vector2i(0, 0)
		_max_g = Vector2i(0, 0)
	else:
		_min_g = Vector2i(min_x, min_y)
		_max_g = Vector2i(max_x, max_y)


func _screen_to_grid_f(local_mouse: Vector2) -> Vector2:
	return Vector2(_min_g) + (local_mouse - _map_origin) / _cell_px


func _grid_to_screen_top_left(g: Vector2i) -> Vector2:
	return _map_origin + Vector2(float(g.x - _min_g.x), float(g.y - _min_g.y)) * _cell_px


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.06, 0.09, 1.0))

	var cf: Dictionary = _scan.get(&"cells_floor", {}) as Dictionary
	var cw: Dictionary = _scan.get(&"cells_wall", {}) as Dictionary
	var mech_empty := true
	var mech0: Variant = _scan.get(&"mechanisms", [])
	if mech0 is Array:
		mech_empty = (mech0 as Array).is_empty()
	if cf.is_empty() and cw.is_empty() and mech_empty:
		draw_string(FONT_12, Vector2(_PAD, _PAD + 12.0), "（无砖格 / 机关数据）", HORIZONTAL_ALIGNMENT_LEFT, -1, 11)

	var floor_col := Color(0.32, 0.55, 0.38, 0.92)
	var wall_col := Color(0.38, 0.38, 0.42, 0.95)

	for k in cf.keys():
		if k is Vector2i:
			var g: Vector2i = k
			var tier := _reveal_tier_at(g)
			if tier <= 0:
				continue
			var p := _grid_to_screen_top_left(g)
			var rr := Rect2(p.x + 0.5, p.y + 0.5, _cell_px - 1.0, _cell_px - 1.0)
			if tier == 1:
				draw_rect(rr, _CELL_DIM)
			else:
				draw_rect(rr, floor_col)
				_draw_cell_label(rr, "地", Color(0.88, 1.0, 0.93, 1.0))

	for k in cw.keys():
		if k is Vector2i:
			var g2: Vector2i = k
			var tier_w := _reveal_tier_at(g2)
			if tier_w <= 0:
				continue
			var p2 := _grid_to_screen_top_left(g2)
			var rr2 := Rect2(p2.x + 0.5, p2.y + 0.5, _cell_px - 1.0, _cell_px - 1.0)
			if tier_w == 1:
				draw_rect(rr2, _CELL_DIM)
			else:
				draw_rect(rr2, wall_col)
				_draw_cell_label(rr2, "墙", Color(0.94, 0.94, 0.97, 1.0))

	var mech: Variant = _scan.get(&"mechanisms", [])
	if mech is Array:
		for item in mech as Array:
			if item is Dictionary:
				var d := item as Dictionary
				var gv: Variant = d.get(&"g", Vector2i.ZERO)
				if gv is Vector2i:
					var mg: Vector2i = gv
					var tier_m := _reveal_tier_at(mg)
					if tier_m <= 0:
						continue
					var kind := str(d.get(&"kind", ""))
					var ch := _mechanism_glyph(d)
					var top_left := _grid_to_screen_top_left(mg)
					var rr_m := Rect2(top_left.x + 0.5, top_left.y + 0.5, _cell_px - 1.0, _cell_px - 1.0)
					if tier_m == 1:
						draw_rect(rr_m, _CELL_DIM)
					else:
						var cols_c := _mechanism_cell_colors(kind, d, _scene_name)
						draw_rect(rr_m, cols_c[&"fill"])
						draw_rect(rr_m, cols_c[&"border"], false, maxf(1.0, mini(_cell_px * 0.08, 2.5)))
						_draw_cell_label(rr_m, ch, cols_c[&"glyph"])

	var cs2_var: Variant = _scan.get(&"cell_size", Vector2(16, 16))
	var cs2 := cs2_var as Vector2
	if cs2.x <= 0.001:
		cs2.x = 16.0
	if cs2.y <= 0.001:
		cs2.y = 16.0
	var pgx := int(floor(_player_world.x / cs2.x))
	var pgy := int(floor(_player_world.y / cs2.y))
	var p_cell := Vector2i(pgx, pgy)
	if _reveal_tier_at(p_cell) >= 1:
		var pl := _grid_to_screen_top_left(p_cell) + Vector2(_cell_px, _cell_px) * 0.5
		draw_circle(pl, mini(_cell_px * 0.38, 10.0), Color(0.95, 0.28, 0.22, 1.0))
		draw_arc(pl, mini(_cell_px * 0.38, 10.0), 0.0, TAU, 24, Color.WHITE, 1.2, true)


func _draw_cell_label(rr: Rect2, text: String, color: Color) -> void:
	var fs := _max_font_size_for_square(text, rr.size.x - 2.0)
	if fs < 4:
		return
	var sz_txt := FONT_12.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	var baseline_x := rr.position.x + (rr.size.x - sz_txt.x) * 0.5
	var ascent := FONT_12.get_ascent(fs)
	var descent := FONT_12.get_descent(fs)
	var baseline_y := rr.position.y + (rr.size.y + ascent - descent) * 0.5
	draw_string(
		FONT_12, Vector2(baseline_x, baseline_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, color
	)


func _max_font_size_for_square(text: String, inner_px: float) -> int:
	var inner := maxf(2.0, inner_px)
	var hi := mini(int(floor(inner)), 96)
	var lo := 4
	if hi < lo:
		return hi
	for fs in range(hi, lo - 1, -1):
		var sz := FONT_12.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		if sz.x <= inner and sz.y <= inner:
			return fs
	return lo


static func _mechanism_glyph(d: Dictionary) -> String:
	var kind := str(d.get(&"kind", ""))
	match kind:
		"switch":
			return "开" if bool(d.get(&"switch_on", false)) else "关"
		"door":
			return "门"
		"window":
			return "窗"
		"hole":
			return "洞"
		"bucket":
			return "桶"
		"save_point":
			return "存"
		"heart_blade":
			return "心"
		_:
			return "?"


static func _mechanism_cell_colors(kind: String, mech: Dictionary = {}, scene_bn: String = "") -> Dictionary:
	match kind:
		"switch":
			if bool(mech.get(&"switch_on", false)):
				return {&"fill": Color(0.22, 0.38, 0.44, 0.96), &"border": Color(0.45, 0.92, 1.0, 1.0), &"glyph": Color(0.95, 0.98, 1.0, 1.0)}
			return {&"fill": Color(0.20, 0.26, 0.30, 0.96), &"border": Color(0.52, 0.58, 0.64, 1.0), &"glyph": Color(0.82, 0.86, 0.90, 1.0)}
		"door":
			return {&"fill": Color(0.42, 0.32, 0.22, 0.96), &"border": Color(0.85, 0.62, 0.38, 1.0), &"glyph": Color(1.0, 0.94, 0.82, 1.0)}
		"window":
			return {&"fill": Color(0.28, 0.34, 0.48, 0.96), &"border": Color(0.55, 0.72, 0.95, 1.0), &"glyph": Color(0.92, 0.96, 1.0, 1.0)}
		"hole":
			return {&"fill": Color(0.32, 0.22, 0.38, 0.96), &"border": Color(0.72, 0.48, 0.88, 1.0), &"glyph": Color(0.98, 0.88, 1.0, 1.0)}
		"bucket":
			return {&"fill": Color(0.44, 0.38, 0.22, 0.96), &"border": Color(0.92, 0.82, 0.38, 1.0), &"glyph": Color(1.0, 0.98, 0.82, 1.0)}
		"save_point":
			if not scene_bn.is_empty():
				var gnode := _static_game_node()
				if gnode != null and gnode.has_method(&"is_save_point_known"):
					var sid := str(mech.get(&"save_point_id", ""))
					if gnode.is_save_point_known(scene_bn, sid):
						return {&"fill": Color(0.42, 0.14, 0.14, 0.96), &"border": Color(0.95, 0.32, 0.32, 1.0), &"glyph": Color(1.0, 0.86, 0.86, 1.0)}
			return {&"fill": Color(0.22, 0.42, 0.48, 0.96), &"border": Color(0.52, 0.88, 0.95, 1.0), &"glyph": Color(0.94, 0.98, 1.0, 1.0)}
		"heart_blade":
			return {&"fill": Color(0.40, 0.22, 0.26, 0.96), &"border": Color(0.92, 0.38, 0.44, 1.0), &"glyph": Color(1.0, 0.88, 0.88, 1.0)}
		_:
			return {&"fill": Color(0.36, 0.34, 0.32, 0.96), &"border": Color(0.78, 0.76, 0.72, 1.0), &"glyph": Color(1.0, 1.0, 1.0, 1.0)}
