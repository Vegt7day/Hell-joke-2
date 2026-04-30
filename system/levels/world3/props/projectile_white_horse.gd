extends CharacterBody2D
## 白马「剑」：`CharacterBody2D` + `move_and_collide`，高速下不易穿模；先播 `ready`，再沿 X 飞向主角，命中玩家播 `over` 后销毁。

@export var fly_speed: float = 420.0
@export var despawn_margin: float = 80.0
@export var hit_damage: float = 1.0
## 整剑（碰撞体 + 子节点）绕根节点 X 翻转；与 `_fly_dir_x` 相反以贴合当前美术朝向，仍反了可在 Inspector 乘 -1。
@export var root_facing_multiplier: float = 1.0

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _hit_sfx: AudioStreamPlayer = $HitSfx
var _fly_dir_x: float = -1.0
var _hit_consumed: bool = false


func _ready() -> void:
	add_to_group("boss_white_horse_projectile")
	motion_mode = MOTION_MODE_FLOATING
	velocity = Vector2.ZERO
	set_physics_process(false)
	# 等一帧：父节点在 add_child 返回后才写 global_position。
	await get_tree().process_frame
	_resolve_fly_direction()
	# 必须在播 ready 之前翻根节点，否则向右飞时前几帧动画仍是未镜像的。
	_apply_root_facing_to_player_x()
	if _animation_player != null and _animation_player.has_animation(&"ready"):
		_animation_player.play(&"ready")
		var len := _animation_player.get_animation(&"ready").length
		if len <= 0.0:
			len = 0.1
		await get_tree().create_timer(len).timeout
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _hit_consumed:
		return
	var motion := Vector2(_fly_dir_x * fly_speed * delta, 0.0)
	var collision := move_and_collide(motion)
	if collision != null:
		var collider: Object = collision.get_collider()
		if collider is Node and (collider as Node).is_in_group("player"):
			_hit_consumed = true
			_run_hit_and_despawn(collider as Node2D)
			return
	var bounds := _get_view_bounds_x()
	if global_position.x < bounds.x - despawn_margin:
		queue_free()
		return
	if global_position.x > bounds.y + despawn_margin:
		queue_free()


func _get_view_bounds_x() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Vector2(-10000.0, 10000.0)
	var rect := get_viewport_rect().size
	var half_w := rect.x * 0.5 * camera.zoom.x
	var center := camera.get_screen_center_position()
	return Vector2(center.x - half_w, center.x + half_w)


func _resolve_fly_direction() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_fly_dir_x = -1.0
		return
	if player.global_position.x >= global_position.x:
		_fly_dir_x = 1.0
	else:
		_fly_dir_x = -1.0


func _apply_root_facing_to_player_x() -> void:
	var base_x: float = absf(scale.x)
	if base_x < 0.0001:
		base_x = 1.0
	# 美术默认朝 -X 时，移动朝 +X 需 scale.x 为负；与 fly 同号会画反，故取反。
	scale.x = base_x * root_facing_multiplier * (-_fly_dir_x)


func _run_hit_and_despawn(body: Node2D) -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if is_instance_valid(body) and body.has_method("take_damage"):
		body.call("take_damage", hit_damage)
	if _hit_sfx and _hit_sfx.stream:
		_hit_sfx.play()
	if _animation_player != null and _animation_player.has_animation(&"over"):
		_animation_player.play(&"over")
		var over_len: float = _animation_player.get_animation(&"over").length
		if over_len <= 0.0:
			over_len = 0.3
		await get_tree().create_timer(over_len).timeout
	else:
		await get_tree().create_timer(0.12).timeout
	queue_free()
