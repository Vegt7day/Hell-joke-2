extends Area2D
## 红马炸弹：`ready` 预警阶段缓慢移向主角、无伤害；`boom` 后半段开启碰撞检测并对玩家造成单次伤害。

@export var explosion_damage: float = 10.0
## 预警阶段每秒向当前主角位置靠近的像素速度（上限）
@export var ready_seek_speed: float = 150.0
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var _explosion_sfx: AudioStreamPlayer = $ExplosionSfx
@onready var _misfire_sfx: AudioStreamPlayer = $MisfireSfx

var _boom_damage_active: bool = false
var _damage_applied: bool = false
var _during_ready_seek: bool = false


func _ready() -> void:
	add_to_group("boss_red_horse_bomb")
	# 前半段预警：不参与与玩家的重叠检测
	collision_mask = 0
	monitoring = false
	set_physics_process(false)
	set_process(false)
	call_deferred("_run_red_bomb_sequence")


func _process(delta: float) -> void:
	if _during_ready_seek:
		var target := _get_player_global_position_or_fallback(global_position)
		var to_v := target - global_position
		var dist := to_v.length()
		if dist > 0.5:
			var step: float = minf(ready_seek_speed * delta, dist)
			global_position += to_v.normalized() * step


func _get_player_global_position_or_fallback(fallback: Vector2) -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null and is_instance_valid(p):
		return p.global_position
	return fallback


func _physics_process(_delta: float) -> void:
	if not _boom_damage_active or _damage_applied:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.call("take_damage", explosion_damage)
			_damage_applied = true
			break


func _run_red_bomb_sequence() -> void:
	if animation_player == null:
		queue_free()
		return
	_during_ready_seek = true
	set_process(true)
	await _play_optional(&"ready", 0.5)
	_during_ready_seek = false
	set_process(false)
	# 爆炸段：与玩家层重叠并每帧检测（已进入区域内的玩家也能命中）
	collision_mask = 2
	monitoring = true
	# 检测玩家是否在爆炸范围内，选择爆炸 / 哑火音效
	var _player_in_range := false
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_player_in_range = true
			break
	if _player_in_range:
		if _explosion_sfx and _explosion_sfx.stream:
			_explosion_sfx.play()
	else:
		if _misfire_sfx and _misfire_sfx.stream:
			_misfire_sfx.play()
	_boom_damage_active = true
	_damage_applied = false
	set_physics_process(true)
	await _play_optional(&"boom", 0.5)
	_boom_damage_active = false
	set_physics_process(false)
	queue_free()


func _play_optional(anim_name: StringName, fallback_seconds: float = 0.5) -> void:
	if animation_player == null or not animation_player.has_animation(anim_name):
		await get_tree().create_timer(fallback_seconds).timeout
		return
	animation_player.play(anim_name)
	var length := animation_player.get_animation(anim_name).length
	if length <= 0.0:
		length = fallback_seconds
	await get_tree().create_timer(length).timeout
