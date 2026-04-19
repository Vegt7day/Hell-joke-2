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
	if is_open:
		# 设置为打开状态：显示最后一帧，禁用碰撞
		sprite_2d.frame = 4
		collision_shape.disabled = true
	else:
		# 设置为关闭状态：显示第0帧，启用碰撞
		sprite_2d.frame = 0
		collision_shape.disabled = false
	
	print("门初始化完成 - 颜色:", current_color, " 状态:", "开" if is_open else "关")

# 处理开关状态变化信号
func _on_switch_state_changed(color: String, state_str: String):
	# 防止重复处理
	if door_is_processing:
		return
	
	# 颜色不匹配，不处理
	if color != current_color:
		return
	
	# 将字符串状态转换为布尔值
	var target_state: bool = (state_str == "开")
	
	# 如果目标状态与当前状态不符
	if target_state != is_open:
		door_is_processing = true
		
		if target_state:
			# 开门：播放开门动画，禁用碰撞
			animation_player.play("open")
			collision_shape.disabled = true
			print("门正在打开 - 颜色:", color)
		else:
			# 关门：播放关门动画，启用碰撞
			animation_player.play("close")
			collision_shape.disabled = false
			print("门正在关闭 - 颜色:", color)
		
		# 更新门的状态
		is_open = target_state
		
		# 等待动画完成
		await get_tree().create_timer(0.5).timeout
		door_is_processing = false
		print("门状态更新完成 - 颜色:", color, " 状态:", "开" if is_open else "关")
	else:
		print("门状态无需改变 - 颜色:", color, " 当前状态:", "开" if is_open else "关")


func _on_开关_switch_state_changed(color: String, switch_state: String) -> void:
	if(switch_state=="关"):
		push_players_out()
	_on_switch_state_changed(color,switch_state)

# 在门的脚本中添加以下功能
func push_players_out():
	# 获取PushArea内的所有物体
	var overlapping_bodies = $PushArea.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		# 只处理玩家
		if body.is_in_group("player"):
			# 计算推力方向（从门中心指向玩家位置）
			var push_direction = (body.global_position - global_position).normalized()
			# 施加推力
			body.apply_central_impulse(push_direction * 100)  # 100是推力大小
