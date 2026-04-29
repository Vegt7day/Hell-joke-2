extends Node2D

const MAIN_ARENA_HEART_NAME := &"MainArenaHeartInteractable"
const DEFAULT_MAIN_ARENA_HEART_SCENE := preload("res://system/levels/world3/props/boss_damage_interactable.tscn")

@export var death_y_extra_below_ground: float = 96.0
@export var main_arena_heart_scene: PackedScene = DEFAULT_MAIN_ARENA_HEART_SCENE
@onready var player: Node2D = $player
@onready var bosses_root: Node2D = $Bosses
@onready var main_horse: Node2D = $Bosses/MainHorse
@onready var boss_si: Node2D = $Bosses/BossSi
@onready var minors_root: Node2D = $Bosses/Minors
@onready var phase_controller: Node = $Systems/PhaseController
@onready var random_piece_builder: Node = $Systems/RandomPieceBuilder
@onready var boss_battle_bgm: AudioStreamPlayer = get_node_or_null("BossBattleBgm") as AudioStreamPlayer
@onready var boss_phase_stinger: AudioStreamPlayer = get_node_or_null("BossPhaseStinger") as AudioStreamPlayer
var _pending_shared_hp_override_for_save: int = -1
var _death_ground_y: float = 0.0
var _fall_death_triggered: bool = false
var _no_damage_heart_interaction_tokens: int = 1


func _ready() -> void:
	if player != null:
		_death_ground_y = player.global_position.y
	_fall_death_triggered = false
	call_deferred("_ensure_main_arena_heart_at_attack_marker")
	_setup_boss_audio()


func _setup_boss_audio() -> void:
	if phase_controller != null and phase_controller.has_signal("phase_changed"):
		if not phase_controller.phase_changed.is_connected(_on_boss_phase_changed_stinger):
			phase_controller.phase_changed.connect(_on_boss_phase_changed_stinger)
	if boss_battle_bgm != null and boss_battle_bgm.stream != null:
		var st: AudioStream = boss_battle_bgm.stream
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		elif st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		boss_battle_bgm.play()


func _on_boss_phase_changed_stinger(_new_phase: Variant) -> void:
	if boss_phase_stinger != null and boss_phase_stinger.stream != null:
		boss_phase_stinger.play()


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
	return out


func from_dict(dict: Dictionary) -> void:
	_apply_node_state(player, dict.get("player", {}))
	_apply_node_state(main_horse, dict.get("main_horse", {}))
	_apply_node_state(boss_si, dict.get("boss_si", {}))
	var minors_dict: Dictionary = dict.get("minors", {})
	if phase_controller != null and phase_controller.has_method("ensure_saved_minors_present"):
		phase_controller.call("ensure_saved_minors_present", minors_dict)
	for c in minors_root.get_children():
		if c is Node2D and minors_dict.has(String(c.name)):
			_apply_node_state(c as Node2D, minors_dict[String(c.name)])
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
	var intro_battle_triggered := bool(dict.get("intro_battle_triggered", false))
	if phase_controller != null and phase_controller.has_method("apply_intro_battle_triggered_from_save"):
		phase_controller.call("apply_intro_battle_triggered_from_save", intro_battle_triggered)
	var should_skip_intro_gate: bool = intro_battle_triggered
	if saved_phase_int > int(BossHorseTypes.BossPhase.INTRO):
		should_skip_intro_gate = true
	if shared_max_hp > 0 and boss_shared_hp >= 0 and boss_shared_hp < shared_max_hp:
		should_skip_intro_gate = true
	if should_skip_intro_gate and phase_controller != null and phase_controller.has_method("force_main_si_enter_battle_from_save"):
		phase_controller.call_deferred("force_main_si_enter_battle_from_save")
	var int_map: Dictionary = dict.get("interactables", {})
	for i in bosses_root.get_node("PropsSpawn").get_children():
		if i is BossDamageInteractable and int_map.has(String(i.name)):
			(i as BossDamageInteractable).apply_save_state(int_map[String(i.name)])
	var rpb_state: Variant = dict.get("random_piece_builder", {})
	if rpb_state is Dictionary and random_piece_builder != null and random_piece_builder.has_method("apply_builder_state"):
		random_piece_builder.call("apply_builder_state", rpb_state)
	_fall_death_triggered = false


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
		node.set("horse_id", state["horse_id"])
		if node.has_method("refresh_visual_to_horse_id"):
			node.call("refresh_visual_to_horse_id")
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
