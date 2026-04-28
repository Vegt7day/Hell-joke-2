class_name SavePointInteractable
extends Interactable

@export var ready_anim_name: StringName = &"ready"
@export var save_anim_name: StringName = &"save"
@export var recover_anim_name: StringName = &"recover"

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _is_processing_interact: bool = false
var _interaction_serial: int = 0


func _ready() -> void:
	monitoring = true
	monitorable = true
	if animation_player != null:
		animation_player.stop()


func interact() -> void:
	if _is_processing_interact:
		return
	_is_processing_interact = true
	super.interact()
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("trigger_hit_shake_only"):
		p.call("trigger_hit_shake_only")
	if p != null:
		_interaction_serial += 1
		var heal_id := "savepoint_interact:%s:%d" % [str(get_instance_id()), _interaction_serial]
		if p.has_method("recover_full_health_once"):
			p.call("recover_full_health_once", heal_id)
		elif p.has_method("recover_full_health"):
			p.call("recover_full_health")
	if animation_player != null and animation_player.has_animation(ready_anim_name):
		animation_player.play(ready_anim_name)
	# 按需求：ready 动画开始时即触发存档。
	if is_instance_valid(Game) and Game.has_method("save_game"):
		Game.save_game("savepoint")
	if animation_player != null and animation_player.has_animation(ready_anim_name):
		await animation_player.animation_finished
	if animation_player != null and animation_player.has_animation(save_anim_name):
		animation_player.play(save_anim_name)
		await animation_player.animation_finished
	_play_if_exists(recover_anim_name)
	_is_processing_interact = false


func _play_if_exists(anim_name: StringName) -> void:
	if animation_player != null and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
