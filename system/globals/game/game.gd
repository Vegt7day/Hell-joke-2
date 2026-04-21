extends Node

var world_states := {}

@onready var color_rect: ColorRect = $ColorRect
@onready var player_stats: Stats = $PlayerStats

func _ready() -> void:
	color_rect.color.a = 0

func change_scene(path: String, entery_point: String) -> void:
	var tree := get_tree()
	
	# 1. 首先保存当前场景的状态（在开始切换前）
	if tree.current_scene != null and not tree.current_scene.scene_file_path.is_empty():
		var old_name := tree.current_scene.scene_file_path.get_file().get_basename()
		world_states[old_name] = tree.current_scene.to_dict()
		print("保存场景状态: ", old_name)
	else:
		print("当前场景不存在或未保存，跳过状态保存")
	
	# 2. 暂停游戏并开始淡出动画
	tree.paused = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "color:a", 1, 0.2)
	await tween.finished
	
	# 3. 切换到新场景
	tree.change_scene_to_file(path)
	
	# 4. 等待场景完全加载
	await _wait_for_scene_load(tree, 20)
	
	# 5. 检查新场景是否加载成功
	if tree.current_scene == null:
		push_error("新场景加载失败！current_scene 为 null")
		tree.paused = false
		return
	
	# 6. 检查新场景是否有有效路径
	if tree.current_scene.scene_file_path.is_empty():
		push_error("新场景没有保存路径，无法获取名称")
		tree.paused = false
		return
	
	# 7. 获取新场景名称
	var new_name := tree.current_scene.scene_file_path.get_file().get_basename()
	print("加载场景: ", new_name)
	
	# 8. 恢复场景状态（如果之前保存过）
	if new_name in world_states:
		tree.current_scene.from_dict(world_states[new_name])
		print("恢复场景状态: ", new_name)
	
	# 9. 设置玩家到入口点
	var player_set = false
	for node in tree.get_nodes_in_group("entry_points"):
		if node.name == entery_point:
			tree.current_scene.update_player(node.global_position)
			print("设置玩家到入口点: ", entery_point)
			player_set = true
			break
	
	if not player_set:
		push_error("未找到入口点: " + entery_point)
	
	# 10. 恢复游戏
	tree.paused = false
	
	# 11. 淡入动画
	await tree.process_frame
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0, 0.2)

# 等待场景加载的辅助函数
func _wait_for_scene_load(tree: SceneTree, max_frames: int) -> void:
	print("等待场景加载...")
	for i in range(max_frames):
		if tree.current_scene != null and not tree.current_scene.scene_file_path.is_empty():
			print("场景在第", i + 1, "帧加载完成")
			return
		await tree.process_frame
		print("等待第", i + 1, "帧...")
	
	push_error("场景加载超时，等待了" + str(max_frames) + "帧")

const SAVE_PATH := "user://data.sav"
func save_game() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		push_error("无法保存：当前场景为 null")
		return
	
	if scene.scene_file_path.is_empty():
		push_error("无法保存：场景未保存到文件")
		return
	
	var scene_name := scene.scene_file_path.get_file().get_basename()
	world_states[scene_name] = scene.to_dict()
	
	# 检查是否有 player 属性
	if scene.has_method("get_player"):
		var player = scene.get_player()
		var data := {
			"world_states": world_states,
			"stats": player_stats.to_dict(),
			"scene": scene.scene_file_path,
			"player": {
				"direction": player.direction if player.has_property("direction") else Vector2.ZERO,
				"position": {
					"x": player.global_position.x,
					"y": player.global_position.y
				}
			}
		}
		print("游戏已保存: ", scene_name)
	else:
		print("场景没有 get_player 方法，保存基本状态")
