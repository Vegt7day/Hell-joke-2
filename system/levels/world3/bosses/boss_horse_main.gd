extends CharacterBody2D
## 主马：受击体、跳跃与四马技能调度入口（占位）。
## 子节点：`Stats`、`AnimationPlayer`、`Abilities`、`CanvasLayer/boss_health_bar` 等。

@export var auto_cast_enabled: bool = true
@export var cast_check_interval: float = 0.2
@export var move_left_speed: float = 90.0
@export var respawn_margin: float = 120.0
@export var offscreen_respawn_delay_seconds: float = 1.0
## 传送回屏幕右侧时，Y 定位在摄像机下 1/4 高度（基于可视半高的一半）。
@export var respawn_y_quarter_down_factor: float = 0.5
## Y 轴追踪：纯跟随 + 延后（非 PID）
@export var y_follow_full_tilt_distance: float = 220.0
@export var y_follow_lag_seconds: float = 0.45
## X 轴始终向左；当越过玩家后不再改变 X 方向（不转向右）
@export var stop_x_adjust_after_pass_player: bool = true
## 灰马技能：朝左冲刺
@export var grey_dash_distance: float = 220.0
@export var grey_dash_duration: float = 0.32
## 白马技能：召唤剑
const DEFAULT_SWORD_SCENE := preload("res://system/levels/world3/props/projectile_white_horse.tscn")
@export var sword_scene: PackedScene = DEFAULT_SWORD_SCENE
@export var white_cast_repeat: int = 2
@export var white_sword_count_per_cast: int = 1
@export var white_sword_spawn_delay: float = 0.12
## 红马技能：召唤炸弹
const DEFAULT_RED_BOMB_SCENE := preload("res://system/levels/world3/props/bomb_red_horse.tscn")
@export var red_bomb_scene: PackedScene = DEFAULT_RED_BOMB_SCENE
@export var red_bomb_count_per_cast: int = 1
@export var red_bomb_spawn_delay: float = 0.15
## 黑马技能：召唤分身（弱化版，外观与主马一致）
const DEFAULT_MAIN_CLONE_SCENE := preload("res://system/levels/world3/bosses/boss_horse_main.tscn")
@export var black_clone_scene: PackedScene = DEFAULT_MAIN_CLONE_SCENE
## 由大黑马召唤的分身为 true（不扣共享血条、不自动放 Boss 技能）
@export var is_summoned_clone: bool = false
@export var black_clone_cast_count: int = 2
@export var black_clone_cast_interval: float = 9.5
@export var black_clone_fade_out_seconds: float = 0.25

@onready var stats: Stats = $Stats
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: Node2D = $CanvasLayer/boss_health_bar

var _phase_controller: Node
var _intro_timeline_done: bool = false
var _is_casting_skill: bool = false
var _cast_accumulator: float = 0.0
var _cooldown_left: float = 0.0
var _shared_skill_cooldown: float = 10.0
var _unlocked_skills: Array[BossHorseTypes.HorseId] = [BossHorseTypes.HorseId.GREY]
var _movement_enabled: bool = true
var _offscreen_elapsed: float = 0.0
var _smoothed_y_cmd: float = 0.0


func _ready() -> void:
	if is_summoned_clone:
		add_to_group("boss_horse_main_summoned_clone")
		auto_cast_enabled = false
		_intro_timeline_done = true
		if has_node("CanvasLayer"):
			$CanvasLayer.visible = false
		if stats:
			stats.process_mode = Node.PROCESS_MODE_DISABLED
		if animation_player and animation_player.has_animation(&"jump"):
			animation_player.play(&"jump")
		set_movement_enabled(true)
		return

	add_to_group("boss_horse_main")
	add_to_group("boss_horse_shared_target")
	_resolve_phase_controller()
	if health_bar and health_bar.has_method("set_stats"):
		var shared_stats := stats
		if _phase_controller and _phase_controller.has_method("get_shared_stats"):
			var queried := _phase_controller.get_shared_stats() as Stats
			if queried:
				shared_stats = queried
		health_bar.set_stats(shared_stats)

	if animation_player and animation_player.has_animation(&"jump"):
		animation_player.play(&"jump")

	if _phase_controller:
		if _phase_controller.has_signal("phase_changed") and not _phase_controller.phase_changed.is_connected(_on_phase_changed):
			_phase_controller.phase_changed.connect(_on_phase_changed)
		if _phase_controller.has_signal("intro_timeline_finished") and not _phase_controller.intro_timeline_finished.is_connected(_on_intro_timeline_finished):
			_phase_controller.intro_timeline_finished.connect(_on_intro_timeline_finished)
		if "main_skill_shared_cooldown" in _phase_controller:
			_shared_skill_cooldown = float(_phase_controller.main_skill_shared_cooldown)
		var phase_value: Variant = _phase_controller.get("current_phase")
		if phase_value is int:
			_on_phase_changed(phase_value as BossHorseTypes.BossPhase)
	else:
		# 无控制器时允许本地测试技能循环。
		_intro_timeline_done = true


func _process(delta: float) -> void:
	if is_summoned_clone:
		return
	if not _movement_enabled:
		return
	if not auto_cast_enabled or not _intro_timeline_done:
		return
	if _is_casting_skill:
		return
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		return
	_cast_accumulator += delta
	if _cast_accumulator < cast_check_interval:
		return
	_cast_accumulator = 0.0
	call_deferred("_try_cast_random_skill")


func _physics_process(delta: float) -> void:
	if not _movement_enabled:
		velocity = Vector2.ZERO
		_offscreen_elapsed = 0.0
		return
	if _is_outside_camera_bounds():
		_offscreen_elapsed += delta
		if _offscreen_elapsed >= offscreen_respawn_delay_seconds:
			_respawn_to_camera_right_quarter_down()
			_offscreen_elapsed = 0.0
	else:
		_offscreen_elapsed = 0.0
	velocity = _compute_pid_tracking_velocity(delta)
	move_and_slide()


func take_damage(damage_amount: float, _attacker: Variant = null) -> void:
	if is_summoned_clone:
		return
	# 主马与四马共享同一血条：统一走 PhaseController 结算。
	if _phase_controller == null:
		_resolve_phase_controller()
	if _phase_controller and _phase_controller.has_method("apply_shared_damage"):
		_phase_controller.apply_shared_damage(damage_amount, name)
		return
	stats.health -= int(round(damage_amount))
	print("[BossMain] 受伤(降级路径) damage=", damage_amount, " hp=", stats.health)


func _resolve_phase_controller() -> void:
	_phase_controller = get_tree().get_first_node_in_group("boss_phase_controller")
	if _phase_controller:
		return
	var current_scene := get_tree().current_scene
	if current_scene:
		_phase_controller = current_scene.get_node_or_null("Systems/PhaseController")


func _on_intro_timeline_finished() -> void:
	_intro_timeline_done = true
	print("[BossMain] 入场 Timeline 完成，开始技能循环。")


func _on_phase_changed(new_phase: BossHorseTypes.BossPhase) -> void:
	match new_phase:
		BossHorseTypes.BossPhase.GREY_SOLO:
			_unlocked_skills = [BossHorseTypes.HorseId.GREY]
			print("[BossMain] 技能池：仅灰马技能。")
		BossHorseTypes.BossPhase.WHITE_SOLO:
			_unlocked_skills = [BossHorseTypes.HorseId.GREY, BossHorseTypes.HorseId.WHITE]
			print("[BossMain] 技能池：灰 + 白。")
		BossHorseTypes.BossPhase.BLACK_SOLO, BossHorseTypes.BossPhase.RED_SOLO:
			_unlocked_skills = [
				BossHorseTypes.HorseId.GREY,
				BossHorseTypes.HorseId.WHITE,
				BossHorseTypes.HorseId.BLACK,
				BossHorseTypes.HorseId.RED
			]
			print("[BossMain] 技能池：灰 + 白 + 黑 + 红。")
		BossHorseTypes.BossPhase.ALL_HORSES, BossHorseTypes.BossPhase.CHAIN_CINEMATIC:
			# 与红马单马阶段相同：四色技能全开
			_unlocked_skills = [
				BossHorseTypes.HorseId.GREY,
				BossHorseTypes.HorseId.WHITE,
				BossHorseTypes.HorseId.BLACK,
				BossHorseTypes.HorseId.RED
			]
			print("[BossMain] 技能池：五马合围（灰+白+黑+红）。")
		_:
			pass


func _try_cast_random_skill() -> void:
	if _is_casting_skill:
		return
	if _unlocked_skills.is_empty():
		return
	_is_casting_skill = true
	var picked := _unlocked_skills[randi() % _unlocked_skills.size()]
	match picked:
		BossHorseTypes.HorseId.GREY:
			await _cast_grey_skill()
		BossHorseTypes.HorseId.WHITE:
			await _cast_white_skill()
		BossHorseTypes.HorseId.BLACK:
			await _cast_black_skill()
		BossHorseTypes.HorseId.RED:
			await _cast_red_skill()
		_:
			await _cast_grey_skill()
	_cooldown_left = _shared_skill_cooldown
	_is_casting_skill = false


func _cast_grey_skill() -> void:
	await _play_optional(&"to grey")
	await _play_optional(&"grey_ready")
	if animation_player and animation_player.has_animation(&"grey_running"):
		animation_player.play(&"grey_running")
	var dash_to := global_position + Vector2.LEFT * grey_dash_distance
	await _move_to_position(dash_to, grey_dash_duration)
	await _play_optional(&"grey_over")
	_restore_idle_jump()


func _cast_white_skill() -> void:
	await _play_optional(&"to white")
	var repeat_count := clampi(white_cast_repeat, 1, 2)
	for i in repeat_count:
		if i > 0:
			await get_tree().create_timer(white_sword_spawn_delay).timeout
		await _play_optional(&"white_call")
		await _spawn_white_swords(white_sword_count_per_cast)
	await _play_optional(&"to grey")
	_restore_idle_jump()


func _cast_black_skill() -> void:
	await _play_optional(&"to_black")
	await _play_optional(&"black_ready")
	var clone := _spawn_black_clone()
	var clone_ap := _get_clone_animation_player(clone)
	var call_len := _play_anim_sync(animation_player, clone_ap, &"black_call", 0.12)
	if call_len > 0.0:
		await get_tree().create_timer(call_len).timeout
	if clone and is_instance_valid(clone):
		call_deferred("_run_black_clone_skill_loop", clone)
	await _play_optional(&"to grey")
	_restore_idle_jump()


func _cast_red_skill() -> void:
	await _play_optional(&"to red")
	await _play_optional(&"red_ready")
	await _play_optional(&"red_call")
	await _spawn_red_bombs(red_bomb_count_per_cast)
	await _play_optional(&"to grey")
	_restore_idle_jump()


func _restore_idle_jump() -> void:
	if animation_player and animation_player.has_animation(&"jump"):
		animation_player.play(&"jump")


func _play_optional(anim_name: StringName, fallback_seconds: float = 0.15) -> void:
	if animation_player == null or not animation_player.has_animation(anim_name):
		await get_tree().create_timer(fallback_seconds).timeout
		return
	animation_player.play(anim_name)
	var length := animation_player.get_animation(anim_name).length
	if length <= 0.0:
		length = fallback_seconds
	await get_tree().create_timer(length).timeout


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO


func _move_to_position(target: Vector2, duration: float) -> void:
	var prev_move := _movement_enabled
	_movement_enabled = false
	velocity = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, NodePath("global_position"), target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_movement_enabled = prev_move


func _is_outside_camera_bounds() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	var size := vp.get_visible_rect().size
	var center := cam.get_screen_center_position()
	var half_w := size.x * 0.5 * cam.zoom.x
	var half_h := size.y * 0.5 * cam.zoom.y
	if global_position.x < center.x - half_w - respawn_margin:
		return true
	if global_position.x > center.x + half_w + respawn_margin:
		return true
	if global_position.y < center.y - half_h - respawn_margin:
		return true
	if global_position.y > center.y + half_h + respawn_margin:
		return true
	return false


func _respawn_to_camera_right_quarter_down() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var size := vp.get_visible_rect().size
	var center := cam.get_screen_center_position()
	var half_w := size.x * 0.5 * cam.zoom.x
	var half_h := size.y * 0.5 * cam.zoom.y
	global_position.x = center.x + half_w + respawn_margin
	global_position.y = center.y + half_h * clampf(respawn_y_quarter_down_factor, 0.0, 1.0)
	_smoothed_y_cmd = 0.0


func _compute_pid_tracking_velocity(delta: float) -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var x_cmd := -1.0
	if stop_x_adjust_after_pass_player and player != null and global_position.x <= player.global_position.x:
		x_cmd = -1.0
	var desired_y_cmd := 0.0
	if player != null:
		var err := player.global_position.y - global_position.y
		var denom := maxf(1.0, y_follow_full_tilt_distance)
		desired_y_cmd = clampf(err / denom, -1.0, 1.0)
	var follow_lag := maxf(0.01, y_follow_lag_seconds)
	var t := clampf(delta / follow_lag, 0.0, 1.0)
	_smoothed_y_cmd = lerpf(_smoothed_y_cmd, desired_y_cmd, t)
	var cmd := Vector2(x_cmd, _smoothed_y_cmd)
	if cmd.length_squared() <= 0.0001:
		cmd = Vector2.LEFT
	return cmd.normalized() * move_left_speed


func _get_view_bounds_x() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Vector2(-10000.0, 10000.0)
	var rect := get_viewport_rect().size
	var half_w := rect.x * 0.5 * camera.zoom.x
	var center := camera.get_screen_center_position()
	return Vector2(center.x - half_w, center.x + half_w)


func _spawn_white_swords(spawn_count: int) -> void:
	if sword_scene == null:
		return
	var spawn := get_node_or_null("SummonMarkers/ProjectileSpawn") as Node2D
	if spawn == null:
		push_warning("主马缺少 SummonMarkers/ProjectileSpawn，无法召唤剑。")
		return
	var root := get_node_or_null("../PropsSpawn/ProjectilesRoot") as Node2D
	if root == null:
		root = get_parent() as Node2D

	var count := clampi(spawn_count, 1, 2)
	for i in count:
		if i > 0:
			await get_tree().create_timer(white_sword_spawn_delay).timeout
		var sword := sword_scene.instantiate() as Node2D
		if sword == null:
			continue
		root.add_child(sword)
		sword.global_position = spawn.global_position + Vector2(0, -6 * i)


func _spawn_red_bombs(spawn_count: int) -> void:
	if red_bomb_scene == null:
		return
	var target_pos := _get_player_position_or_fallback(global_position)
	var root := get_node_or_null("../PropsSpawn/ProjectilesRoot") as Node2D
	if root == null:
		root = get_parent() as Node2D
	var count := clampi(spawn_count, 1, 3)
	for i in count:
		if i > 0:
			await get_tree().create_timer(red_bomb_spawn_delay).timeout
		var bomb := red_bomb_scene.instantiate() as Node2D
		if bomb == null:
			continue
		root.add_child(bomb)
		bomb.global_position = target_pos + Vector2(-18 * i, 0)


func _spawn_black_clone() -> CharacterBody2D:
	if black_clone_scene == null:
		return null
	var root := get_parent() as Node2D
	if root == null:
		return null
	var clone := black_clone_scene.instantiate() as CharacterBody2D
	if clone == null:
		return null
	if "is_summoned_clone" in clone:
		clone.set("is_summoned_clone", true)
	root.add_child(clone)
	clone.global_position = global_position + Vector2(-56, 0)
	if clone.has_method("set_movement_enabled"):
		clone.call("set_movement_enabled", true)
	return clone


func _run_black_clone_skill_loop(clone: CharacterBody2D) -> void:
	if clone == null or not is_instance_valid(clone):
		return
	if clone.has_method("set_movement_enabled"):
		clone.call("set_movement_enabled", false)
	var loops := clampi(black_clone_cast_count, 1, 2)
	for i in loops:
		if i > 0:
			await get_tree().create_timer(black_clone_cast_interval).timeout
		if clone == null or not is_instance_valid(clone):
			return
		var skill := _pick_clone_skill()
		await _cast_clone_skill(clone, skill)
		if clone and is_instance_valid(clone) and clone.has_method("set_movement_enabled"):
			clone.call("set_movement_enabled", true)
	if clone and is_instance_valid(clone):
		if clone.has_method("set_movement_enabled"):
			clone.call("set_movement_enabled", false)
		await _fade_and_free_clone(clone)


func _pick_clone_skill() -> BossHorseTypes.HorseId:
	var choices: Array[BossHorseTypes.HorseId] = []
	for id in _unlocked_skills:
		if id != BossHorseTypes.HorseId.BLACK:
			choices.append(id)
	if choices.is_empty():
		choices = [BossHorseTypes.HorseId.GREY]
	return choices[randi() % choices.size()]


func _cast_clone_skill(clone: CharacterBody2D, skill: BossHorseTypes.HorseId) -> void:
	var ap := clone.get_node_or_null("AnimationPlayer") as AnimationPlayer
	match skill:
		BossHorseTypes.HorseId.GREY:
			await _play_optional_on(ap, &"to grey", 0.05)
			await _play_optional_on(ap, &"grey_ready", 0.05)
			if ap:
				if ap.has_animation(&"grey_running"):
					ap.play(&"grey_running")
				elif ap.has_animation(&"grey_run"):
					ap.play(&"grey_run")
			var to := clone.global_position + Vector2.LEFT * grey_dash_distance
			await _move_node_to(clone, to, grey_dash_duration * 2.0)
			await _play_optional_on(ap, &"grey_over", 0.05)
			await _play_optional_on(ap, &"to_black", 0.05)
		BossHorseTypes.HorseId.WHITE:
			await _play_optional_on(ap, &"to white", 0.05)
			await _play_optional_on(ap, &"white_ready", 0.05)
			await _play_optional_on(ap, &"white_call", 0.05)
			await _spawn_white_sword_at(clone.global_position)
			await _play_optional_on(ap, &"to_black", 0.05)
		BossHorseTypes.HorseId.RED:
			# 红马技能占位：分身阶段暂不释放
			await get_tree().create_timer(0.2).timeout
		_:
			pass
	_restore_clone_idle_jump(ap)


func _spawn_white_sword_at(spawn_pos: Vector2) -> void:
	if sword_scene == null:
		return
	var root := get_node_or_null("../PropsSpawn/ProjectilesRoot") as Node2D
	if root == null:
		root = get_parent() as Node2D
	var sword := sword_scene.instantiate() as Node2D
	if sword == null:
		return
	root.add_child(sword)
	sword.global_position = spawn_pos


func _move_node_to(node: Node2D, target: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, NodePath("global_position"), target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _fade_and_free_clone(clone: CharacterBody2D) -> void:
	var sprite := clone.get_node_or_null("Sprite2D") as CanvasItem
	if sprite:
		var tw := create_tween()
		tw.tween_property(sprite, NodePath("modulate:a"), 0.0, black_clone_fade_out_seconds)
		await tw.finished
	clone.queue_free()


func _get_clone_animation_player(clone: CharacterBody2D) -> AnimationPlayer:
	if clone == null or not is_instance_valid(clone):
		return null
	return clone.get_node_or_null("AnimationPlayer") as AnimationPlayer


func _play_anim_sync(a: AnimationPlayer, b: AnimationPlayer, anim_name: StringName, fallback_seconds: float = 0.12) -> float:
	var length := 0.0
	if a and a.has_animation(anim_name):
		a.play(anim_name)
		length = maxf(length, a.get_animation(anim_name).length)
	if b and b.has_animation(anim_name):
		b.play(anim_name)
		length = maxf(length, b.get_animation(anim_name).length)
	if length <= 0.0:
		length = fallback_seconds
	return length


func _get_player_position_or_fallback(fallback: Vector2) -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		return player.global_position
	return fallback


func _play_optional_on(ap: AnimationPlayer, anim_name: StringName, fallback_seconds: float = 0.08) -> void:
	if ap == null or not ap.has_animation(anim_name):
		await get_tree().create_timer(fallback_seconds).timeout
		return
	ap.play(anim_name)
	var length := ap.get_animation(anim_name).length
	if length <= 0.0:
		length = fallback_seconds
	await get_tree().create_timer(length).timeout


func _restore_clone_idle_jump(ap: AnimationPlayer) -> void:
	if ap and ap.has_animation(&"jump"):
		ap.play(&"jump")
