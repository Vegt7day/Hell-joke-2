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
@onready var trigger_sound: AudioStreamPlayer = $TriggerSound

var current_color: String
var _channel_id: StringName = StringName()
var is_processing: bool = false  # 防止连续触发

func _ready():
	# 初始化颜色
	current_color = initial_color
	_channel_id = MechanismChannelIds.color_to_channel_id(current_color)
	if _channel_id.is_empty():
		push_warning("开关: 未知颜色 %s，无法映射 channel_id" % current_color)
	
	# 初始化开关状态
	_apply_switch_visual(is_on)
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
	if not _channel_id.is_empty():
		MechanismLinkBus.channel_state_changed.connect(_on_channel_state_changed)
		call_deferred("_deferred_sync_initial_from_bus")
	print("开关初始化完成 - 颜色:", current_color, " 状态:", "开" if is_on else "关")


func _exit_tree() -> void:
	if MechanismLinkBus.channel_state_changed.is_connected(_on_channel_state_changed):
		MechanismLinkBus.channel_state_changed.disconnect(_on_channel_state_changed)


func _deferred_sync_initial_from_bus() -> void:
	if not is_inside_tree() or _channel_id.is_empty():
		return
	if not MechanismLinkBus.has_published_state(_channel_id):
		return
	apply_switch_bus_state(MechanismLinkBus.get_last_is_open(_channel_id), false)


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
	if _channel_id.is_empty():
		push_warning("开关状态发送失败：未知颜色 %s，无法映射 channel_id" % current_color)
		return
	# 同色开关共用一个通道状态：发布目标状态，由总线回调驱动所有同色开关（含自身）统一播放/同步。
	MechanismLinkBus.publish_channel_state(_channel_id, not is_on)


func _on_channel_state_changed(ch: StringName, target_on: bool) -> void:
	if ch != _channel_id:
		return
	apply_switch_bus_state(target_on, true)


func apply_switch_bus_state(target_on: bool, play_anim: bool = true) -> void:
	if is_processing:
		return
	if target_on == is_on:
		return
	if not play_anim:
		is_on = target_on
		_apply_switch_visual(target_on)
		_emit_state_change()
		return
	is_processing = true
	_play_trigger_sound()
	if target_on:
		animation_player.play("open")
	else:
		animation_player.play("close")
	is_on = target_on
	await get_tree().create_timer(0.4).timeout
	_apply_switch_visual(target_on)
	_emit_state_change()
	is_processing = false


func _apply_switch_visual(target_on: bool) -> void:
	if target_on:
		sprite_2d.frame = 0  # 开的状态
	else:
		sprite_2d.frame = 3  # 关的状态


func _emit_state_change() -> void:
	var state_str = "开" if is_on else "关"
	emit_signal("switch_state_changed", current_color, state_str)
	print("开关状态已发送 - 颜色:", current_color, " 状态:", state_str)


func _play_trigger_sound() -> void:
	if trigger_sound == null or trigger_sound.stream == null:
		return
	trigger_sound.play()
