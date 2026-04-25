extends StaticBody2D

# 导出变量，可以在编辑器中设置
@export var initial_color: String = "红"
@export var is_open: bool = false  # 初始状态：false=关闭，true=打开

# 节点引用
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var color_rect: ColorRect = $ColorRect

var current_color: String
var door_is_processing: bool = false  # 防止重复处理

func _ready():
	# 初始化颜色
	current_color = initial_color
	
	# 根据颜色字符串设置ColorRect的颜色
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
			print("警告：未知颜色", current_color, "，使用默认白色")
	
	# 初始化门的状态
	if not is_open:
		# 设置为打开状态：显示最后一帧，禁用碰撞
		sprite_2d.frame = 4
		collision_shape.disabled = true
	else:
		# 设置为关闭状态：显示第0帧，启用碰撞
		sprite_2d.frame = 0
		collision_shape.disabled = false
	
	print("门初始化完成 - 颜色:", current_color, " 状态:", "开" if is_open else "关")


## 由子节点 [SwitchChannelListener] 在收到 [MechanismLinkBus] 事件时调用（已按颜色通道过滤）。
## [param play_anim]：为 false 时仅同步帧与碰撞（用于从总线恢复状态、不在 _ready 链上播动画）。
func apply_switch_bus_state(target_open: bool, play_anim: bool = true) -> void:
	if door_is_processing:
		return
	if target_open == is_open:
		return
	if not play_anim:
		is_open = target_open
		if target_open:
			sprite_2d.frame = 4
			collision_shape.disabled = true
		else:
			sprite_2d.frame = 0
			collision_shape.disabled = false
		return
	if not target_open:
		push_players_out()
	door_is_processing = true
	if not target_open:
		animation_player.play("open")
		collision_shape.disabled = true
		print("门正在打开 - 颜色:", current_color)
	else:
		animation_player.play("close")
		collision_shape.disabled = false
		print("门正在关闭 - 颜色:", current_color)
	is_open = target_open
	await get_tree().create_timer(0.5).timeout
	door_is_processing = false
	print("门状态更新完成 - 颜色:", current_color, " 状态:", "开" if is_open else "关")


func push_players_out():
	var overlapping_bodies = $PushArea.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("player"):
			var push_direction = (body.global_position - global_position).normalized()
			body.apply_central_impulse(push_direction * 100)
