extends Node2D
class_name WorldController

# 场景参数
@export var level_duration: float = 5.0
@export var teacher_intro_timeline: String = "teacher_intro"
@export var student_escape_timeline: String = "student_intro"
@export var door_area_path: NodePath

# 节点引用
@onready var teacher: CharacterBody2D = $teacher
@onready var player: CharacterBody2D = $player
@onready var door_area: Area2D = get_node(door_area_path) if door_area_path else null

# 状态变量
var is_level_active: bool = false
var level_timer: Timer = Timer.new()
var dialogue_started: bool = false
var dialogue_ended: bool = false
var level_completed: bool = false
var level_failed: bool = false
var level_start_time: float = 0.0
var elapsed_time: float = 0.0
var student_escaped: bool = false
var door_interacted: bool = false
var current_dialog: Node = null
var ui_message_display: RichTextLabel = $UI/DialogueBox/RichTextLabel if has_node("UI/DialogueBox/RichTextLabel") else null
var dialogue_box: PanelContainer = $UI/DialogueBox if has_node("UI/DialogueBox") else null
var name_label: Label = $UI/DialogueBox/NameLabel if has_node("UI/DialogueBox/NameLabel") else null

# 角色注册状态
var characters_registered: bool = false
var registry_initialized: bool = false

## 本场景已播放完成的时间线（与存档 completed_timelines 同步）
var _completed_timelines: Array[String] = []


func mark_dialog_timeline_completed(timeline_id: String) -> void:
	if timeline_id.is_empty() or timeline_id in _completed_timelines:
		return
	_completed_timelines.append(timeline_id)


func has_completed_timeline(timeline_id: String) -> bool:
	return timeline_id in _completed_timelines

func _ready():
	print("世界场景控制器加载中...")
	
	# 初始化关卡计时器
	add_child(level_timer)
	level_timer.one_shot = true
	level_timer.wait_time = level_duration
	level_timer.timeout.connect(_on_level_timer_timeout)
	
	# 连接门区域信号
	if door_area and door_area is Area2D:
		door_area.body_entered.connect(_on_door_area_entered)
	
	# 等待一帧确保所有节点初始化完成
	await get_tree().process_frame
	
	# 检查玩家节点是否有效
	if player and player.has_method("disable_action"):
		player.disable_action("move_left")
		player.disable_action("move_right")
		player.disable_action("attack")
		player.enable_action("jump")
	
	# 注册角色到全局注册表
	register_characters_globally()
	
	# 等待注册完成
	await get_tree().process_frame
	
	# 启动对话
	await get_tree().create_timer(0.5).timeout
	start_dialogue()

# 全局注册角色
func register_characters_globally() -> void:
	if characters_registered:
		return
	
	print("=== 开始全局注册角色 ===")
	
	# 等待自动加载节点完全就绪
	await get_tree().process_frame
	
	# 通过自动加载节点路径获取注册器实例
	var registry = get_node_or_null("/root/DialogicRegistry")
	if not registry:
		# 再尝试等待一帧
		await get_tree().process_frame
		registry = get_node_or_null("/root/DialogicRegistry")
		
	if not registry:
		printerr("错误：DialogicRegistry自动加载节点不存在！")
		print("当前根节点下的子节点:")
		for child in get_tree().root.get_children():
			print("  - ", child.name, " (类型: ", child.get_class(), ")")
		return
	
	print("DialogicRegistry找到: ", registry.name)
	
	# 注册学生角色
	var student_marker = get_student_dialog_marker()
	if student_marker and student_marker.is_inside_tree():
		var success = registry.register_character("中学生", student_marker)
		if success:
			print("全局注册学生角色到标记点: ", student_marker.get_path())
	elif player and player.is_inside_tree():
		var success = registry.register_character("中学生", player)
		if success:
			print("全局注册学生角色到玩家节点")
	else:
		print("警告：无法注册学生角色，节点无效")
	
	# 注册教师角色
	var teacher_marker = get_teacher_dialog_marker()
	if teacher_marker and teacher_marker.is_inside_tree():
		var success = registry.register_character("老教师", teacher_marker)
		if success:
			print("全局注册教师角色到标记点: ", teacher_marker.get_path())
	elif teacher and teacher.is_inside_tree():
		var success = registry.register_character("老教师", teacher)
		if success:
			print("全局注册教师角色到教师节点")
	else:
		print("警告：无法注册教师角色，节点无效")
	
	characters_registered = true
	print("=== 全局角色注册完成 ===")
	
	# 测试注册结果
	test_registry(registry)

func test_registry(registry) -> void:
	print("=== 测试注册结果 ===")
	var test_characters = ["中学生", "老教师"]
	
	for char_id in test_characters:
		var node = registry.get_character_node(char_id)
		if node and is_instance_valid(node):
			print("✓ 角色 ", char_id, " 成功注册: ", node.get_path())
		else:
			print("✗ 角色 ", char_id, " 注册失败")
	
	var resource_paths = registry.character_resource_map
	for char_id in resource_paths:
		var path = resource_paths[char_id]
		if ResourceLoader.exists(path):
			print("✓ 角色资源 ", char_id, " 存在: ", path)
		else:
			print("✗ 角色资源 ", char_id, " 不存在: ", path)
	
	print("=== 注册测试完成 ===")

func receive(sig: String):
	if sig == "attack_start":
		start_level()
	if sig == "允许移动":
		if player and player.has_method("enable_action"):
			player.enable_action("move_left")
			player.enable_action("move_right")
	if sig == "禁止移动":
		if player and player.has_method("disable_action"):
			player.disable_action("move_left")
			player.disable_action("move_right")

func _physics_process(delta):
	if is_level_active and not level_completed and not level_failed:
		elapsed_time += delta
		check_player_health()

func start_dialogue():
	if dialogue_started:
		return
	
	dialogue_started = true

	if has_completed_timeline(teacher_intro_timeline):
		_apply_post_intro_dialogue_state()
		return
	
	if not Dialogic:
		printerr("Dialogic不可用，跳过对话")
		_on_intro_dialogue_ended()
		return
	
	# 启动教师介绍时间线
	var dialog = Dialogic.start(teacher_intro_timeline)
	if not dialog:
		printerr("无法创建Dialogic对话")
		_on_intro_dialogue_ended()
		return
	
	add_child(dialog)
	current_dialog = dialog
	
	dialog.connect("event_end", Callable(self, "_on_intro_dialogue_ended"))
	DialogicUtil.autoload().signal_event.connect(receive)
	
	print("对话已启动")


func _apply_post_intro_dialogue_state() -> void:
	dialogue_ended = true
	var dlg := DialogicUtil.autoload()
	if dlg and not dlg.signal_event.is_connected(receive):
		dlg.signal_event.connect(receive)
	start_level()
	show_message("关卡开始！坚持5秒！", 3.0)


func _on_intro_dialogue_ended():
	print("=== 教师介绍对话结束回调被调用 ===")
	
	if dialogue_ended:
		return
	
	dialogue_ended = true
	mark_dialog_timeline_completed(teacher_intro_timeline)
	
	if current_dialog and is_instance_valid(current_dialog):
		current_dialog.queue_free()
		current_dialog = null
	
	start_level()
	show_message("关卡开始！坚持5秒！", 3.0)

func get_teacher_dialog_marker() -> Marker2D:
	if not teacher or not is_instance_valid(teacher):
		return null
	
	for child in teacher.get_children():
		if child is Marker2D:
			print("找到教师对话标记点: ", child.name)
			return child
	
	print("未找到教师对话标记点，使用教师节点")
	return null

func get_student_dialog_marker() -> Marker2D:
	if not player or not is_instance_valid(player):
		return null
	
	for child in player.get_children():
		if child is Marker2D:
			print("找到学生对话标记点: ", child.name)
			return child
	
	print("未找到学生对话标记点，使用玩家节点")
	return null

func start_level():
	print("=== 开始关卡 ===")
	is_level_active = true
	level_start_time = Time.get_ticks_msec() / 1000.0
	
	if teacher and teacher.has_signal("teacher_time_out"):
		teacher.teacher_time_out.connect(_on_teacher_time_out)
		print("已连接教师teacher_time_out信号")
	
	start_teacher_attack()
	level_timer.start()
	print("关卡计时器已启动，持续时间:", level_duration, "秒")

func _on_teacher_time_out():
	print("=== 接收到教师时间结束信号 ===")
	
	if not level_completed and not level_failed and not student_escaped:
		print("教师时间结束！玩家胜利！")
		level_completed = true
		
		if teacher and teacher.has_signal("teacher_time_out") and teacher.teacher_time_out.is_connected(_on_teacher_time_out):
			teacher.teacher_time_out.disconnect(_on_teacher_time_out)
		
		play_ending_dialogue(true)
		end_level()

func start_teacher_attack():
	if teacher and is_instance_valid(teacher):
		if teacher.has_method("start_auto_damage"):
			teacher.start_auto_damage()
			print("教师开始自动扣血")
		
		if teacher.has_method("start_attacking"):
			teacher.start_attacking(2.0)
			print("教师开始攻击，间隔2秒")
		else:
			print("警告：教师节点没有start_attacking方法")
	else:
		print("警告：教师节点未找到或无效")

func _on_level_timer_timeout():
	if not level_completed and not level_failed and not student_escaped:
		print("关卡时间到！玩家坚持了5秒！")
		level_completed = true
		
		if teacher and teacher.has_signal("teacher_time_out") and teacher.teacher_time_out.is_connected(_on_teacher_time_out):
			teacher.teacher_time_out.disconnect(_on_teacher_time_out)
		
		play_ending_dialogue(true)
		end_level()

func check_player_health():
	if player and is_instance_valid(player) and player.has_method("get_health"):
		var health = player.get_health()
		if health <= 0:
			on_player_death()

func on_player_death():
	if not level_failed and not level_completed and not student_escaped:
		print("玩家血量见底！")
		level_failed = true
		
		if teacher and teacher.has_signal("teacher_time_out") and teacher.teacher_time_out.is_connected(_on_teacher_time_out):
			teacher.teacher_time_out.disconnect(_on_teacher_time_out)
		
		play_ending_dialogue(false)
		end_level()

func _on_door_area_entered(body: Node2D):
	if body == player and not door_interacted and not student_escaped:
		print("玩家进入门区域")
		door_interacted = true
		show_message("门关上了！按'J'键射击'开'字开门", 3.0)

func play_ending_dialogue(is_victory: bool):
	print("开始播放结局对话，胜利状态:", is_victory)

	if has_completed_timeline(student_escape_timeline):
		show_level_result()
		return
	
	if not Dialogic:
		printerr("Dialogic不可用，跳过结局对话")
		show_level_result()
		return
	
	var dialog = Dialogic.start(student_escape_timeline)
	if not dialog:
		printerr("无法创建结局对话")
		show_level_result()
		return
	
	add_child(dialog)
	current_dialog = dialog
	dialog.connect("event_end", Callable(self, "_on_ending_dialogue_ended"))
	
	print("结局对话已启动")

func _on_ending_dialogue_ended():
	print("结局对话结束")
	mark_dialog_timeline_completed(student_escape_timeline)
	if current_dialog and is_instance_valid(current_dialog):
		current_dialog.queue_free()
		current_dialog = null
	show_level_result()

func end_level():
	is_level_active = false
	print("关卡结束")

func show_level_result():
	var result_text = ""
	if level_completed:
		result_text = "胜利！坚持了5秒！"
	elif level_failed:
		result_text = "失败！被蚊子叮死了！"
	elif student_escaped:
		result_text = "成功逃跑！"
	
	show_message("关卡结束：" + result_text + "\n\n按R键重新开始关卡", 5.0)

func show_message(message: String, duration: float = 3.0):
	print("提示:", message.replace("\n", " "))
	
	if ui_message_display and is_instance_valid(ui_message_display):
		ui_message_display.text = message
		if name_label and is_instance_valid(name_label):
			name_label.text = "系统提示"
		if dialogue_box and is_instance_valid(dialogue_box):
			dialogue_box.visible = true
		
		if duration > 0:
			await get_tree().create_timer(duration).timeout
			if dialogue_box and is_instance_valid(dialogue_box):
				dialogue_box.visible = false
				ui_message_display.text = ""
				if name_label and is_instance_valid(name_label):
					name_label.text = ""

func to_dict() -> Dictionary:
	var enemies_alive := []
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			var path := get_path_to(node)
			enemies_alive.append(str(path))
	return {
		"enemies_alive": enemies_alive,
		"completed_timelines": _completed_timelines.duplicate(),
	}

func from_dict(dict: Dictionary) -> void:
	if dict.has("enemies_alive"):
		var enemies_alive: Array = dict.enemies_alive
		for node in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(node):
				var path := get_path_to(node)
				if not str(path) in enemies_alive:
					node.queue_free()
	_completed_timelines.clear()
	for x in dict.get("completed_timelines", []):
		_completed_timelines.append(String(x))
		
func update_player(position: Vector2, direction: int = 1) -> void:
	if has_node("player"):
		var player_node = $player
		if is_instance_valid(player_node):
			player_node.global_position = position
			
			if player_node.has_method("set_direction"):
				player_node.set_direction(direction)
			elif player_node.has_property("direction"):
				player_node.direction = direction
			else:
				print("玩家没有方向属性或方法")
		else:
			print("玩家节点无效")
	else:
		print("场景中没有找到玩家节点")
