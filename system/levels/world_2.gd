extends Node2D

@onready var player: Player = $Student

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
		var player = $player
		player.global_position = position
		print("传送")
		# 设置玩家方向
		if player.has_method("set_direction"):
			player.set_direction(direction)
		elif player.has_property("direction"):
			player.direction = direction
		else:
			print("玩家没有方向属性或方法")
	else:
		print("场景中没有找到玩家节点")
