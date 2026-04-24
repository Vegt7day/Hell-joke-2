class_name ShangYangLimb
extends Interactable

## 同场景商鞅 NPC（挂在 world2/ShangYangLimbs 下时默认为 ../../商鞅）
@export var shangyang_path: NodePath = ^"../../商鞅"

var _collected: bool = false
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("shangyang_limb")
	monitoring = true
	monitorable = true


func set_limb_pickups_enabled(enabled: bool) -> void:
	if _collected:
		return
	monitoring = enabled
	monitorable = enabled
	visible = enabled


func apply_saved_collected() -> void:
	_collected = true
	monitoring = false
	monitorable = false
	visible = false
	queue_free()


func _process(_delta: float) -> void:
	if _collected or not visible:
		return
	if _sprite == null:
		return
	var t := Time.get_ticks_msec() / 500.0
	_sprite.modulate.a = 0.65 + 0.35 * sin(t)


func interact() -> void:
	if _collected:
		return
	var sy := get_node_or_null(shangyang_path) as ShangYang
	if sy == null or not sy.can_accept_limb_pickup():
		return
	super.interact()
	sy.notify_limb_collected()
	var w := get_tree().current_scene
	if w and w.has_method("register_shangyang_limb_collected"):
		w.register_shangyang_limb_collected(name)
	_collected = true
	var p := _overlapping_player()
	if p:
		p.unregister_interactable(self)
	monitoring = false
	monitorable = false
	queue_free()


func _overlapping_player() -> Player:
	for b in get_overlapping_bodies():
		if b is Player:
			return b as Player
	return null
