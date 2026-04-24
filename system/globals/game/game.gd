extends Node

var world_states := {}

@onready var color_rect: ColorRect = $ColorRect
@onready var player_stats: Stats = $PlayerStats
@onready var default_player_stats := player_stats.to_dict()

func _ready() -> void:
	color_rect.color.a = 0
	print("游戏管理器初始化完成")

func change_scene(path: String, params: Dictionary = {}) -> void:
	var tree := get_tree()
	
	# 1. 首先保存当前场景的状态（在开始切换前）
	if tree.current_scene != null and not tree.current_scene.scene_file_path.is_empty() and tree.current_scene.has_method("to_dict"):
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
	
	if params.has("entry_point"):
		for node in tree.get_nodes_in_group("entry_points"):
			if node.name == params.entry_point:
				tree.current_scene.update_player(node.global_position)
				player_set = true
				break
	
	if params.has("position") and params.has("direction"):
		tree.current_scene.update_player(params.position, params.direction)
		player_set = true
	
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
## 与 project.godot [autoload] 中名称一致（勿写成 DialogueRegistryManager）
const DIALOGIC_REGISTRY_PATH := "/root/DialogicRegistry"
## 玩家根节点约定组名（与 tip_开.gd 等一致）；由 Player 在 _ready 中入组
const PLAYER_SAVE_GROUP := "player"


func _find_player_node_under_scene(scene: Node) -> Node:
	"""在当前场景子树中查找第一个带 PLAYER_SAVE_GROUP 的 Node2D（浅层优先）。"""
	if scene == null:
		return null
	var queue: Array[Node] = [scene]
	while not queue.is_empty():
		var n: Node = queue.pop_front()
		for c in n.get_children():
			if c is Node2D and c.is_in_group(PLAYER_SAVE_GROUP):
				return c
			queue.append(c)
	return null


func save_game() -> void:
	var scene := get_tree().current_scene
	if not scene or scene.scene_file_path.is_empty():
		print("错误：没有有效的当前场景")
		return
	
	var scene_name := scene.scene_file_path.get_file().get_basename()
	
	# 保存场景状态
	if scene.has_method("to_dict"):
		world_states[scene_name] = scene.to_dict()
	
	# 保存角色注册信息
	var character_registry_data = {}
	
	# 通过自动加载节点获取注册表
	var registry = get_node_or_null(DIALOGIC_REGISTRY_PATH)
	if registry and registry.has_method("save_registry"):
		character_registry_data = registry.save_registry()
	else:
		print("警告：DialogicRegistry 不存在或没有 save_registry 方法，跳过保存角色注册信息")
	
	var player_position = Vector2.ZERO
	var player_direction = 1
	
	var player_node := _find_player_node_under_scene(scene)
	if player_node:
		player_position = player_node.global_position
		if player_node.has_method("get_direction"):
			player_direction = player_node.get_direction()
		elif "direction" in player_node:
			player_direction = player_node.direction
	
	var data := {
		"world_states": world_states,
		"character_registry": character_registry_data,
		"stats": player_stats.to_dict(),
		"scene": scene.scene_file_path,
		"player": {
			"direction": player_direction,
			"position": {
				"x": player_position.x,
				"y": player_position.y
			}
		}
	}
	
	var json := JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		print("存档失败：无法创建文件")
		return
	
	file.store_string(json)
	file = null
	
	print("游戏已保存: ", scene_name)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("存档文件不存在")
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		print("读取存档失败：无法打开文件")
		return
	
	var json := file.get_as_text()
	var parse_result = JSON.parse_string(json)
	
	if not parse_result or not (parse_result is Dictionary):
		print("存档文件格式错误")
		return
	
	var data := parse_result as Dictionary
	
	# 验证必要字段
	if not data.has("scene") or not data.has("player") or not data.has("stats"):
		print("存档文件缺少必要字段")
		return
	
	# 恢复世界状态
	world_states = data.get("world_states", {})
	
	# 恢复玩家状态
	player_stats.from_dict(data.stats)
	
	# 获取玩家位置和方向
	var player_data = data.get("player", {})
	var position_data = player_data.get("position", {"x": 0, "y": 0})
	var player_position = Vector2(position_data.get("x", 0), position_data.get("y", 0))
	var player_direction = player_data.get("direction", 1)
	
	# 恢复角色注册
	if data.has("character_registry"):
		var registry = get_node_or_null(DIALOGIC_REGISTRY_PATH)
		if registry and registry.has_method("load_registry"):
			registry.load_registry(data.character_registry)
		else:
			print("警告：无法加载角色注册信息，DialogicRegistry 不存在或没有 load_registry 方法")
	
	print("正在加载存档...")
	print("场景: ", data.scene)
	print("玩家位置: ", player_position)
	print("玩家方向: ", player_direction)
	
	change_scene(data.scene, {
		"direction": player_direction,
		"position": player_position
	})

func new_game() -> void:
	# 新游戏：在进入关卡前清空会话状态（勿依赖 change_scene 的 params，避免与步骤 8 的 from_dict 顺序纠缠）
	world_states.clear()
	player_stats.from_dict(default_player_stats)
	var registry = get_node_or_null(DIALOGIC_REGISTRY_PATH)
	if registry and registry.has_method("clear_all"):
		registry.clear_all()
	change_scene("res://system/levels/world.tscn", {})

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		print("保存游戏")
		save_game()
