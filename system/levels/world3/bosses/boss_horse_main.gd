extends CharacterBody2D
## 主马：受击体、跳跃与四马技能调度入口（占位）。
## 子节点：`Stats`、`AnimationPlayer`、`Abilities`、`CanvasLayer/boss_health_bar` 等。

@export var auto_cast_enabled: bool = true
@export var cast_check_interval: float = 0.2
@export var move_left_speed: float = 78.0
@export var respawn_margin: float = 120.0
## 离开摄像机可视区后，累计该秒数再传送到屏幕右侧外（其余传送参数仍用 respawn_margin、respawn_y_quarter_down_factor）
@export var offscreen_respawn_delay_seconds: float = 0.5
## 仅当角色 X 在「视口左缘向内」与「视口右缘向内」之间时才开始释放技能；否则等下次进入该带再释放
@export var skill_cast_inset_from_left_px: float = 256.0
@export var skill_cast_inset_from_right_px: float = 16.0
## 传送回屏幕右侧时，Y 定位在摄像机下 1/4 高度（基于可视半高的一半）。
@export var respawn_y_quarter_down_factor: float = 0.5
## Y 轴追踪：纯跟随 + 延后（非 PID）
@export var y_follow_full_tilt_distance: float = 220.0
@export var y_follow_lag_seconds: float = 0.45
## X 轴始终向左；当越过玩家后不再改变 X 方向（不转向右）
@export var stop_x_adjust_after_pass_player: bool = true
## 灰马技能：朝左冲刺
@export var grey_dash_distance: float = 200.0
@export var grey_dash_duration: float = 0.34
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
const _PLAYER_BUMP_AREA := preload("res://system/levels/world3/bosses/boss_horse_player_bump_area.gd")
const ENTRY_FONT := preload("res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf")
const SKILL_FEED_ROW_SCENE := preload("res://system/levels/world3/ui/skill_feed_row.tscn")
@export var black_clone_scene: PackedScene = DEFAULT_MAIN_CLONE_SCENE
## 由大黑马召唤的分身为 true（不扣共享血条、不自动放 Boss 技能）
@export var is_summoned_clone: bool = false
@export var black_clone_cast_count: int = 2
@export var black_clone_cast_interval: float = 9.5
@export var black_clone_fade_out_seconds: float = 0.25
@export var skill_feed_root_path: NodePath = NodePath("../../Systems/UIHints/SkillFeedRoot")
@export var skill_feed_max_rows: int = 5 ## 弹幕轨道数
@export var skill_feed_row_height: float = 28.0
@export var skill_feed_text_width: float = 304.0
@export var skill_feed_danmaku_speed: float = 220.0
@export var skill_feed_lane_enter_margin: float = 8.0
@export var skill_feed_spawn_offset_x: float = 16.0

@onready var stats: Stats = $Stats
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: Node2D = $CanvasLayer/boss_health_bar
@onready var _grey_dash_sfx: AudioStreamPlayer = $GreyDashSfx
@onready var _black_clone_sfx: AudioStreamPlayer = $BlackCloneSfx

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
var _skill_feed_lane_active: Array[Control] = []


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
		process_mode = Node.PROCESS_MODE_INHERIT
		# 分身为 is_summoned_clone 时提前 return，先补碰撞区，再做一帧后重试，避免入树时机偶发缺失。
		_ensure_player_bump_area()
		call_deferred("_ensure_player_bump_area")
		call_deferred("_bootstrap_summoned_clone_walk_state")
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

	_ensure_player_bump_area()


func _ensure_player_bump_area() -> void:
	if get_node_or_null("PlayerBumpArea") != null:
		return
	var a := _PLAYER_BUMP_AREA.new() as BossHorsePlayerBumpArea
	a.name = "PlayerBumpArea"
	a.apply_standard_bump_preset()
	a.setup_shape_from_horse(self)
	add_child(a)


func _process(delta: float) -> void:
	if is_summoned_clone:
		return
	if not _movement_enabled:
		return
	if not auto_cast_enabled or not _intro_timeline_done:
		return
	if _is_casting_skill:
		return
	# 20% 致命演出：主马技能与回场暂停（已开始的技能不受影响）
	if _is_fatal_pull_sequence_active():
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
			if not _is_fatal_pull_sequence_active():
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


func _is_fatal_pull_sequence_active() -> bool:
	if _phase_controller == null:
		_resolve_phase_controller()
	if _phase_controller != null and is_instance_valid(_phase_controller) and _phase_controller.has_method("is_fatal_pull_sequence_active"):
		return bool(_phase_controller.call("is_fatal_pull_sequence_active"))
	return false


func _on_intro_timeline_finished() -> void:
	_intro_timeline_done = true
	print("[BossMain] 入场 Timeline 完成，开始技能循环。")


func _on_phase_changed(new_phase: BossHorseTypes.BossPhase) -> void:
	# 兜底：只要阶段推进到战斗阶段，就保证主马技能循环开启。
	if new_phase != BossHorseTypes.BossPhase.INTRO:
		_intro_timeline_done = true
		auto_cast_enabled = true
	match new_phase:
		BossHorseTypes.BossPhase.GREY_SOLO:
			_unlocked_skills = [BossHorseTypes.HorseId.GREY]
			print("[BossMain] 技能池：仅灰马技能。")
		BossHorseTypes.BossPhase.WHITE_SOLO:
			_unlocked_skills = [BossHorseTypes.HorseId.GREY, BossHorseTypes.HorseId.WHITE]
			print("[BossMain] 技能池：灰 + 白。")
		BossHorseTypes.BossPhase.BLACK_SOLO:
			_unlocked_skills = [
				BossHorseTypes.HorseId.GREY,
				BossHorseTypes.HorseId.WHITE,
				BossHorseTypes.HorseId.BLACK
			]
			print("[BossMain] 技能池：灰 + 白 + 黑。")
		BossHorseTypes.BossPhase.RED_SOLO:
			_unlocked_skills = [
				BossHorseTypes.HorseId.GREY,
				BossHorseTypes.HorseId.WHITE,
				BossHorseTypes.HorseId.BLACK,
				BossHorseTypes.HorseId.RED
			]
			print("[BossMain] 技能池：灰 + 白 + 黑 + 红（红马解锁）。")
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
	if not _is_in_skill_cast_horizontal_band(self):
		return
	_is_casting_skill = true
	var picked := _unlocked_skills[randi() % _unlocked_skills.size()]
	_show_skill_broadcast(picked, true)
	# 按需求：小马技能播报也要出现（与皇马播报并行入队）
	_show_skill_broadcast(picked, false)
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
	if _grey_dash_sfx and _grey_dash_sfx.stream:
		_grey_dash_sfx.play()
	_toggle_root_collision_shape_disabled(false)
	if animation_player and animation_player.has_animation(&"grey_running"):
		animation_player.play(&"grey_running")
	var dash_to := global_position + Vector2.LEFT * grey_dash_distance
	await _move_to_position(dash_to, grey_dash_duration)
	_toggle_root_collision_shape_disabled(true)
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
	if _black_clone_sfx and _black_clone_sfx.stream:
		_black_clone_sfx.play()
	var clone := _spawn_black_clone()
	# 黑马分身出场即播一条“小马”消息，避免体感只看到皇马。
	_show_skill_broadcast(BossHorseTypes.HorseId.BLACK, false)
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


func _toggle_root_collision_shape_disabled(disabled: bool) -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = disabled


func _move_to_position(target: Vector2, duration: float) -> void:
	var prev_move := _movement_enabled
	_movement_enabled = false
	velocity = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, NodePath("global_position"), target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_movement_enabled = prev_move


func _camera_viewport_world_x_range() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(-100000.0, 100000.0)
	var cam := vp.get_camera_2d()
	if cam == null:
		return Vector2(-100000.0, 100000.0)
	var size := vp.get_visible_rect().size
	var center := cam.get_screen_center_position()
	var half_w := size.x * 0.5 * cam.zoom.x
	return Vector2(center.x - half_w, center.x + half_w)


func _is_in_skill_cast_horizontal_band(subject: Node2D) -> bool:
	if subject == null or not is_instance_valid(subject):
		return false
	var xr := _camera_viewport_world_x_range()
	var x := subject.global_position.x
	var lo := xr.x + skill_cast_inset_from_left_px
	var hi := xr.y - skill_cast_inset_from_right_px
	if hi < lo:
		return false
	return x >= lo and x <= hi


func _await_subject_in_skill_cast_horizontal_band(subject: Node2D) -> void:
	var tree := get_tree()
	while is_instance_valid(subject):
		if tree == null:
			return
		if not is_inside_tree():
			return
		if _is_in_skill_cast_horizontal_band(subject):
			return
		await tree.physics_frame


func _is_outside_camera_bounds() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var cam := vp.get_camera_2d()
	if cam == null:
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
	var player_y: float = _get_player_position_or_fallback(spawn.global_position).y - 16.0
	for i in count:
		if i > 0:
			await get_tree().create_timer(white_sword_spawn_delay).timeout
		var sword := sword_scene.instantiate() as Node2D
		if sword == null:
			continue
		root.add_child(sword)
		# X 仍为召唤点；Y 对齐主角（多把时保留原纵向错开）。
		sword.global_position = Vector2(spawn.global_position.x, player_y + (-6.0 * float(i)))


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
	clone.process_mode = Node.PROCESS_MODE_INHERIT
	if clone.has_method("_ensure_player_bump_area"):
		clone.call("_ensure_player_bump_area")
	if clone.has_method("_bootstrap_summoned_clone_walk_state"):
		clone.call_deferred("_bootstrap_summoned_clone_walk_state")
	if clone.has_method("set_movement_enabled"):
		clone.call("set_movement_enabled", true)
	return clone


func _bootstrap_summoned_clone_walk_state() -> void:
	if not is_summoned_clone:
		return
	set_movement_enabled(true)
	process_mode = Node.PROCESS_MODE_INHERIT
	if animation_player == null:
		return
	# 回档后分身可能停在 ready/非循环动画；短延时切回稳定行走循环。
	var ready_len := 0.18
	if animation_player.has_animation(&"black_ready"):
		ready_len = maxf(0.08, animation_player.get_animation(&"black_ready").length)
	elif animation_player.has_animation(&"jump"):
		ready_len = maxf(0.08, animation_player.get_animation(&"jump").length * 0.35)
	await get_tree().create_timer(minf(0.35, ready_len)).timeout
	if not is_instance_valid(self):
		return
	if animation_player.has_animation(&"jump"):
		animation_player.play(&"jump")
	elif animation_player.has_animation(&"grey_run"):
		animation_player.play(&"grey_run")


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
		await _await_subject_in_skill_cast_horizontal_band(clone)
		if not is_inside_tree():
			return
		if clone == null or not is_instance_valid(clone):
			return
		var skill := _pick_clone_skill()
		await _cast_clone_skill(clone, skill)
		if not is_inside_tree():
			return
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
	_show_skill_broadcast(skill, false)
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
			await _play_optional_on(ap, &"to red", 0.05)
			await _play_optional_on(ap, &"red_ready", 0.05)
			await _play_optional_on(ap, &"red_call", 0.05)
			await _spawn_red_bombs(red_bomb_count_per_cast)
			await _play_optional_on(ap, &"to_black", 0.05)
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
	var py: float = _get_player_position_or_fallback(spawn_pos).y - 16.0
	sword.global_position = Vector2(spawn_pos.x, py)


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
	var tree := get_tree()
	if tree == null:
		return fallback
	var player := tree.get_first_node_in_group("player") as Node2D
	if player:
		return player.global_position
	return fallback


func _play_optional_on(ap: AnimationPlayer, anim_name: StringName, fallback_seconds: float = 0.08) -> void:
	if ap == null or not ap.has_animation(anim_name):
		await _await_seconds_safe(fallback_seconds)
		return
	ap.play(anim_name)
	var length := ap.get_animation(anim_name).length
	if length <= 0.0:
		length = fallback_seconds
	await _await_seconds_safe(length)


func _await_seconds_safe(seconds: float) -> void:
	var t := get_tree()
	if t == null:
		return
	await t.create_timer(maxf(0.0, seconds)).timeout


func _restore_clone_idle_jump(ap: AnimationPlayer) -> void:
	if ap and ap.has_animation(&"jump"):
		ap.play(&"jump")


func _skill_display_name(skill: BossHorseTypes.HorseId) -> String:
	match skill:
		BossHorseTypes.HorseId.GREY:
			return "爱的冲撞"
		BossHorseTypes.HorseId.WHITE:
			return "认真一剑"
		BossHorseTypes.HorseId.BLACK:
			return "诡影兵团"
		BossHorseTypes.HorseId.RED:
			return "猩红风暴"
		_:
			return "未知技能"


func _horse_display_name(skill: BossHorseTypes.HorseId, is_main_horse: bool) -> String:
	if is_main_horse:
		return "皇马"
	match skill:
		BossHorseTypes.HorseId.GREY:
			return "灰马"
		BossHorseTypes.HorseId.WHITE:
			return "白马"
		BossHorseTypes.HorseId.BLACK:
			return "黑马"
		BossHorseTypes.HorseId.RED:
			return "红马"
		_:
			return "小马"


func _horse_color_hex(skill: BossHorseTypes.HorseId, is_main_horse: bool) -> String:
	if is_main_horse:
		return "#fbff86"
	match skill:
		BossHorseTypes.HorseId.GREY:
			return "#c7dcd0"
		BossHorseTypes.HorseId.WHITE:
			return "#ffffff"
		BossHorseTypes.HorseId.BLACK:
			return "#3e3546"
		BossHorseTypes.HorseId.RED:
			return "#e83b3b"
		_:
			return "#FFFFFF"


func _skill_color_hex(skill: BossHorseTypes.HorseId) -> String:
	match skill:
		BossHorseTypes.HorseId.GREY:
			return "#c7dcd0"
		BossHorseTypes.HorseId.WHITE:
			return "#ffffff"
		BossHorseTypes.HorseId.BLACK:
			return "#3e3546"
		BossHorseTypes.HorseId.RED:
			return "#e83b3b"
		_:
			return "#FFFFFF"


func _show_skill_broadcast(skill: BossHorseTypes.HorseId, is_main_horse: bool) -> void:
	var feed_root := _resolve_skill_feed_root()
	if feed_root == null or not is_instance_valid(feed_root):
		return
	var caster := _horse_display_name(skill, is_main_horse)
	var gift := _skill_display_name(skill)
	if is_main_horse and (skill == BossHorseTypes.HorseId.WHITE or skill == BossHorseTypes.HorseId.RED):
		gift += "*2"
	var caster_color := _horse_color_hex(skill, is_main_horse)
	var skill_color := _skill_color_hex(skill)
	var msg := "[color=%s]%s[/color] 打赏了 [color=%s]%s[/color]" % [
		caster_color,
		caster,
		skill_color,
		gift
	]
	_push_skill_feed_message(feed_root, msg)


func post_skill_broadcast(skill: int, is_main_horse: bool) -> void:
	_show_skill_broadcast(skill as BossHorseTypes.HorseId, is_main_horse)


func post_minor_entry_broadcast(phase_raw: int) -> void:
	var skill := BossHorseTypes.HorseId.GREY
	match phase_raw:
		int(BossHorseTypes.BossPhase.GREY_SOLO):
			skill = BossHorseTypes.HorseId.GREY
		int(BossHorseTypes.BossPhase.WHITE_SOLO):
			skill = BossHorseTypes.HorseId.WHITE
		int(BossHorseTypes.BossPhase.BLACK_SOLO):
			skill = BossHorseTypes.HorseId.BLACK
		int(BossHorseTypes.BossPhase.RED_SOLO):
			skill = BossHorseTypes.HorseId.RED
		_:
			return
	var feed_root := _resolve_skill_feed_root()
	if feed_root == null or not is_instance_valid(feed_root):
		return
	var horse_name := _horse_display_name(skill, false)
	var horse_color := _horse_color_hex(skill, false)
	var msg := "[color=%s]%s[/color] 进入了直播间" % [horse_color, horse_name]
	_push_skill_feed_message(feed_root, msg, true)


func _resolve_skill_feed_root() -> Control:
	var by_path := get_node_or_null(skill_feed_root_path) as Control
	if by_path != null and is_instance_valid(by_path):
		return by_path
	var tree := get_tree()
	if tree == null:
		return null
	var scene := tree.current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Systems/UIHints/SkillFeedRoot") as Control


func _create_skill_feed_row(feed_root: Control, message_bbcode: String, is_entry: bool = false) -> Control:
	var container := SKILL_FEED_ROW_SCENE.instantiate()
	var row := container.get_child(0) as RichTextLabel
	row.custom_minimum_size = Vector2(0, 0 if is_entry else skill_feed_row_height)
	row.theme = feed_root.theme
	row.theme_type_variation = &""
	row.add_theme_font_override("normal_font", ENTRY_FONT)
	row.add_theme_font_override("bold_font", ENTRY_FONT)
	row.add_theme_font_override("italics_font", ENTRY_FONT)
	row.add_theme_font_override("bold_italics_font", ENTRY_FONT)
	row.add_theme_font_override("mono_font", ENTRY_FONT)
	var font_size := 16 if is_entry else 12
	row.add_theme_font_size_override("normal_font_size", font_size)
	row.add_theme_font_size_override("bold_font_size", font_size)
	row.add_theme_font_size_override("italics_font_size", font_size)
	row.add_theme_font_size_override("bold_italics_font_size", font_size)
	row.add_theme_font_size_override("mono_font_size", font_size)
	row.text = message_bbcode
	return container


func _push_skill_feed_message(feed_root: Control, message_bbcode: String, is_entry: bool = false) -> void:
	var lane_count: int = maxi(1, skill_feed_max_rows)
	if _skill_feed_lane_active.size() != lane_count:
		_skill_feed_lane_active.resize(lane_count)
	for lane in range(lane_count):
		var old := _skill_feed_lane_active[lane]
		if old == null or not is_instance_valid(old):
			_skill_feed_lane_active[lane] = null
	var lane_idx := _pick_danmaku_lane(feed_root)
	if lane_idx < 0:
		return
	var container := _create_skill_feed_row(feed_root, message_bbcode, is_entry)
	feed_root.add_child(container)
	_skill_feed_lane_active[lane_idx] = container

	# 用 viewport 绝对坐标计算 spawn/end，再转 feed_root 本地空间
	var vp_width := feed_root.get_viewport_rect().size.x
	var feed_screen_left := feed_root.global_position.x
	var spawn_x := vp_width + skill_feed_spawn_offset_x - feed_screen_left
	var y := float(lane_idx) * skill_feed_row_height
	container.position = Vector2(spawn_x, y)
	container.modulate.a = 1.0

	# 从 container 内取 RichTextLabel 算宽度
	var row := container.get_child(0) as RichTextLabel
	var label_w := maxf(skill_feed_text_width, row.get_content_width())
	var end_x := -label_w - 24.0 - feed_screen_left
	var dist := absf(end_x - spawn_x)
	var dur := dist / maxf(1.0, skill_feed_danmaku_speed)
	var tw := feed_root.create_tween()
	tw.tween_property(container, "position:x", end_x, maxf(0.05, dur)).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(func() -> void:
		if lane_idx >= 0 and lane_idx < _skill_feed_lane_active.size() and _skill_feed_lane_active[lane_idx] == container:
			_skill_feed_lane_active[lane_idx] = null
		if is_instance_valid(container):
			container.queue_free()
	, CONNECT_ONE_SHOT)


func _pick_danmaku_lane(feed_root: Control) -> int:
	var lane_count: int = maxi(1, skill_feed_max_rows)
	var lane_right_x := feed_root.size.x
	for lane in range(lane_count):
		var ctrl := _skill_feed_lane_active[lane]
		if ctrl == null or not is_instance_valid(ctrl):
			return lane
		if _is_danmaku_fully_inside_right_boundary(ctrl, lane_right_x):
			return lane
	return -1


func _is_danmaku_fully_inside_right_boundary(container: Control, lane_right_x: float) -> bool:
	if container == null or not is_instance_valid(container):
		return true
	# container -> RichTextLabel
	var row := container.get_child(0) as RichTextLabel
	if row == null:
		return true
	var content_w := maxf(container.size.x, row.get_content_width())
	var right_x := container.position.x + maxf(skill_feed_text_width, content_w)
	return right_x <= (lane_right_x - skill_feed_lane_enter_margin)
