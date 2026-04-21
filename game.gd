extends Node
const SAVE_PATH := "user://data.sav"


func save_game() -> void:
	var scene :=get_tree().current_scene
	var scene_name := scene.scene_file_path.get_file().get_basename()
	world_states[scene_name]=scene.to_dict()
	
	var data:= {
		world_states=world_states,
		stats=player_stats.to_dict()
		scene=scene.scene_file_path
		player={
			direction=scene.player.direction,
			position={
				x=scene.player.global_position.x,
				y=scene.player.global_position.y,
			},
		},
	}
