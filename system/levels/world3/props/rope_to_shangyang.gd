extends Node2D
## 五马锁链：实时连接「马」与「商鞅肢体」两端。

@export var rope_color: Color = Color(0.35, 0.28, 0.22, 1.0)
@export var rope_width: float = 3.0
@export var start_offset: Vector2 = Vector2.ZERO
@export var end_offset: Vector2 = Vector2.ZERO

@onready var line_2d: Line2D = $Line2D

var _start_node: Node2D
var _end_node: Node2D
var _is_bound: bool = false
## 1 = 完全连到末端；0 = 收在起点（用于「伸出绳子」演出）
var _extend_progress: float = 1.0

func _ready() -> void:
	add_to_group("boss_rope_to_shangyang")
	if line_2d:
		line_2d.width = rope_width
		line_2d.default_color = rope_color
		line_2d.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT * 8.0])


func bind_endpoints(start_node: Node2D, end_node: Node2D, custom_start_offset: Vector2 = Vector2.ZERO, custom_end_offset: Vector2 = Vector2.ZERO, initial_extend: float = 0.0) -> void:
	_start_node = start_node
	_end_node = end_node
	start_offset = custom_start_offset
	end_offset = custom_end_offset
	_is_bound = _start_node != null and _end_node != null
	set_extend_progress(initial_extend)


func set_extend_progress(p: float) -> void:
	_extend_progress = clampf(p, 0.0, 1.0)
	_update_line_now()


func _process(_delta: float) -> void:
	if not _is_bound:
		return
	_update_line_now()


func _update_line_now() -> void:
	if line_2d == null or _start_node == null or _end_node == null:
		return
	var from := _start_node.global_position + start_offset
	var to := _end_node.global_position + end_offset
	var full := to - from
	line_2d.global_position = from
	line_2d.points = PackedVector2Array([Vector2.ZERO, full * _extend_progress])
