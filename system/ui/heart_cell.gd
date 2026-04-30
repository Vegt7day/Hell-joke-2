class_name HeartCell
extends Control

## 约定：1 颗心有 3 个离散状态：0=空，1=半，2=满
## 播放顺序：
## - 扣血：2 ->(damage1)-> 1 ->(damage2)-> 0
## - 恢复：0 ->(heal1)-> 1 ->(heal2)-> 2

@export var anim_full: StringName = &"full"
@export var anim_half: StringName = &"half"
@export var anim_empty: StringName = &"empty"
@export var anim_damage_1: StringName = &"damage_1"
@export var anim_damage_2: StringName = &"damage_2"
@export var anim_heal_1: StringName = &"heal_1"
@export var anim_heal_2: StringName = &"heal_2"

@onready var sprite: AnimatedSprite2D = $Sprite

var state: int = 2
@export var cell_size: Vector2 = Vector2(32.0, 32.0)


func _ready() -> void:
	custom_minimum_size = cell_size
	if sprite != null:
		sprite.position = cell_size * 0.5


func set_state_instant(next_state: int) -> void:
	state = clampi(next_state, 0, 2)
	if sprite == null:
		return
	var anim := anim_full
	if state == 0:
		anim = anim_empty
	elif state == 1:
		anim = anim_half
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		sprite.pause()


func play_damage_step() -> void:
	if state == 2:
		await _play_if_exists(anim_damage_1)
		state = 1
		set_state_instant(state)
		return
	if state == 1:
		await _play_if_exists(anim_damage_2)
		state = 0
		set_state_instant(state)


func play_heal_step() -> void:
	if state == 0:
		await _play_if_exists(anim_heal_1)
		state = 1
		set_state_instant(state)
		return
	if state == 1:
		await _play_if_exists(anim_heal_2)
		state = 2
		set_state_instant(state)


func _play_if_exists(anim_name: StringName) -> void:
	if not is_inside_tree():
		return
	if sprite == null or sprite.sprite_frames == null:
		if not await _await_next_frame_safe():
			return
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		# 没配置动画资源时也要让队列推进
		if not await _await_next_frame_safe():
			return
		return
	sprite.play(anim_name)
	# AnimatedSprite2D 的 animation_finished 只在非 loop 动画触发；用兜底 timer 防止资源配置为 loop 时卡住
	var done := false
	var on_done := func() -> void:
		done = true
	if not sprite.animation_finished.is_connected(on_done):
		sprite.animation_finished.connect(on_done, CONNECT_ONE_SHOT)
	var len: float = 0.12
	if sprite.sprite_frames != null:
		len = _estimate_animation_seconds(sprite.sprite_frames, anim_name, 0.12)
	var tree := get_tree()
	if tree == null:
		return
	var t: SceneTreeTimer = tree.create_timer(maxf(0.03, len))
	while not done and is_instance_valid(sprite):
		if not await _await_next_frame_safe():
			return
		if t.time_left <= 0.0:
			break


func _estimate_animation_seconds(frames: SpriteFrames, anim_name: StringName, fallback: float) -> float:
	if frames == null or not frames.has_animation(anim_name):
		return fallback
	var total_weight: float = 0.0
	var cnt: int = int(frames.get_frame_count(anim_name))
	for i in cnt:
		total_weight += float(frames.get_frame_duration(anim_name, i))
	var fps: float = float(frames.get_animation_speed(anim_name))
	if fps <= 0.001:
		return fallback
	var seconds: float = total_weight / fps
	return maxf(0.03, seconds) if seconds > 0.0 else fallback


func _await_next_frame_safe() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	await tree.process_frame
	return true
