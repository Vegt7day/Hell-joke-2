extends CanvasLayer

const SAVE_POINT_PANEL_GROUP := &"save_point_choice_ui"

var _save_point: SavePointInteractable
var _opening_map_teleport := false


func setup(save_point: SavePointInteractable) -> void:
	_save_point = save_point


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 105
	add_to_group(SAVE_POINT_PANEL_GROUP)


func _exit_tree() -> void:
	if _opening_map_teleport:
		return
	if is_instance_valid(Game) and Game.has_method(&"on_save_point_panel_exited"):
		Game.on_save_point_panel_exited()


func _on_save_pressed() -> void:
	if _save_point == null or not is_instance_valid(_save_point):
		queue_free()
		return
	var scene_bn := Game.get_current_scene_basename()
	Game.mark_save_point_known(scene_bn, _save_point.get_save_point_id())
	await _save_point.run_save_sequence_and_heal()
	queue_free()


func _on_teleport_pressed() -> void:
	if _save_point == null or not is_instance_valid(_save_point):
		queue_free()
		return
	var scene_bn := Game.get_current_scene_basename()
	Game.mark_save_point_known(scene_bn, _save_point.get_save_point_id())
	# 先从组里摘掉，否则同一帧内 Game.open_abstract_map_ui 会因「存档点面板仍打开」而直接 return，游戏保持暂停 → 卡住
	remove_from_group(SAVE_POINT_PANEL_GROUP)
	_opening_map_teleport = true
	await get_tree().process_frame
	queue_free()
	Game.open_abstract_map_ui(true)


func _on_cancel_pressed() -> void:
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()
