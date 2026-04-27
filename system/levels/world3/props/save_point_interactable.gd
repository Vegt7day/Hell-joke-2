class_name SavePointInteractable
extends Interactable

@export var ready_anim_name: StringName = &"ready"
@export var save_anim_name: StringName = &"save"
@export var recover_anim_name: StringName = &"recover"

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _is_processing_interact: bool = false


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
	if animation_player != null and animation_player.has_animation(ready_anim_name):
		animation_player.play(ready_anim_name)
	# 按需求：ready 动画开始时即触发存档。
	if is_instance_valid(Game) and Game.has_method("save_game"):
		Game.save_game()
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
