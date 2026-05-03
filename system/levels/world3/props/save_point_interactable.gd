class_name SavePointInteractable
extends Interactable

## 地图传送用的稳定 id；留空则用节点名
@export var save_point_id: String = ""

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


func get_save_point_id() -> String:
	var s := save_point_id.strip_edges()
	if s.is_empty():
		return str(name)
	return s


func interact() -> void:
	if _is_processing_interact:
		return
	if is_instance_valid(Game) and Game.has_method(&"open_save_point_choice_ui"):
		Game.open_save_point_choice_ui(self)
		return


func run_save_sequence_and_heal() -> void:
	if _is_processing_interact:
		return
	_is_processing_interact = true
	# 其它 UI（暂停菜单等）仍可能暂停树；此处始终推进 AnimationPlayer，避免 await animation_finished 挂起
	var prev_pm := process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	var prev_anim_pm := Node.PROCESS_MODE_INHERIT
	if animation_player != null:
		prev_anim_pm = animation_player.process_mode
		animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	super.interact()
	var p := get_tree().get_first_node_in_group(&"player")
	if p != null and p.has_method(&"trigger_hit_shake_only"):
		p.call(&"trigger_hit_shake_only")
	if p != null:
		_interaction_serial += 1
		var heal_id := "savepoint_interact:%s:%d" % [str(get_instance_id()), _interaction_serial]
		if p.has_method(&"recover_full_health_once"):
			p.call(&"recover_full_health_once", heal_id)
		elif p.has_method(&"recover_full_health"):
			p.call(&"recover_full_health")
	if animation_player != null and animation_player.has_animation(ready_anim_name):
		animation_player.play(ready_anim_name)
	if animation_player != null and animation_player.has_animation(ready_anim_name):
		await animation_player.animation_finished
	if animation_player != null and animation_player.has_animation(save_anim_name):
		animation_player.play(save_anim_name)
		await animation_player.animation_finished
	_play_if_exists(recover_anim_name)
	_is_processing_interact = false
	process_mode = prev_pm
	if animation_player != null:
		animation_player.process_mode = prev_anim_pm


func _play_if_exists(anim_name: StringName) -> void:
	if animation_player != null and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


func _get_inspect_description() -> String:
	return "可以存放心灵的节点"
