extends Area2D

# 导出变量，可以在编辑器中设置
@export var dialogue_timeline: String = "res://assets/tip_开关与门1.dtl"  # Dialogic2时间线名称
@export var one_shot: bool = true  # 是否只触发一次
@export var player_group_name: String = "player"  # 玩家所在的组名
@export var require_input: bool = false  # 是否需要按交互键触发
@export var interaction_key: String = "ui_accept"  # 交互键，默认可在项目设置中设置

# 节点引用
@onready var interaction_indicator: Sprite2D = $InteractionIndicator
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_player_in_area: bool = false
var has_triggered: bool = false
var player_node: Node2D = null

func _ready():
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 隐藏交互指示器（如果有的话）
	if interaction_indicator:
		interaction_indicator.visible = false
	
	print("对话区域初始化完成 - 时间线:", dialogue_timeline)

func _process(delta):
	# 如果玩家在区域内且需要按交互键
	if is_player_in_area and require_input and player_node:
		if Input.is_action_just_pressed(interaction_key):
			_trigger_dialogue()

func _on_body_entered(body: Node2D):
	# 检查进入的物体是否是玩家
	if body.is_in_group(player_group_name):
		print("玩家进入对话区域:", body.name)
		is_player_in_area = true
		player_node = body
		
		# 显示交互指示器
		if interaction_indicator:
			interaction_indicator.visible = true
		
		# 如果不需要按交互键，直接触发对话
		if not require_input and not (one_shot and has_triggered):
			_trigger_dialogue()

func _on_body_exited(body: Node2D):
	# 检查离开的物体是否是玩家
	if body.is_in_group(player_group_name):
		print("玩家离开对话区域:", body.name)
		is_player_in_area = false
		player_node = null
		
		# 隐藏交互指示器
		if interaction_indicator:
			interaction_indicator.visible = false

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
		# Dialogic2的调用方式
		# Dialogic.start(dialogue_timeline)
		
		# 实际调用Dialogic2的代码（根据您的Dialogic2版本调整）
		_start_dialogic_dialogue()
	else:
		print("错误：未指定对话时间线")
		
	# 如果是one_shot，禁用区域
	if one_shot:
		collision_shape.disabled = true
		print("对话区域已禁用")

func _start_dialogic_dialogue():
	# 这是调用Dialogic2的实际代码
	# 根据您的Dialogic2版本，可能需要不同的调用方式
	
	# 方法1: 如果Dialogic2已安装并启用
	# var dialog = Dialogic.start(dialogue_timeline)
	# add_child(dialog)
	
	# 方法2: 如果Dialogic2有全局单例
	# Dialogic.start_timeline(dialogue_timeline)
	
	# 方法3: 通过资源路径
	# var timeline_resource = load("res://dialogic/timelines/" + dialogue_timeline + ".dtl")
	# Dialogic.start_timeline_resource(timeline_resource)
	
	# 由于Dialogic2的具体实现可能不同，这里使用通用方法
	print("调用Dialogic2开始对话:", dialogue_timeline)
	
	# 实际代码示例（根据您的设置调整）：
	# 确保在项目中已启用Dialogic2插件
	# 取消注释下面的代码并根据需要修改
	
	# if Dialogic.has_resource(dialogue_timeline):
	#     var dialog_node = Dialogic.start(dialogue_timeline)
	#     get_tree().current_scene.add_child(dialog_node)
	# else:
	#     print("错误：找不到Dialogic2时间线 - ", dialogue_timeline)

# 外部接口：重置触发状态
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
