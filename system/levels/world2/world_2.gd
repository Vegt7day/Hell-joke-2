extends Node2D

const _AUDIO_UTILS := preload("res://system/globals/audio_utils.gd")
const _STREAM_LEVEL_NORMAL_BGM := preload("res://assets/资源总库/10_音频/场景背景音乐.mp3")
const INTRO_TIMELINE := "level2/商鞅提出要求"
const TL_RETURN_SY := "level2/回去看商鞅"
const TL_GAIN_ABILITY := "level2/获得商鞅能力"
@export var wakeup_intro_animation_player_path: NodePath
@export var wakeup_intro_sprite_path: NodePath
@export var wakeup_intro_animation_name: StringName = &"wakeup_intro"

@onready var player: Player = $player
@onready var shangyang_npc: ShangYang = $商鞅 as ShangYang

var _intro_completed: bool = false
var _intro_dialog_node: Node = null
var _listening_intro_timeline: bool = false
## 已收集肢体节点名（与存档 sy_limbs_collected 同步）
var _limbs_collected_names: Array[String] = []
var sy_npc_removed: bool = false
var _sy_awaiting_interact_restore: bool = false
var _sy_story_state_from_save: Dictionary = {}
## 本场景已播放完成的时间线 / 演出键（与存档 completed_timelines 同步）
var _completed_timelines: Array[String] = []
var _level_bgm_player: AudioStreamPlayer
## 开场睡醒/眨眼动画是否已播过（写入存档 world_states，读档后不再播放）
var _wakeup_intro_completed: bool = false


func mark_dialog_timeline_completed(timeline_id: String) -> void:
	if timeline_id.is_empty() or timeline_id in _completed_timelines:
		return
	_completed_timelines.append(timeline_id)


func has_completed_timeline(timeline_id: String) -> bool:
	return timeline_id in _completed_timelines


func _disconnect_intro_timeline_listener() -> void:
	var dlg := DialogicUtil.autoload()
	if dlg and dlg.timeline_ended.is_connected(_on_dialogic_intro_timeline_ended):
		dlg.timeline_ended.disconnect(_on_dialogic_intro_timeline_ended)
	_listening_intro_timeline = false


func _on_dialogic_intro_timeline_ended() -> void:
	if not _listening_intro_timeline:
		return
	_listening_intro_timeline = false
	_disconnect_intro_timeline_listener()
	_on_intro_dialog_finished()


func run_shangyang_get_cutscene(sy: ShangYang, anim_index: int) -> void:
	if not is_instance_valid(player) or not is_instance_valid(sy):
		return
	var cut_key := "sy_cutscene_get_%d" % (anim_index + 1)
	if has_completed_timeline(cut_key):
		if anim_index == 2:
			sy.consume_pending_return_sy_dialog()
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var from_off := Vector2.ZERO
	var spd := 120.0
	if player.has_method("set_camera_drag_ignore_player_input"):
		player.call("set_camera_drag_ignore_player_input", true)
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
	if player.has_method("set_camera_drag_ignore_player_input"):
		player.call("set_camera_drag_ignore_player_input", false)
	if is_instance_valid(sy):
		mark_dialog_timeline_completed(cut_key)
		sy.consume_pending_return_sy_dialog()


func _infer_cutscene_completions_from_saved_limbs() -> void:
	var n := _limbs_collected_names.size()
	if n >= 2:
		mark_dialog_timeline_completed("sy_cutscene_get_1")
	if n >= 4:
		mark_dialog_timeline_completed("sy_cutscene_get_2")
	if n >= 5:
		mark_dialog_timeline_completed("sy_cutscene_get_3")


func _ready() -> void:
	_setup_level_bgm()
	# deferred：`from_dict` 先于本函数写入 `_wakeup_intro_completed`，避免读档仍播放眨眼
	call_deferred(&"_world2_ready_after_restore")


func _world2_ready_after_restore() -> void:
	await _play_wakeup_intro_if_configured()
	MechanismLinkBus.clear_last_states()
	await get_tree().process_frame
	call_deferred("_world2_quest_setup")


func _setup_level_bgm() -> void:
	_level_bgm_player = _AUDIO_UTILS.ensure_looping_bgm(self, _level_bgm_player, _STREAM_LEVEL_NORMAL_BGM, &"BGM", &"LevelNormalBgm")


func _play_wakeup_intro_if_configured() -> void:
	if _wakeup_intro_completed:
		return
	if wakeup_intro_animation_player_path.is_empty() or wakeup_intro_animation_name.is_empty():
		return
	var ap := get_node_or_null(wakeup_intro_animation_player_path) as AnimationPlayer
	if ap == null:
		push_warning("world2: 未找到开场睡醒动画 AnimationPlayer，path=%s" % String(wakeup_intro_animation_player_path))
		return
	if not ap.has_animation(wakeup_intro_animation_name):
		push_warning("world2: 开场睡醒动画不存在，name=%s" % String(wakeup_intro_animation_name))
		return
	var wake_sprite := get_node_or_null(wakeup_intro_sprite_path) as Node2D if not wakeup_intro_sprite_path.is_empty() else null
	if wake_sprite != null:
		var vr := get_viewport().get_visible_rect()
		wake_sprite.position = vr.size * 0.5
	ap.play(wakeup_intro_animation_name)
	var len := ap.get_animation(wakeup_intro_animation_name).length
	if len <= 0.0:
		len = 0.01
	await get_tree().create_timer(len).timeout
	_wakeup_intro_completed = true


func _world2_quest_setup() -> void:
	_restore_limbs_from_save()
	await get_tree().process_frame
	if is_instance_valid(shangyang_npc):
		if not _sy_story_state_from_save.is_empty() and shangyang_npc.has_method("apply_story_progress_state"):
			shangyang_npc.apply_story_progress_state(_sy_story_state_from_save)
		elif shangyang_npc.has_method("apply_story_progress_without_cutscene"):
			shangyang_npc.apply_story_progress_without_cutscene(_limbs_collected_names.size())
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
		var sy_marker: Marker2D = null
		for child in shangyang_npc.get_children():
			if child is Marker2D:
				sy_marker = child
				break
		if sy_marker:
			registry.register_character("商鞅", sy_marker)
		else:
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
	if has_completed_timeline(INTRO_TIMELINE):
		_intro_completed = true
		_set_limbs_pickups_enabled(true)
		return
	if not Dialogic:
		mark_dialog_timeline_completed(INTRO_TIMELINE)
		_on_intro_dialog_finished()
		return
	_disconnect_intro_timeline_listener()
	var dlg := DialogicUtil.autoload()
	if dlg:
		_listening_intro_timeline = true
		dlg.timeline_ended.connect(_on_dialogic_intro_timeline_ended)
	var dialog := Dialogic.start(INTRO_TIMELINE)
	if dialog == null:
		_disconnect_intro_timeline_listener()
		mark_dialog_timeline_completed(INTRO_TIMELINE)
		_on_intro_dialog_finished()
		return
	_intro_dialog_node = dialog


func _on_intro_dialog_finished(_arg = null) -> void:
	if _intro_completed:
		return
	_intro_completed = true
	mark_dialog_timeline_completed(INTRO_TIMELINE)
	if _intro_dialog_node and is_instance_valid(_intro_dialog_node):
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
	var sy_story_state := {}
	if is_instance_valid(shangyang_npc) and shangyang_npc.has_method("export_story_progress_state"):
		sy_story_state = shangyang_npc.export_story_progress_state()
	return {
		"enemies_alive": enemies_alive,
		"sy_intro_done": has_completed_timeline(INTRO_TIMELINE),
		"sy_limbs_collected": _limbs_collected_names.duplicate(),
		"sy_story_state": sy_story_state,
		"sy_npc_removed": sy_npc_removed,
		"sy_awaiting_sy_interact": awaiting_interact,
		"completed_timelines": _completed_timelines.duplicate(),
		"wakeup_intro_completed": _wakeup_intro_completed,
	}


func from_dict(dict: Dictionary) -> void:
	var alive: Array = dict.get("enemies_alive", [])
	for node in get_tree().get_nodes_in_group("enemies"):
		var path := get_path_to(node)
		if path not in alive:
			node.queue_free()
	_completed_timelines.clear()
	for x in dict.get("completed_timelines", []):
		_completed_timelines.append(String(x))
	if dict.get("sy_intro_done", false):
		mark_dialog_timeline_completed(INTRO_TIMELINE)
	_limbs_collected_names.clear()
	for x in dict.get("sy_limbs_collected", []):
		_limbs_collected_names.append(String(x))
	_infer_cutscene_completions_from_saved_limbs()
	_intro_completed = has_completed_timeline(INTRO_TIMELINE)
	_sy_story_state_from_save = dict.get("sy_story_state", {})
	sy_npc_removed = dict.get("sy_npc_removed", false)
	_sy_awaiting_interact_restore = dict.get("sy_awaiting_sy_interact", false)
	_wakeup_intro_completed = bool(dict.get("wakeup_intro_completed", false))


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
