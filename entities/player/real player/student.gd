class_name Player
extends CharacterBody2D

# 移动参数
@export var move_speed: float = 200.0
@export var jump_velocity: float = -300.0
@export var acceleration: float = 40.0
@export var friction: float = 10.0
@export var attack_duration: float = 0.3
@export var attack_shoot_delay: float = 0.2

# 子弹相关参数
@export var ink_bullet_scene: PackedScene
@export var shoot_offset_x: float = 50.0  # 子弹发射位置的水平偏移
@export var shoot_offset_y: float = 0.0   # 子弹发射位置的垂直偏移

# 召唤商鞅相关参数
@export var shangyang_summon_scene: PackedScene
@export var summon_cooldown: float = 5.0  # 召唤冷却时间
@export var summon_ink_cost: float = 30.0  # 召唤墨水消耗
@export var summon_offset_x: float = 100.0  # 召唤位置的水平偏移
@export var summon_offset_y: float = 0.0    # 召唤位置的垂直偏移
@export var summon_delay_in_animation: float = 0.2  # 动画中召唤的延迟时间

# 墨水恢复参数
@export var ink_recovery_rate: float = 1
@export var ink_recovery_interval: float = 0.1
@export var max_ink: float = 100

@onready var interaction_icon: AnimatedSprite2D = $interactionIcon

# 重力
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var stats: Stats = Game.player_stats
@onready var player: Player = $"."

# 获取节点
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = Timer.new()
@onready var attack_delay_timer: Timer = Timer.new()
@onready var ink_recovery_timer: Timer = Timer.new()
@onready var summon_delay_timer: Timer = Timer.new()  # 召唤延迟计时器

# 发射位置（现在只使用一个参考节点）
@onready var shoot_position_base: Marker2D = $Marker2D
@onready var jump_sound: AudioStreamPlayer = $jump
@onready var walk_sound: AudioStreamPlayer = $walk
@onready var attack_sound: AudioStreamPlayer = $attack
@onready var dialogic: Marker2D = $Marker2D3

# 召唤音效
@onready var summon_sound: AudioStreamPlayer = $summon_sound

# ========== 状态机定义 ==========
enum PlayerState {
	IDLE,           # 闲置
	WALK,           # 行走
	JUMP_ASCEND,    # 跳跃上升
	JUMP_FALL,      # 跳跃下落
	ATTACK_START,   # 攻击开始
	ATTACK_SHOOT,   # 攻击发射子弹
	ATTACK_END,     # 攻击结束
	STUNNED,        # 被击晕/受伤
	SUMMON_START,   # 召唤开始
	SUMMON_END      # 召唤结束
}

var current_state: PlayerState = PlayerState.IDLE
var previous_state: PlayerState = PlayerState.IDLE
var state_timer: float = 0.0
var direction: int = 1  # 1=向右, 0=向左
var last_shoot_direction: int = 1
var interacting_with: Array[Interactable] = []
var 接触触发_with: Array[接触触发] = []

# 状态机参数
var attack_cooldown: float = 0.0
var summon_cooldown_timer: float = 0.0
var can_summon: bool = true
var animation_complete_connected: bool = false  # 动画完成信号连接标志

# 输入控制相关变量
@export var enable_input_control: bool = true
var disabled_actions: Dictionary = {}
var action_callbacks: Dictionary = {}
var action_presses: Dictionary = {}

func _ready():
	add_to_group("player")
	print("=== Player.gd _ready() 开始 ===")
	print("玩家初始位置:", global_position)
	print("父节点:", get_parent().name if get_parent() else "无父节点")
	
	# 首先重置所有物理状态
	velocity = Vector2.ZERO
	
	# 初始化角色朝向
	update_facing()
	
	# 确保发射位置基础节点存在
	if not shoot_position_base:
		printerr("警告：没有找到发射位置基础节点 Marker2D")
	
	# 初始化计时器
	init_timers()
	
	# 初始化输入控制
	_init_input_control()
	
	# 连接动画完成信号
	if not animation_complete_connected:
		animation_player.animation_finished.connect(_on_animation_finished)
		animation_complete_connected = true
	
	# 等待一帧，让物理系统完全初始化
	await get_tree().process_frame
	
	# 强制进行一次物理检测
	move_and_slide()
	
	# 检查是否在地面上
	if is_on_floor():
		print("玩家在地面上，初始状态: IDLE")
		change_state(PlayerState.IDLE)
	else:
		# 如果不在平面上，尝试向上调整位置
		var original_y = global_position.y
		var found_ground = false
		
		# 尝试向上搜索地面
		for i in range(10):
			global_position.y -= 20
			velocity = Vector2.ZERO
			move_and_slide()
			
			if is_on_floor():
				print("找到地面，调整后位置:", global_position)
				change_state(PlayerState.IDLE)
				found_ground = true
				break
		
		# 如果没有找到地面，恢复原始位置
		if not found_ground:
			global_position.y = original_y
			print("玩家不在平面上，初始状态: JUMP_FALL")
			# 重置速度，防止初始速度过大
			velocity = Vector2.ZERO
			change_state(PlayerState.JUMP_FALL)
	
	print("=== Player.gd _ready() 完成 ===")

func init_timers():
	# 攻击计时器
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.wait_time = attack_duration
	
	# 攻击延迟计时器
	add_child(attack_delay_timer)
	attack_delay_timer.one_shot = true
	attack_delay_timer.timeout.connect(_on_attack_delay_timer_timeout)
	attack_delay_timer.wait_time = attack_shoot_delay
	
	# 墨水恢复计时器
	add_child(ink_recovery_timer)
	ink_recovery_timer.one_shot = false
	ink_recovery_timer.wait_time = ink_recovery_interval
	ink_recovery_timer.timeout.connect(_on_ink_recovery_timer_timeout)
	ink_recovery_timer.start()
	
	# 召唤延迟计时器
	add_child(summon_delay_timer)
	summon_delay_timer.one_shot = true
	summon_delay_timer.timeout.connect(_on_summon_delay_timer_timeout)
	summon_delay_timer.wait_time = summon_delay_in_animation

# ========== 状态机核心函数 ==========
func change_state(new_state: PlayerState):
	if new_state == current_state:
		return
	
	# 执行退出当前状态的逻辑
	exit_state(current_state)
	
	# 记录状态转换
	previous_state = current_state
	current_state = new_state
	state_timer = 0.0
	
	# 执行进入新状态的逻辑
	enter_state(current_state)
	
	# 打印状态转换（调试用）
	print("状态转换: ", get_state_name(previous_state), " -> ", get_state_name(current_state))

func get_state_name(state: PlayerState) -> String:
	match state:
		PlayerState.IDLE: return "IDLE"
		PlayerState.WALK: return "WALK"
		PlayerState.JUMP_ASCEND: return "JUMP_ASCEND"
		PlayerState.JUMP_FALL: return "JUMP_FALL"
		PlayerState.ATTACK_START: return "ATTACK_START"
		PlayerState.ATTACK_SHOOT: return "ATTACK_SHOOT"
		PlayerState.ATTACK_END: return "ATTACK_END"
		PlayerState.STUNNED: return "STUNNED"
		PlayerState.SUMMON_START: return "SUMMON_START"
		PlayerState.SUMMON_END: return "SUMMON_END"
		_: return "UNKNOWN"

func enter_state(state: PlayerState):
	match state:
		PlayerState.IDLE:
			animation_player.play("idle")
			
		PlayerState.WALK:
			animation_player.play("walk")
			if not walk_sound.playing:
				walk_sound.play()
			
		PlayerState.JUMP_ASCEND:
			# 执行跳跃
			velocity.y = jump_velocity
			jump_sound.play()
			animation_player.play("walk")
			
		PlayerState.JUMP_FALL:
			# 开始下落
			animation_player.play("walk")
			
		PlayerState.ATTACK_START:
			attack_timer.start()
			attack_sound.play()
			last_shoot_direction = direction
			animation_player.play("attack")
			
		PlayerState.ATTACK_SHOOT:
			# 发射子弹
			if stats.ink >= 15:
				stats.ink -= 15
				shoot()
			# 启动攻击延迟计时器
			attack_delay_timer.start()
			
		PlayerState.ATTACK_END:
			# 攻击结束，立即回到合适的状态
			return_to_normal_state()
			
		PlayerState.STUNNED:
			# 被击晕状态
			animation_player.play("idle")
			
		PlayerState.SUMMON_START:
			# 播放draw动画
			if animation_player.has_animation("draw"):
				animation_player.play("draw")
				# 播放召唤音效
				if summon_sound:
					summon_sound.play()
				# 在动画中延迟召唤
				summon_delay_timer.start()
				print("开始召唤商鞅，播放draw动画")
			else:
				# 如果没有draw动画，直接召唤
				print("警告：未找到draw动画，直接召唤")
				execute_summon()
				change_state(PlayerState.SUMMON_END)
			
		PlayerState.SUMMON_END:
			# 召唤结束，回到之前的状态
			return_to_normal_state()

func exit_state(state: PlayerState):
	match state:
		PlayerState.WALK:
			if walk_sound.playing:
				walk_sound.stop()
		PlayerState.ATTACK_START:
			# 停止攻击计时器
			attack_timer.stop()
		PlayerState.ATTACK_SHOOT:
			# 停止攻击延迟计时器
			attack_delay_timer.stop()
		PlayerState.SUMMON_START:
			# 停止召唤延迟计时器
			if summon_delay_timer.time_left > 0:
				summon_delay_timer.stop()

func update_state(delta: float):
	state_timer += delta
	
	# 通用状态更新
	handle_common_updates(delta)
	
	match current_state:
		PlayerState.IDLE:
			update_idle(delta)
			
		PlayerState.WALK:
			update_walk(delta)
			
		PlayerState.JUMP_ASCEND:
			update_jump_ascend(delta)
			
		PlayerState.JUMP_FALL:
			update_jump_fall(delta)
			
		PlayerState.ATTACK_START:
			update_attack_start(delta)
			
		PlayerState.ATTACK_SHOOT:
			update_attack_shoot(delta)
			
		PlayerState.ATTACK_END:
			update_attack_end(delta)
			
		PlayerState.STUNNED:
			update_stunned(delta)
			
		PlayerState.SUMMON_START:
			update_summon_start(delta)
			
		PlayerState.SUMMON_END:
			update_summon_end(delta)

func handle_common_updates(delta: float):
	# 处理冷却时间
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# 处理召唤冷却时间
	if summon_cooldown_timer > 0:
		summon_cooldown_timer -= delta
		if summon_cooldown_timer <= 0:
			can_summon = true

# ========== 状态更新函数 ==========
func update_idle(delta: float):
	var input_direction = Input.get_axis("move_left", "move_right")
	
	# 检查移动输入
	if input_direction != 0:
		change_state(PlayerState.WALK)
		return
	
	# 检查是否离开地面
	if not is_on_floor():
		change_state(PlayerState.JUMP_FALL)
		return
	
	# 检查攻击
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0:
		start_attack()
		return
	
	# 检查召唤
	if Input.is_action_just_pressed("summon") and can_summon:
		try_summon_shangyang()
		return
	
	# 应用水平减速
	if velocity.x != 0:
		velocity.x = move_toward(velocity.x, 0, friction)

func update_walk(delta: float):
	var input_direction = Input.get_axis("move_left", "move_right")
	
	# 移动逻辑
	if input_direction != 0:
		# 更新朝向
		if (input_direction > 0 and direction != 1) or (input_direction < 0 and direction != 0):
			direction = 1 if input_direction > 0 else 0
			update_facing()
		
		# 应用移动
		velocity.x = move_toward(velocity.x, input_direction * move_speed, acceleration)
	else:
		velocity.x = move_toward(velocity.x, 0, friction)
		change_state(PlayerState.IDLE)
		return
	
	# 检查是否离开地面
	if not is_on_floor():
		change_state(PlayerState.JUMP_FALL)
		return
	
	# 检查攻击
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0:
		start_attack()
		return
	
	# 检查召唤
	if Input.is_action_just_pressed("summon") and can_summon:
		try_summon_shangyang()
		return

func update_jump_ascend(delta: float):
	# 处理水平移动
	var input_direction = Input.get_axis("move_left", "move_right")
	if input_direction != 0:
		velocity.x = move_toward(velocity.x, input_direction * move_speed, acceleration)
		if (input_direction > 0 and direction != 1) or (input_direction < 0 and direction != 0):
			direction = 1 if input_direction > 0 else 0
			update_facing()
	
	# 应用重力
	velocity.y += gravity * delta
	
	# 检查状态转换
	if velocity.y >= 0:
		# 上升速度降为0或负数，转为下落状态
		change_state(PlayerState.JUMP_FALL)
		return
	elif is_on_floor():
		# 意外落地，回到行走或闲置状态
		return_to_normal_state()
		return
		
	# 检查攻击
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0:
		start_attack()
		return
	
	# 检查召唤
	if Input.is_action_just_pressed("summon") and can_summon:
		try_summon_shangyang()
		return

func update_jump_fall(delta: float):
	# 处理水平移动
	var input_direction = Input.get_axis("move_left", "move_right")
	if input_direction != 0:
		velocity.x = move_toward(velocity.x, input_direction * move_speed, acceleration)
		if (input_direction > 0 and direction != 1) or (input_direction < 0 and direction != 0):
			direction = 1 if input_direction > 0 else 0
			update_facing()
	
	# 应用重力
	velocity.y += gravity * delta
	
	# 检查状态转换
	if is_on_floor():
		# 落地
		return_to_normal_state()
		return
	
	# 检查攻击
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0:
		start_attack()
		return
	
	# 检查召唤
	if Input.is_action_just_pressed("summon") and can_summon:
		try_summon_shangyang()
		return

func update_attack_start(delta: float):
	# 攻击期间不能移动
	velocity.x = move_toward(velocity.x, 0, friction)
	
	# 应用重力
	if not is_on_floor():
		velocity.y += gravity * delta

func update_attack_shoot(delta: float):
	# 子弹已发射，等待攻击结束
	velocity.x = move_toward(velocity.x, 0, friction)
	
	# 应用重力
	if not is_on_floor():
		velocity.y += gravity * delta

func update_attack_end(delta: float):
	# 攻击结束状态，应该立即转换
	# 这里不执行任何逻辑，让计时器触发状态转换
	pass

func update_stunned(delta: float):
	# 被击晕状态，不能移动
	velocity.x = move_toward(velocity.x, 0, friction)
	
	# 应用重力
	if not is_on_floor():
		velocity.y += gravity * delta

func update_summon_start(delta: float):
	# 召唤期间不能移动
	velocity.x = move_toward(velocity.x, 0, friction)
	
	# 应用重力
	if not is_on_floor():
		velocity.y += gravity * delta

func update_summon_end(delta: float):
	# 召唤结束状态，应该立即转换
	# 这里不执行任何逻辑，让计时器触发状态转换
	pass

# ========== 动作函数 ==========
func can_jump() -> bool:
	# 检查是否可以进行跳跃
	return is_on_floor()

func start_attack():
	if stats.ink <= 0 or attack_cooldown > 0:
		return
	
	# 切换到攻击状态
	change_state(PlayerState.ATTACK_START)
	attack_cooldown = attack_duration

# ========== 召唤功能 ==========
func try_summon_shangyang():
	"""尝试召唤商鞅"""
	if not can_summon or stats.ink < summon_ink_cost or not shangyang_summon_scene:
		# 如果墨水不足、冷却中或没有设置商鞅场景
		print("无法召唤商鞅：墨水不足、冷却中或未设置召唤场景")
		return
	
	# 扣除墨水
	stats.ink -= summon_ink_cost
	
	# 启动冷却
	can_summon = false
	summon_cooldown_timer = summon_cooldown
	
	# 切换到召唤开始状态
	change_state(PlayerState.SUMMON_START)
	
	print("开始召唤商鞅，冷却时间: %.1f秒" % summon_cooldown)

func execute_summon():
	"""执行召唤商鞅"""
	if not shangyang_summon_scene:
		push_error("无法召唤商鞅：shangyang_summon_scene 未设置！")
		return
	
	# 实例化商鞅
	var shangyang = shangyang_summon_scene.instantiate() as ShangYang
	
	# 计算召唤位置
	var summon_position = calculate_summon_position()
	
	# 设置商鞅位置
	shangyang.global_position = summon_position
	
	# 添加到场景
	get_parent().add_child(shangyang)
	
	# 切换到被召唤模式
	shangyang.switch_to_summoned_mode()
	
	print("成功召唤商鞅在位置: %s" % str(summon_position))

func calculate_summon_position() -> Vector2:
	"""计算召唤位置"""
	var base_position = global_position
	var offset = Vector2(summon_offset_x, summon_offset_y)
	
	# 根据玩家朝向调整水平偏移
	if direction == 0:  # 向左
		offset.x = -summon_offset_x
	
	return Vector2(
		base_position.x + offset.x,
		base_position.y + offset.y
	)

# ========== 辅助函数 ==========
func return_to_normal_state():
	# 根据当前状态返回到合适的正常状态
	if is_on_floor():
		if abs(velocity.x) > 10:
			change_state(PlayerState.WALK)
		else:
			change_state(PlayerState.IDLE)
	else:
		if velocity.y < 0:
			change_state(PlayerState.JUMP_ASCEND)
		else:
			change_state(PlayerState.JUMP_FALL)

# ========== 主循环 ==========
func _physics_process(delta):
	# 处理交互图标
	interaction_icon.visible = not interacting_with.is_empty()
	
	# 处理被禁用的输入
	if enable_input_control:
		for action in disabled_actions:
			if disabled_actions[action] and Input.is_action_pressed(action):
				Input.action_release(action)
	
	# 处理跳跃输入 - 立即响应
	if Input.is_action_just_pressed("jump") and is_on_floor() and current_state != PlayerState.ATTACK_START and current_state != PlayerState.ATTACK_SHOOT and current_state != PlayerState.ATTACK_END and current_state != PlayerState.SUMMON_START:
		change_state(PlayerState.JUMP_ASCEND)
	
	# 更新当前状态
	update_state(delta)
	
	# 处理互动输入
	if Input.is_action_just_pressed("interact") and not interacting_with.is_empty():
		interacting_with.back().interact()
	if not 接触触发_with.is_empty():
		接触触发_with.back().interact()
	
	# 处理攻击输入
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0 and current_state != PlayerState.ATTACK_START and current_state != PlayerState.ATTACK_SHOOT and current_state != PlayerState.ATTACK_END and current_state != PlayerState.SUMMON_START:
		start_attack()
	
	# 处理召唤输入
	if Input.is_action_just_pressed("summon") and can_summon and stats.ink >= summon_ink_cost and current_state != PlayerState.SUMMON_START:
		try_summon_shangyang()
	
	# 应用移动
	move_and_slide()
	
	# 更新朝向
	update_facing()

# ========== 计时器回调 ==========
func _on_attack_timer_timeout():
	# 攻击计时器结束，转换到ATTACK_SHOOT状态
	if current_state == PlayerState.ATTACK_START:
		change_state(PlayerState.ATTACK_SHOOT)

func _on_attack_delay_timer_timeout():
	# 攻击延迟结束，转换到ATTACK_END状态
	if current_state == PlayerState.ATTACK_SHOOT:
		change_state(PlayerState.ATTACK_END)

func _on_ink_recovery_timer_timeout():
	# 墨水恢复
	if stats.ink < max_ink:
		stats.ink = min(stats.ink + ink_recovery_rate, max_ink)

func _on_summon_delay_timer_timeout():
	"""召唤延迟计时器超时，在动画中召唤商鞅"""
	if current_state == PlayerState.SUMMON_START:
		# 执行召唤
		execute_summon()

# ========== 动画完成回调 ==========
func _on_animation_finished(anim_name: String):
	"""动画播放完成时的回调"""
	print("动画完成: %s, 当前状态: %s" % [anim_name, get_state_name(current_state)])
	
	match current_state:
		PlayerState.SUMMON_START:
			# draw动画播放完成，进入SUMMON_END状态
			if anim_name == "draw":
				print("draw动画播放完成，进入SUMMON_END状态")
				change_state(PlayerState.SUMMON_END)
		
		# 其他状态的处理保持不变
		# ...

# ========== 辅助函数 ==========
func update_facing():
	if current_state == PlayerState.ATTACK_START or current_state == PlayerState.ATTACK_SHOOT or current_state == PlayerState.ATTACK_END or current_state == PlayerState.SUMMON_START:
		# 攻击状态和召唤状态下不更新朝向
		return
	
	# direction=1: 向右，不翻转
	# direction=0: 向左，翻转
	sprite.flip_h = direction == 0

func shoot():
	if not ink_bullet_scene:
		push_error("无法发射子弹：ink_bullet_scene 未设置！")
		return
	
	var bullet = ink_bullet_scene.instantiate()
	
	# 根据射击方向计算发射位置
	var shoot_position = calculate_shoot_position()
	
	# 初始化子弹
	bullet.initialize(shoot_position, last_shoot_direction)
	
	get_parent().add_child(bullet)

func calculate_shoot_position() -> Vector2:
	# 使用相对位移计算发射位置
	var base_position = shoot_position_base.global_position if shoot_position_base else global_position
	var offset = Vector2(shoot_offset_x, shoot_offset_y)
	
	# 根据射击方向调整水平偏移
	if last_shoot_direction == 0:
		# 向左射击，水平偏移取反
		offset.x = -shoot_offset_x
	
	return Vector2(
		base_position.x + offset.x,
		base_position.y + offset.y
	)

func take_damage(damage_amount: float):
	stats.health -= damage_amount
	# 可以在这里添加击退效果

func get_health():
	return stats.health

# 获取方向
func get_direction() -> int:
	return direction

# 设置方向
func set_direction(new_direction: int) -> void:
	if new_direction != direction:
		direction = new_direction
		update_facing()

# ========== 输入控制系统 ==========
func _input(event):
	if enable_input_control:
		_process_controlled_input(event)
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_J:
			Input.action_press("attack")
		elif not event.pressed and event.keycode == KEY_J:
			Input.action_release("attack")
		
		# 添加F键召唤检测
		if event.pressed and event.keycode == KEY_F:
			Input.action_press("summon")
		elif not event.pressed and event.keycode == KEY_F:
			Input.action_release("summon")

func _init_input_control():
	var actions_to_monitor = ["move_left", "move_right", "jump", "attack", "summon"]
	for action in actions_to_monitor:
		if InputMap.has_action(action):
			disabled_actions[action] = false
			action_callbacks[action] = false
			action_presses[action] = false
		else:
			print("警告：动作 ", action, " 不存在于InputMap中")

func _process_controlled_input(event):
	for action in disabled_actions.keys():
		if disabled_actions[action] and event.is_action(action):
			event.set_echo(false)
			if event.is_pressed():
				action_presses[action] = true
				if action_callbacks[action]:
					call(action + "_pressed_callback")
			else:
				action_presses[action] = false
				if action_callbacks[action]:
					call(action + "_released_callback")
			get_viewport().set_input_as_handled()
			return

func disable_action(action_name: String, add_callback: bool = false, callback_node: Node = null, callback_method: String = ""):
	if not InputMap.has_action(action_name):
		print("错误：动作 ", action_name, " 不存在于InputMap中")
		return
	
	if action_name in disabled_actions:
		disabled_actions[action_name] = true
		action_callbacks[action_name] = add_callback
		
		if add_callback and callback_node and callback_method != "":
			if not callback_node.has_signal(action_name + "_pressed"):
				callback_node.add_user_signal(action_name + "_pressed")
			if not callback_node.has_signal(action_name + "_released"):
				callback_node.add_user_signal(action_name + "_released")
			
			if not has_method(action_name + "_pressed_callback"):
				_add_callback_method(action_name, callback_node, callback_method)
		
		print("动作 ", action_name, " 已被禁用")
		
		if Input.is_action_pressed(action_name):
			Input.action_release(action_name)
	else:
		print("警告：动作 ", action_name, " 未被监控")

func enable_action(action_name: String):
	if not InputMap.has_action(action_name):
		print("错误：动作 ", action_name, " 不存在于InputMap中")
		return
	
	if action_name in disabled_actions:
		disabled_actions[action_name] = false
		action_callbacks[action_name] = false
		
		if has_method(action_name + "_pressed_callback"):
			_remove_callback_method(action_name)
		
		print("动作 ", action_name, " 已被解锁")
	else:
		print("警告：动作 ", action_name, " 未被监控")

func _add_callback_method(action_name: String, callback_node: Node, callback_method: String):
	var callback_func = func():
		callback_node.call(callback_method, action_name)
	set(action_name + "_callback_func", callback_func)
	
	var pressed_callback = func():
		var callback = get(action_name + "_callback_func")
		if callback:
			callback.call()
	var released_callback = func():
		var callback = get(action_name + "_callback_func")
		if callback:
			callback.call()
	
	if not has_method(action_name + "_pressed_callback"):
		set(action_name + "_pressed_callback", pressed_callback)
	if not has_method(action_name + "_released_callback"):
		set(action_name + "_released_callback", released_callback)

func _remove_callback_method(action_name: String):
	if has_method(action_name + "_pressed_callback"):
		set(action_name + "_pressed_callback", null)
	if has_method(action_name + "_released_callback"):
		set(action_name + "_released_callback", null)
	if get(action_name + "_callback_func"):
		set(action_name + "_callback_func", null)

func is_action_disabled(action_name: String) -> bool:
	if action_name in disabled_actions:
		return disabled_actions[action_name]
	return false

func disable_all_actions():
	for action in disabled_actions.keys():
		disable_action(action)
	print("所有动作已被禁用")

func enable_all_actions():
	for action in disabled_actions.keys():
		enable_action(action)
	print("所有动作已被解锁")

# ========== 交互系统 ==========
func register_interactable(v: Interactable):
	if v in interacting_with:
		return
	interacting_with.append(v)

func unregister_interactable(v: Interactable):
	interacting_with.erase(v)

func register_接触触发(v: 接触触发):
	if v in 接触触发_with:
		return
	接触触发_with.append(v)

func unregister_接触触发(v: 接触触发):
	接触触发_with.erase(v)
