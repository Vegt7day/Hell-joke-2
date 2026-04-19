extends Area2D

# 导出变量，可以在编辑器中设置
@export var dialogue_timeline: String = ""  # Dialogic2时间线名称
@export var one_shot: bool = true  # 是否只触发一次
@export var player_group_name: String = "player"  # 玩家所在的组名
@export var require_input: bool = false  # 是否需要按交互键触发
@export var interaction_key: String = "ui_accept"  # 交互键，默认可在项目设置中设置

# 调试相关导出变量
@export var debug_enabled: bool = true  # 是否启用调试显示
@export var debug_color: Color = Color(1, 0, 0, 0.3)  # 调试颜色，默认半透明红色
@export var debug_collision_width: float = 100.0  # 碰撞区域宽度
@export var debug_collision_height: float = 100.0  # 碰撞区域高度

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var debug_rect: ColorRect = $ColorRect
var in_area: bool = false
var has_triggered: bool = false
var player_node: Node2D = null

func _ready():
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 初始化碰撞形状
	_update_collision_shape()
	
	# 初始化调试显示
	_update_debug_display()
	
	print("对话区域初始化完成 - 时间线:", dialogue_timeline)

func _process(delta):
	# 如果玩家在区域内且需要按交互键
	if in_area and require_input and player_node:
		if Input.is_action_just_pressed(interaction_key):
			_trigger_dialogue()

func _on_body_entered(body: Node2D):
	in_area = true
	player_node = body
	
	# 如果不需要按交互键，直接触发对话
	if not require_input and not (one_shot and has_triggered):
		_trigger_dialogue()

func _on_body_exited(body: Node2D):
	in_area = false
	player_node = null
	

func _trigger_dialogue():
	# 检查是否已经触发过（如果是one_shot）
	if one_shot and has_triggered:
		print("对话区域已触发过，跳过")
		return
	
	# 标记为已触发
	has_triggered = true
	
	# 调用Dialogic2开始对话
	if dialogue_timeline != "":
		print("开始Dialogic2对话，时间线:", dialogue_timeline)
		_start_dialogic_dialogue()
	else:
		print("错误：未指定对话时间线")
	if one_shot:
		collision_shape.disabled = true
		print("对话区域已禁用")

func _start_dialogic_dialogue():
	Dialogic.start_timeline(dialogue_timeline)

func reset_trigger():
	has_triggered = false
	collision_shape.disabled = false
	print("对话区域已重置")

# 外部接口：手动触发对话
func trigger_dialogue_manually():
	_trigger_dialogue()

# 外部接口：更改时间线
func set_dialogue_timeline(new_timeline: String):
	dialogue_timeline = new_timeline
	print("对话时间线已更改为:", new_timeline)

# 外部接口：更新碰撞形状
func _update_collision_shape():
	if collision_shape and collision_shape.shape is RectangleShape2D:
		# 创建或更新矩形碰撞形状
		var shape = collision_shape.shape as RectangleShape2D
		shape.size = Vector2(debug_collision_width, debug_collision_height)
		print("碰撞形状已更新 - 宽度:", debug_collision_width, " 高度:", debug_collision_height)
	elif collision_shape:
		# 如果当前不是矩形形状，创建一个新的矩形形状
		var new_shape = RectangleShape2D.new()
		new_shape.size = Vector2(debug_collision_width, debug_collision_height)
		collision_shape.shape = new_shape
		print("碰撞形状已设置为矩形 - 宽度:", debug_collision_width, " 高度:", debug_collision_height)

# 外部接口：更新调试显示
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
		print("调试显示已更新 - 启用:", debug_enabled, " 大小:", debug_collision_width, "x", debug_collision_height)

# 外部检查器接口：设置碰撞区域宽度
func set_collision_width(new_width: float):
	debug_collision_width = new_width
	_update_collision_shape()
	_update_debug_display()

# 外部检查器接口：设置碰撞区域高度
func set_collision_height(new_height: float):
	debug_collision_height = new_height
	_update_collision_shape()
	_update_debug_display()

# 外部检查器接口：切换调试显示
func toggle_debug_display(enabled: bool):
	debug_enabled = enabled
	_update_debug_display()

# 外部检查器接口：设置调试颜色
func set_debug_color(new_color: Color):
	debug_color = new_color
	_update_debug_display()

# 当导出变量在编辑器中改变时自动更新
func _property_changed(property: String):
	match property:
		"debug_collision_width", "debug_collision_height":
			_update_collision_shape()
			_update_debug_display()
		"debug_enabled", "debug_color":
			_update_debug_display()
