class_name InkSlot
extends Control

signal recover_finished(slot: Node)

## 0=empty, 1=full
var state: int = 1

@export var anim_full: StringName = &"full"
@export var anim_empty: StringName = &"empty"
@export var anim_use: StringName = &"use"
@export var anim_recover: StringName = &"recover"

@onready var sprite: AnimatedSprite2D = $Sprite

var _recover_token: int = 0
@export var slot_size: Vector2 = Vector2(32.0, 32.0)


func _ready() -> void:
	custom_minimum_size = slot_size
	if sprite != null:
		sprite.position = slot_size * 0.5


func set_state_instant(next_state: int) -> void:
	state = clampi(next_state, 0, 1)
	if sprite == null:
		return
	var anim: StringName = anim_full if state == 1 else anim_empty
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		sprite.pause()


func play_use_step() -> void:
	if state <= 0:
		if not await _await_next_frame_safe():
			return
		return
	# 按需求：消耗时不播放 use，直接进入 empty
	state = 0
	set_state_instant(state)


func start_recover(snapshot: Dictionary = {}) -> void:
	_recover_token += 1
	var my_token: int = _recover_token
	# 强制进入 recover 动画；若提供 snapshot，则沿用 snapshot 的帧与进度
	if sprite == null:
		if not await _await_next_frame_safe():
			return
		if my_token != _recover_token:
			return
		state = 1
		emit_signal("recover_finished", self)
		return
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_recover):
		if my_token != _recover_token:
			return
		state = 1
		set_state_instant(state)
		emit_signal("recover_finished", self)
		return

	sprite.play(anim_recover)

	if not snapshot.is_empty():
		if snapshot.has("frame"):
			sprite.frame = int(snapshot["frame"])
		if snapshot.has("frame_progress"):
			sprite.frame_progress = float(snapshot["frame_progress"])
		if snapshot.has("speed_scale"):
			sprite.speed_scale = float(snapshot["speed_scale"])

	var done := false
	var on_done := func() -> void:
		done = true
	if not sprite.animation_finished.is_connected(on_done):
		sprite.animation_finished.connect(on_done, CONNECT_ONE_SHOT)

	var len: float = _estimate_animation_seconds(sprite.sprite_frames, anim_recover, 0.18)
	var tree := get_tree()
	if tree == null:
		return
	var t: SceneTreeTimer = tree.create_timer(maxf(0.03, len))
	while not done and is_instance_valid(sprite):
		if not await _await_next_frame_safe():
			return
		if my_token != _recover_token:
			return
		if t.time_left <= 0.0:
			break

	if my_token != _recover_token:
		return
	state = 1
	set_state_instant(state)
	emit_signal("recover_finished", self)


func abort_to_empty_instant() -> void:
	_recover_token += 1
	if sprite != null:
		sprite.stop()
	state = 0
	set_state_instant(state)


func snapshot_recover_progress() -> Dictionary:
	# 仅用于“把正在恢复的动画赋给别的格子”
	var d: Dictionary = {}
	if sprite == null:
		return d
	d["frame"] = int(sprite.frame)
	d["frame_progress"] = float(sprite.frame_progress)
	d["speed_scale"] = float(sprite.speed_scale)
	return d


func _play_if_exists(anim_name: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		if not await _await_next_frame_safe():
			return
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		if not await _await_next_frame_safe():
			return
		return
	sprite.play(anim_name)
	var done := false
	var on_done := func() -> void:
		done = true
	if not sprite.animation_finished.is_connected(on_done):
		sprite.animation_finished.connect(on_done, CONNECT_ONE_SHOT)
	var len: float = _estimate_animation_seconds(sprite.sprite_frames, anim_name, 0.12)
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
