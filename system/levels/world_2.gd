extends Node2D

@onready var player: Player = $player

func to_dict()-> Dictionary:
	var enemies_alive:=[]
	for node in get_tree().get_nodes_in_group("enemies"):
		var path := get_path_to(node)
		enemies_alive.append(path)
	return{
		enemies_alive=enemies_alive,
	}

func from_dict(dict:Dictionary)->void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var path:=get_path_to(node)
		if path not in dict.enemies_alive:
			node.queue_free()
		
		
func update_player(position: Vector2, direction: int = 1) -> void:
	if has_node("player"):
		var player_node = $player
		if is_instance_valid(player_node):
			player_node.global_position = position
			if player_node.has_method("set_direction"):
				player_node.set_direction(direction)
			elif player_node.has_property("direction"):
				player_node.direction = direction
			else:
				print("玩家没有方向属性或方法")
		else:
			print("玩家节点无效")
	else:
		print("场景中没有找到玩家节点")
