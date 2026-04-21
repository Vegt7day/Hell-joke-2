extends Node

@onready var color_rect: ColorRect = $ColorRect
@onready var player_stats: Stats = $PlayerStats

func _ready() -> void:
	color_rect.color.a = 0

func change_scene(path:String,entery_point:String)->void:
	var tree:= get_tree()
	tree.change_scene_to_file(path)
	await tree.process_frame
	for node in tree.get_nodes_in_group("entry_points"):
		if node.name==entery_point:
			tree.current_scene.update_player(node.global_position)
			break
#
#const SAVE_PATH := "user://data.sav"
#func save_game() -> void:
	#var scene :=get_tree().current_scene
	#var scene_name := scene.scene_file_path.get_file().get_basename()
	#world_states[scene_name]=scene.to_dict()
	#
	#var data:= {
		#world_states=world_states,
		#stats=player_stats.to_dict()
		#scene=scene.scene_file_path
		#player={
			#direction=scene.player.direction,
			#position={
				#x=scene.player.global_position.x,
				#y=scene.player.global_position.y,
			#},
		#},
	#}
