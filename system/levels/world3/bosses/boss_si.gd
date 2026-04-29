extends Node2D
## 驷：入场 / 变四马视觉与离场驱动（占位）。

const _PLAYER_BUMP_AREA := preload("res://system/levels/world3/bosses/boss_horse_player_bump_area.gd")

@export var move_left_speed: float = 78.0
@export var respawn_margin: float = 120.0
@export var si_bump_y_scale: float = 0.86

var _phase_controller: Node
var _movement_enabled: bool = true


func _ready() -> void:
	add_to_group("boss_si")
	add_to_group("boss_horse_shared_target")
	_resolve_phase_controller()
	_ensure_player_bump_area()


func take_damage(damage_amount: float, _attacker: Variant = null) -> void:
	if _phase_controller == null:
		_resolve_phase_controller()
	if _phase_controller and _phase_controller.has_method("apply_shared_damage"):
		_phase_controller.apply_shared_damage(damage_amount, name)


func _physics_process(delta: float) -> void:
	if not _movement_enabled:
		return
	global_position += Vector2.LEFT * move_left_speed * delta
	_wrap_to_right_if_out_of_view()


func _resolve_phase_controller() -> void:
	_phase_controller = get_tree().get_first_node_in_group("boss_phase_controller")
	if _phase_controller:
		return
	var current_scene := get_tree().current_scene
	if current_scene:
		_phase_controller = current_scene.get_node_or_null("Systems/PhaseController")


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled


func _ensure_player_bump_area() -> void:
	if get_node_or_null("PlayerBumpArea") != null:
		return
	var a := _PLAYER_BUMP_AREA.new() as BossHorsePlayerBumpArea
	a.name = "PlayerBumpArea"
	a.apply_standard_bump_preset()
	var src := get_node_or_null("HitboxPlaceholder/CollisionShape2D") as CollisionShape2D
	if src != null and src.shape != null:
		var c2 := CollisionShape2D.new()
		c2.shape = src.shape.duplicate()
		c2.position = src.position
		c2.rotation = src.rotation
		c2.scale = Vector2(src.scale.x, src.scale.y * si_bump_y_scale)
		a.add_child(c2)
	else:
		var c := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 46.0
		c.shape = circ
		c.position = Vector2(20, -28)
		a.add_child(c)
	add_child(a)


func _wrap_to_right_if_out_of_view() -> void:
	var bounds := _get_view_bounds_x()
	if global_position.x < bounds.x - respawn_margin:
		global_position.x = bounds.y + respawn_margin


func _get_view_bounds_x() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Vector2(-10000.0, 10000.0)
	var rect := get_viewport_rect().size
	var half_w := rect.x * 0.5 * camera.zoom.x
	var center := camera.get_screen_center_position()
	return Vector2(center.x - half_w, center.x + half_w)
