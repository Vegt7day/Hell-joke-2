extends CharacterBody2D

@export var gravity: float = 900.0
@export var max_fall_speed: float = 900.0
@export var damage: float = 1.0
@export var lifetime: float = 6.0
@export var collision_disable_defer: bool = true

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _is_destroying: bool = false
var _is_falling: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 85
	animation_player.animation_finished.connect(_on_animation_finished)
	_start_spawn()
	_start_lifetime_timer()


func initialize_from_bucket(spawn_pos: Vector2) -> void:
	global_position = spawn_pos


func _physics_process(delta: float) -> void:
	if _is_destroying or not _is_falling:
		return
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		_on_hit(collision.get_collider())


func _start_spawn() -> void:
	_is_falling = false
	velocity = Vector2.ZERO
	animation_player.play("be created")


func _start_fall() -> void:
	if _is_destroying:
		return
	_is_falling = true
	animation_player.play("fall")


func _on_hit(collider: Object) -> void:
	if _is_destroying:
		return
	if collider != null and collider.has_method("take_damage"):
		collider.call("take_damage", damage, self)
	_start_disappear()


func _start_disappear() -> void:
	if _is_destroying:
		return
	_is_destroying = true
	_is_falling = false
	velocity = Vector2.ZERO
	if collision_shape != null:
		if collision_disable_defer:
			collision_shape.set_deferred("disabled", true)
		else:
			collision_shape.disabled = true
	animation_player.play("disappear")
	var length := animation_player.current_animation_length
	if length <= 0.0:
		queue_free()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"be created":
		_start_fall()
	elif anim_name == &"disappear":
		queue_free()


func _start_lifetime_timer() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_lifetime_timeout)


func _on_lifetime_timeout() -> void:
	if _is_destroying:
		return
	_start_disappear()
