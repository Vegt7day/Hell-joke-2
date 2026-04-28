class_name CameraCuePanToMarker
extends Area2D

## 目标 Marker（可在场景内放一个 Marker2D，位置可在视野外）
@export var target_marker_path: NodePath = NodePath("FocusMarker")
## 偏移比例：玩家到 Marker 的插值比例（0~1）
@export_range(0.0, 1.0) var pan_k: float = 1.0
## 相机移动速度（像素/秒）
@export var camera_move_speed: float = 220.0
## 到达/过程中停留时长（秒）
@export var hold_seconds: float = 1.0
## 结束后回正速度（<=0 则沿用 camera_move_speed）
@export var clear_move_speed: float = 220.0
## 可触发次数：-1 为无限次；>=0 为最大进入触发次数
@export var max_triggers: int = 1

var _tracked_player: Node2D
var _triggered_count: int = 0
var _running: bool = false


func _ready() -> void:
	add_to_group("save_camera_cue")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _resolve_target_marker() -> Marker2D:
	if target_marker_path == NodePath() or String(target_marker_path) == "":
		var fallback := get_node_or_null("FocusMarker")
		return fallback as Marker2D if fallback is Marker2D else null
	var n := get_node_or_null(target_marker_path)
	if n is Marker2D:
		return n as Marker2D
	return null


func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if _running:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("set_camera_focus_target_world"):
		return
	if max_triggers >= 0 and _triggered_count >= max_triggers:
		return
	_tracked_player = body
	_triggered_count += 1
	call_deferred("_run_pan_sequence")


func _on_body_exited(body: Node2D) -> void:
	# 允许离开区域后继续执行（避免边界抖动），不在这里强制中断
	pass


func _run_pan_sequence() -> void:
	if _running:
		return
	_running = true
	var player := _tracked_player
	if player == null or not is_instance_valid(player):
		_running = false
		return
	var mk := _resolve_target_marker()
	if mk == null or not is_instance_valid(mk):
		_running = false
		return
	var player_pos := player.global_position
	var target_world := player_pos + (mk.global_position - player_pos) * clampf(pan_k, 0.0, 1.0)
	if player.has_method("set_camera_drag_ignore_player_input"):
		player.call("set_camera_drag_ignore_player_input", true)
	player.call("set_camera_focus_target_world", target_world, camera_move_speed)
	var hold := maxf(0.0, hold_seconds)
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout
	if is_instance_valid(player):
		var speed := clear_move_speed if clear_move_speed > 0.0 else camera_move_speed
		player.call("clear_camera_focus_target", speed)
		if player.has_method("set_camera_drag_ignore_player_input"):
			player.call("set_camera_drag_ignore_player_input", false)
	_running = false


func export_save_state() -> Dictionary:
	return {
		"triggered": _triggered_count,
	}


func apply_save_state(state: Dictionary) -> void:
	if state == null:
		return
	_triggered_count = int(state.get("triggered", 0))

