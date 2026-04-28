class_name CameraCueFocusArea
extends Area2D

## 玩家到焦点点的插值比例（0~1，越大越靠近焦点点）
@export_range(0.01, 0.99) var focus_k: float = 0.35
## 相机平滑移动速度（单位：像素/秒）
@export var camera_move_speed: float = 220.0
## 离开区域后，相机回正速度（<=0 则沿用 camera_move_speed）
@export var clear_move_speed: float = 220.0
## 可触发次数：-1 为无限次；>=0 为最大进入触发次数
@export var max_triggers: int = -1

## 碰撞箱形状：矩形或圆形（可选；只有你手动添加 CollisionShape2D 才会生效）
@export_enum("rectangle", "circle") var collision_shape_type: String = "rectangle":
	set(v):
		collision_shape_type = v
		_refresh_collision_shape()
## 外部可直接注入 Shape2D（用于流水化生成）；设置后优先于内置枚举参数
@export var collision_shape_resource: Shape2D:
	set(v):
		collision_shape_resource = v
		_refresh_collision_shape()
## 矩形碰撞箱尺寸（仅 rectangle 生效）
@export var collision_rect_size: Vector2 = Vector2(256.0, 128.0):
	set(v):
		collision_rect_size = Vector2(maxf(1.0, v.x), maxf(1.0, v.y))
		_refresh_collision_shape()
## 圆形碰撞箱半径（仅 circle 生效）
@export var collision_circle_radius: float = 96.0:
	set(v):
		collision_circle_radius = maxf(1.0, v)
		_refresh_collision_shape()

var _tracked_player: Node2D
@onready var _collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var _focus_marker: Marker2D = get_node_or_null("FocusMarker") as Marker2D
var _triggered_count: int = 0


func _ready() -> void:
	add_to_group("save_camera_cue")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(false)
	_refresh_collision_shape()


func _refresh_collision_shape() -> void:
	if _collision_shape == null:
		return
	if collision_shape_resource != null:
		_collision_shape.shape = collision_shape_resource
		return
	if collision_shape_type == "circle":
		var circle := _collision_shape.shape as CircleShape2D
		if circle == null:
			circle = CircleShape2D.new()
			_collision_shape.shape = circle
		circle.radius = maxf(1.0, collision_circle_radius)
	else:
		var rect := _collision_shape.shape as RectangleShape2D
		if rect == null:
			rect = RectangleShape2D.new()
			_collision_shape.shape = rect
		rect.size = Vector2(maxf(1.0, collision_rect_size.x), maxf(1.0, collision_rect_size.y))


func _process(_delta: float) -> void:
	if _tracked_player == null or not is_instance_valid(_tracked_player):
		set_process(false)
		return
	var center := _focus_marker.global_position if _focus_marker != null else global_position
	var player_pos := _tracked_player.global_position
	var target := player_pos + (center - player_pos) * clampf(focus_k, 0.01, 0.99)
	if _tracked_player.has_method("set_camera_focus_target_world"):
		_tracked_player.call("set_camera_focus_target_world", target, camera_move_speed)


func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("set_camera_focus_target_world"):
		return
	if max_triggers >= 0 and _triggered_count >= max_triggers:
		return
	_tracked_player = body
	_triggered_count += 1
	set_process(true)
	_process(0.0)


func _on_body_exited(body: Node2D) -> void:
	if _tracked_player == null:
		return
	if body != _tracked_player:
		return
	if _tracked_player.has_method("clear_camera_focus_target"):
		var speed := clear_move_speed if clear_move_speed > 0.0 else camera_move_speed
		_tracked_player.call("clear_camera_focus_target", speed)
	_tracked_player = null
	set_process(false)


func export_save_state() -> Dictionary:
	return {
		"triggered": _triggered_count,
	}


func apply_save_state(state: Dictionary) -> void:
	if state == null:
		return
	_triggered_count = int(state.get("triggered", 0))

