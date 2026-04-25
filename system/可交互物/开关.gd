extends StaticBody2D

const MechanismChannelIds = preload("res://system/mechanisms/mechanism_channel_ids.gd")

# 信号定义
signal switch_state_changed(color: String, switch_state: String)

# 导出变量，可以在编辑器或外部设置
@export var initial_color: String = "红"
@export var is_on: bool = false
@export var bullet_trigger_enabled: bool = true  # 是否允许子弹触发
@export var damage_threshold: float = 1.0  # 触发开关所需的最小伤害值

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

var current_color: String
var is_processing: bool = false  # 防止连续触发

func _ready():
	# 初始化颜色
	current_color = initial_color
	
	# 初始化开关状态
	if is_on:
		sprite_2d.frame = 0  # 开的状态
	else:
		sprite_2d.frame = 3  # 关的状态
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
			color_rect.color = Color.WHITE  # 默认白色
			print("警告：未知颜色", current_color, "，使用默认白色")
	print("开关初始化完成 - 颜色:", current_color, " 状态:", "开" if is_on else "关")

func take_damage(damage_amount: float, attacker = null):
	# 检查是否允许子弹触发
	if not bullet_trigger_enabled:
		return
	
	# 检查伤害是否达到阈值
	if damage_amount < damage_threshold:
		print("伤害", damage_amount, "低于阈值", damage_threshold, "，不触发开关")
		return
	
	# 防止重复处理
	if is_processing:
		return
	
	print("被攻击触发机关，伤害:", damage_amount)
	
	# 触发开关状态变化
	_trigger_switch()

func _trigger_switch():
	is_processing = true
	
	# 切换开关状态
	if is_on:
		animation_player.play("close")
		is_on = false
	else:
		animation_player.play("open")
		is_on = true
	
	# 延迟一段时间后发送信号
	await get_tree().create_timer(0.4).timeout
	_emit_state_change()
	is_processing = false

func _emit_state_change():
	var state_str = "开" if is_on else "关"
	emit_signal("switch_state_changed", current_color, state_str)
	var channel_id := MechanismChannelIds.color_to_channel_id(current_color)
	if channel_id.is_empty():
		push_warning("开关状态发送失败：未知颜色 %s，无法映射 channel_id" % current_color)
		return
	MechanismLinkBus.publish_channel_state(channel_id, is_on)
	print("开关状态已发送 - 颜色:", current_color, " 状态:", state_str)
