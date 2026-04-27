extends Node2D

@onready var player: Node2D = $player
@onready var bosses_root: Node2D = $Bosses
@onready var main_horse: Node2D = $Bosses/MainHorse
@onready var boss_si: Node2D = $Bosses/BossSi
@onready var minors_root: Node2D = $Bosses/Minors
@onready var phase_controller: Node = $Systems/PhaseController
var _pending_shared_hp_override_for_save: int = -1


func to_dict() -> Dictionary:
	var out := {
		"player": _capture_node_state(player),
		"main_horse": _capture_node_state(main_horse),
		"boss_si": _capture_node_state(boss_si),
		"minors": {},
		"current_phase": phase_controller.get("current_phase") if phase_controller != null else 0,
		"boss_shared_hp": -1,
		"interactables": {},
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
	return out


func from_dict(dict: Dictionary) -> void:
	_apply_node_state(player, dict.get("player", {}))
	_apply_node_state(main_horse, dict.get("main_horse", {}))
	_apply_node_state(boss_si, dict.get("boss_si", {}))
	var minors_dict: Dictionary = dict.get("minors", {})
	for c in minors_root.get_children():
		if c is Node2D and minors_dict.has(String(c.name)):
			_apply_node_state(c as Node2D, minors_dict[String(c.name)])
	var boss_shared_hp: int = int(dict.get("boss_shared_hp", -1))
	if boss_shared_hp >= 0 and phase_controller != null and phase_controller.has_method("get_shared_stats"):
		var st := phase_controller.call("get_shared_stats") as Stats
		if st != null:
			st.health = boss_shared_hp
	var saved_phase: Variant = dict.get("current_phase", null)
	if saved_phase != null and phase_controller != null and phase_controller.has_method("request_phase"):
		phase_controller.call_deferred("request_phase", int(saved_phase))
	var int_map: Dictionary = dict.get("interactables", {})
	for i in bosses_root.get_node("PropsSpawn").get_children():
		if i is BossDamageInteractable and int_map.has(String(i.name)):
			(i as BossDamageInteractable).apply_save_state(int_map[String(i.name)])


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
