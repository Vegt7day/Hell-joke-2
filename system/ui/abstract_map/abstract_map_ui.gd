extends CanvasLayer

const CONFIRM_POPUP_SCENE := preload("res://system/ui/confirm_popup.tscn")

@onready var _draw_area: AbstractMapDraw = $Root/MarginContainer/MainHBox/LeftVBox/MapDraw
@onready var _zoom_slider: VSlider = $Root/MarginContainer/MainHBox/ZoomSlider
@onready var _close_button: Button = $Root/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
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

	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	var scan := LevelMapScanner.scan_scene(scene)
	var pl := tree.get_first_node_in_group(&"player") as Node2D
	var ppos := pl.global_position if pl != null else Vector2.ZERO
	var scene_bn := ""
	if scene != null and not scene.scene_file_path.is_empty():
		scene_bn = scene.scene_file_path.get_file().get_basename()
	_draw_area.set_scan(scan, ppos, scene_bn)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func _close_map() -> void:
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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_map"):
		queue_free()
		get_viewport().set_input_as_handled()
