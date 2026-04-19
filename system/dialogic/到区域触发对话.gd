extends Area2D

# 导出变量，可以在编辑器中设置
@export var dialogue_timeline: String = ""  # Dialogic2时间线名称
@export var one_shot: bool = true  # 是否只触发一次
@export var require_input: bool = false  # 是否需要按交互键触发
@export var interaction_key: String = "ui_accept"  # 交互键，默认可在项目设置中设置

# 调试相关导出变量
@export var debug_enabled: bool = true  # 是否启用调试显示
@export var debug_color: Color = Color(1, 0, 0, 0.3)  # 调试颜色，默认半透明红色
@export var debug_collision_width: float = 100.0  # 碰撞区域宽度
@export var debug_collision_height: float = 100.0  # 碰撞区域高度

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var debug_rect: ColorRect = $ColorRect

# 状态变量
var in_area: bool = false
var has_triggered: bool = false
var player_node: Node2D = null
var is_dialog_active: bool = false
var dialog_node: Node = null
var dialog_cooldown: float = 1.0
var dialog_start_time: float = 0.0

func _ready():
	# 连接信号
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if body_exited.is_connected(_on_body_exited):
		body_exited.disconnect(_on_body_exited)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 初始化碰撞形状
	_update_collision_shape()
	
	# 初始化调试显示
	_update_debug_display()

func _process(delta):
	# 处理冷却时间
	if is_dialog_active:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - dialog_start_time > dialog_cooldown:
			is_dialog_active = false

	if in_area and require_input and player_node:
		if Input.is_action_just_pressed(interaction_key):
			_trigger_dialogue()

func _on_body_entered(body: Node2D):
	# 检查是否是玩家
	if _is_player(body):
		in_area = true
		player_node = body
		
		# 如果不需要按交互键，直接触发对话
		if not require_input and not (one_shot and has_triggered) and not is_dialog_active:
			_trigger_dialogue()

func _on_body_exited(body: Node2D):
	if _is_player(body):
		in_area = false
		player_node = null

func _is_player(body: Node) -> bool:
	"""检查是否是玩家"""
	# 根据您的玩家节点类型进行检查
	# 这里假设玩家是CharacterBody2D类型，您可以根据实际情况调整
	return body is CharacterBody2D

func _trigger_dialogue():
	# 检查是否在冷却时间内
	if is_dialog_active:
		return
	
	# 检查是否已经触发过（如果是one_shot）
	if one_shot and has_triggered:
		return
	
	# 检查时间线是否为空
	if dialogue_timeline == "" or dialogue_timeline.is_empty():
		return
	
	# 检查文件是否存在
	if not ResourceLoader.exists(dialogue_timeline):
		return
	
	# 标记状态
	is_dialog_active = true
	dialog_start_time = Time.get_ticks_msec() / 1000.0
	has_triggered = true
	
	# 开始对话
	_start_dialogic_dialogue()
	
	# 如果是one_shot，禁用碰撞
	if one_shot:
		collision_shape.disabled = true

func _start_dialogic_dialogue():
	"""启动Dialogic2对话"""
	# 检查时间线是否存在
	var timeline_resource = load(dialogue_timeline)
	if not timeline_resource:
		is_dialog_active = false
		return
	
	# 清理之前的对话节点
	if dialog_node and is_instance_valid(dialog_node):
		dialog_node.queue_free()
		dialog_node = null

	var dialog = Dialogic.start(dialogue_timeline)
	
	# 检查dialog是否有效
	if not dialog:
		is_dialog_active = false
		return
	
	# 将对话节点添加到场景
	get_tree().current_scene.add_child(dialog)
	dialog_node = dialog
	
	# 连接对话结束信号
	if dialog.has_signal("timeline_ended"):
		dialog.timeline_ended.connect(_on_dialog_ended)
	elif dialog.has_signal("event_end"):
		dialog.event_end.connect(_on_dialog_ended)
	
	# 连接信号事件
	if dialog.has_signal("signal_event"):
		dialog.signal_event.connect(_on_dialog_signal)

func _on_dialog_ended():
	"""对话结束回调"""
	is_dialog_active = false
	
	# 清理对话节点
	if dialog_node and is_instance_valid(dialog_node):
		dialog_node.queue_free()
		dialog_node = null

func _on_dialog_signal(signal_name: String):
	"""Dialogic信号回调"""
	# 这里可以处理Dialogic发出的特定信号
	pass

func reset_trigger():
	"""重置触发状态"""
	has_triggered = false
	collision_shape.disabled = false
	is_dialog_active = false

# 外部接口：手动触发对话
func trigger_dialogue_manually():
	"""手动触发对话"""
	_trigger_dialogue()

# 外部接口：更改时间线
func set_dialogue_timeline(new_timeline: String):
	"""设置对话时间线"""
	dialogue_timeline = new_timeline

# 更新碰撞形状
func _update_collision_shape():
	if collision_shape and collision_shape.shape is RectangleShape2D:
		# 创建或更新矩形碰撞形状
		var shape = collision_shape.shape as RectangleShape2D
		shape.size = Vector2(debug_collision_width, debug_collision_height)
	elif collision_shape:
		# 如果当前不是矩形形状，创建一个新的矩形形状
		var new_shape = RectangleShape2D.new()
		new_shape.size = Vector2(debug_collision_width, debug_collision_height)
		collision_shape.shape = new_shape

# 更新调试显示
func _update_debug_display():
	if debug_rect:
		# 设置ColorRect的大小和位置
		debug_rect.size = Vector2(debug_collision_width, debug_collision_height)
		
		# 将ColorRect居中（因为ColorRect的锚点是左上角）
		debug_rect.position = Vector2(-debug_collision_width/2, -debug_collision_height/2)
		
		# 设置颜色
		if debug_enabled:
			debug_rect.color = debug_color
		else:
			# 设置为完全透明
			debug_rect.color = Color(0, 0, 0, 0)
		
		debug_rect.visible = true
