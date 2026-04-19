extends Node2D

# 场景参数
@export var level_duration: float = 10  # 关卡持续时间（秒）
@export var teacher_path: CharacterBody2D  # 教师节点路径
@export var player_path: CharacterBody2D  # 玩家节点路径
@export var teacher_intro_timeline: String = "teacher_intro"  # 教师介绍时间线
@export var student_escape_timeline: String = "student_intro"  # 学生逃跑时间线
@export var door_area_path: NodePath  # 门区域路径

# 节点引用
@onready var teacher: CharacterBody2D = $teacher
@onready var player: CharacterBody2D = $Student
@onready var door_area: Area2D = get_node(door_area_path) if door_area_path else null

# 状态变量
var is_level_active: bool = false
var level_timer: Timer = Timer.new()  # 关卡计时器
var dialogue_started: bool = false
var dialogue_ended: bool = false
var level_completed: bool = false
var level_failed: bool = false
var level_start_time: float = 0.0
var elapsed_time: float = 0.0
var student_escaped: bool = false
var door_interacted: bool = false
var current_dialog: Node = null
var dialogic_check_timer: Timer = Timer.new()  # Dialogic检查计时器
var ui_message_display: RichTextLabel = $UI/DialogueBox/RichTextLabel if has_node("UI/DialogueBox/RichTextLabel") else null
var dialogue_box: PanelContainer = $UI/DialogueBox if has_node("UI/DialogueBox") else null
var name_label: Label = $UI/DialogueBox/NameLabel if has_node("UI/DialogueBox/NameLabel") else null

func _ready():
	print("世界场景控制器加载中...")
	
	# 初始化关卡计时器
	add_child(level_timer)
	level_timer.one_shot = true
	level_timer.wait_time = level_duration
	level_timer.timeout.connect(_on_level_timer_timeout)
	
	# 初始化Dialogic检查计时器
	add_child(dialogic_check_timer)
	dialogic_check_timer.one_shot = false
	dialogic_check_timer.wait_time = 0.5
	dialogic_check_timer.stop()
	Dialogic.signal_event.connect(receive)
	# 连接门区域信号
	if door_area and door_area is Area2D:
		door_area.body_entered.connect(_on_door_area_entered)
	
	# 延迟后开始对话
	print("等待1秒后开始对话...")
	await get_tree().create_timer(1.0).timeout
	start_dialogue()

func receive(sig:String):
	if sig=="attack_start":
		start_level()

func _physics_process(delta):
	# 更新关卡时间
	if is_level_active and not level_completed and not level_failed:
		elapsed_time += delta
		
		# 检查玩家血量
		check_player_health()


func start_dialogue():
	"""开始对话"""
	if dialogue_started:
		return
	dialogue_started = true
	# 检查Dialogic是否可用
	if Dialogic:
		# 启动教师介绍时间线
		var dialog = Dialogic.start(teacher_intro_timeline)
		# 获取教师和学生的对话标记点
		var teacher_marker = get_teacher_dialog_marker()
		var student_marker = get_student_dialog_marker()
		# 注册角色到对应的Marker2D
		if teacher_marker:
			dialog.register_character("res://assets/Dialogic/老教师.dch", teacher_marker)
		else:
			if teacher:
				dialog.register_character("res://assets/Dialogic/老教师.dch", teacher)
		if student_marker:
			dialog.register_character("res://assets/Dialogic/中学生.dch", student_marker)
		else:
			if player:
				dialog.register_character("res://assets/Dialogic/中学生.dch", player)
		# 将对话添加到场景
		add_child(dialog)
		current_dialog = dialog


func get_teacher_dialog_marker():
	"""获取教师的对话标记点"""
	if teacher:
		# 查找名为Marker2D2的子节点
		var marker = teacher.find_child("Marker2D2")
		if marker:
			print("找到教师对话标记点: Marker2D2")
			return marker
		
		# 查找任何名为Marker2D的子节点
		marker = teacher.find_child("Marker2D")
		if marker:
			print("找到教师对话标记点: Marker2D")
			return marker
		
		# 查找任何类型为Marker2D的子节点
		for child in teacher.get_children():
			if child is Marker2D:
				print("找到教师对话标记点: ", child.name)
				return child
	
	print("未找到教师对话标记点")
	return null

func get_student_dialog_marker():
	"""获取学生的对话标记点"""
	if player:
		# 查找名为Marker2D3的子节点
		var marker = player.find_child("Marker2D3")
		if marker:
			print("找到学生对话标记点: Marker2D3")
			return marker
		
		# 查找名为Marker2D的子节点
		marker = player.find_child("Marker2D")
		if marker:
			print("找到学生对话标记点: Marker2D")
			return marker
		
		# 查找任何类型为Marker2D的子节点
		for child in player.get_children():
			if child is Marker2D:
				print("找到学生对话标记点: ", child.name)
				return child
	
	print("未找到学生对话标记点")
	return null

func _on_intro_dialogue_ended():
	"""教师介绍对话结束回调"""
	print("=== 教师介绍对话结束回调被调用 ===")
	
	# 防止重复调用
	if dialogue_ended:
		return
	
	dialogue_ended = true
	dialogic_check_timer.stop()
	
	# 清理Dialogic对话节点
	if current_dialog and is_instance_valid(current_dialog):
		current_dialog.queue_free()
		current_dialog = null
	
	# 激活关卡
	start_level()
	
	# 通知玩家关卡开始
	show_message("关卡开始！坚持5秒！", 3.0)


func start_level():
	"""开始关卡"""
	print("=== 开始关卡 ===")
	is_level_active = true
	level_start_time = Time.get_ticks_msec() / 1000.0
	start_teacher_attack()
	# 启动关卡计时器
	level_timer.start()
	print("关卡计时器已启动，持续时间:", level_duration, "秒")

func start_teacher_attack():
	"""命令教师开始攻击"""
	if teacher and teacher.has_method("start_attacking"):
		teacher.start_attacking(2.0)  # 2秒攻击间隔
		print("教师开始攻击，间隔2秒")
	else:
		print("警告：教师节点未找到或没有start_attacking方法")
		if teacher:
			print("教师节点类型:", teacher.get_class())
			print("教师节点方法列表:")
			for method in teacher.get_method_list():
				print("  - ", method["name"])

func stop_teacher_attack():
	"""命令教师停止攻击"""
	if teacher and teacher.has_method("stop_attacking"):
		teacher.stop_attacking()
		print("教师停止攻击")
	else:
		print("警告：教师节点未找到或没有stop_attacking方法")

func _on_level_timer_timeout():
	"""关卡计时器超时"""
	if not level_completed and not level_failed and not student_escaped:
		print("关卡时间到！玩家坚持了5秒！")
		level_completed = true
		
		# 停止教师攻击
		stop_teacher_attack()
		
		# 播放胜利对话
		play_ending_dialogue(true)
		
		# 关卡结束
		end_level()

func check_player_health():
	"""检查玩家血量"""
	if player and player.has_method("get_health"):
		var health = player.get_health()
		if health <= 0:
			on_player_death()

func on_player_death():
	"""玩家死亡"""
	if not level_failed and not level_completed and not student_escaped:
		print("玩家血量见底！")
		level_failed = true
		
		# 停止教师攻击
		stop_teacher_attack()
		
		# 播放失败对话
		play_ending_dialogue(false)
		
		# 关卡结束
		end_level()

func on_player_escape():
	"""玩家触发逃跑"""
	if not level_failed and not level_completed and not student_escaped:
		student_escaped = true
		print("玩家触发逃跑！")
		
		# 停止教师攻击
		stop_teacher_attack()
		
		# 播放逃跑对话
		play_escape_dialogue()

func _on_door_area_entered(body: Node2D):
	"""玩家进入门区域"""
	if body == player and not door_interacted and not student_escaped:
		print("玩家进入门区域")
		door_interacted = true
		
		# 显示门提示
		show_message("门关上了！按'J'键射击'开'字开门", 3.0)

func on_door_unlocked():
	"""门被打开"""
	print("门被打开了！")
	
	# 触发逃跑
	on_player_escape()

func play_ending_dialogue(is_victory: bool):
	"""播放结局对话"""
	var dialog = Dialogic.start(student_escape_timeline)
	var teacher_marker = get_teacher_dialog_marker()
	var student_marker = get_student_dialog_marker()
	if teacher_marker:
		dialog.register_character("res://assets/Dialogic/老教师.dch", teacher_marker)
	else:
		if teacher:
			dialog.register_character("res://assets/Dialogic/老教师.dch", teacher)
	if student_marker:
		dialog.register_character("res://assets/Dialogic/中学生.dch", student_marker)
	else:
		if player:
			dialog.register_character("res://assets/Dialogic/中学生.dch", player)


func play_escape_dialogue():
	"""播放逃跑对话"""
	var dialogue_text = "中学生: 老师，我突然肚子疼，我去上个厕所\n\n老教师: 又想逃跑？门都没有！\n\n中学生: 可恶，门关上了，不过虽然我没有枪，但是我带了笔\n\n提示: 按'J'键射击，射击'开'字有意想不到的效果..."
	show_message(dialogue_text, 6.0)

func end_level():
	"""关卡结束"""
	is_level_active = false
	
	# 显示关卡结果
	show_level_result()

func show_level_result():
	"""显示关卡结果"""
	var result_text = ""
	if level_completed:
		result_text = "胜利！坚持了5秒！"
	elif level_failed:
		result_text = "失败！被蚊子叮死了！"
	elif student_escaped:
		result_text = "成功逃跑！"
	
	show_message("关卡结束：" + result_text + "\n\n按R键重新开始关卡", 5.0)

func show_message(message: String, duration: float = 3.0):
	"""显示消息给玩家"""
	print("提示:", message.replace("\n", " "))
	
	# 如果有UI消息显示组件，显示消息
	if ui_message_display:
		ui_message_display.text = message
		if name_label:
			name_label.text = "系统提示"
		if dialogue_box:
			dialogue_box.visible = true
		
		# 指定时间后隐藏消息
		if duration > 0:
			await get_tree().create_timer(duration).timeout
			if dialogue_box and is_instance_valid(dialogue_box):
				dialogue_box.visible = false
				ui_message_display.text = ""
				if name_label:
					name_label.text = ""

func get_remaining_time() -> float:
	"""获取剩余时间"""
	return max(0, level_duration - elapsed_time)

func get_level_status() -> Dictionary:
	"""获取关卡状态"""
	return {
		"active": is_level_active,
		"completed": level_completed,
		"failed": level_failed,
		"escaped": student_escaped,
		"elapsed_time": elapsed_time,
		"remaining_time": get_remaining_time()
	}
