class_name Player
extends CharacterBody2D

# 移动参数
@export var move_speed: float = 200.0
@export var jump_velocity: float = -380.0
@export var acceleration: float = 40.0
@export var friction: float = 40.0
@export var attack_duration: float = 0.3
@export var attack_shoot_delay: float = 0.2

# 子弹相关参数
@export var ink_bullet_scene: PackedScene
@export var shoot_offset_x: float = 50.0  # 子弹发射位置的水平偏移
@export var shoot_offset_y: float = 0.0   # 子弹发射位置的垂直偏移

# 召唤商鞅相关参数
@export var shangyang_summon_scene: PackedScene
@export var summon_cooldown: float = 5.0  # 召唤冷却时间
@export var summon_offset_x: float = 100.0  # 召唤位置的水平偏移
@export var summon_offset_y: float = 0.0    # 召唤位置的垂直偏移
@export var summon_delay_in_animation: float = 0.2  # 动画中召唤的延迟时间

## 单次攻击消耗的墨水（与 ATTACK_SHOOT 中扣除量一致）
const ATTACK_INK_COST: int = 1

## world2 剧情完成后解锁；由存档恢复
var shangyang_summon_unlocked: bool = false

# 墨水恢复参数
@export var ink_recovery_rate: float = 1
@export var ink_recovery_interval: float = 0.1
@export var max_ink: float = 100

## 受击：屏幕震动（指数衰减包络 × 振荡）
@export var hit_shake_duration: float = 0.38
@export var hit_shake_amplitude: float = 7.0
@export var hit_shake_decay: float = 10.0
@export var hit_shake_omega: float = 42.0
## 受击：主角 Sprite2D 朝白色插值闪动（0=不变，1=纯白），贴合贴图透明区域
@export_range(0.0, 1.0) var hit_flash_blend_peak: float = 0.88
@export_range(0.0, 1.0) var hit_flash_blend_soft: float = 0.52
@export var hit_flash_pulse_up: float = 0.045
@export var hit_flash_pulse_down: float = 0.055

@onready var interaction_icon: AnimatedSprite2D = $interactionIcon

# 重力
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var stats: Stats

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
@onready var summon_sound: AudioStreamPlayer = $common

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
var _contact_triggers: Array[ContactTrigger] = []

var _hurt_flash_modulate_base: Color = Color.WHITE
var _shake_tween: Tween
var _flash_tween: Tween
var _shake_cam_cached: Camera2D
var _shake_cam_base_saved: Vector2 = Vector2.ZERO
var _focus_cam_cached: Camera2D
var _camera_focus_has_control: bool = false
var _camera_focus_active: bool = false
var _camera_focus_target_world: Vector2 = Vector2.ZERO
var _camera_focus_move_speed: float = 220.0
@onready var _camera_aim_marker: Marker2D = get_node_or_null("CameraAimMarker") as Marker2D

## ===== 相机前瞻（Camera2D.position） =====
@export var camera_lookahead_enabled: bool = true
@export var lookahead_camera_move_speed: float = 320.0
@export var lookahead_x_distance: float = 44.0
@export var lookahead_x_start_speed: float = 10.0
@export var lookahead_y_up_distance: float = 26.0
@export var lookahead_y_down_distance: float = 44.0
@export var lookahead_y_fall_threshold: float = 10.0
@export var lookahead_xy_lerp_speed: float = 10.0

var _lookahead_current: Vector2 = Vector2.ZERO
var _lookahead_wants_fall: bool = false
var _camera_drag_ignore_player_input: bool = false


## 读档用：直接写入 Camera2D.position，避免读档时视野从默认位置闪现
func apply_camera_local_position_from_save(local_pos: Vector2) -> void:
	var cam := _resolve_player_camera2d()
	if cam == null:
		return
	cam.enabled = true
	cam.position = local_pos
	# 同步内部缓存，避免下一帧前瞻/焦点把相机拉走
	_lookahead_current = Vector2.ZERO
	_camera_focus_has_control = false
	_camera_focus_active = false

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
var _last_full_heal_interaction_id: String = ""

func _ready():
	add_to_group("player")
	_resolve_and_bind_stats_source()
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
	_ensure_walk_sound_loop()
	
	# 初始化输入控制
	_init_input_control()
	if sprite != null:
		_hurt_flash_modulate_base = sprite.modulate
	
	# 连接动画完成信号
	if not animation_complete_connected:
		animation_player.animation_finished.connect(_on_animation_finished)
		animation_complete_connected = true
	
	# 等待一帧，让物理系统完全初始化
	await get_tree().physics_frame
	
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


func _resolve_and_bind_stats_source() -> void:
	# 统一血量数据源：优先使用玩家场景下的 Stats（便于在角色预制上直接调参），并同步给 Game 全局引用
	var local_stats := get_node_or_null("Stats") as Stats
	if local_stats != null:
		stats = local_stats
		if is_instance_valid(Game):
			if Game.has_method("bind_player_stats_runtime"):
				Game.call("bind_player_stats_runtime", local_stats)
			else:
				Game.player_stats = local_stats
		return
	if is_instance_valid(Game):
		stats = Game.player_stats

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
	# 墨水回复已改为“墨水格恢复动画结束时发放一次攻击用量”，不再使用连续回复计时器
	ink_recovery_timer.stop()
	
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
			if stats.ink >= ATTACK_INK_COST:
				stats.ink -= ATTACK_INK_COST
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
	if Input.is_action_just_pressed("attack") and can_attack_now():
		start_attack()
		return
	
	# 检查召唤
	if Input.is_action_just_pressed("summon") and can_summon_shangyang_now():
		try_summon_shangyang()
		return
	
	# 应用水平减速
	if velocity.x != 0:
		velocity.x = move_toward(velocity.x, 0, friction)

func update_walk(delta: float):
	var input_direction = Input.get_axis("move_left", "move_right")
	if not walk_sound.playing:
		walk_sound.play()
	
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
	if Input.is_action_just_pressed("attack") and can_attack_now():
		start_attack()
		return
	
	# 检查召唤
	if Input.is_action_just_pressed("summon") and can_summon_shangyang_now():
		try_summon_shangyang()
		return


func _ensure_walk_sound_loop() -> void:
	if walk_sound == null or walk_sound.stream == null:
		return
	var stream := walk_sound.stream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

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
	if Input.is_action_just_pressed("attack") and can_attack_now():
		start_attack()
		return
	
	# 检查召唤
	if Input.is_action_just_pressed("summon") and can_summon_shangyang_now():
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
	if Input.is_action_just_pressed("attack") and can_attack_now():
		start_attack()
		return
	
	# 检查召唤
	if Input.is_action_just_pressed("summon") and can_summon_shangyang_now():
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


func has_active_summoned_shangyang() -> bool:
	for n in get_tree().get_nodes_in_group("shangyang_player_summon"):
		if n is ShangYang and is_instance_valid(n):
			return true
	return false


func can_attack_now() -> bool:
	if not enable_input_control:
		return false
	if attack_cooldown > 0:
		return false
	if stats.ink < ATTACK_INK_COST:
		return false
	return true


func can_summon_shangyang_now() -> bool:
	if not enable_input_control:
		return false
	if not shangyang_summon_unlocked:
		return false
	if not can_summon:
		return false
	if shangyang_summon_scene == null:
		return false
	if has_active_summoned_shangyang():
		return false
	return true


func start_attack():
	if not can_attack_now():
		return
	
	# 切换到攻击状态
	change_state(PlayerState.ATTACK_START)
	attack_cooldown = attack_duration

# ========== 召唤功能 ==========
func unlock_shangyang_summon() -> void:
	shangyang_summon_unlocked = true


func _boss_fatal_summon_warning_active() -> bool:
	var ctrl := get_tree().get_first_node_in_group("boss_phase_controller")
	if ctrl == null or not ctrl.has_method("is_summon_during_fatal_warning_window"):
		return false
	return bool(ctrl.call("is_summon_during_fatal_warning_window"))


func _notify_boss_warning_summon_ready(shangyang: ShangYang) -> void:
	var ctrl := get_tree().get_first_node_in_group("boss_phase_controller")
	if ctrl == null or not ctrl.has_method("on_warning_summoned_shangyang_ready"):
		return
	ctrl.call("on_warning_summoned_shangyang_ready", shangyang)


func try_summon_shangyang():
	"""尝试召唤商鞅"""
	if not can_summon_shangyang_now():
		return
	
	# 启动冷却
	can_summon = false
	summon_cooldown_timer = summon_cooldown
	
	# 切换到召唤开始状态
	change_state(PlayerState.SUMMON_START)
	
	print("开始召唤商鞅，冷却时间: %.1f秒" % summon_cooldown)


func get_summon_cooldown_ratio() -> float:
	if summon_cooldown <= 0.001:
		return 0.0
	return clampf(summon_cooldown_timer / summon_cooldown, 0.0, 1.0)

func execute_summon():
	"""执行召唤商鞅"""
	if not shangyang_summon_scene:
		push_error("无法召唤商鞅：shangyang_summon_scene 未设置！")
		return
	
	# 实例化商鞅
	var shangyang = shangyang_summon_scene.instantiate() as ShangYang
	
	# 计算召唤位置
	var summon_position = calculate_summon_position()
	var boss_fatal_warn := _boss_fatal_summon_warning_active()

	# 设置商鞅位置
	shangyang.global_position = summon_position
	
	# 添加到场景
	get_parent().add_child(shangyang)
	
	if boss_fatal_warn and shangyang.has_method("setup_summoned_for_boss_fatal_warning"):
		shangyang.setup_summoned_for_boss_fatal_warning()
		_notify_boss_warning_summon_ready(shangyang)
	else:
		shangyang.switch_to_summoned_mode()
	
	print("成功召唤商鞅在位置: %s" % str(summon_position))

func calculate_summon_position() -> Vector2:
	"""计算召唤位置"""
	var base_position = global_position
	var offset = Vector2(summon_offset_x, summon_offset_y)
	
	# 根据玩家朝向调整水平偏移
	if direction == 0:  # 向左
		offset.x = -summon_offset_x
	else:
		offset.x = summon_offset_x
	return Vector2(
		base_position.x + offset.x-30,
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
	if not _contact_triggers.is_empty():
		_contact_triggers.back().interact()
	
	# 处理攻击输入
	if Input.is_action_just_pressed("attack") and can_attack_now() and current_state != PlayerState.ATTACK_START and current_state != PlayerState.ATTACK_SHOOT and current_state != PlayerState.ATTACK_END and current_state != PlayerState.SUMMON_START and current_state != PlayerState.STUNNED:
		start_attack()
	
	# 处理召唤输入
	if Input.is_action_just_pressed("summon") and can_summon_shangyang_now() and current_state != PlayerState.SUMMON_START and current_state != PlayerState.STUNNED:
		try_summon_shangyang()
	
	# 应用移动
	move_and_slide()
	
	# 更新朝向
	update_facing()
	# 可选：仅在相机焦点系统接管时更新 Camera2D.position 偏移
	_update_camera_bias(delta)


func _resolve_player_camera2d() -> Camera2D:
	if is_instance_valid(_focus_cam_cached):
		return _focus_cam_cached
	var local_cam := get_node_or_null("Camera2D") as Camera2D
	# 这里不强依赖 enabled：不同世界可能未显式设 current/enabled，但节点仍存在。
	# 当焦点系统接管时，会在 _update_camera_focus_bias 内强制启用以保证生效。
	if local_cam != null:
		_focus_cam_cached = local_cam
		return local_cam
	var vp := get_viewport()
	if vp == null:
		return null
	var vp_cam := vp.get_camera_2d() as Camera2D
	if vp_cam != null and vp_cam.get_parent() == self:
		_focus_cam_cached = vp_cam
		return vp_cam
	return null


func _update_camera_bias(delta: float) -> void:
	if not _camera_focus_has_control and not camera_lookahead_enabled:
		return
	var cam := _resolve_player_camera2d()
	if cam == null:
		_camera_focus_has_control = false
		_camera_focus_active = false
		return
	# 确保本相机成为当前相机，否则 position 偏移不会体现到画面上
	if not cam.enabled:
		cam.enabled = true
	if _camera_drag_ignore_player_input:
		# 拖拽期间，相机不受玩家移动输入影响：前瞻偏移清零并保持
		_lookahead_current = Vector2.ZERO
	else:
		_update_lookahead(delta)
	var base_world := _camera_aim_marker.global_position if _camera_aim_marker != null else global_position
	var base_local := _camera_aim_marker.position if _camera_aim_marker != null else Vector2.ZERO
	var focus_local := Vector2.ZERO
	if _camera_focus_active:
		focus_local = _camera_focus_target_world - base_world
	var desired_local := base_local + focus_local + _lookahead_current
	var spd := _camera_focus_move_speed if _camera_focus_active else lookahead_camera_move_speed
	var step := maxf(1.0, spd) * maxf(delta, 0.0)
	cam.position = cam.position.move_toward(desired_local, step)
	if not _camera_focus_active and not camera_lookahead_enabled and cam.position.length() <= 0.5:
		cam.position = Vector2.ZERO
		_camera_focus_has_control = false


func _update_lookahead(delta: float) -> void:
	if not camera_lookahead_enabled:
		_lookahead_current = _lookahead_current.move_toward(Vector2.ZERO, maxf(1.0, lookahead_xy_lerp_speed) * delta * 60.0)
		return
	var desired_x := 0.0
	if absf(velocity.x) >= lookahead_x_start_speed:
		desired_x = signf(velocity.x) * lookahead_x_distance
	var desired_y := 0.0
	if is_on_floor():
		_lookahead_wants_fall = false
	else:
		# 上升时给上前瞻；当开始明显下落后切到落地前瞻
		if velocity.y > lookahead_y_fall_threshold:
			_lookahead_wants_fall = true
		elif velocity.y < -lookahead_y_fall_threshold:
			_lookahead_wants_fall = false
		desired_y = lookahead_y_down_distance if _lookahead_wants_fall else -lookahead_y_up_distance
	var desired := Vector2(desired_x, desired_y)
	# 指数型平滑（帧率无关）
	var a := 1.0 - exp(-maxf(0.0, lookahead_xy_lerp_speed) * maxf(0.0, delta))
	_lookahead_current = _lookahead_current.lerp(desired, clampf(a, 0.0, 1.0))


## 外部（如 CameraFocusArea）调用：将相机焦点移向一个世界坐标点
func set_camera_focus_target_world(target_world: Vector2, move_speed: float = 220.0) -> void:
	_camera_focus_has_control = true
	_camera_focus_active = true
	_camera_focus_target_world = target_world
	_camera_focus_move_speed = maxf(1.0, move_speed)


## 外部调用：退出焦点区后回正相机；可传回正速度
func clear_camera_focus_target(move_speed: float = -1.0) -> void:
	_camera_focus_active = false
	_camera_focus_has_control = true
	if move_speed > 0.0:
		_camera_focus_move_speed = move_speed


## 外部调用：拖拽期间忽略“玩家输入导致的相机偏移”（不禁用角色操作本身）
func set_camera_drag_ignore_player_input(active: bool) -> void:
	_camera_drag_ignore_player_input = active
	if active:
		_lookahead_current = Vector2.ZERO

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
	if stats == null:
		return
	if damage_amount <= 0.0:
		return
	# Stats.health 是 int；很多敌方伤害是小数（如 0.05），若直接相减会被截断为 0 导致“被打不掉血”。
	var damage_i: int = maxi(1, int(ceil(damage_amount)))
	stats.health -= damage_i
	if stats.health > 0:
		_trigger_hit_screen_feedback()


## 按需求：仅在特定交互（心/剑、存档点）时调用，瞬间回满血
func recover_full_health() -> void:
	recover_full_health_once("__legacy__")


## 仅当 interaction_id 与上次不同才会回满一次；用于“单次有效交互仅回满一次”
func recover_full_health_once(interaction_id: String) -> bool:
	if stats == null:
		return false
	if interaction_id.is_empty():
		return false
	if _last_full_heal_interaction_id == interaction_id:
		return false
	_last_full_heal_interaction_id = interaction_id
	stats.health = stats.max_health
	return true


func _hurt_flash_modulate_toward_white(base: Color, blend: float) -> Color:
	var t := clampf(blend, 0.0, 1.0)
	return Color(lerpf(base.r, 1.0, t), lerpf(base.g, 1.0, t), lerpf(base.b, 1.0, t), base.a)


func _kill_hit_shake_tween() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
		_shake_tween = null
	if is_instance_valid(_shake_cam_cached):
		_shake_cam_cached.offset = _shake_cam_base_saved
		_shake_cam_cached = null


func _kill_sprite_hurt_flash_tween() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
		_flash_tween = null
	if sprite != null and is_instance_valid(sprite):
		sprite.modulate = _hurt_flash_modulate_base


## 交互（心剑、存档点等）：仅屏幕震动，不改变主角闪色
func trigger_hit_shake_only() -> void:
	_kill_hit_shake_tween()
	var cam := get_viewport().get_camera_2d() as Camera2D
	if cam == null:
		return
	_shake_cam_cached = cam
	_shake_cam_base_saved = cam.offset
	_shake_tween = create_tween()
	_shake_tween.tween_method(_hit_shake_step, 0.0, 1.0, hit_shake_duration).set_trans(Tween.TRANS_LINEAR)
	_shake_tween.tween_callback(_hit_shake_reset)


func _run_sprite_hurt_flash_pulse() -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var base := _hurt_flash_modulate_base
	sprite.modulate = base
	var c_peak := _hurt_flash_modulate_toward_white(base, hit_flash_blend_peak)
	var c_soft := _hurt_flash_modulate_toward_white(base, hit_flash_blend_soft)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", c_peak, hit_flash_pulse_up)
	_flash_tween.tween_property(sprite, "modulate", base, hit_flash_pulse_down)
	_flash_tween.tween_property(sprite, "modulate", c_soft, hit_flash_pulse_up * 0.85)
	_flash_tween.tween_property(sprite, "modulate", base, hit_flash_pulse_down)


func _hit_shake_step(u: float) -> void:
	var cam := _shake_cam_cached
	if not is_instance_valid(cam):
		return
	var t: float = u * hit_shake_duration
	var env: float = exp(-hit_shake_decay * t)
	var ox: float = hit_shake_amplitude * env * sin(hit_shake_omega * t)
	var oy: float = hit_shake_amplitude * env * cos(hit_shake_omega * t * 1.07)
	cam.offset = _shake_cam_base_saved + Vector2(ox, oy)


func _hit_shake_reset() -> void:
	if is_instance_valid(_shake_cam_cached):
		_shake_cam_cached.offset = _shake_cam_base_saved
	_shake_cam_cached = null


func _trigger_hit_screen_feedback() -> void:
	_kill_hit_shake_tween()
	_kill_sprite_hurt_flash_tween()
	if sprite != null and is_instance_valid(sprite):
		_hurt_flash_modulate_base = sprite.modulate
	var cam := get_viewport().get_camera_2d() as Camera2D
	if cam != null:
		_shake_cam_cached = cam
		_shake_cam_base_saved = cam.offset
		_shake_tween = create_tween()
		_shake_tween.tween_method(_hit_shake_step, 0.0, 1.0, hit_shake_duration).set_trans(Tween.TRANS_LINEAR)
		_shake_tween.tween_callback(_hit_shake_reset)
	_run_sprite_hurt_flash_pulse()

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
		if event.pressed and not event.echo and event.keycode == KEY_F1:
			unlock_shangyang_summon()
			print("调试后门：已解锁召唤商鞅能力（F1）")
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

func register_contact_trigger(v: ContactTrigger) -> void:
	if v in _contact_triggers:
		return
	_contact_triggers.append(v)


func unregister_contact_trigger(v: ContactTrigger) -> void:
	_contact_triggers.erase(v)
