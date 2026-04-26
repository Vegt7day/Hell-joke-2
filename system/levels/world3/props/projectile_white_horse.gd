extends Area2D
## 白马「剑」：先播 `ready`，再向左直线飞行，离开视野后销毁。

@export var fly_speed: float = 420.0
@export var despawn_margin: float = 80.0

@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	add_to_group("boss_white_horse_projectile")
	set_physics_process(false)
	if _animation_player and _animation_player.has_animation(&"ready"):
		_animation_player.play(&"ready")
		var len := _animation_player.get_animation(&"ready").length
		if len <= 0.0:
			len = 0.1
		await get_tree().create_timer(len).timeout
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	global_position += Vector2.LEFT * fly_speed * delta
	var bounds := _get_view_bounds_x()
	if global_position.x < bounds.x - despawn_margin:
		queue_free()


func _get_view_bounds_x() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Vector2(-10000.0, 10000.0)
	var rect := get_viewport_rect().size
	var half_w := rect.x * 0.5 * camera.zoom.x
	var center := camera.get_screen_center_position()
	return Vector2(center.x - half_w, center.x + half_w)
