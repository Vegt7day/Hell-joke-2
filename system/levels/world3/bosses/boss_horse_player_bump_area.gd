class_name BossHorsePlayerBumpArea
extends Area2D
## 与玩家物理层分离后，用 Area 触发单次「马身撞击」位移。

@export var bump_dir: Vector2 = Vector2(-1.0, -0.42)
@export var bump_speed: float = 268.0
## 离开该区域后才可以再次触发一次击飞
@export var require_exit_to_rearm: bool = true

const STANDARD_BUMP_DIR := Vector2(-1.0, -0.42)
const STANDARD_BUMP_SPEED := 268.0


var _armed: bool = true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if require_exit_to_rearm and not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


## 复制父马 CollisionShape2D 的几何，略缩小 Y 以减轻误触。
func setup_shape_from_horse(h: CharacterBody2D, y_scale: float = 0.82) -> void:
	var src := h.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if src == null or src.shape == null:
		var c := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 44.0
		c.shape = circ
		c.position = Vector2(16, -36)
		add_child(c)
		return
	var c2 := CollisionShape2D.new()
	c2.shape = src.shape.duplicate()
	c2.position = src.position
	c2.rotation = src.rotation
	c2.scale = Vector2(src.scale.x, src.scale.y * y_scale)
	add_child(c2)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not _armed:
		return
	var p: Node = body
	if not p.has_method("apply_bump_from_horse"):
		return
	var impulse := bump_dir.normalized() * bump_speed
	if bool(p.call("apply_bump_from_horse", impulse)):
		if require_exit_to_rearm:
			_armed = false


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_armed = true


func set_bump_enabled(on: bool) -> void:
	set_deferred("monitoring", on)


func apply_standard_bump_preset() -> void:
	bump_dir = STANDARD_BUMP_DIR
	bump_speed = STANDARD_BUMP_SPEED
