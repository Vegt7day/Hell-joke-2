extends CharacterBody2D

# 子弹参数
@export var speed: float = 300.0
@export var facing_right: bool = true
@export var damage: float = 0.05
@export var lifetime: float = 5.0
@export var stick_to_target: bool = true  # 是否附着在目标上
@export var stick_duration: float = 2  # 附着持续时间

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var shoot_sound: AudioStreamPlayer = $shooting
@onready var disappear_sound: AudioStreamPlayer = $disappear
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = Timer.new()
@onready var stick_timer: Timer = Timer.new()

# 状态变量
var direction: Vector2 = Vector2.RIGHT
var is_active: bool = true
var has_collided: bool = false
var is_destroyed: bool = false
var current_speed: float = 0.0
var is_sticking: bool = false
var stick_target: Node2D = null
var relative_offset: Vector2 = Vector2.ZERO
var original_parent: Node

# 初始化参数
var initial_position: Vector2 = Vector2.ZERO
var initial_direction: bool = true
var initial_speed: float = 300.0
var initial_damage: float = 0.05
var needs_initialization: bool = false

func _ready():
	# 记录原始父节点
	original_parent = get_parent()
	
	# 添加存活时间计时器
	add_child(lifetime_timer)
	lifetime_timer.one_shot = true
	lifetime_timer.wait_time = lifetime
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	
	# 添加附着时间计时器
	add_child(stick_timer)
	stick_timer.one_shot = true
	stick_timer.wait_time = stick_duration
	stick_timer.timeout.connect(_on_stick_timer_timeout)
	
	# 如果有需要初始化的参数，先应用它们
	if needs_initialization:
		apply_initialization()
	
	# 设置初始方向和精灵朝向
	if not facing_right:
		direction = Vector2.LEFT
		$Sprite2D.flip_h = false
	else:
		direction = Vector2.RIGHT
		$Sprite2D.flip_h = true
	
	# 设置速度
	current_speed = speed
	
	# 播放发射动画
	animation_player.play("shooting")
	
	# 播放发射音效
	if shoot_sound and shoot_sound.stream:
		shoot_sound.play()
	
	# 启动存活计时器
	lifetime_timer.start()


func take_damage(damage_amount: float):
	destroy()

func _physics_process(delta):
	# 如果子弹不活跃或已销毁，不进行物理处理
	if not is_active or is_destroyed:
		return
	
	# 如果子弹附着在目标上，更新位置
	if is_sticking and stick_target and is_instance_valid(stick_target):
		# 更新位置，保持相对偏移
		global_position = stick_target.global_position + relative_offset
			# 对目标造成伤害
		if stick_target.has_method("take_damage"):
				stick_target.take_damage(damage)
		
		
		return
	
	# 如果已经发生碰撞但未附着，不移动
	if has_collided and not is_sticking:
		return
	
	# 设置速度
	velocity = direction * current_speed
	
	# 移动并检测碰撞
	var collision = move_and_collide(velocity * delta)
	
	# 如果发生碰撞
	if collision:
		handle_collision(collision)

func initialize(spawn_position: Vector2, shoot_direction: bool, bullet_speed: float = 300.0, 
				bullet_damage: float = 0.05):
	"""
	初始化子弹
	"""
	# 保存初始化参数
	initial_position = spawn_position
	initial_direction = shoot_direction
	initial_speed = bullet_speed
	initial_damage = bullet_damage
	needs_initialization = true
	
	# 如果已经进入场景树，立即应用初始化
	if is_inside_tree():
		apply_initialization()

func apply_initialization():
	"""应用初始化参数"""
	global_position = initial_position
	facing_right = initial_direction
	speed = initial_speed
	current_speed = initial_speed
	damage = initial_damage
	
	# 设置方向和精灵朝向
	if not facing_right:
		direction = Vector2.LEFT
		$Sprite2D.flip_h = false
	else:
		direction = Vector2.RIGHT
		$Sprite2D.flip_h = true
	
	needs_initialization = false

func _enter_tree():
	# 当节点进入场景树时，如果有需要初始化的参数，应用它们
	if needs_initialization:
		apply_initialization()

func handle_collision(collision: KinematicCollision2D):
	# 如果已经在销毁过程中，直接返回
	if is_destroyed:
		return
	
	# 标记已发生碰撞
	has_collided = true
	
	# 停止移动
	velocity = Vector2.ZERO
	
	# 获取碰撞体
	var collider = collision.get_collider()
	
	# 如果开启附着功能且碰撞体有效
	if stick_to_target and collider and is_instance_valid(collider):
		# 附着到目标
		var body_layers = collider.collision_layer
			# 判断碰撞对象属于哪个层
		if body_layers & 2:  # 检查第1层
			stick_to_collider(collider)
		else:
			destroy()
	else:
		# 不附着，直接销毁
		destroy()

func stick_to_collider(target: Node2D):
	"""附着到碰撞体"""
	# 标记为附着状态
	is_sticking = true
	stick_target = target
	
	# 计算相对偏移
	relative_offset = global_position - target.global_position
	
	# 禁用碰撞检测
	collision_shape.set_deferred("disabled", true)
	
	# 播放附着动画
	animation_player.play("disappear")
	
	# 播放碰撞音效
	if disappear_sound and disappear_sound.stream:
		disappear_sound.play()
	
	# 停止存活计时器，启动附着计时器
	lifetime_timer.stop()
	stick_timer.start()
	


func _on_stick_timer_timeout():
	"""附着时间到期，销毁子弹"""
	if is_sticking and not is_destroyed:
		destroy()

func destroy():
	"""销毁子弹"""
	if is_destroyed:
		return
	
	is_destroyed = true
	
	# 停止所有计时器
	lifetime_timer.stop()
	stick_timer.stop()

	queue_free()

func _on_lifetime_timer_timeout():
	"""存活时间到期，自动销毁子弹"""
	if not is_destroyed and not is_sticking:
		# 如果不在附着状态，直接销毁
		destroy()
	elif not is_destroyed and is_sticking:
		# 如果在附着状态，启动附着计时器
		# 确保附着时间不会超过剩余存活时间
		var remaining_time = lifetime - lifetime_timer.time_left
		if remaining_time < stick_duration:
			stick_timer.start(remaining_time)
		else:
			stick_timer.start()
