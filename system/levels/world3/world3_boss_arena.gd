extends Node2D

const MAIN_ARENA_HEART_NAME := &"MainArenaHeartInteractable"
const DEFAULT_MAIN_ARENA_HEART_SCENE := preload("res://system/levels/world3/props/boss_damage_interactable.tscn")

const _STREAM_ARENA_NORMAL := preload("res://assets/资源总库/10_音频/场景背景音乐.mp3")
const _STREAM_ARENA_BOSS := preload("res://assets/资源总库/10_音频/boss马伴奏音乐.mp3")
const _STREAM_ARENA_PHASE_20 := preload("uid://dqem8mja12ojh")




enum _ArenaBgmSlot { NORMAL, BOSS, PHASE_20 }

const _BOSS_BGM_SILENT_DB := -60.0

@export var death_y_extra_below_ground: float = 96.0
@export var main_arena_heart_scene: PackedScene = DEFAULT_MAIN_ARENA_HEART_SCENE
@export var boss_bgm_playing_volume_db: float = -5.0
@export var boss_bgm_crossfade_seconds: float = 1.2
@export var boss_bgm_load_resync_seconds: float = 0.45
@onready var player: Node2D = $player
@onready var bosses_root: Node2D = $Bosses
@onready var main_horse: Node2D = $Bosses/MainHorse
@onready var boss_si: Node2D = $Bosses/BossSi
@onready var minors_root: Node2D = $Bosses/Minors
@onready var phase_controller: Node = $Systems/PhaseController
@onready var random_piece_builder: Node = $Systems/RandomPieceBuilder
@onready var _boss_bgm_a: AudioStreamPlayer = $ArenaBgmA
@onready var _boss_bgm_b: AudioStreamPlayer = $ArenaBgmB
@onready var boss_phase_stinger: AudioStreamPlayer = get_node_or_null("BossPhaseStinger") as AudioStreamPlayer
var _pending_shared_hp_override_for_save: int = -1
var _death_ground_y: float = 0.0
var _fall_death_triggered: bool = false
var _no_damage_heart_interaction_tokens: int = 1
@export var heart_delayed_save_timeout_seconds: float = 3.0
var _pending_heart_save_active: bool = false
var _pending_heart_save_target_minor: StringName = StringName()
var _pending_heart_save_elapsed: float = 0.0

var _boss_bgm_active_kind: _ArenaBgmSlot = _ArenaBgmSlot.NORMAL
var _boss_bgm_active_is_a: bool = true
var _boss_bgm_fade_tween: Tween
var _boss_bgm_fade_pending_slot: Variant = null
var _combat_bgm_unlocked: bool = false

const _DEBUG_LOG_PATH := "d:/items/godot/hell_joke_2/文字地狱重制版/debug-5144a3.log"


func _ready() -> void:
	if player != null:
		_death_ground_y = player.global_position.y
	_fall_death_triggered = false
	call_deferred("_ensure_main_arena_heart_at_attack_marker")
	_setup_boss_audio()


func _setup_boss_audio() -> void:
	_ensure_boss_bgm_stream_loops()
	if phase_controller != null:
		if phase_controller.has_signal("phase_changed"):
			if not phase_controller.phase_changed.is_connected(_on_boss_phase_changed):
				phase_controller.phase_changed.connect(_on_boss_phase_changed)
		if phase_controller.has_signal("boss_combat_bgm_requested"):
			if not phase_controller.boss_combat_bgm_requested.is_connected(_on_boss_combat_bgm_requested):
				phase_controller.boss_combat_bgm_requested.connect(_on_boss_combat_bgm_requested)
		if phase_controller.has_signal("shared_health_depleted"):
			if not phase_controller.shared_health_depleted.is_connected(_on_shared_health_depleted_bgm):
				phase_controller.shared_health_depleted.connect(_on_shared_health_depleted_bgm)
	_boss_bgm_start_initial_normal()


func _ensure_boss_bgm_stream_loops() -> void:
	for s: AudioStream in [_STREAM_ARENA_NORMAL, _STREAM_ARENA_BOSS, _STREAM_ARENA_PHASE_20]:
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		elif s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true


func _boss_bgm_stream_for(slot: _ArenaBgmSlot) -> AudioStream:
	match slot:
		_ArenaBgmSlot.NORMAL:
			return _STREAM_ARENA_NORMAL
		_ArenaBgmSlot.BOSS:
			return _STREAM_ARENA_BOSS
		_ArenaBgmSlot.PHASE_20:
			return _STREAM_ARENA_PHASE_20
	return _STREAM_ARENA_NORMAL


func _kill_boss_bgm_tween() -> void:
	if _boss_bgm_fade_tween != null and is_instance_valid(_boss_bgm_fade_tween):
		_boss_bgm_fade_tween.kill()
	_boss_bgm_fade_tween = null
	_boss_bgm_fade_pending_slot = null


func _boss_bgm_active_player() -> AudioStreamPlayer:
	return _boss_bgm_a if _boss_bgm_active_is_a else _boss_bgm_b


func _boss_bgm_incoming_player() -> AudioStreamPlayer:
	return _boss_bgm_b if _boss_bgm_active_is_a else _boss_bgm_a


func _boss_bgm_start_initial_normal() -> void:
	_kill_boss_bgm_tween()
	_boss_bgm_a.stream = _STREAM_ARENA_NORMAL
	_boss_bgm_a.volume_db = boss_bgm_playing_volume_db
	_boss_bgm_a.play()
	_boss_bgm_b.stop()
	_boss_bgm_b.volume_db = _BOSS_BGM_SILENT_DB
	_boss_bgm_active_is_a = true
	_boss_bgm_active_kind = _ArenaBgmSlot.NORMAL
	_combat_bgm_unlocked = false


func _boss_bgm_crossfade_to(target: _ArenaBgmSlot, duration_override: float = -1.0) -> void:
	if _boss_bgm_fade_tween != null and _boss_bgm_fade_pending_slot != null and int(_boss_bgm_fade_pending_slot) == int(target):
		return
	if target == _boss_bgm_active_kind and _boss_bgm_fade_tween == null:
		var cur := _boss_bgm_active_player()
		if cur.playing and cur.volume_db > _BOSS_BGM_SILENT_DB + 6.0:
			return
	var dur: float = boss_bgm_crossfade_seconds if duration_override < 0.0 else duration_override
	var outgoing := _boss_bgm_active_player()
	var incoming := _boss_bgm_incoming_player()
	var stream_new := _boss_bgm_stream_for(target)
	incoming.stream = stream_new
	incoming.volume_db = _BOSS_BGM_SILENT_DB
	if not incoming.playing:
		incoming.play(0.0)
	_kill_boss_bgm_tween()
	_boss_bgm_fade_pending_slot = target
	_boss_bgm_fade_tween = create_tween()
	_boss_bgm_fade_tween.set_parallel(true)
	_boss_bgm_fade_tween.tween_property(outgoing, "volume_db", _BOSS_BGM_SILENT_DB, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_boss_bgm_fade_tween.tween_property(incoming, "volume_db", boss_bgm_playing_volume_db, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var out_player := outgoing
	var set_active_is_a := not _boss_bgm_active_is_a
	var finished_kind := target
	_boss_bgm_fade_tween.finished.connect(
		_boss_bgm_on_crossfade_finished.bind(out_player, set_active_is_a, finished_kind),
		CONNECT_ONE_SHOT
	)


func _boss_bgm_on_crossfade_finished(out_player: AudioStreamPlayer, set_active_is_a: bool, finished_kind: _ArenaBgmSlot) -> void:
	if is_instance_valid(out_player):
		out_player.stop()
	_boss_bgm_active_is_a = set_active_is_a
	_boss_bgm_active_kind = finished_kind
	_boss_bgm_fade_pending_slot = null


func _on_boss_phase_changed(new_phase: Variant) -> void:
	if boss_phase_stinger != null and boss_phase_stinger.stream != null:
		boss_phase_stinger.play()
	if int(new_phase) == int(BossHorseTypes.BossPhase.FINAL_WARNING_20):
		_boss_bgm_crossfade_to(_ArenaBgmSlot.PHASE_20)


func _on_boss_combat_bgm_requested() -> void:
	_combat_bgm_unlocked = true
	if _boss_bgm_active_kind == _ArenaBgmSlot.PHASE_20:
		return
	_boss_bgm_crossfade_to(_ArenaBgmSlot.BOSS)


func _on_shared_health_depleted_bgm() -> void:
	_combat_bgm_unlocked = false
	_boss_bgm_crossfade_to(_ArenaBgmSlot.NORMAL)


func _boss_bgm_sync_after_load() -> void:
	if phase_controller == null:
		return
	var st: Stats = null
	if phase_controller.has_method("get_shared_stats"):
		st = phase_controller.call("get_shared_stats") as Stats
	if st == null:
		return
	if st.health <= 0:
		_combat_bgm_unlocked = false
		_boss_bgm_crossfade_to(_ArenaBgmSlot.NORMAL, boss_bgm_load_resync_seconds)
		return
	var intro_tr := false
	if phase_controller.has_method("is_intro_battle_triggered_for_save"):
		intro_tr = bool(phase_controller.call("is_intro_battle_triggered_for_save"))
	if intro_tr:
		_combat_bgm_unlocked = true
	var ph: Variant = phase_controller.get("current_phase")
	var p := int(ph) if ph != null else int(BossHorseTypes.BossPhase.INTRO)
	var want := _ArenaBgmSlot.NORMAL
	if p >= int(BossHorseTypes.BossPhase.FINAL_WARNING_20) and st.health > 0:
		want = _ArenaBgmSlot.PHASE_20
	elif _combat_bgm_unlocked:
		want = _ArenaBgmSlot.BOSS
	_boss_bgm_crossfade_to(want, boss_bgm_load_resync_seconds)


func _ensure_main_arena_heart_at_attack_marker() -> void:
	var props := bosses_root.get_node_or_null("PropsSpawn") as Node2D
	if props == null:
		return
	var attack_m := props.get_node_or_null("attack") as Marker2D
	if attack_m == null:
		return
	var existing := props.get_node_or_null(String(MAIN_ARENA_HEART_NAME))
	if existing is BossDamageInteractable:
		(existing as Node2D).global_position = attack_m.global_position
		return
	if main_arena_heart_scene == null:
		return
	var heart := main_arena_heart_scene.instantiate() as Node2D
	if heart == null:
		return
	heart.name = String(MAIN_ARENA_HEART_NAME)
	props.add_child(heart)
	heart.global_position = attack_m.global_position


func _physics_process(_delta: float) -> void:
	if _fall_death_triggered:
		return
	if player == null or not is_instance_valid(Game) or Game.player_stats == null:
		return
	if Game.player_stats.health <= 0:
		return
	var death_y: float = _death_ground_y + death_y_extra_below_ground
	if player.global_position.y >= death_y:
		Game.player_stats.health = 0
		_fall_death_triggered = true


func _process(delta: float) -> void:
	if not _pending_heart_save_active:
		return
	_pending_heart_save_elapsed += maxf(0.0, delta)
	if _pending_heart_save_target_minor != StringName() and not _is_minor_ready_for_heart_save(_pending_heart_save_target_minor):
		if _pending_heart_save_elapsed < maxf(0.1, heart_delayed_save_timeout_seconds):
			return
	_finalize_delayed_heart_save()


func to_dict() -> Dictionary:
	var out := {
		"player": _capture_node_state(player),
		"main_horse": _capture_node_state(main_horse),
		"boss_si": _capture_node_state(boss_si),
		"minors": {},
		"current_phase": phase_controller.get("current_phase") if phase_controller != null else 0,
		"boss_shared_hp": -1,
		"interactables": {},
		"intro_battle_triggered": false,
		"si_split_triggered": false,
	}
	if phase_controller != null and phase_controller.has_method("get_shared_stats"):
		var st := phase_controller.call("get_shared_stats") as Stats
		if st != null:
			out["boss_shared_hp"] = st.health
	if _pending_shared_hp_override_for_save >= 0:
		out["boss_shared_hp"] = _pending_shared_hp_override_for_save
		_pending_shared_hp_override_for_save = -1
	for c in minors_root.get_children():
		if c is Node2D:
			out["minors"][String(c.name)] = _capture_node_state(c as Node2D)
	for i in bosses_root.get_node("PropsSpawn").get_children():
		if i is BossDamageInteractable:
			out["interactables"][String(i.name)] = (i as BossDamageInteractable).export_save_state()
	if random_piece_builder != null and random_piece_builder.has_method("export_builder_state"):
		out["random_piece_builder"] = random_piece_builder.call("export_builder_state")
	if phase_controller != null and phase_controller.has_method("is_intro_battle_triggered_for_save"):
		out["intro_battle_triggered"] = bool(phase_controller.call("is_intro_battle_triggered_for_save"))
	if phase_controller != null and phase_controller.has_method("is_si_split_triggered_for_save"):
		out["si_split_triggered"] = bool(phase_controller.call("is_si_split_triggered_for_save"))
	return out


func from_dict(dict: Dictionary) -> void:
	_apply_node_state(player, dict.get("player", {}))
	_apply_node_state(main_horse, dict.get("main_horse", {}))
	_apply_node_state(boss_si, dict.get("boss_si", {}))
	var minors_dict: Dictionary = dict.get("minors", {})
	#region agent log
	_debug_log("run10", "H2", "world3_boss_arena.gd:from_dict", "entry", {
		"saved_minors_keys": minors_dict.keys(),
		"saved_current_phase": dict.get("current_phase", null),
		"saved_boss_shared_hp": int(dict.get("boss_shared_hp", -1))
	})
	#endregion
	if phase_controller != null and phase_controller.has_method("ensure_saved_minors_present"):
		phase_controller.call("ensure_saved_minors_present", minors_dict)
	for c in minors_root.get_children():
		if c is Node2D and minors_dict.has(String(c.name)):
			_apply_node_state(c as Node2D, minors_dict[String(c.name)])
	if phase_controller != null and phase_controller.has_method("restore_minor_horse_ids"):
		phase_controller.call("restore_minor_horse_ids", minors_root)
	#region agent log
	var minor_states: Array = []
	for c2 in minors_root.get_children():
		if c2 is Node2D:
			var n2 := c2 as Node2D
			minor_states.append({
				"name": String(n2.name),
				"visible": n2.visible,
				"process_mode": n2.process_mode
			})
	_debug_log("run11", "H4", "world3_boss_arena.gd:from_dict", "after_apply_node_state", {
		"main_pos": {"x": main_horse.global_position.x, "y": main_horse.global_position.y} if main_horse != null else {},
		"main_visible": main_horse.visible if main_horse != null else false,
		"main_process_mode": main_horse.process_mode if main_horse != null else -1,
		"minor_states": minor_states
	})
	#endregion
	var boss_shared_hp: int = int(dict.get("boss_shared_hp", -1))
	var shared_max_hp: int = -1
	if boss_shared_hp >= 0 and phase_controller != null and phase_controller.has_method("get_shared_stats"):
		var st := phase_controller.call("get_shared_stats") as Stats
		if st != null:
			shared_max_hp = st.max_health
			st.health = boss_shared_hp
	var saved_phase: Variant = dict.get("current_phase", null)
	var saved_phase_int: int = int(saved_phase) if saved_phase != null else int(BossHorseTypes.BossPhase.INTRO)
	if saved_phase != null and phase_controller != null and phase_controller.has_method("request_phase"):
		phase_controller.call_deferred("request_phase", saved_phase_int)
	#region agent log
	_debug_log("run11", "H5", "world3_boss_arena.gd:from_dict", "after_request_phase_deferred", {
		"saved_phase_int": saved_phase_int,
		"controller_current_phase_now": int(phase_controller.get("current_phase")) if phase_controller != null else -1
	})
	#endregion
	var intro_battle_triggered := bool(dict.get("intro_battle_triggered", false))
	if phase_controller != null and phase_controller.has_method("apply_intro_battle_triggered_from_save"):
		phase_controller.call("apply_intro_battle_triggered_from_save", intro_battle_triggered)
	var si_split_triggered := bool(dict.get("si_split_triggered", not minors_dict.is_empty()))
	var should_skip_intro_gate: bool = intro_battle_triggered
	if saved_phase_int > int(BossHorseTypes.BossPhase.INTRO):
		should_skip_intro_gate = true
	if shared_max_hp > 0 and boss_shared_hp >= 0 and boss_shared_hp < shared_max_hp:
		should_skip_intro_gate = true
	# 若存档时已完成“驷马分裂/退场”，读档直接恢复 Minors，不再重演驷变四马。
	var should_restore_direct_minors := si_split_triggered and not minors_dict.is_empty()
	#region agent log
	_debug_log("run10", "H2", "world3_boss_arena.gd:from_dict", "gate_eval", {
		"intro_battle_triggered": intro_battle_triggered,
		"si_split_triggered": si_split_triggered,
		"should_skip_intro_gate": should_skip_intro_gate,
		"should_restore_direct_minors": should_restore_direct_minors
	})
	#endregion
	if should_skip_intro_gate and not should_restore_direct_minors and phase_controller != null and phase_controller.has_method("force_main_si_enter_battle_from_save"):
		phase_controller.call_deferred("force_main_si_enter_battle_from_save")
	if should_skip_intro_gate and phase_controller != null and phase_controller.has_method("restore_combat_state_from_save"):
		phase_controller.call_deferred("restore_combat_state_from_save", saved_phase_int, should_restore_direct_minors)
	#region agent log
	_debug_log("run11", "H4", "world3_boss_arena.gd:from_dict", "gate_path_taken", {
		"should_restore_direct_minors": should_restore_direct_minors,
		"called_force_main_si_enter_battle_from_save": should_skip_intro_gate and not should_restore_direct_minors,
		"called_restore_combat_state_from_save": should_skip_intro_gate
	})
	#endregion
	var int_map: Dictionary = dict.get("interactables", {})
	for i in bosses_root.get_node("PropsSpawn").get_children():
		if i is BossDamageInteractable and int_map.has(String(i.name)):
			(i as BossDamageInteractable).apply_save_state(int_map[String(i.name)])
	var rpb_state: Variant = dict.get("random_piece_builder", {})
	if rpb_state is Dictionary and random_piece_builder != null and random_piece_builder.has_method("apply_builder_state"):
		random_piece_builder.call("apply_builder_state", rpb_state)
	_fall_death_triggered = false
	call_deferred("_boss_bgm_sync_after_load")


func _debug_log(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var payload := {
		"sessionId": "5144a3",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0)
	}
	var f := FileAccess.open(_DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(_DEBUG_LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()


func update_player(position: Vector2, direction: int = 1) -> void:
	if player == null:
		return
	player.global_position = position
	if player.has_method("set_direction"):
		player.call("set_direction", direction)
	elif "direction" in player:
		player.set("direction", direction)


func set_pending_shared_hp_override_for_save(value: int) -> void:
	_pending_shared_hp_override_for_save = max(value, 0)


func request_delayed_heart_save(predicted_hp: int, target_minor_name: StringName = StringName()) -> void:
	set_pending_shared_hp_override_for_save(predicted_hp)
	_pending_heart_save_active = true
	_pending_heart_save_target_minor = target_minor_name
	_pending_heart_save_elapsed = 0.0
	if target_minor_name == StringName():
		_finalize_delayed_heart_save()


func _is_minor_ready_for_heart_save(minor_name: StringName) -> bool:
	if minors_root == null:
		return false
	var minor := minors_root.get_node_or_null(String(minor_name)) as Node2D
	if minor == null or not is_instance_valid(minor):
		return false
	if not minor.visible:
		return false
	if minor.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if "_movement_enabled" in minor and not bool(minor.get("_movement_enabled")):
		return false
	return true


func _finalize_delayed_heart_save() -> void:
	_pending_heart_save_active = false
	_pending_heart_save_target_minor = StringName()
	_pending_heart_save_elapsed = 0.0
	if is_instance_valid(Game) and Game.has_method("save_game"):
		Game.save_game("heart", true)


func consume_no_damage_heart_interaction_token() -> bool:
	if _no_damage_heart_interaction_tokens <= 0:
		return false
	_no_damage_heart_interaction_tokens -= 1
	return true


func _capture_node_state(node: Node2D) -> Dictionary:
	if node == null:
		return {}
	var out := {
		"position": {"x": node.global_position.x, "y": node.global_position.y},
		"visible": node.visible,
		"process_mode": node.process_mode,
	}
	if "horse_id" in node:
		out["horse_id"] = node.get("horse_id")
		#region agent log
		_debug_log("run13", "H1", "world3_boss_arena.gd:_capture_node_state", "capture_node_horse_id", {
			"node_name": String(node.name),
			"horse_id": int(node.get("horse_id"))
		})
		#endregion
	if node is CharacterBody2D:
		var v := (node as CharacterBody2D).velocity
		out["velocity"] = {"x": v.x, "y": v.y}
	return out


func _apply_node_state(node: Node2D, state: Dictionary) -> void:
	if node == null or state.is_empty():
		return
	if state.has("position"):
		node.global_position = _read_vec2_compat(state["position"], node.global_position)
	if state.has("visible"):
		node.visible = bool(state["visible"])
	if state.has("process_mode"):
		node.process_mode = int(state["process_mode"])
	if state.has("horse_id") and "horse_id" in node:
		#region agent log
		_debug_log("run13", "H1", "world3_boss_arena.gd:_apply_node_state", "before_apply_horse_id", {
			"node_name": String(node.name),
			"node_horse_id_before": int(node.get("horse_id")),
			"saved_horse_id": int(state["horse_id"])
		})
		#endregion
		node.set("horse_id", state["horse_id"])
		if node.has_method("refresh_visual_to_horse_id"):
			node.call("refresh_visual_to_horse_id")
		#region agent log
		_debug_log("run13", "H1", "world3_boss_arena.gd:_apply_node_state", "after_apply_horse_id", {
			"node_name": String(node.name),
			"node_horse_id_after": int(node.get("horse_id"))
		})
		#endregion
	if state.has("velocity") and node is CharacterBody2D:
		var cb := node as CharacterBody2D
		cb.velocity = _read_vec2_compat(state["velocity"], cb.velocity)


func _read_vec2_compat(raw: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if raw is Vector2:
		return raw as Vector2
	if raw is Dictionary:
		var d := raw as Dictionary
		var x := float(d.get("x", fallback.x))
		var y := float(d.get("y", fallback.y))
		return Vector2(x, y)
	if raw is String:
		# 兼容旧档把 Vector2 序列化成 "(x, y)" 字符串的情况。
		var s := (raw as String).strip_edges()
		s = s.trim_prefix("(").trim_suffix(")")
		var parts := s.split(",", false)
		if parts.size() >= 2:
			return Vector2(float(parts[0]), float(parts[1]))
	return fallback
