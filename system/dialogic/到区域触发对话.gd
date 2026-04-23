extends Area2D

@export var dialogue_timeline: String = ""
@export var one_shot: bool = true
@export var require_input: bool = false
@export var interaction_key: String = "ui_accept"

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 状态变量
var in_area: bool = false
var has_triggered: bool = false
var player_node: Node2D = null
var is_dialog_active: bool = false
var dialog_node: Node = null
var dialog_cooldown: float = 1.0
var dialog_start_time: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta):
	if is_dialog_active:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - dialog_start_time > dialog_cooldown:
			is_dialog_active = false

	if in_area and require_input and player_node:
		if Input.is_action_just_pressed(interaction_key):
			_trigger_dialogue()

func _on_body_entered(body: Node2D):
	if _is_player(body):
		in_area = true
		player_node = body
		print("玩家进入触发器区域: ", body.name, " (触发器: ", name, ")")
		
		if not require_input and not (one_shot and has_triggered) and not is_dialog_active:
			_trigger_dialogue()

func _on_body_exited(body: Node2D):
	if _is_player(body):
		in_area = false
		player_node = null
		print("玩家离开触发器区域: ", body.name, " (触发器: ", name, ")")

func _is_player(body: Node) -> bool:
	return body is CharacterBody2D

func _trigger_dialogue():
	if is_dialog_active:
		return
	
	if one_shot and has_triggered:
		return
	
	if dialogue_timeline == "" or dialogue_timeline.is_empty():
		return
	
	if not ResourceLoader.exists(dialogue_timeline):
		print("时间线文件不存在: ", dialogue_timeline)
		return
	
	is_dialog_active = true
	dialog_start_time = Time.get_ticks_msec() / 1000.0
	has_triggered = true
	
	print("触发器开始触发对话: ", name, " (时间线: ", dialogue_timeline, ")")
	
	_start_dialogic_dialogue()
	
	if one_shot:
		collision_shape.disabled = true

func _start_dialogic_dialogue():
	if not Dialogic:
		is_dialog_active = false
		return
	
	var timeline_resource = load(dialogue_timeline)
	if not timeline_resource:
		is_dialog_active = false
		return
	
	if dialog_node and is_instance_valid(dialog_node):
		dialog_node.queue_free()
		dialog_node = null

	var dialog = Dialogic.start(dialogue_timeline)
	if not dialog:
		is_dialog_active = false
		return
	
	# 注意：这里不再需要注册角色，因为角色已经在全局注册过了
	# Dialogic布局层会自动从全局注册表获取已注册的角色
	
	get_tree().current_scene.add_child(dialog)
	dialog_node = dialog
	
	# 连接对话结束信号
	if dialog.has_signal("timeline_ended"):
		dialog.timeline_ended.connect(_on_dialog_ended)
	elif dialog.has_signal("event_end"):
		dialog.event_end.connect(_on_dialog_ended)
	
	print("对话已启动: ", dialogue_timeline)

func _on_dialog_ended():
	print("对话结束: ", dialogue_timeline)
	is_dialog_active = false
	
	if dialog_node and is_instance_valid(dialog_node):
		dialog_node.queue_free()
		dialog_node = null

func reset_trigger():
	has_triggered = false
	collision_shape.disabled = false
	is_dialog_active = false
	print("触发器已重置: ", name)
