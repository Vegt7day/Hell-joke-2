extends StaticBody2D
## 与 [MechanismLinkBus] 同色通道联动：开关为「开」时播 open，为「关」时播 close（与门语义一致）。
## 子节点 [SwitchChannelListener] 会调用 [method apply_switch_bus_state]。

const _OPEN_FRAME := 4
const _CLOSED_FRAME := 0
const _COLLISION_POS := Vector2(16.5, -2.5)
const _PUSH_STEP := 2.0
const _PUSH_MAX_STEPS := 32
const _PUSH_FRAME_META := "_window_push_frame"
const _PUSH_DIR_META := "_window_push_dir"

@export var initial_color: String = "红"
@export var is_open: bool = true
@export var trigger_sfx: AudioStream = preload("res://assets/资源总库/10_音频/jump.mp3")

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var color_rect: ColorRect = $ColorRect

var current_color: String
var _is_processing: bool = false


func _ready() -> void:
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate(true)
	current_color = initial_color
	match current_color:
		"红":
			color_rect.color = Color.RED
		"绿":
			color_rect.color = Color.GREEN
		"蓝":
			color_rect.color = Color.BLUE
		"黄":
			color_rect.color = Color.YELLOW
		"紫":
			color_rect.color = Color.PURPLE
		"橙":
			color_rect.color = Color.ORANGE
		"白":
			color_rect.color = Color.WHITE
		"黑":
			color_rect.color = Color.BLACK
		_:
			color_rect.color = Color.WHITE
			push_warning("窗: 未知颜色 %s，使用白色" % current_color)
	_apply_instant_visual(is_open)


func apply_switch_bus_state(target_open: bool, play_anim: bool = true) -> void:
	if _is_processing:
		return
	if target_open == is_open:
		return
	if not play_anim:
		is_open = target_open
		_apply_instant_visual(target_open)
		return
	_is_processing = true
	_play_trigger_sound()
	if target_open:
		animation_player.play("open")
		collision_shape.disabled = false
		call_deferred("_resolve_overlapping_players_after_open")
	else:
		animation_player.play("close")
		collision_shape.disabled = true
	is_open = target_open
	await get_tree().create_timer(0.5).timeout
	_is_processing = false


func _apply_instant_visual(open: bool) -> void:
	if open:
		sprite_2d.frame = _OPEN_FRAME
		collision_shape.disabled = false
		call_deferred("_resolve_overlapping_players_after_open")
	else:
		sprite_2d.frame = _CLOSED_FRAME
		collision_shape.disabled = true
	collision_shape.position = _COLLISION_POS


func _resolve_overlapping_players_after_open() -> void:
	if not is_inside_tree() or collision_shape.disabled or collision_shape.shape == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	# 避免在 physics flush / space lock 期间访问 direct_space_state
	await tree.physics_frame
	if not is_inside_tree() or collision_shape.disabled or collision_shape.shape == null:
		return
	var players := _collect_overlapping_players()
	if players.is_empty():
		return
	var window_rect := _get_window_rect()
	for p in players:
		_push_player_out_vertical(p, window_rect)


func _collect_overlapping_players() -> Array[Node2D]:
	var result: Array[Node2D] = []
	var seen := {}
	var world := get_world_2d()
	if world == null:
		return result
	var space_state := world.direct_space_state
	if space_state == null:
		return result
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hits := space_state.intersect_shape(query, 16)
	for hit in hits:
		if not hit.has("collider"):
			continue
		var collider = hit["collider"]
		if not (collider is Node2D):
			continue
		var body := collider as Node2D
		if not body.is_in_group("player"):
			continue
		var id := body.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		result.append(body)
	return result


func _get_window_rect() -> Rect2:
	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		var center := collision_shape.global_position
		return Rect2(center - Vector2.ONE, Vector2(2, 2))
	var size := shape.size
	var center := collision_shape.global_position
	return Rect2(center - size * 0.5, size)


func _get_body_rect(body: Node2D) -> Rect2:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		var p := body.global_position
		return Rect2(p - Vector2.ONE * 4.0, Vector2.ONE * 8.0)
	var c := shape_node.global_position
	var shape := shape_node.shape
	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		return Rect2(c - rect.size * 0.5, rect.size)
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var sz := Vector2(capsule.radius * 2.0, capsule.height + capsule.radius * 2.0)
		return Rect2(c - sz * 0.5, sz)
	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		var d := circle.radius * 2.0
		return Rect2(c - Vector2.ONE * circle.radius, Vector2.ONE * d)
	var p2 := body.global_position
	return Rect2(p2 - Vector2.ONE * 4.0, Vector2.ONE * 8.0)


func _push_player_out_vertical(player: Node2D, window_rect: Rect2) -> void:
	var player_rect := _get_body_rect(player)
	if not player_rect.intersects(window_rect):
		return
	var window_mid_y := window_rect.position.y + window_rect.size.y * 0.5
	var top_overlap := _segment_overlap(
		player_rect.position.y,
		player_rect.position.y + player_rect.size.y,
		window_rect.position.y,
		window_mid_y
	)
	var bottom_overlap := _segment_overlap(
		player_rect.position.y,
		player_rect.position.y + player_rect.size.y,
		window_mid_y,
		window_rect.position.y + window_rect.size.y
	)
	var desired_dir := -1.0 if top_overlap > bottom_overlap else 1.0
	var dir := _resolve_push_direction(player, desired_dir)
	for _i in range(_PUSH_MAX_STEPS):
		player_rect = _get_body_rect(player)
		if not player_rect.intersects(window_rect):
			break
		player.global_position.y += dir * _PUSH_STEP
	if player is CharacterBody2D:
		var cb := player as CharacterBody2D
		cb.velocity.y = 0.0


func _segment_overlap(a0: float, a1: float, b0: float, b1: float) -> float:
	return maxf(0.0, minf(a1, b1) - maxf(a0, b0))


func _resolve_push_direction(player: Node2D, desired_dir: float) -> float:
	var current_frame := Engine.get_physics_frames()
	var cached_frame := int(player.get_meta(_PUSH_FRAME_META, -1))
	if cached_frame == current_frame:
		var cached_dir := float(player.get_meta(_PUSH_DIR_META, desired_dir))
		return -1.0 if cached_dir < 0.0 else 1.0
	player.set_meta(_PUSH_FRAME_META, current_frame)
	player.set_meta(_PUSH_DIR_META, desired_dir)
	return desired_dir


func _play_trigger_sound() -> void:
	if trigger_sfx == null:
		return
	MechanismSfxBus.request_once(&"switch_chain_trigger", trigger_sfx)
