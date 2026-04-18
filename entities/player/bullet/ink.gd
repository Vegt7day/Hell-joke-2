extends CharacterBody2D

# 子弹参数
@export var speed: float = 400.0  # 子弹速度
@export var facing_right: bool = true  # 子弹方向（由发射者设置）
@export var damage: int = 10  # 子弹伤害值
@export var lifetime: float = 5.0  # 子弹存活时间（秒）

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = Timer.new()
@onready var disapear_voice: AudioStreamPlayer = $disapear


# 状态变量
var is_active: bool = true  # 子弹是否活跃
var has_collided: bool = false  # 是否已发生碰撞
var is_destroyed: bool = false  # 是否正在销毁过程中
var direction: Vector2 = Vector2.RIGHT  # 移动方向

func _ready():
	# 初始化子弹方向
	if not facing_right:
		direction = Vector2.LEFT

	
	# 添加存活时间计时器
	add_child(lifetime_timer)
	lifetime_timer.one_shot = true
	lifetime_timer.wait_time = lifetime
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	lifetime_timer.start()
	
	# 播放射击动画
	animation_player.play("shooting")

func _physics_process(delta):
	# 如果子弹不活跃或已发生碰撞，不进行物理处理
	if not is_active or has_collided or is_destroyed:
		return
	
	# 设置速度
	velocity = direction * speed
	
	# 移动并检测碰撞
	var collision = move_and_collide(velocity * delta)
	
	# 如果发生碰撞
	if collision:
		_handle_collision(collision)

func initialize(start_position: Vector2, shoot_direction: bool):
	"""
	初始化子弹
	start_position: 起始位置
	shoot_direction: 射击方向 (true=向右, false=向左)
	"""
	global_position = start_position
	facing_right = shoot_direction
	if not facing_right:
		direction = Vector2.LEFT


func _handle_collision(collision: KinematicCollision2D):
	"""
	处理碰撞事件
	"""
	# 如果已经在销毁过程中，直接返回
	if is_destroyed:
		return
	
	# 标记已发生碰撞
	has_collided = true
	disapear_voice.play()
	# 停止移动
	velocity = Vector2.ZERO
	
	# 禁用碰撞检测
	collision_shape.set_deferred("disabled", true)
	
	# 标记为销毁过程中
	is_destroyed = true
	
	# 根据方向播放对应的消失动画
	if facing_right:
		animation_player.play("right_shoot_disapear")
	else:
		animation_player.play("left_shoot_disapear")
	
	# 播放音效（如果有）
	
	
	# 显示击中效果（如果有）
	# show_hit_effect(collision.get_position())
	
	# 如果有碰撞对象，可以传递伤害
	var collider = collision.get_collider()
	if collider and collider.has_method("take_damage"):
		collider.take_damage(damage)
	
	# 启动消失动画计时器，0.6秒后销毁子弹
	var destroy_timer = get_tree().create_timer(0.6)
	destroy_timer.timeout.connect(_destroy_bullet)

func _on_lifetime_timer_timeout():
	"""
	存活时间到期，自动销毁子弹
	"""
	if not has_collided and not is_destroyed:
		# 标记为销毁过程中
		is_destroyed = true
		
		# 停止移动
		velocity = Vector2.ZERO
		
		# 禁用碰撞检测
		collision_shape.set_deferred("disabled", true)
		
		# 播放消失动画
		if facing_right:
			animation_player.play("right_shoot_disapear")
		else:
			animation_player.play("left_shoot_disapear")
		
		# 启动消失动画计时器，0.6秒后销毁子弹
		var destroy_timer = get_tree().create_timer(0.6)
		destroy_timer.timeout.connect(_destroy_bullet)

func _destroy_bullet():
	"""
	销毁子弹
	"""
	# 确保子弹还没有被销毁
	if not is_instance_valid(self):
		return
	
	# 停止所有动画
	if animation_player.is_playing():
		animation_player.stop()
	
	# 销毁子弹
	queue_free()

func disable():
	"""
	禁用子弹
	"""
	is_active = false
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)

func enable():
	"""
	启用子弹
	"""
	is_active = true
	collision_shape.set_deferred("disabled", false)
