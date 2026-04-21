class_name Player

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

@onready var interaction_icon: AnimatedSprite2D = $interactionIcon




# 重力（从项目设置中获取）
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var stats: Stats = $Stats

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
@onready var jump: AudioStreamPlayer=$jump
@onready var walk: AudioStreamPlayer = $walk
@onready var attack: AudioStreamPlayer = $attack

@onready var dialogic: Marker2D = $Marker2D3

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
var can_use_coyote_time: bool = false  # 新增：是否可以使用coyote time

# 攻击相关变量
var is_attack_delayed: bool = false
var is_shoot_requested: bool = false
var attack_delay_remaining: float = 0.0
var last_shoot_facing_right=false
var interacting_with:Array[Interactable]
var 接触触发_with:Array[接触触发]


func _ready():
	# 初始化角色朝向
	update_facing()
	
	# 初始化跳跃计时器
	add_child(jump_timer)
	jump_timer.one_shot = true
	jump_timer.timeout.connect(_on_jump_timer_timeout)
	jump_timer.wait_time = jump_delay
	#var layout=Dialogic.start("timeline")
	#layout.register_character("res://assets/Dialogic/中学生.dch",$Marker2D3)
	# 初始化攻击计时器
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.wait_time = attack_duration
	# 禁用跳跃键
	disable_action("jump")

	# 禁用移动键
	disable_action("move_left")
	disable_action("move_right")

	# 禁用攻击键
	disable_action("attack")

	# 解锁跳跃键
	enable_action("jump")
	
	
	
	# 初始化攻击延迟计时器
	add_child(attack_delay_timer)
	attack_delay_timer.one_shot = true
	attack_delay_timer.timeout.connect(_on_attack_delay_timer_timeout)
	attack_delay_timer.wait_time = attack_shoot_delay
	
	# 检查子弹场景是否已设置
	if not ink_bullet_scene:
		push_warning("ink_bullet_scene 未设置！请在编辑器中分配子弹场景。")
	_init_input_control()
	print("输入控制系统初始化完成")
	
	
	
func register_interactable(v:Interactable):
	if v in interacting_with:
		return
	interacting_with.append(v)

func unregister_interactable(v:Interactable):

	interacting_with.erase(v)

func register_接触触发(v:接触触发):
	if v in 接触触发_with:
		return
	接触触发_with.append(v)

func unregister_接触触发(v:接触触发):

	接触触发_with.erase(v)



func _physics_process(delta):
	
	interaction_icon.visible=not interacting_with.is_empty()
	if enable_input_control:
		# 检查被禁用的动作，确保它们没有被处理
		for action in disabled_actions:
			if disabled_actions[action] and Input.is_action_pressed(action):
				# 确保动作被释放
				if Input.is_action_pressed(action):
					Input.action_release(action)
	# 处理冷却时间
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# 处理跳跃缓冲时间
	if jump_buffer_time > 0:
		jump_buffer_time -= delta
	
	# 处理coyote时间
	if is_on_floor():
		coyote_time = coyote_duration
		# 在地面上时，重置跳跃状态
		if is_jumping and is_on_floor_last_frame == false:
			is_jumping = false
			is_jump_delayed = false
			can_use_coyote_time = true
		elif not is_jumping and not is_jump_delayed:
			can_use_coyote_time = true
	else:
		coyote_time -= delta
		# 离开地面后，只有在没有跳跃的情况下才能使用coyote time
		if not is_jumping and not is_jump_delayed:
			can_use_coyote_time = true
	
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
	
	if Input.is_action_just_pressed("interact") and interacting_with:
		interacting_with.back().interact()
	if 接触触发_with:
		接触触发_with.back().interact()
	
	# 跳跃输入检测 - 彻底修复：只有在地面上或coyote时间内，并且可以使用coyote time，并且没有处于跳跃延迟中才能跳跃
	if Input.is_action_just_pressed("jump") and not is_jump_delayed:
		var can_jump = false
		
		# 检查是否在地面上
		if is_on_floor():
			can_jump = true
		# 检查是否可以使用coyote time并且coyote_time大于0
		elif can_use_coyote_time and coyote_time > 0:
			can_jump = true
		
		if can_jump:
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
			
			# 禁用coyote time，防止在空中再次使用
			can_use_coyote_time = false
	
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
	jump.play()
	if is_jump_requested and is_jump_delayed:
		# 检查是否仍然可以跳跃
		var can_jump = false
		
		# 检查是否在地面上
		if is_on_floor():
			can_jump = true
		# 检查是否可以使用coyote time并且coyote_time大于0
		elif can_use_coyote_time and coyote_time > 0:
			can_jump = true
		
		if can_jump:
			# 执行跳跃位移
			velocity.y = jump_velocity
			is_jumping = true
			# 重要：跳跃执行后，禁用coyote_time，防止在空中再次跳跃
			can_use_coyote_time = false
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
	if enable_input_control:
		_process_controlled_input(event)
	
	# 现有的攻击键键盘映射代码
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_J:
			Input.action_press("attack")
		elif not event.pressed and event.keycode == KEY_J:
			Input.action_release("attack")
	
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
	last_shoot_facing_right=facing_right
	# 启动攻击计时器
	attack_timer.start()
	attack.play()
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
	if not last_shoot_facing_right:
		bullet.initialize(shoot_position_left.global_position, last_shoot_facing_right)
	else:
		bullet.initialize(shoot_position_right.global_position, last_shoot_facing_right)
	
	# 将子弹添加到场景中
	get_parent().add_child(bullet)
	
	# 可以调整子弹速度等参数
	# bullet.speed = 500.0

func take_damage(damage_amount: float):
	stats.health-=damage_amount

func get_health():
	return stats.health

# 添加以下代码到角色脚本中

# ... 在现有的导出变量后面添加 ...
@export var enable_input_control: bool = true  # 是否启用输入控制

# ... 在现有的变量声明后面添加 ...
var disabled_actions: Dictionary = {}  # 存储被禁用的动作和它们的原始状态
var action_callbacks: Dictionary = {}  # 存储动作的回调函数
var action_presses: Dictionary = {}  # 存储动作的按下状态



# 初始化输入控制
func _init_input_control():
	# 定义要监控的动作
	var actions_to_monitor = ["move_left", "move_right", "jump", "attack"]
	
	for action in actions_to_monitor:
		# 确保动作存在
		if InputMap.has_action(action):
			disabled_actions[action] = false
			action_callbacks[action] = false
			action_presses[action] = false
		else:
			print("警告：动作 ", action, " 不存在于InputMap中")



# 处理受控的输入
func _process_controlled_input(event):
	# 检查所有被监控的动作
	for action in disabled_actions.keys():
		# 如果动作被禁用，阻止其输入事件
		if disabled_actions[action] and event.is_action(action):
			# 标记事件为已处理，阻止其传播
			event.set_echo(false)  # 阻止回声
			
			# 记录动作回调状态
			if event.is_pressed():
				action_presses[action] = true
				if action_callbacks[action]:
					# 如果有回调函数，调用它
					call(action + "_pressed_callback")
			else:
				action_presses[action] = false
				if action_callbacks[action]:
					# 如果有回调函数，调用它
					call(action + "_released_callback")
			
			# 阻止事件被默认处理
			get_viewport().set_input_as_handled()
			return

# 禁用指定的动作
func disable_action(action_name: String, add_callback: bool = false, callback_node: Node = null, callback_method: String = ""):
	if not InputMap.has_action(action_name):
		print("错误：动作 ", action_name, " 不存在于InputMap中")
		return
	
	if action_name in disabled_actions:
		disabled_actions[action_name] = true
		action_callbacks[action_name] = add_callback
		
		if add_callback and callback_node and callback_method != "":
			# 连接回调信号
			if not callback_node.has_signal(action_name + "_pressed"):
				callback_node.add_user_signal(action_name + "_pressed")
			if not callback_node.has_signal(action_name + "_released"):
				callback_node.add_user_signal(action_name + "_released")
			
			# 添加回调方法
			if not has_method(action_name + "_pressed_callback"):
				_add_callback_method(action_name, callback_node, callback_method)
		
		print("动作 ", action_name, " 已被禁用")
		
		# 立即释放当前按下的该动作
		if Input.is_action_pressed(action_name):
			Input.action_release(action_name)
	else:
		print("警告：动作 ", action_name, " 未被监控")

# 解锁指定的动作
func enable_action(action_name: String):
	if not InputMap.has_action(action_name):
		print("错误：动作 ", action_name, " 不存在于InputMap中")
		return
	
	if action_name in disabled_actions:
		disabled_actions[action_name] = false
		action_callbacks[action_name] = false
		
		# 移除回调方法
		if has_method(action_name + "_pressed_callback"):
			_remove_callback_method(action_name)
		
		print("动作 ", action_name, " 已被解锁")
	else:
		print("警告：动作 ", action_name, " 未被监控")

# 添加回调方法
func _add_callback_method(action_name: String, callback_node: Node, callback_method: String):
	# 创建动态方法
	var callback_func = func():
		callback_node.call(callback_method, action_name)
	
	# 存储回调函数
	set(action_name + "_callback_func", callback_func)
	
	# 创建按下回调方法
	var pressed_callback = func():
		var callback = get(action_name + "_callback_func")
		if callback:
			callback.call()
	
	# 创建释放回调方法
	var released_callback = func():
		var callback = get(action_name + "_callback_func")
		if callback:
			callback.call()
	
	# 添加方法到对象
	if not has_method(action_name + "_pressed_callback"):
		set(action_name + "_pressed_callback", pressed_callback)
	if not has_method(action_name + "_released_callback"):
		set(action_name + "_released_callback", released_callback)

# 移除回调方法
func _remove_callback_method(action_name: String):
	if has_method(action_name + "_pressed_callback"):
		# 移除动态方法
		set(action_name + "_pressed_callback", null)
	if has_method(action_name + "_released_callback"):
		set(action_name + "_released_callback", null)
	if get(action_name + "_callback_func"):
		set(action_name + "_callback_func", null)

# 检查动作是否被禁用
func is_action_disabled(action_name: String) -> bool:
	if action_name in disabled_actions:
		return disabled_actions[action_name]
	return false

# 禁用所有动作
func disable_all_actions():
	for action in disabled_actions.keys():
		disable_action(action)
	print("所有动作已被禁用")

# 解锁所有动作
func enable_all_actions():
	for action in disabled_actions.keys():
		enable_action(action)
	print("所有动作已被解锁")
