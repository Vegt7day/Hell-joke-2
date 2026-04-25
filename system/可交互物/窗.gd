extends StaticBody2D
## 与 [MechanismLinkBus] 同色通道联动：开关为「开」时播 open，为「关」时播 close（与门语义一致）。
## 子节点 [SwitchChannelListener] 会调用 [method apply_switch_bus_state]。

const _OPEN_FRAME := 4
const _CLOSED_FRAME := 0
const _COLLISION_POS := Vector2(16.5, -2.5)

@export var initial_color: String = "红"
@export var is_open: bool = true

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var color_rect: ColorRect = $ColorRect

var current_color: String
var _is_processing: bool = false


func _ready() -> void:
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate(true)
	current_color = initial_color
	match current_color:
		"红":
			color_rect.color = Color.RED
		"绿":
			color_rect.color = Color.GREEN
		"蓝":
			color_rect.color = Color.BLUE
		"黄":
			color_rect.color = Color.YELLOW
		"紫":
			color_rect.color = Color.PURPLE
		"橙":
			color_rect.color = Color.ORANGE
		"白":
			color_rect.color = Color.WHITE
		"黑":
			color_rect.color = Color.BLACK
		_:
			color_rect.color = Color.WHITE
			push_warning("窗: 未知颜色 %s，使用白色" % current_color)
	_apply_instant_visual(is_open)


func apply_switch_bus_state(target_open: bool, play_anim: bool = true) -> void:
	if _is_processing:
		return
	if target_open == is_open:
		return
	if not play_anim:
		is_open = target_open
		_apply_instant_visual(target_open)
		return
	_is_processing = true
	if target_open:
		animation_player.play("open")
		collision_shape.disabled = false
	else:
		animation_player.play("close")
		collision_shape.disabled = true
	is_open = target_open
	await get_tree().create_timer(0.5).timeout
	_is_processing = false


func _apply_instant_visual(open: bool) -> void:
	if open:
		sprite_2d.frame = _OPEN_FRAME
		collision_shape.disabled = false
	else:
		sprite_2d.frame = _CLOSED_FRAME
		collision_shape.disabled = true
	collision_shape.position = _COLLISION_POS
