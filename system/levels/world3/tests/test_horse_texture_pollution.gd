extends Node2D

## 按 world3 完全一致的逻辑：_get_or_spawn_minor / _play_minor_jump / _set_horse_movement
## 运行：在 Godot 中打开 test_horse_texture_pollution.tscn

const _MINOR_SCENE := preload("res://system/levels/world3/bosses/boss_horse_minor.tscn")
const _ATLAS_GREY := preload("res://assets/资源总库/06_图像_World3/bosses/灰马.png")

## 与 boss_horse_phase_controller.gd:_minor_name_to_horse_id 一致
const _MINOR_NAME_TO_HORSE_ID: Dictionary = {
	"MinorGrey": 0,
	"MinorWhite": 1,
	"MinorBlack": 2,
	"MinorRed": 3,
}

var _grey_horse: Node2D
var _black_horse: Node2D
var _grey_sprite: Sprite2D
var _pollution_frame_count := 0
var _first_pollution_logged := false
var _phase := 0
var _phase_timer := 0.0

@onready var _minors: Node2D = $"Bosses/Minors"
@onready var _grey_spawn: Marker2D = $"Bosses/SpawnMarkers/GreySpawn"
@onready var _black_spawn: Marker2D = $"Bosses/SpawnMarkers/BlackSpawn"


func _ready() -> void:
	# Camera2D — 使 boss_horse_minor._is_in_skill_cast_horizontal_band() 通过
	var cam := Camera2D.new()
	cam.position = Vector2(360, 240)
	cam.enabled = true
	add_child(cam)
	cam.make_current()
	print("[TEST] Camera2D at ", cam.position)

	# --- 灰马：完全按 world3 _apply_grey_solo_spawn 的逻辑 ---
	_grey_horse = _get_or_spawn_minor(&"MinorGrey")
	if _grey_horse:
		_grey_horse.set("auto_use_skill", false)
		_grey_horse.global_position = _grey_spawn.global_position
		_grey_horse.visible = true
		_grey_horse.process_mode = Node.PROCESS_MODE_INHERIT
		_play_minor_jump(_grey_horse, &"MinorGrey")
		await get_tree().create_timer(0.6).timeout
		_play_minor_travel_loop_anim(_grey_horse, &"MinorGrey")
		_set_horse_movement(_grey_horse, false)
		print("[TEST] MinorGrey spawned at ", _grey_horse.global_position)

	# --- 黑马：完全按 world3 _run_minor_switch 的逻辑 ---
	_black_horse = _get_or_spawn_minor(&"MinorBlack")
	if _black_horse:
		_black_horse.set("black_minor_summon_interval", 2.0)
		_black_horse.set("move_left_speed", 0.0)
		_black_horse.global_position = _black_spawn.global_position
		_black_horse.visible = true
		_black_horse.process_mode = Node.PROCESS_MODE_INHERIT
		_play_minor_jump(_black_horse, &"MinorBlack")
		await get_tree().create_timer(0.6).timeout
		_play_minor_travel_loop_anim(_black_horse, &"MinorBlack")
		_set_horse_movement(_black_horse, true)
		print("[TEST] MinorBlack spawned at ", _black_horse.global_position)

	# 拿灰马 Sprite2D 引用用于监控
	await get_tree().process_frame
	if _grey_horse:
		_grey_sprite = _grey_horse.get_node_or_null("Sprite2D") as Sprite2D
		if _grey_sprite and _grey_sprite.texture and _grey_sprite.texture is AtlasTexture:
			var at := _grey_sprite.texture as AtlasTexture
			print("[TEST] Grey AtlasTexture.atlas init: ", at.atlas.get_path() if at.atlas else "NULL")


# --- 以下三个函数完全复制自 boss_horse_phase_controller.gd ---

func _get_or_spawn_minor(minor_name: StringName) -> Node2D:
	var existed := _minors.get_node_or_null(String(minor_name)) as Node2D
	if existed != null:
		return existed
	var spawned := _MINOR_SCENE.instantiate() as Node2D
	if spawned == null:
		return null
	spawned.name = String(minor_name)
	if "horse_id" in spawned:
		var key := String(minor_name)
		if _MINOR_NAME_TO_HORSE_ID.has(key):
			spawned.set("horse_id", _MINOR_NAME_TO_HORSE_ID[key])
	_minors.add_child(spawned)
	spawned.visible = false
	spawned.process_mode = Node.PROCESS_MODE_DISABLED
	_set_horse_movement(spawned, false)
	return spawned


func _play_minor_jump(minor: Node2D, minor_name: StringName) -> void:
	if minor.has_method("refresh_visual_to_horse_id"):
		minor.call("refresh_visual_to_horse_id")
	var ap := minor.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		return
	match minor_name:
		&"MinorGrey":
			if ap.has_animation(&"grey_jump"):
				ap.play(&"grey_jump")
		&"MinorBlack":
			if ap.has_animation(&"black_jump"):
				ap.play(&"black_jump")


func _play_minor_travel_loop_anim(minor: Node2D, minor_name: StringName) -> void:
	var ap := minor.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		return
	match minor_name:
		&"MinorGrey":
			if ap.has_animation(&"grey_run"):
				ap.play(&"grey_run")
		&"MinorBlack":
			if ap.has_animation(&"black_jump"):
				ap.play(&"black_jump")


func _set_horse_movement(node: Node, enabled: bool) -> void:
	if node and node.has_method("set_movement_enabled"):
		node.call("set_movement_enabled", enabled)


# --- 每帧监控灰马贴图 ---

func _process(_delta: float) -> void:
	_phase_timer += _delta

	if _grey_sprite and _grey_sprite.texture and _grey_sprite.texture is AtlasTexture:
		var at := _grey_sprite.texture as AtlasTexture
		if at.atlas != _ATLAS_GREY:
			if not _first_pollution_logged:
				_first_pollution_logged = true
				print("[POLLUTION] Frame %d: Grey AtlasTexture.atlas changed to %s!" % [Engine.get_process_frames(), at.atlas.get_path() if at.atlas else "NULL"])
			_pollution_frame_count += 1

	match _phase:
		0:
			if _phase_timer > 3.0:
				print("[TEST] Phase 0 done (black summon should have triggered by ~2s)")
				_phase = 1
				_phase_timer = 0.0
		1:
			if _phase_timer > 5.0:
				print("[TEST] Phase 1 done — %d polluted frames total" % _pollution_frame_count)
				if _pollution_frame_count > 0:
					print("[RESULT] 灰马贴图 被 黑马分身动画 污染!")
				else:
					print("[RESULT] 灰马贴图 未被污染.")
				_phase = 2