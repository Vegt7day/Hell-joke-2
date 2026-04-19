extends CharacterBody2D

# 敌人参数
@export var bullet_speed: float = 300.0  # 子弹速度
@export var bullet_scene: PackedScene  # 子弹场景
@export var face_direction: int = 1  # 1=向右, -1=向左
@export var damage: float = 0.05  # 造成的伤害

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var shoot_sound: AudioStreamPlayer = $shoot
@onready var bullet_spawn_point: Marker2D = $Marker2D  # 子弹发射点

@onready var dialogic: Marker2D = $Marker2D2
# 状态变量
var is_shooting: bool = false
var is_dead: bool = false
var can_shoot: bool = true
var shoot_interval: float = 2.0  # 发射间隔（秒），由世界场景控制
var shoot_timer: Timer = Timer.new()  # 射击计时器
var is_attacking_enabled: bool = false  # 是否允许攻击

@onready var stats: Node = $Stats


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
		return
	
	shoot_interval = interval
	is_attacking_enabled = true
	shoot_timer.wait_time = shoot_interval
	shoot_timer.start()
	
	print("教师开始攻击，间隔:", shoot_interval, "秒")

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

func _physics_process(delta):
	# 如果敌人死亡，不做任何处理
	if is_dead:
		return

func shoot():
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
	# 计时器触发，尝试发射
	if not is_dead and can_shoot and is_attacking_enabled:
		shoot()

func take_damage(damage_amount: float):
	# 敌人受到伤害
	print("敌人受到伤害: ", damage_amount)
	
	stats.health-=damage_amount
	print("敌人health: ", stats.health)
	if stats.health <=0:
		die()
	# 这里可以添加受伤动画、扣血逻辑等

func die():
	# 敌人死亡
	is_dead = true
	stop_attacking()
	
	# 这里可以添加死亡动画
	print("敌人死亡")
	
	# 延迟后销毁
	await get_tree().create_timer(1.0).timeout
	queue_free()
