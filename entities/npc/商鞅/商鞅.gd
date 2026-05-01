
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
	DEAD,       # 死亡状态
	COMMON      # 执行common动画状态
}

# 血量阈值常量
const HEALTH_THRESHOLDS = [0.75, 0.5, 0.25, 0.0]

# 导出变量
@export var current_mode: MODE = MODE.STORY
@export var max_health: float = 10.0
@export var health: float = 10.0
@export var summoned_lifetime_seconds: float = 10.0
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 900.0
@export var hit_knockback_speed_x: float = 120.0
@export var hit_knockback_decay: float = 700.0
@export var player_push_factor: float = 0.35
@export var player_push_max_speed: float = 80.0

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var story_interact: ShangYangStoryInteract = $StoryInteract
@onready var limb_markers_root: Node2D = $LimbMarkers
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var be_pull_sfx: AudioStreamPlayer = get_node_or_null("BePullSfx") as AudioStreamPlayer

# 私有变量
var _current_state: STATE = STATE.IDLE
var _current_form: int = 0  # 当前形态索引 0-3
var _thresholds_passed: Array[int] = []  # 已触发的血量阈值
var _is_dead: bool = false
var _story_form_index: int = 3  # 剧情模式下当前形态索引

# world2 肢体收集剧情
var _limb_pickup_count: int = 0
var _await_ability_dialog_after_get3: bool = false
var _pending_return_sy_dialog_after_camera: bool = false
var _story_get_cutscene_running: bool = false
var _return_sy_dialog_active: bool = false
var _return_sy_dialog_node: Node = null
var _awaiting_npc_interact_for_ability: bool = false
var _listening_for_ability_dialog_signal: bool = false
var _ability_dialog_node: Node = null
var _npc_exiting_after_reward: bool = false
var _disable_destroy_sequence_started: bool = false
## 正在等 Dialogic 全局 timeline_ended，以结束「回去看商鞅」
var _listening_return_sy_timeline: bool = false
## Boss 五马分尸演出后：无碰撞、不受击、不挡子弹，仅作布景
var _ghost_after_boss_pull: bool = false
## Boss 20% 预警期间由玩家召唤：已用 setup_summoned_for_boss_fatal_warning 初始化，_ready 里勿再跑 common
var _boss_fatal_warning_summon_applied: bool = false
## 预警期间召唤的商鞅：无碰撞，但仍受重力；且不进入掉血形态/死亡销毁流程
var _boss_fatal_warning_damage_immune: bool = false
var _summoned_despawn_token: int = 0
var _summoned_despawn_cancelled: bool = false
var _summoned_disappearing: bool = false
const TL_RETURN_SY := "level2/回去看商鞅"
const TL_GAIN_ABILITY := "level2/获得商鞅能力"

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
		if story_interact:
			story_interact.set_interact_enabled(false)
	elif _boss_fatal_warning_summon_applied:
		# 预警期间召唤：已由 setup_summoned_for_boss_fatal_warning 配好，不再播 common
		pass
	else:
		# 召唤模式：先执行common动作
		_initialize_summoned_mode()

func _initialize_story_mode():
	"""初始化剧情模式"""
	remove_from_group("shangyang_player_summon")
	sprite.frame = 19
	_current_state = STATE.IDLE
	_story_form_index = 3
	_is_dead = false
	health = max_health
	_thresholds_passed.clear()

func _initialize_summoned_mode():
	"""初始化召唤模式"""
	add_to_group("shangyang_player_summon")
	_current_state = STATE.COMMON
	_current_form = 0
	_is_dead = false
	health = max_health
	_thresholds_passed.clear()
	
	# 先执行common动作
	if animation_player.has_animation("common"):
		animation_player.play("common")
	else:
		# 如果没有common动画，直接进入idle状态
		print("警告：未找到common动画，直接进入idle状态")
		_current_state = STATE.IDLE
		animation_player.play("idle")
	_start_summoned_lifetime_countdown()

func setup_summoned_for_boss_fatal_warning() -> void:
	"""Boss 20% 预警 UI 期间被玩家召唤：进入 ready_to_pull 动画态，不播 common。"""
	_boss_fatal_warning_summon_applied = true
	_boss_fatal_warning_damage_immune = true
	current_mode = MODE.SUMMONED
	add_to_group("shangyang_player_summon")
	_current_state = STATE.IDLE
	_current_form = 0
	_is_dead = false
	health = max_health
	_thresholds_passed.clear()
	# 按需求：预警期间召唤体仅与环境层碰撞；不与玩家/敌人/敌弹交互
	collision_layer = 16
	collision_mask = 1
	if body_collision != null:
		body_collision.set_deferred("disabled", false)
	if story_interact != null:
		story_interact.monitoring = false
		story_interact.monitorable = false
		story_interact.collision_layer = 0
		story_interact.collision_mask = 0
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	if animation_player and animation_player.has_animation("ready_to_pull"):
		animation_player.play("ready_to_pull")
	cancel_summoned_lifetime_limit()


func switch_to_summoned_mode():
	"""切换到被召唤模式"""
	current_mode = MODE.SUMMONED
	_initialize_summoned_mode()
	add_to_group("shangyang_player_summon")

func switch_to_story_mode():
	"""切换到剧情模式"""
	current_mode = MODE.STORY
	remove_from_group("shangyang_player_summon")
	_summoned_despawn_token += 1
	_summoned_despawn_cancelled = true
	_initialize_story_mode()

func can_accept_limb_pickup() -> bool:
	if _npc_exiting_after_reward:
		return false
	if current_mode != MODE.STORY:
		return false
	if _limb_pickup_count >= 5:
		return false
	if _current_state == STATE.TRANSITION:
		return false
	if _story_get_cutscene_running:
		return false
	if _return_sy_dialog_active:
		return false
	if _awaiting_npc_interact_for_ability:
		return false
	if _listening_for_ability_dialog_signal or _ability_dialog_node != null:
		return false
	return true


func can_use_story_interact() -> bool:
	return _awaiting_npc_interact_for_ability and not _npc_exiting_after_reward and current_mode == MODE.STORY


func is_awaiting_story_interact() -> bool:
	return _awaiting_npc_interact_for_ability


func restore_post_get3_waiting_interact() -> void:
	_awaiting_npc_interact_for_ability = true
	if story_interact:
		story_interact.set_interact_enabled(true)
		call_deferred("_story_interact_refresh_overlapping_player")


func notify_limb_collected() -> void:
	if not can_accept_limb_pickup():
		return
	_story_get_cutscene_running = true
	_limb_pickup_count += 1
	var idx := -1
	match _limb_pickup_count:
		1:
			idx = 0
		3:
			idx = 1
		5:
			_await_ability_dialog_after_get3 = true
			idx = 2
		_:
			_story_get_cutscene_running = false
			return
	call_deferred("_deferred_limb_pickup_cutscene", idx)


func _deferred_limb_pickup_cutscene(animation_index: int) -> void:
	await _run_get_cutscene(animation_index)
	_story_get_cutscene_running = false


func _run_get_cutscene(animation_index: int) -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("run_shangyang_get_cutscene"):
		await scene.run_shangyang_get_cutscene(self, animation_index)
	else:
		play_get_animation(animation_index)
		await animation_player.animation_finished


func consume_pending_return_sy_dialog() -> void:
	if not _pending_return_sy_dialog_after_camera:
		return
	_pending_return_sy_dialog_after_camera = false
	_start_return_to_sy_dialog()


func _disconnect_dialogic_return_sy_listener() -> void:
	var dlg := DialogicUtil.autoload()
	if dlg and dlg.timeline_ended.is_connected(_on_dialogic_timeline_ended_for_return_sy):
		dlg.timeline_ended.disconnect(_on_dialogic_timeline_ended_for_return_sy)
	_listening_return_sy_timeline = false


func _on_dialogic_timeline_ended_for_return_sy() -> void:
	if not _listening_return_sy_timeline or not _return_sy_dialog_active:
		return
	_listening_return_sy_timeline = false
	_disconnect_dialogic_return_sy_listener()
	if _return_sy_dialog_node and is_instance_valid(_return_sy_dialog_node):
		_return_sy_dialog_node.queue_free()
		_return_sy_dialog_node = null
	_return_sy_dialog_active = false
	var sc := get_tree().current_scene
	if sc and sc.has_method("mark_dialog_timeline_completed"):
		sc.mark_dialog_timeline_completed("回去看商鞅")
	_finish_return_sy_dialog_enable_interact()


func _start_return_to_sy_dialog() -> void:
	var scn := get_tree().current_scene
	if scn and scn.has_method("has_completed_timeline") and scn.has_completed_timeline("回去看商鞅"):
		_return_sy_dialog_active = false
		_finish_return_sy_dialog_enable_interact()
		return
	_return_sy_dialog_active = true
	if not Dialogic:
		_return_sy_dialog_active = false
		_finish_return_sy_dialog_enable_interact()
		return
	_disconnect_dialogic_return_sy_listener()
	var dlg := DialogicUtil.autoload()
	if dlg:
		_listening_return_sy_timeline = true
		dlg.timeline_ended.connect(_on_dialogic_timeline_ended_for_return_sy)
	var dialog := Dialogic.start(TL_RETURN_SY)
	if dialog == null:
		dialog = Dialogic.start("回去看商鞅")
	if dialog == null:
		_disconnect_dialogic_return_sy_listener()
		_return_sy_dialog_active = false
		_finish_return_sy_dialog_enable_interact()
		return
	get_tree().current_scene.add_child(dialog)
	_return_sy_dialog_node = dialog


func _finish_return_sy_dialog_enable_interact() -> void:
	_awaiting_npc_interact_for_ability = true
	if story_interact:
		story_interact.set_interact_enabled(true)
		call_deferred("_story_interact_refresh_overlapping_player")


func _story_interact_refresh_overlapping_player() -> void:
	if not is_instance_valid(story_interact) or not story_interact.monitoring:
		return
	var p := get_tree().get_first_node_in_group("player")
	if not p is Player:
		return
	for b in story_interact.get_overlapping_bodies():
		if b == p:
			(p as Player).register_interactable(story_interact)
			return


func on_player_story_interact() -> void:
	if not can_use_story_interact():
		return
	_awaiting_npc_interact_for_ability = false
	if story_interact:
		story_interact.set_interact_enabled(false)
	_start_world2_ability_dialog()


func _start_world2_ability_dialog() -> void:
	var scn2 := get_tree().current_scene
	if scn2 and scn2.has_method("has_completed_timeline") and scn2.has_completed_timeline("获得商鞅能力"):
		_finish_world2_ability_reward_after_dialog()
		return
	if not Dialogic:
		_on_ability_dialogic_signal("ShangYang_dialogic_over")
		return
	var dlg := DialogicUtil.autoload()
	if dlg and not dlg.signal_event.is_connected(_on_ability_dialogic_signal):
		dlg.signal_event.connect(_on_ability_dialogic_signal)
	_listening_for_ability_dialog_signal = true
	var dialog := Dialogic.start(TL_GAIN_ABILITY)
	if dialog == null:
		dialog = Dialogic.start("获得商鞅能力")
	if dialog == null:
		_on_ability_dialogic_signal("ShangYang_dialogic_over")
		return
	get_tree().current_scene.add_child(dialog)
	_ability_dialog_node = dialog


func _disconnect_ability_dialog_listener() -> void:
	var dlg := DialogicUtil.autoload()
	if dlg and dlg.signal_event.is_connected(_on_ability_dialogic_signal):
		dlg.signal_event.disconnect(_on_ability_dialogic_signal)
	_listening_for_ability_dialog_signal = false


func _on_ability_dialogic_signal(sig: String) -> void:
	if sig != "ShangYang_dialogic_over":
		return
	if not _listening_for_ability_dialog_signal:
		return
	_listening_for_ability_dialog_signal = false
	_finish_world2_ability_reward_after_dialog()


func _finish_world2_ability_reward_after_dialog() -> void:
	var scn3 := get_tree().current_scene
	if scn3 and scn3.has_method("mark_dialog_timeline_completed"):
		scn3.mark_dialog_timeline_completed("获得商鞅能力")
	_disconnect_ability_dialog_listener()
	if _ability_dialog_node and is_instance_valid(_ability_dialog_node):
		_ability_dialog_node.queue_free()
		_ability_dialog_node = null
	_grant_player_summon_unlock()
	call_deferred("_run_disable_destroy_sequence")


func _grant_player_summon_unlock() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p is Player and p.has_method("unlock_shangyang_summon"):
		(p as Player).unlock_shangyang_summon()


func _run_disable_destroy_sequence() -> void:
	if not is_inside_tree() or _disable_destroy_sequence_started:
		return
	_disable_destroy_sequence_started = true
	_npc_exiting_after_reward = true
	_disconnect_dialogic_return_sy_listener()
	if story_interact:
		story_interact.set_interact_enabled(false)
	var scene := get_tree().current_scene
	if scene and scene.has_method("mark_shangyang_npc_removed"):
		scene.mark_shangyang_npc_removed()
	if animation_player.has_animation("disable"):
		animation_player.play("disable")
		await animation_player.animation_finished
	else:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.45)
		await tw.finished
	queue_free()


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

func take_damage(damage_amount: float, attacker: Node2D = null):
	"""受到攻击
	
	Args:
		damage_amount: 伤害值
	"""
	if _ghost_after_boss_pull:
		return
	if _is_dead or current_mode != MODE.SUMMONED or _current_state == STATE.COMMON:
		# 在common动画播放期间不接受伤害
		return
	if _boss_fatal_warning_damage_immune:
		return
	_apply_hit_knockback(attacker)
	_apply_summoned_damage(damage_amount)

func _check_health_thresholds():
	"""检查血量是否达到阈值并触发相应动画"""
	if _is_dead or current_mode != MODE.SUMMONED or _current_state == STATE.COMMON:
		# 在common动画播放期间不检查血量阈值
		return
	if _boss_fatal_warning_damage_immune:
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
		STATE.COMMON:
			# common动画播放完成后，进入idle状态
			if current_mode == MODE.SUMMONED:
				_current_state = STATE.IDLE
				animation_player.play("idle")
				print("common动画完成，进入idle状态")
				_start_summoned_lifetime_countdown()
		
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
				safe_destroy()
		
		STATE.TRANSITION:
			# 形态切换动画播放完成
			_current_state = STATE.IDLE
			if str(anim_name) == "get_3" and _await_ability_dialog_after_get3:
				_await_ability_dialog_after_get3 = false
				_pending_return_sy_dialog_after_camera = true
			else:
				print("形态切换完成: %s" % anim_name)
		
		STATE.DEAD:
			# 死亡动画播放完成
			print("死亡动画播放完成")
			safe_destroy()
			# 可以在这里添加死亡后的逻辑，如移除节点、播放特效等

func _process(delta):
	"""每帧更新，用于调试和状态监测"""
	pass


func _start_summoned_lifetime_countdown() -> void:
	if current_mode != MODE.SUMMONED:
		return
	if _boss_fatal_warning_damage_immune:
		return
	if summoned_lifetime_seconds <= 0.0:
		return
	_summoned_despawn_cancelled = false
	_summoned_despawn_token += 1
	var token := _summoned_despawn_token
	_run_summoned_lifetime_countdown(token)


func cancel_summoned_lifetime_limit() -> void:
	_summoned_despawn_cancelled = true
	_summoned_despawn_token += 1


func _run_summoned_lifetime_countdown(token: int) -> void:
	if not is_inside_tree():
		return
	var t := get_tree()
	if t == null:
		return
	await t.create_timer(summoned_lifetime_seconds).timeout
	if not is_inside_tree():
		return
	if token != _summoned_despawn_token:
		return
	if _summoned_despawn_cancelled:
		return
	if _boss_fatal_warning_damage_immune:
		return
	if current_mode != MODE.SUMMONED:
		return
	if _is_dead or _summoned_disappearing:
		return
	await _play_summoned_disappear_and_destroy()


func _play_summoned_disappear_and_destroy() -> void:
	if _summoned_disappearing:
		return
	_summoned_disappearing = true
	if animation_player != null and animation_player.has_animation("disable"):
		animation_player.play("disable")
		await animation_player.animation_finished
	elif is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.45)
		await tw.finished
	if is_inside_tree():
		queue_free()


func _physics_process(delta: float) -> void:
	if _ghost_after_boss_pull:
		return
	var g: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	velocity.y = minf(velocity.y + g * gravity_scale * maxf(0.0, delta), max_fall_speed)
	# 轻微击退速度逐步衰减
	velocity.x = move_toward(velocity.x, 0.0, hit_knockback_decay * maxf(0.0, delta))
	move_and_slide()
	_apply_player_push_resistance()


func _apply_summoned_damage(damage_amount: float) -> void:
	if damage_amount <= 0.0:
		return
	# 减少血量
	health -= damage_amount
	health = max(health, 0.0)
	print("受到伤害: %.2f, 当前血量: %.2f" % [damage_amount, health])
	# 检查血量阈值
	_check_health_thresholds()
	# 如果血量归零，设置为死亡状态
	if health <= 0.0 and not _is_dead:
		_is_dead = true
		_current_state = STATE.DEAD
		print("商鞅已死亡")


func _apply_hit_knockback(attacker: Node2D = null) -> void:
	var dir := -1.0
	if attacker != null and is_instance_valid(attacker):
		dir = -1.0 if attacker.global_position.x < global_position.x else 1.0
	else:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null:
			dir = -1.0 if p.global_position.x < global_position.x else 1.0
	velocity.x = dir * hit_knockback_speed_x


func _apply_player_push_resistance() -> void:
	# 被玩家推动：允许位移，但带阻力（速度较小）
	var cnt := get_slide_collision_count()
	if cnt <= 0:
		return
	for i in range(cnt):
		var col := get_slide_collision(i)
		if col == null:
			continue
		var c := col.get_collider()
		if c is Node and (c as Node).is_in_group("player"):
			var p := c as CharacterBody2D
			if p != null:
				var target_vx := clampf(p.velocity.x * player_push_factor, -player_push_max_speed, player_push_max_speed)
				velocity.x = move_toward(velocity.x, target_vx, maxf(1.0, hit_knockback_decay) * 0.5)
			return


func force_initial_story_form() -> void:
	# Boss 演出时固定显示「商鞅」待拉扯态，不播放其它动画。
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	if animation_player and animation_player.has_animation("ready_to_pull"):
		animation_player.play("ready_to_pull")


func play_be_pull_animation() -> void:
	if be_pull_sfx != null and be_pull_sfx.stream != null:
		be_pull_sfx.play()
	if animation_player and animation_player.has_animation("be_pull"):
		animation_player.play("be_pull")


func enter_post_boss_pull_story_state() -> void:
	_ghost_after_boss_pull = true
	collision_layer = 0
	collision_mask = 0
	for c in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred(&"disabled", true)
		elif c is CollisionPolygon2D:
			(c as CollisionPolygon2D).set_deferred(&"disabled", true)
	if story_interact:
		story_interact.set_interact_enabled(false)
		story_interact.monitoring = false
		story_interact.monitorable = false
		story_interact.collision_layer = 0
		story_interact.collision_mask = 0


func get_limb_marker_nodes() -> Array[Node2D]:
	var markers: Array[Node2D] = []
	if limb_markers_root == null:
		return markers
	for c in limb_markers_root.get_children():
		if c is Node2D:
			markers.append(c as Node2D)
	return markers


func apply_story_progress_without_cutscene(saved_pickup_count: int) -> void:
	if current_mode != MODE.STORY:
		return
	_limb_pickup_count = clampi(saved_pickup_count, 0, 5)
	var idx := -1
	if _limb_pickup_count >= 5:
		idx = 2
	elif _limb_pickup_count >= 4:
		idx = 1
	elif _limb_pickup_count >= 2:
		idx = 0
	if idx >= 0:
		_snap_get_animation_to_end(idx)


func export_story_progress_state() -> Dictionary:
	return {
		"limb_pickup_count": _limb_pickup_count,
		"story_form_index": _story_form_index,
	}


func apply_story_progress_state(state: Dictionary) -> void:
	if current_mode != MODE.STORY:
		return
	_limb_pickup_count = clampi(int(state.get("limb_pickup_count", _limb_pickup_count)), 0, 5)
	var form_idx := clampi(int(state.get("story_form_index", _story_form_index)), 0, 3)
	_story_form_index = form_idx
	match form_idx:
		3:
			if animation_player and animation_player.is_playing():
				animation_player.stop()
			sprite.frame = 19
			_current_state = STATE.IDLE
		2:
			_snap_get_animation_to_end(0)
		1:
			_snap_get_animation_to_end(1)
		0:
			_snap_get_animation_to_end(2)


func _snap_get_animation_to_end(animation_index: int) -> void:
	if animation_index < 0 or animation_index >= _get_animations.size():
		return
	var anim_name := _get_animations[animation_index]
	if not animation_player.has_animation(anim_name):
		return
	_current_state = STATE.TRANSITION
	animation_player.play(anim_name)
	var anim := animation_player.get_animation(anim_name)
	if anim:
		animation_player.seek(anim.length, true)
	_current_state = STATE.IDLE
	_story_form_index = 2 - animation_index

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
	if _ghost_after_boss_pull:
		return
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
