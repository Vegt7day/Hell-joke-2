extends CharacterBody2D

# 移动参数
@export var move_speed: float = 500.0
@export var jump_velocity: float = -400.0
@export var acceleration: float = 40.0
@export var friction: float = 10.0
@export var jump_delay: float = 0.14  # 跳跃延迟时间，单位：秒
@export var attack_duration: float = 0.55  # 攻击动画持续时间，单位：秒
@export var attack_shoot_delay: float = 0.3  # 攻击后发射子弹的延迟时间，单位：秒

# 子弹相关参数
@export var ink_bullet_scene: PackedScene  # 子弹场景

# 重力（从项目设置中获取）
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# 获取节点
@onready var animation_down: Sprite2D = $downer
@onready var animation_up: Sprite2D = $downer/Marker2D/upper
@onready var animation_player_down: AnimationPlayer = $AnimationDowner
@onready var animation_player_up: AnimationPlayer = $AnimationUpper
@onready var jump_timer: Timer = Timer.new()
@onready var attack_timer: Timer = Timer.new()
@onready var attack_delay_timer: Timer = Timer.new()

# 发射位置
@onready var shoot_position_right: Marker2D = $Marker2D
@onready var shoot_position_left: Marker2D = $Marker2D2

# 状态变量
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var facing_right: bool = true
var is_jumping: bool = false
var is_on_floor_last_frame: bool = true

# 跳跃相关变量
var jump_buffer_time: float = 0.0
var jump_buffer_duration: float = 0.3
var jump_pressed: bool = false
var coyote_time: float = 0.0
var coyote_duration: float = 0.5
var is_jump_delayed: bool = false
var is_jump_requested: bool = false
var jump_timer_started: bool = false
var jump_delay_remaining: float = 0.0

# 攻击相关变量
var is_attack_delayed: bool = false
var is_shoot_requested: bool = false
var attack_delay_remaining: float = 0.0

func _ready():
	# 初始化角色朝向
	update_facing()
	
	# 初始化跳跃计时器
	add_child(jump_timer)
	jump_timer.one_shot = true
	jump_timer.timeout.connect(_on_jump_timer_timeout)
	jump_timer.wait_time = jump_delay
	
	# 初始化攻击计时器
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.wait_time = attack_duration
	
	# 初始化攻击延迟计时器
	add_child(attack_delay_timer)
	attack_delay_timer.one_shot = true
	attack_delay_timer.timeout.connect(_on_attack_delay_timer_timeout)
	attack_delay_timer.wait_time = attack_shoot_delay
	
	# 检查子弹场景是否已设置
	if not ink_bullet_scene:
		push_warning("ink_bullet_scene 未设置！请在编辑器中分配子弹场景。")

func _physics_process(delta):
	# 处理冷却时间
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# 处理跳跃缓冲时间
	if jump_buffer_time > 0:
		jump_buffer_time -= delta
	
	# 处理coyote时间
	if is_on_floor():
		coyote_time = coyote_duration
	else:
		coyote_time -= delta
	
	# 处理跳跃延迟剩余时间
	if jump_delay_remaining > 0:
		jump_delay_remaining -= delta
		if jump_delay_remaining <= 0:
			jump_delay_remaining = 0
	
	# 处理攻击延迟剩余时间
	if attack_delay_remaining > 0:
		attack_delay_remaining -= delta
		if attack_delay_remaining <= 0:
			attack_delay_remaining = 0
	
	# 获取输入
	var input_direction = Input.get_axis("move_left", "move_right")
	
	# 攻击输入检测
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0 and not is_attacking:
		start_attack()
	
	# 跳跃输入检测
	if Input.is_action_just_pressed("jump") and not is_jump_delayed and (is_on_floor() or coyote_time > 0):
		# 立即播放跳跃动画
		animation_player_down.play("jump")
		is_jumping = true
		
		# 设置跳跃延迟状态
		is_jump_delayed = true
		is_jump_requested = true
		jump_delay_remaining = jump_delay
		jump_buffer_time = jump_buffer_duration
		
		# 启动跳跃延迟计时器
		jump_timer.start()
		jump_timer_started = true
	
	# 移动逻辑
	if input_direction != 0:
		# 更新朝向
		if (input_direction > 0 and not facing_right) or (input_direction < 0 and facing_right):
			facing_right = input_direction > 0
			update_facing()
		
		# 应用移动
		velocity.x = move_toward(velocity.x, input_direction * move_speed, acceleration)
		
		# 播放移动动画
		if is_on_floor() and not is_jumping and not is_jump_delayed:
			animation_player_down.play("run")
	else:
		# 停止移动
		velocity.x = move_toward(velocity.x, 0, friction)
		
		# 播放闲置动画
		if is_on_floor() and not is_jumping and not is_jump_delayed:
			animation_player_down.play("idle")
	
	# 应用重力
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# 落地检测
		if is_jumping and is_on_floor_last_frame == false and not is_jump_delayed:
			is_jumping = false
			is_jump_delayed = false
			animation_player_down.play("idle")
	
	# 记录上一帧的地面状态
	is_on_floor_last_frame = is_on_floor()
	
	# 应用移动
	move_and_slide()

func _on_jump_timer_timeout():
	# 计时器超时，执行跳跃位移
	if is_jump_requested and is_jump_delayed:
		# 检查是否仍然可以跳跃
		if is_on_floor() or coyote_time > 0:
			# 执行跳跃位移
			velocity.y = jump_velocity
			is_jumping = true
		else:
			# 不能跳跃，回到闲置或移动状态
			is_jumping = false
			if is_on_floor():
				var input_direction = Input.get_axis("move_left", "move_right")
				if input_direction != 0:
					animation_player_down.play("run")
				else:
					animation_player_down.play("idle")
		
		# 重置跳跃状态
		is_jump_requested = false
		is_jump_delayed = false
		jump_timer_started = false
		jump_delay_remaining = 0.0

func _on_attack_timer_timeout():
	# 攻击计时器超时，结束攻击状态
	is_attacking = false
	attack_cooldown = 0.0
	is_attack_delayed = false
	is_shoot_requested = false
	
	# 恢复上半身闲置动画
	if facing_right:
		animation_player_up.play("upper_idle_right")
	else:
		animation_player_up.play("upper_idle_left")

func _on_attack_delay_timer_timeout():
	# 攻击延迟计时器超时，执行发射子弹
	if is_shoot_requested and is_attack_delayed and is_attacking:
		# 发射子弹
		shoot()
		is_shoot_requested = false
		is_attack_delayed = false
		attack_delay_remaining = 0.0
	else:
		# 如果条件不满足，重置状态
		is_shoot_requested = false
		is_attack_delayed = false
		attack_delay_remaining = 0.0

func _input(event):
	# 为攻击键添加键盘映射
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_J:
			Input.action_press("attack")
		elif not event.pressed and event.keycode == KEY_J:
			Input.action_release("attack")

func start_attack():
	is_attacking = true
	attack_cooldown = attack_duration
	is_attack_delayed = true
	is_shoot_requested = true
	attack_delay_remaining = attack_shoot_delay
	
	# 播放上半身攻击动画
	if facing_right:
		animation_player_up.play("upper_shoot_right")
	else:
		animation_player_up.play("upper_shoot_left")
	
	# 启动攻击计时器
	attack_timer.start()
	
	# 启动攻击延迟计时器，0.3秒后发射子弹
	attack_delay_timer.start()

func update_facing():
	# 更新上半身闲置动画朝向
	if is_attacking:
		# 攻击状态下不更新闲置动画朝向
		return
	
	if facing_right:
		animation_player_up.play("upper_idle_right")
	else:
		animation_player_up.play("upper_idle_left")

func shoot():
	# 检查子弹场景是否已设置
	if not ink_bullet_scene:
		push_error("无法发射子弹：ink_bullet_scene 未设置！")
		return
	
	# 创建子弹实例
	var bullet = ink_bullet_scene.instantiate()
	
	# 根据朝向选择发射位置
	if not facing_right:
		bullet.initialize(shoot_position_left.global_position, facing_right)
	else:
		bullet.initialize(shoot_position_right.global_position, facing_right)
	
	# 将子弹添加到场景中
	get_parent().add_child(bullet)
	
	# 可以调整子弹速度等参数
	# bullet.speed = 500.0
