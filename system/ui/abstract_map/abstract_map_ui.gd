extends CanvasLayer

const CONFIRM_POPUP_SCENE := preload("res://system/ui/confirm_popup.tscn")

@onready var _draw_area: AbstractMapDraw = $Root/MenuBack/MapArea/MapDraw
@onready var _zoom_slider: VSlider = $Root/MenuBack/MapArea/MapDraw/ZoomSlider
@onready var _close_button: Button = $Root/CloseButton

# 面板拖拽
var _dragging_panel: Control = null
var _drag_mouse_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 115
	add_to_group(&"abstract_map_ui")

	if bool(get_meta(&"abstract_map_teleport_pick", false)):
		_draw_area.set_teleport_pick_mode(true)

	_close_button.pressed.connect(_close_map)

	_zoom_slider.min_value = 0.0
	_zoom_slider.max_value = 1.0
	_zoom_slider.step = 0.02

	_draw_area.zoom_normalized_changed.connect(_sync_slider_from_draw)
	_zoom_slider.value_changed.connect(_on_zoom_slider_value_changed)
	_draw_area.teleport_save_pick_requested.connect(_on_teleport_save_pick_requested)

	# 面板标题栏拖拽
	var panel := $Root/MenuBack as Control
	if panel != null:
		var title := $Root/MenuBack/MapArea/TitleLabel as Control
		if title != null:
			title.gui_input.connect(func(ev: InputEvent): _on_title_gui(panel, ev))

	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	var scan := LevelMapScanner.scan_scene(scene)
	var pl := tree.get_first_node_in_group(&"player") as Node2D
	var ppos := pl.global_position if pl != null else Vector2.ZERO
	var scene_bn := ""
	if scene != null and not scene.scene_file_path.is_empty():
		scene_bn = scene.scene_file_path.get_file().get_basename()
	_draw_area.set_scan(scan, ppos, scene_bn)
	# 恢复上次关闭时的缩放，并以玩家位置为地图中心
	if AbstractMapDraw._saved_zoom_mul > 0.0:
		var saved_zm := AbstractMapDraw._saved_zoom_mul
		_draw_area._zoom_mul = saved_zm
		_draw_area._cell_px = _draw_area._effective_cell_px()
		# 以玩家位置为地图中心重新计算 origin
		var cs_var: Variant = scan.get(&"cell_size", Vector2(16, 16))
		var cs := cs_var as Vector2
		if cs.x <= 0.001: cs.x = 16.0
		if cs.y <= 0.001: cs.y = 16.0
		var pg := Vector2i(int(floor(ppos.x / cs.x)), int(floor(ppos.y / cs.y)))
		var pivot := _draw_area.size * 0.5
		_draw_area._map_origin = pivot - (Vector2(pg) - Vector2(_draw_area._min_g)) * _draw_area._cell_px
		_draw_area.queue_redraw()
		_draw_area.zoom_normalized_changed.emit(_draw_area.get_zoom_normalized())


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func _close_map() -> void:
	# 保存地图显示位置和缩放大小的状态
	AbstractMapDraw._saved_map_origin = _draw_area._map_origin
	AbstractMapDraw._saved_zoom_mul = _draw_area._zoom_mul
	queue_free()


func _sync_slider_from_draw(t: float) -> void:
	_zoom_slider.set_block_signals(true)
	_zoom_slider.value = clampf(t, 0.0, 1.0)
	_zoom_slider.set_block_signals(false)


func _on_zoom_slider_value_changed(v: float) -> void:
	_draw_area.apply_zoom_normalized(v)


func _on_teleport_save_pick_requested(save_point_id: String, world_pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene_bn := tree.current_scene.scene_file_path.get_file().get_basename()
	if not Game.is_save_point_known(scene_bn, save_point_id):
		return
	var pl := tree.get_first_node_in_group(&"player") as Node2D
	if pl != null:
		var cs := LevelMapScanner.get_logic_cell_size_for_scene(tree.current_scene)
		var thr := minf(cs.x, cs.y) * 0.4
		if pl.global_position.distance_to(world_pos) < thr:
			return
	var dlg: ConfirmPopup = CONFIRM_POPUP_SCENE.instantiate() as ConfirmPopup
	if dlg == null:
		return
	tree.root.add_child(dlg)
	var on_confirm := func():
		Game.teleport_player_to_world(world_pos)
		queue_free()
	dlg.show_confirm("传送", "传送到该存档点？", on_confirm, Callable())


func _on_title_gui(panel: Control, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging_panel = panel
			_drag_mouse_offset = panel.position - get_viewport().get_mouse_position()
		elif _dragging_panel == panel:
			_dragging_panel = null


func _input(event: InputEvent) -> void:
	# 面板拖拽
	if event is InputEventMouseMotion and _dragging_panel != null:
		_dragging_panel.position = get_viewport().get_mouse_position() + _drag_mouse_offset
		return
	if event is InputEventMouseButton and not event.pressed and _dragging_panel != null:
		_dragging_panel = null
		return

	if event.is_action_pressed(&"ui_cancel"):
		_close_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_map"):
		_close_map()
		get_viewport().set_input_as_handled()
