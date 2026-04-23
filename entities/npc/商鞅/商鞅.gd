@tool
class_name ShangYang
extends CharacterBody2D

# 模式枚举
enum MODE {
	SUMMONED,  # 被召唤模式
	STORY      # NPC剧情模式
}

# 状态枚举
enum STATE {
	IDLE,       # 空闲状态
	DAMAGED,    # 受击状态
	TRANSITION, # 形态切换状态
	DEAD        # 死亡状态
}

# 血量阈值常量
const HEALTH_THRESHOLDS = [0.75, 0.5, 0.25, 0.0]

# 导出变量
@export var current_mode: MODE = MODE.STORY
@export var max_health: float = 10.0
@export var health: float = 10.0

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 私有变量
var _current_state: STATE = STATE.IDLE
var _current_form: int = 0  # 当前形态索引 0-3
var _thresholds_passed: Array[int] = []  # 已触发的血量阈值
var _is_dead: bool = false
var _story_form_index: int = 3  # 剧情模式下当前形态索引

# 动画名称映射
var _damage_animations: Array[String] = ["less_1", "less_2", "less_3", "less_4"]
var _get_animations: Array[String] = ["get_1", "get_2", "get_3"]

# 动画完成信号处理
var _animation_complete_signal_connected: bool = false

func _ready():
	# 连接动画完成信号
	if not _animation_complete_signal_connected:
		animation_player.animation_finished.connect(_on_animation_finished)
		_animation_complete_signal_connected = true
	
	# 根据模式初始化
	if current_mode == MODE.STORY:
		# 剧情模式：初始形态为19帧
		_initialize_story_mode()
	else:
		# 召唤模式：播放idle动画
		_initialize_summoned_mode()

func _initialize_story_mode():
	"""初始化剧情模式"""
	sprite.frame = 19
	_current_state = STATE.IDLE
	_story_form_index = 3
	_is_dead = false
	health = max_health
	_thresholds_passed.clear()

func _initialize_summoned_mode():
	"""初始化召唤模式"""
	_current_state = STATE.IDLE
	_current_form = 0
	_is_dead = false
	health = max_health
	_thresholds_passed.clear()
	
	# 播放idle动画
	if animation_player.has_animation("idle"):
		animation_player.play("idle")

func switch_to_summoned_mode():
	"""切换到被召唤模式"""
	current_mode = MODE.SUMMONED
	_initialize_summoned_mode()

func switch_to_story_mode():
	"""切换到剧情模式"""
	current_mode = MODE.STORY
	_initialize_story_mode()

func play_get_animation(animation_index: int = 0):
	"""播放获取形态的动画 (剧情模式使用)
	
	Args:
		animation_index: 0=get_1, 1=get_2, 2=get_3
	"""
	if current_mode != MODE.STORY:
		push_warning("只能在剧情模式下播放获取动画")
		return
	
	if animation_index < 0 or animation_index >= _get_animations.size():
		push_error("无效的动画索引: %d" % animation_index)
		return
	
	var anim_name = _get_animations[animation_index]
	if animation_player.has_animation(anim_name):
		_current_state = STATE.TRANSITION
		animation_player.play(anim_name)
		
		# 更新剧情形态索引
		_story_form_index = 2 - animation_index  # get_1->2, get_2->1, get_3->0
	else:
		push_error("动画不存在: %s" % anim_name)

func play_next_get_animation():
	"""播放下一个获取动画 (剧情模式下按顺序播放)"""
	if _story_form_index > 0:
		var next_anim_index = 2 - _story_form_index
		play_get_animation(next_anim_index)
	else:
		print("已经是最终形态")

func take_damage(damage_amount: float):
	"""受到攻击
	
	Args:
		damage_amount: 伤害值
	"""
	if _is_dead or current_mode != MODE.SUMMONED:
		return
	
	# 减少血量
	health -= damage_amount
	health = max(health, 0.0)
	
	print("受到伤害: %.1f, 当前血量: %.1f" % [damage_amount, health])
	
	# 可以在这里添加击退效果
	# 例如: apply_knockback(direction)
	
	# 检查血量阈值
	_check_health_thresholds()
	
	# 如果血量归零，设置为死亡状态
	if health <= 0.0 and not _is_dead:
		_is_dead = true
		_current_state = STATE.DEAD
		print("商鞅已死亡")

func _check_health_thresholds():
	"""检查血量是否达到阈值并触发相应动画"""
	if _is_dead or current_mode != MODE.SUMMONED:
		return
	
	var health_percent = health / max_health
	
	# 从高到低检查每个阈值
	for i in range(HEALTH_THRESHOLDS.size() - 1, -1, -1):
		var threshold = HEALTH_THRESHOLDS[i]
		
		# 如果血量低于阈值且还未触发这个阈值
		if health_percent <= threshold and not _thresholds_passed.has(i):
			# 标记这个阈值已触发
			_thresholds_passed.append(i)
			
			# 播放对应的伤害动画
			_play_damage_animation(i)
			break

func _play_damage_animation(threshold_index: int):
	"""播放伤害动画
	
	Args:
		threshold_index: 阈值索引
	"""
	if threshold_index >= 0 and threshold_index < _damage_animations.size():
		var anim_name = _damage_animations[threshold_index]
		
		if animation_player.has_animation(anim_name):
			_current_state = STATE.DAMAGED
			
			# 停止当前动画
			if animation_player.is_playing():
				animation_player.stop()
			
			# 播放伤害动画
			animation_player.play(anim_name)
			
			# 更新当前形态
			_current_form = threshold_index
			
			print("血量降至 %d%%, 播放动画: %s" % [int(HEALTH_THRESHOLDS[threshold_index] * 100), anim_name])
		else:
			push_error("动画不存在: %s" % anim_name)

func _on_animation_finished(anim_name: String):
	"""动画播放完成时的回调"""
	
	match _current_state:
		STATE.DAMAGED:
			# 伤害动画播放完成后
			if not _is_dead and health > 0.0:
				_current_state = STATE.IDLE
				# 注意：根据需求，播放75%血以后就不再播放idle动画
				# 所以我们只在第一次受伤前（即血量>75%）才返回idle状态
				if health / max_health > 0.75:
					animation_player.play("idle")
			elif _is_dead:
				# 如果已经死亡，销毁节点
				print("血量归零，销毁商鞅节点")
				queue_free()
		
		STATE.TRANSITION:
			# 形态切换动画播放完成
			_current_state = STATE.IDLE
			print("形态切换完成: %s" % anim_name)
		
		STATE.DEAD:
			# 死亡动画播放完成
			print("死亡动画播放完成")
			safe_destroy()
			# 可以在这里添加死亡后的逻辑，如移除节点、播放特效等

func _process(delta):
	"""每帧更新，用于调试和状态监测"""
	pass  # 可以根据需要添加逻辑

# 调试函数
func get_status() -> Dictionary:
	"""获取当前状态信息"""
	return {
		"mode": "召唤模式" if current_mode == MODE.SUMMONED else "剧情模式",
		"state": _current_state,
		"health": health,
		"max_health": max_health,
		"health_percent": (health / max_health) * 100.0,
		"current_form": _current_form,
		"is_dead": _is_dead,
		"thresholds_passed": _thresholds_passed
	}

# 安全销毁函数
func safe_destroy():
	"""安全销毁节点，避免在动画播放中销毁"""
	if animation_player.is_playing():
		# 如果正在播放动画，等待动画完成
		await animation_player.animation_finished
		queue_free()
	else:
		queue_free()

# 示例用法注释：
# 1. 在剧情模式下调用 play_get_animation(0) 播放get_1动画
# 2. 在剧情模式下调用 play_get_animation(1) 播放get_2动画  
# 3. 在剧情模式下调用 play_get_animation(2) 播放get_3动画
# 4. 在召唤模式下调用 take_damage(10) 受到10点伤害
# 5. 调用 switch_to_summoned_mode() 切换到召唤模式
# 6. 调用 switch_to_story_mode() 切换到剧情模式
# 7. 血量归零时，播放完切换动画后自动销毁
