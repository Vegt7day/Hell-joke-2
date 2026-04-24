extends Node2D

const INTRO_TIMELINE := "商鞅提出要求"

@onready var player: Player = $player
@onready var shangyang_npc: ShangYang = $商鞅 as ShangYang

var _intro_completed: bool = false
var _intro_dialog_node: Node = null
## 已收集肢体节点名（与存档 sy_limbs_collected 同步）
var _limbs_collected_names: Array[String] = []
var sy_npc_removed: bool = false
var _sy_awaiting_interact_restore: bool = false


func run_shangyang_get_cutscene(sy: ShangYang, anim_index: int) -> void:
	if not is_instance_valid(player) or not is_instance_valid(sy):
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var from_off := Vector2.ZERO
	var spd := 120.0
	if cam != null:
		from_off = cam.position
		spd = maxf(cam.position_smoothing_speed, 8.0)
		var target_global := sy.global_position + Vector2(0, -48)
		var target_off := target_global - player.global_position
		var dist_in := from_off.distance_to(target_off)
		var dur_in := clampf(dist_in / spd, 0.15, 2.5)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(cam, "position", target_off, dur_in)
		await tw.finished
	sy.play_get_animation(anim_index)
	await sy.animation_player.animation_finished
	if cam != null:
		var dist_back := cam.position.distance_to(from_off)
		var dur_back := clampf(dist_back / spd, 0.15, 2.5)
		var twb := create_tween()
		twb.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		twb.tween_property(cam, "position", from_off, dur_back)
		await twb.finished
	if is_instance_valid(sy):
		sy.consume_pending_return_sy_dialog()


func _ready() -> void:
	await get_tree().process_frame
	# Game.change_scene 会在全场景 _ready 之后调用 from_dict，故任务逻辑延后一帧
	call_deferred("_world2_quest_setup")


func _world2_quest_setup() -> void:
	_restore_limbs_from_save()
	await get_tree().process_frame
	if _sy_awaiting_interact_restore and is_instance_valid(shangyang_npc):
		shangyang_npc.restore_post_get3_waiting_interact()
	_register_dialogic_characters()
	if not _intro_completed:
		_start_intro_dialog()
	else:
		_set_limbs_pickups_enabled(true)


func mark_shangyang_npc_removed() -> void:
	sy_npc_removed = true


func register_shangyang_limb_collected(limb_name: StringName) -> void:
	var s := String(limb_name)
	if s not in _limbs_collected_names:
		_limbs_collected_names.append(s)


func _register_dialogic_characters() -> void:
	var registry := get_node_or_null("/root/DialogicRegistry")
	if registry == null:
		push_warning("world2: DialogicRegistry 未找到，对话可能无法定位角色")
		return
	var student_marker: Marker2D = null
	if player:
		for child in player.get_children():
			if child is Marker2D:
				student_marker = child
				break
	if student_marker:
		registry.register_character("中学生", student_marker)
	elif player:
		registry.register_character("中学生", player)
	if is_instance_valid(shangyang_npc):
		registry.register_character("商鞅", shangyang_npc)


func _restore_limbs_from_save() -> void:
	for n in get_tree().get_nodes_in_group("shangyang_limb"):
		if n is ShangYangLimb and (n as ShangYangLimb).name in _limbs_collected_names:
			(n as ShangYangLimb).apply_saved_collected()
	if sy_npc_removed and is_instance_valid(shangyang_npc):
		shangyang_npc.queue_free()


func _set_limbs_pickups_enabled(enabled: bool) -> void:
	for n in get_tree().get_nodes_in_group("shangyang_limb"):
		if n is ShangYangLimb:
			(n as ShangYangLimb).set_limb_pickups_enabled(enabled)


func _start_intro_dialog() -> void:
	if not Dialogic:
		_on_intro_dialog_finished()
		return
	var dialog := Dialogic.start(INTRO_TIMELINE)
	if dialog == null:
		_on_intro_dialog_finished()
		return
	get_tree().current_scene.add_child(dialog)
	_intro_dialog_node = dialog
	if dialog.has_signal("timeline_ended"):
		dialog.timeline_ended.connect(_on_intro_dialog_finished)
	elif dialog.has_signal("event_end"):
		dialog.event_end.connect(_on_intro_dialog_finished)


func _on_intro_dialog_finished(_arg = null) -> void:
	if _intro_completed:
		return
	_intro_completed = true
	if _intro_dialog_node and is_instance_valid(_intro_dialog_node):
		if _intro_dialog_node.has_signal("timeline_ended") and _intro_dialog_node.timeline_ended.is_connected(_on_intro_dialog_finished):
			_intro_dialog_node.timeline_ended.disconnect(_on_intro_dialog_finished)
		if _intro_dialog_node.has_signal("event_end") and _intro_dialog_node.event_end.is_connected(_on_intro_dialog_finished):
			_intro_dialog_node.event_end.disconnect(_on_intro_dialog_finished)
		_intro_dialog_node.queue_free()
		_intro_dialog_node = null
	_set_limbs_pickups_enabled(true)


func to_dict() -> Dictionary:
	var enemies_alive: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		enemies_alive.append(get_path_to(node))
	var awaiting_interact := false
	if is_instance_valid(shangyang_npc) and shangyang_npc.has_method("is_awaiting_story_interact"):
		awaiting_interact = shangyang_npc.is_awaiting_story_interact()
	return {
		"enemies_alive": enemies_alive,
		"sy_intro_done": _intro_completed,
		"sy_limbs_collected": _limbs_collected_names.duplicate(),
		"sy_npc_removed": sy_npc_removed,
		"sy_awaiting_sy_interact": awaiting_interact,
	}


func from_dict(dict: Dictionary) -> void:
	var alive: Array = dict.get("enemies_alive", [])
	for node in get_tree().get_nodes_in_group("enemies"):
		var path := get_path_to(node)
		if path not in alive:
			node.queue_free()
	_intro_completed = dict.get("sy_intro_done", false)
	_limbs_collected_names.clear()
	for x in dict.get("sy_limbs_collected", []):
		_limbs_collected_names.append(String(x))
	sy_npc_removed = dict.get("sy_npc_removed", false)
	_sy_awaiting_interact_restore = dict.get("sy_awaiting_sy_interact", false)


func update_player(position: Vector2, direction: int = 1) -> void:
	if has_node("player"):
		var player_node = $player
		if is_instance_valid(player_node):
			player_node.global_position = position
			if player_node.has_method("set_direction"):
				player_node.set_direction(direction)
			elif "direction" in player_node:
				player_node.direction = direction
			else:
				print("玩家没有方向属性或方法")
		else:
			print("玩家节点无效")
	else:
		print("场景中没有找到玩家节点")
