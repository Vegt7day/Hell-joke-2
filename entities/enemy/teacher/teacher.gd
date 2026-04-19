extends CharacterBody2D

# 敌人参数
@export var bullet_speed: float = 300.0  # 子弹速度
@export var bullet_scene: PackedScene  # 子弹场景
@export var face_direction: int = 1  # 1=向右, -1=向左
@export var damage: float = 0.05  # 造成的伤害

# 信号定义
signal teacher_time_out  # 教师时间结束信号
signal health_depleted  # 血量耗尽信号
signal student_intro_triggered  # 学生对话触发信号

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var shoot_sound: AudioStreamPlayer = $shoot
@onready var bullet_spawn_point: Marker2D = $Marker2D  # 子弹发射点
@onready var dialogic: Marker2D = $Marker2D2

# Stats节点引用
@onready var teacher_stats: Stats = $stats

@onready var health_bar: Node2D = $CanvasLayer/boss_health_bar

# 状态变量
var is_shooting: bool = false
var is_dead: bool = false
var can_shoot: bool = true
var shoot_interval: float = 2.0  # 发射间隔（秒），由世界场景控制
var shoot_timer: Timer = Timer.new()  # 射击计时器
var is_attacking_enabled: bool = false  # 是否允许攻击

# 自动扣血相关变量
var is_auto_damage_enabled: bool = false  # 是否启用自动扣血
var auto_damage_amount: float = 1.0  # 每秒自动扣血量
var auto_damage_interval: float = 1.0  # 自动扣血间隔（秒）
var auto_damage_accumulator: float = 0.0  # 时间累积器
var time_out_signal_sent: bool = false  # 防止重复发送信号
var student_intro_triggered_flag: bool = false  # 学生对话是否已触发

func _ready():
	# 检查是否已设置发射点
	if not bullet_spawn_point:
		bullet_spawn_point = find_child("Marker2D")
		if not bullet_spawn_point:
			create_default_spawn_point()

	# 初始化射击计时器
	add_child(shoot_timer)
	shoot_timer.one_shot = false
	shoot_timer.wait_time = shoot_interval
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	
	# 初始朝向设置
	if face_direction == -1:
		sprite.flip_h = true
	
	# 播放闲置动画
	animation_player.play("idle")
	
	# 确保Stats节点存在
	if not teacher_stats:
		push_error("教师Stats节点未找到！")
		return
	
	# 确保血条节点存在
	if not health_bar:
		push_error("血条节点未找到！路径: CanvasLayer/boss_health_bar")
		return
	
	print("教师Stats节点初始化成功，当前生命值:", teacher_stats.health)
	
	# 设置血条节点的stats引用
	if health_bar.has_method("set_stats"):
		health_bar.set_stats(teacher_stats)
		print("已设置血条节点的stats引用")
	else:
		print("警告：血条节点没有set_stats方法")
	
	# 初始化时隐藏血条
	if health_bar.has_method("hide_health_bar"):
		health_bar.hide_health_bar()
		print("初始化时隐藏血条")
	else:
		print("警告：血条节点没有hide_health_bar方法")

func create_default_spawn_point():
	"""创建默认的子弹发射点"""
	var marker = Marker2D.new()
	marker.name = "Marker2D"
	
	# 根据朝向设置位置
	if face_direction == 1:  # 向右
		marker.position = Vector2(50, -20)  # 向右偏移
	else:  # 向左
		marker.position = Vector2(-50, -20)  # 向左偏移
	
	add_child(marker)
	marker.owner = get_tree().edited_scene_root
	bullet_spawn_point = marker

# 公开方法：开始攻击
func start_attacking(interval: float = 2.0):
	"""开始攻击"""
	if is_dead or not bullet_scene:
		print("教师无法开始攻击：已死亡或无子弹场景")
		return
	
	print("教师开始攻击，间隔:", interval, "秒")
	shoot_interval = interval
	is_attacking_enabled = true
	shoot_timer.wait_time = shoot_interval
	shoot_timer.start()
	
	# 攻击中显示血条
	if health_bar and health_bar.has_method("show_health_bar"):
		health_bar.show_health_bar()
		print("攻击中显示血条")
	
	# 开始自动扣血
	start_auto_damage()

# 公开方法：停止攻击
func stop_attacking():
	"""停止攻击"""
	is_attacking_enabled = false
	shoot_timer.stop()
	
	# 返回闲置动画
	if not is_dead:
		animation_player.play("idle")
	
	print("教师停止攻击")

# 公开方法：设置攻击间隔
func set_shoot_interval(interval: float):
	"""设置攻击间隔"""
	shoot_interval = interval
	if is_attacking_enabled:
		shoot_timer.wait_time = shoot_interval
		shoot_timer.start()  # 重新启动计时器以应用新间隔

# 公开方法：开始自动扣血
func start_auto_damage():
	"""开始每秒自动扣血"""
	if is_dead:
		return
	
	is_auto_damage_enabled = true
	auto_damage_accumulator = 0.0
	time_out_signal_sent = false
	print("教师开始自动扣血，每秒扣除", auto_damage_amount, "点生命值")

# 公开方法：停止自动扣血
func stop_auto_damage():
	"""停止自动扣血"""
	is_auto_damage_enabled = false
	print("教师停止自动扣血")

func _process(delta):
	"""处理自动扣血逻辑"""
	if is_auto_damage_enabled and not is_dead and teacher_stats and teacher_stats.health > 0:
		auto_damage_accumulator += delta
		
		# 当时间累积达到间隔时间时，扣除血量
		if auto_damage_accumulator >= auto_damage_interval:
			# 计算应该扣除的次数（处理帧率过低的情况）
			var damage_count = int(auto_damage_accumulator / auto_damage_interval)
			
			# 扣除血量
			for i in range(damage_count):
				apply_auto_damage(auto_damage_amount)
			
			# 减去已扣除的时间
			auto_damage_accumulator -= damage_count * auto_damage_interval

func _physics_process(delta):
	# 如果敌人死亡，不做任何处理
	if is_dead:
		return

func shoot():
	"""发射子弹"""
	if not can_shoot or is_dead or not bullet_scene or not bullet_spawn_point or not is_attacking_enabled:
		return
	
	# 进入射击状态
	is_shooting = true
	can_shoot = false
	
	# 播放射击动画
	animation_player.play("shoot")
	
	# 播放射击音效
	if shoot_sound and shoot_sound.stream:
		shoot_sound.play()
	
	# 延迟发射子弹（与动画同步）
	await get_tree().create_timer(0.3).timeout
	
	# 创建子弹实例
	var bullet = bullet_scene.instantiate()
	
	# 使用Marker2D的位置作为发射点
	var spawn_position = bullet_spawn_point.global_position
	
	# 设置子弹方向和速度
	bullet.initialize(spawn_position, face_direction < 0, bullet_speed, damage)
	
	# 将子弹添加到场景中
	get_parent().add_child(bullet)
	
	# 等待动画完成
	await get_tree().create_timer(0.5).timeout
	
	# 恢复射击能力
	can_shoot = true
	
	# 重置状态
	is_shooting = false
	
	# 返回闲置动画
	if not is_dead and is_attacking_enabled:
		animation_player.play("idle")

func _on_shoot_timer_timeout():
	"""射击计时器超时"""
	if not is_dead and can_shoot and is_attacking_enabled:
		shoot()

func take_damage(damage_amount: float):
	"""受到伤害"""
	print("敌人受到子弹伤害: ", damage_amount)
	
	# 应用伤害
	apply_damage(damage_amount)

func apply_damage(damage_amount: float):
	"""应用伤害"""
	if not teacher_stats:
		return
	
	# 直接修改血量，这会触发Stats节点的setter，从而发出health_changed信号
	teacher_stats.health -= damage_amount
	print("敌人生命值: ", teacher_stats.health)
	
	# 检查血量是否归零
	check_health_zero()

func apply_auto_damage(damage_amount: float):
	"""应用自动扣血"""
	if not teacher_stats:
		return
	
	# 直接修改血量，这会触发Stats节点的setter，从而发出health_changed信号
	teacher_stats.health -= damage_amount
	print("自动扣血: ", damage_amount, " 点，剩余生命值: ", teacher_stats.health)
	
	# 检查血量是否归零
	check_health_zero()

func check_health_zero():
	"""检查血量是否归零"""
	if teacher_stats.health <= 0 and not time_out_signal_sent:
		time_out_signal_sent = true
		health_depleted.emit()
		teacher_time_out.emit()
		student_intro_triggered.emit()  # 触发学生对话信号
		student_intro_triggered_flag = true
		print("教师血量归零，发出teacher_time_out、health_depleted和student_intro_triggered信号")
		
		# 血量归零时本体不会死亡，只隐藏血条
		_on_student_intro_triggered()

func _on_student_intro_triggered():
	"""处理student_intro触发"""
	print("student_intro触发，隐藏血条但不停止攻击")
	
	# 隐藏血条
	if health_bar and health_bar.has_method("hide_health_bar"):
		health_bar.hide_health_bar()
		print("student_intro触发，已隐藏血条")
	
	# 不停止攻击，只停止自动扣血
	stop_auto_damage()
	
	# 注意：这里不调用stop_attacking()，所以攻击会继续

func die():
	"""敌人死亡"""
	is_dead = true
	stop_attacking()
	stop_auto_damage()
	
	# 这里可以添加死亡动画
	print("敌人死亡")
	
	# 延迟后销毁
	await get_tree().create_timer(1.0).timeout
	queue_free()
