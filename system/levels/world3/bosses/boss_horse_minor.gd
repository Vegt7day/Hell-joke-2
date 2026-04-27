extends CharacterBody2D
## 单马（灰/白/黑/红共用场景），由 `horse_id` 区分外观与 AI（占位）。

const _MINOR_SELF_SCENE := preload("res://system/levels/world3/bosses/boss_horse_minor.tscn")
const _RED_BOMB_SCENE := preload("res://system/levels/world3/props/bomb_red_horse.tscn")
const _ATLAS_GREY := preload("res://system/levels/world3/bosses/灰马.png")
const _ATLAS_WHITE := preload("res://system/levels/world3/bosses/白马.png")
const _ATLAS_BLACK := preload("res://system/levels/world3/bosses/黑马.png")
const _ATLAS_RED := preload("res://system/levels/world3/bosses/红马.png")

@export var horse_id: BossHorseTypes.HorseId = BossHorseTypes.HorseId.GREY
## 小黑马召唤的分身：小黑马外观、仅左移循环，不放技能。
@export var is_summoned_clone: bool = false
@export var suppress_clone_ready_anim: bool = false
@export var move_left_speed: float = 210.0
@export var respawn_margin: float = 120.0
## 离开摄像机可视区后，累计该秒数再传送到屏幕右侧外（与主马一致；其余传送参数不变）
@export var offscreen_respawn_delay_seconds: float = 0.5
## 仅当 X 在视口左缘向内与右缘向内之间时才开始放技能 / 累计小黑马召唤间隔
@export var skill_cast_inset_from_left_px: float = 256.0
@export var skill_cast_inset_from_right_px: float = 16.0
@export var auto_use_skill: bool = true
@export var grey_dash_distance: float = 180.0
@export var grey_dash_duration: float = 0.28
@export var grey_skill_cooldown: float = 4.0
const DEFAULT_SWORD_SCENE := preload("res://system/levels/world3/props/projectile_white_horse.tscn")
@export var sword_scene: PackedScene = DEFAULT_SWORD_SCENE
@export var white_skill_cooldown: float = 4.0
@export var white_sword_spawn_delay: float = 0.1
@export var red_bomb_scene: PackedScene = _RED_BOMB_SCENE
@export var red_skill_cooldown: float = 6.0
@export var red_bomb_spawn_delay: float = 0.15
## 小黑马本体：周期性召唤无技能分身；<=0 表示不自动消失（由场景逻辑回收）。
@export var black_minor_summon_interval: float = 15.0
@export var black_minor_clone_offset: Vector2 = Vector2(-44, 0)
@export var black_minor_clone_lifetime: float = 5.0
@export var black_minor_clone_fade_seconds: float = 0.28

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D

var _phase_controller: Node
var _movement_enabled: bool = true
var _is_casting_skill: bool = false
var _skill_cooldown_left: float = 0.0
var _black_minor_summon_accum: float = 0.0
var _black_summon_locked: bool = false
var _offscreen_elapsed: float = 0.0


func _ready() -> void:
	if is_summoned_clone:
		auto_use_skill = false
		add_to_group("boss_horse_minor")
		set_movement_enabled(true)
		if horse_id == BossHorseTypes.HorseId.BLACK and animation_player and not suppress_clone_ready_anim:
			if animation_player.has_animation(&"black_jump"):
				animation_player.play(&"black_jump")
			elif animation_player.has_animation(&"black_ready"):
				animation_player.play(&"black_ready")
		return

	add_to_group("boss_horse_minor")
	add_to_group("boss_horse_shared_target")
	_resolve_phase_controller()
	refresh_visual_to_horse_id()


func take_damage(damage_amount: float, _attacker: Variant = null) -> void:
	if is_summoned_clone:
		return
	# 四马受击也要扣同一 Boss 血条。
	if _phase_controller == null:
		_resolve_phase_controller()
	if _phase_controller and _phase_controller.has_method("apply_shared_damage"):
		_phase_controller.apply_shared_damage(damage_amount, name)
		return
	print("[BossMinor] 未找到 PhaseController，忽略伤害。name=", name, " damage=", damage_amount)


func _physics_process(delta: float) -> void:
	if not _movement_enabled or _is_casting_skill:
		velocity = Vector2.ZERO
		_offscreen_elapsed = 0.0
		return
	velocity = Vector2.LEFT * move_left_speed
	move_and_slide()
	if _is_outside_camera_bounds():
		_offscreen_elapsed += delta
		if _offscreen_elapsed >= offscreen_respawn_delay_seconds:
			_respawn_to_camera_right_at_player_y()
			_offscreen_elapsed = 0.0
	else:
		_offscreen_elapsed = 0.0


func _process(delta: float) -> void:
	if is_summoned_clone:
		return
	if horse_id == BossHorseTypes.HorseId.BLACK and _movement_enabled and visible:
		if _black_summon_locked:
			return
		if _is_in_skill_cast_horizontal_band():
			_black_minor_summon_accum += delta
		if _black_minor_summon_accum >= black_minor_summon_interval:
			_black_minor_summon_accum = 0.0
			call_deferred("_spawn_black_minor_clone")
			return
	if not auto_use_skill:
		return
	if horse_id != BossHorseTypes.HorseId.GREY and horse_id != BossHorseTypes.HorseId.WHITE and horse_id != BossHorseTypes.HorseId.RED:
		return
	if not _movement_enabled or not visible:
		return
	if _is_casting_skill:
		return
	if _skill_cooldown_left > 0.0:
		_skill_cooldown_left -= delta
		return
	if not _is_in_skill_cast_horizontal_band():
		return
	if horse_id == BossHorseTypes.HorseId.GREY:
		call_deferred("_cast_grey_dash_skill")
	elif horse_id == BossHorseTypes.HorseId.WHITE:
		call_deferred("_cast_white_summon_skill")
	elif horse_id == BossHorseTypes.HorseId.RED:
		call_deferred("_cast_red_bomb_skill")


func _resolve_phase_controller() -> void:
	_phase_controller = get_tree().get_first_node_in_group("boss_phase_controller")
	if _phase_controller:
		return
	var current_scene := get_tree().current_scene
	if current_scene:
		_phase_controller = current_scene.get_node_or_null("Systems/PhaseController")


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO


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


func _is_in_skill_cast_horizontal_band() -> bool:
	var xr := _camera_viewport_world_x_range()
	var x := global_position.x
	var lo := xr.x + skill_cast_inset_from_left_px
	var hi := xr.y - skill_cast_inset_from_right_px
	if hi < lo:
		return false
	return x >= lo and x <= hi


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


func _respawn_to_camera_right_at_player_y() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var size := vp.get_visible_rect().size
	var center := cam.get_screen_center_position()
	var half_w := size.x * 0.5 * cam.zoom.x
	global_position.x = center.x + half_w + respawn_margin
	var target_y := _get_player_position_or_fallback(global_position).y
	global_position.y = target_y


func _get_view_bounds_x() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Vector2(-10000.0, 10000.0)
	var rect := get_viewport_rect().size
	var half_w := rect.x * 0.5 * camera.zoom.x
	var center := camera.get_screen_center_position()
	return Vector2(center.x - half_w, center.x + half_w)


func _cast_grey_dash_skill() -> void:
	if _is_casting_skill or not _movement_enabled:
		return
	_is_casting_skill = true
	await _play_optional(&"grey_ready")
	if animation_player and animation_player.has_animation(&"grey_run"):
		animation_player.play(&"grey_run")
	await _move_to_position(global_position + Vector2.LEFT * grey_dash_distance, grey_dash_duration)
	await _play_optional(&"grey_over")
	if animation_player and animation_player.has_animation(&"grey_jump"):
		animation_player.play(&"grey_jump")
	_skill_cooldown_left = grey_skill_cooldown
	_is_casting_skill = false


func _cast_white_summon_skill() -> void:
	if _is_casting_skill or not _movement_enabled:
		return
	_is_casting_skill = true
	await _play_optional(&"white_ready")
	await _play_optional(&"white_call")
	await _spawn_white_sword()
	if animation_player and animation_player.has_animation(&"white_jump"):
		animation_player.play(&"white_jump")
	_skill_cooldown_left = white_skill_cooldown
	_is_casting_skill = false


func _cast_red_bomb_skill() -> void:
	if _is_casting_skill or not _movement_enabled:
		return
	_is_casting_skill = true
	await _play_optional(&"red_ready")
	await _play_optional(&"red_call")
	await _spawn_red_bomb()
	if animation_player and animation_player.has_animation(&"red_jump"):
		animation_player.play(&"red_jump")
	_skill_cooldown_left = red_skill_cooldown
	_is_casting_skill = false


func _move_to_position(target: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, NodePath("global_position"), target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _play_optional(anim_name: StringName, fallback_seconds: float = 0.12) -> void:
	if animation_player == null or not animation_player.has_animation(anim_name):
		await get_tree().create_timer(fallback_seconds).timeout
		return
	animation_player.play(anim_name)
	var length := animation_player.get_animation(anim_name).length
	if length <= 0.0:
		length = fallback_seconds
	await get_tree().create_timer(length).timeout


func _spawn_white_sword() -> void:
	if sword_scene == null:
		return
	var spawn := get_node_or_null("SummonSpawn") as Node2D
	if spawn == null:
		return
	var root := get_node_or_null("../PropsSpawn/ProjectilesRoot") as Node2D
	if root == null:
		root = get_parent() as Node2D
	var sword := sword_scene.instantiate() as Node2D
	if sword == null:
		return
	root.add_child(sword)
	var py: float = _get_player_position_or_fallback(spawn.global_position).y - 16.0
	sword.global_position = Vector2(spawn.global_position.x, py)
	if white_sword_spawn_delay > 0.0:
		await get_tree().create_timer(white_sword_spawn_delay).timeout


## 按 `horse_id` 强制对齐 Sprite2D（不依赖 jump 动画轨道：`白/黑/红` 的 jump 只改 atlas 不改 texture，会继承上一匹马贴图导致全白）。
func refresh_visual_to_horse_id() -> void:
	if is_summoned_clone or sprite_2d == null:
		return
	if animation_player:
		animation_player.stop(true)
	sprite_2d.region_enabled = true
	var hid := int(horse_id)
	match hid:
		0:
			sprite_2d.texture = _ATLAS_GREY
			sprite_2d.hframes = 18
			sprite_2d.region_rect = Rect2(0, 0, 2304, 128)
		1:
			sprite_2d.texture = _ATLAS_WHITE
			sprite_2d.hframes = 16
			sprite_2d.region_rect = Rect2(0, 0, 2048, 128)
		2:
			sprite_2d.texture = _ATLAS_BLACK
			sprite_2d.hframes = 20
			sprite_2d.region_rect = Rect2(0, 0, 2560, 128)
		3:
			sprite_2d.texture = _ATLAS_RED
			sprite_2d.hframes = 23
			sprite_2d.region_rect = Rect2(0, 0, 2944, 128)
		_:
			sprite_2d.texture = _ATLAS_GREY
			sprite_2d.hframes = 18
			sprite_2d.region_rect = Rect2(0, 0, 2304, 128)
	sprite_2d.frame = 1


func _spawn_black_minor_clone() -> void:
	if _black_summon_locked:
		return
	if not _is_in_skill_cast_horizontal_band():
		return
	_black_summon_locked = true
	var root := get_parent() as Node2D
	if root == null:
		_black_summon_locked = false
		return
	await _play_optional(&"black_ready", 0.08)
	var clone := _MINOR_SELF_SCENE.instantiate() as CharacterBody2D
	if clone == null:
		_black_summon_locked = false
		return
	clone.set("horse_id", BossHorseTypes.HorseId.BLACK)
	clone.set("is_summoned_clone", true)
	clone.set("auto_use_skill", false)
	clone.set("suppress_clone_ready_anim", true)
	root.add_child(clone)
	var slot := get_node_or_null("CloneSlot") as Node2D
	if slot:
		clone.global_position = slot.global_position
	else:
		clone.global_position = global_position + black_minor_clone_offset
	if clone.has_method("set_movement_enabled"):
		clone.call("set_movement_enabled", true)
	var clone_ap := clone.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var create_len := _play_anim_sync(animation_player, clone_ap, &"black_create", 0.08)
	if create_len > 0.0:
		await get_tree().create_timer(create_len).timeout
	_play_anim_sync(animation_player, clone_ap, &"black_jump", 0.05)
	if black_minor_clone_lifetime > 0.0 and clone.has_method("_begin_summoned_clone_lifetime"):
		clone.call_deferred("_begin_summoned_clone_lifetime", black_minor_clone_lifetime)
	_black_summon_locked = false


func _begin_summoned_clone_lifetime(duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self):
		return
	var sprite := get_node_or_null("Sprite2D") as CanvasItem
	if sprite:
		var tw := create_tween()
		tw.tween_property(sprite, NodePath("modulate:a"), 0.0, black_minor_clone_fade_seconds)
		await tw.finished
	queue_free()


func _spawn_red_bomb() -> void:
	if red_bomb_scene == null:
		return
	var target_pos := _get_player_position_or_fallback(global_position)
	var root := get_node_or_null("../PropsSpawn/ProjectilesRoot") as Node2D
	if root == null:
		root = get_parent() as Node2D
	var bomb := red_bomb_scene.instantiate() as Node2D
	if bomb == null:
		return
	root.add_child(bomb)
	bomb.global_position = target_pos
	if red_bomb_spawn_delay > 0.0:
		await get_tree().create_timer(red_bomb_spawn_delay).timeout


func _play_anim_sync(a: AnimationPlayer, b: AnimationPlayer, anim_name: StringName, fallback_seconds: float = 0.08) -> float:
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
