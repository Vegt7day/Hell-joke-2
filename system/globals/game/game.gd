extends Node

var world_states := {}

@onready var color_rect: ColorRect = $ColorRect
@onready var player_stats: Stats = $PlayerStats
@onready var default_player_stats := player_stats.to_dict()
const SAVE_SLOT_SAVEPOINT := "savepoint"
const SAVE_SLOT_HEART := "heart"
const SAVE_PATH_SAVEPOINT := "user://data_savepoint.sav"
const SAVE_PATH_HEART := "user://data_heart.sav"
const WORLD3_BOSS_SCENE_PATH := "res://system/levels/world3/world3_boss_arena.tscn"
const TITLE_SCENE_PATH := "res://system/scene/title_screen.tscn"
const WORLD3_DEATH_UI_SCENE := preload("res://system/ui/world3_death_retry_ui.tscn")
var _world3_death_ui_opened: bool = false

## World3 死亡：先全屏白闪再出死亡 UI（Tween 在暂停下仍推进）
@export var world3_death_flash_peak_alpha: float = 0.92
@export var world3_death_flash_fade_in: float = 0.07
@export var world3_death_flash_fade_out: float = 0.32

func _ready() -> void:
	color_rect.color.a = 0
	if player_stats != null and not player_stats.health_changed.is_connected(_on_player_stats_changed):
		player_stats.health_changed.connect(_on_player_stats_changed)
	print("游戏管理器初始化完成")


func bind_player_stats_runtime(new_stats: Stats) -> void:
	# 运行时切换玩家 Stats 数据源时，必须重连 health_changed，否则死亡 UI 不会触发
	if new_stats == null:
		return
	if player_stats != null and is_instance_valid(player_stats) and player_stats.health_changed.is_connected(_on_player_stats_changed):
		player_stats.health_changed.disconnect(_on_player_stats_changed)
	player_stats = new_stats
	if not player_stats.health_changed.is_connected(_on_player_stats_changed):
		player_stats.health_changed.connect(_on_player_stats_changed)


func _rebind_player_stats_to_embedded() -> void:
	# 关卡玩家的 Stats 随场景释放；会话重置时必须回到 Autoload Game 下的嵌入式 PlayerStats
	var embedded := get_node_or_null("PlayerStats") as Stats
	if embedded == null:
		push_error("Game: 找不到嵌入式 PlayerStats，无法重置会话")
		return
	if player_stats != null and player_stats != embedded:
		if is_instance_valid(player_stats) and player_stats.health_changed.is_connected(_on_player_stats_changed):
			player_stats.health_changed.disconnect(_on_player_stats_changed)
	player_stats = embedded
	if not player_stats.health_changed.is_connected(_on_player_stats_changed):
		player_stats.health_changed.connect(_on_player_stats_changed)


func _is_autoload_game() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	return get_parent() == tree.root and name == "Game"


func _current_scene_is_title(p_tree: SceneTree = null) -> bool:
	var tree := p_tree if p_tree != null else get_tree()
	if tree == null or tree.current_scene == null:
		return false
	return tree.current_scene.scene_file_path == TITLE_SCENE_PATH


func _shutdown_dialogic_for_navigation() -> void:
	# Dialogic 布局挂全局；不切干净则回标题后仍会吞输入/继续推进事件
	var dlg := get_node_or_null("/root/Dialogic") as Node
	if dlg == null or not dlg.has_method("clear"):
		return
	await dlg.clear()


func strip_dialogic_mouse_blockers() -> void:
	# dialogic_default_action 绑定了鼠标左键：残留的 FullAdvanceInputLayer / DialogicNode_Input 会拦住 GUI 点击（键盘 ui_accept 仍可用）
	if not _is_autoload_game():
		return
	var dlg: Variant = get_node_or_null("/root/Dialogic")
	if dlg != null:
		var styles: Variant = dlg.Styles
		if styles != null and styles.has_method("has_active_layout_node") and styles.has_active_layout_node():
			var layout_root: Variant = styles.get_layout_node()
			if layout_root is Node and is_instance_valid(layout_root):
				(layout_root as Node).queue_free()
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group(&"dialogic_input"):
		if is_instance_valid(n):
			n.queue_free()


func change_scene(path: String, params: Dictionary = {}) -> void:
	MechanismLinkBus.clear_last_states()
	var tree := get_tree()
	await _shutdown_dialogic_for_navigation()
	
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
	
	if params.has("shangyang_summon_unlocked"):
		var pn := _find_player_node_under_scene(tree.current_scene)
		if pn is Player:
			(pn as Player).shangyang_summon_unlocked = bool(params["shangyang_summon_unlocked"])
	
	# 10. 恢复游戏
	tree.paused = false
	if tree.current_scene.scene_file_path == TITLE_SCENE_PATH:
		call_deferred("strip_dialogic_mouse_blockers")
	
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


func _save_path_for_slot(slot: String) -> String:
	if slot == SAVE_SLOT_HEART:
		return SAVE_PATH_HEART
	return SAVE_PATH_SAVEPOINT


func has_save(slot: String = SAVE_SLOT_SAVEPOINT) -> bool:
	return FileAccess.file_exists(_save_path_for_slot(slot))


func save_game(slot: String = SAVE_SLOT_SAVEPOINT, skip_pause: bool = false) -> void:
	var tree := get_tree()
	if tree == null:
		print("存档失败：SceneTree 不可用")
		return
	# 保存期间：暂停世界 + 禁用玩家操控（保存结束后恢复）
	var paused_before := tree.paused
	if not skip_pause:
		tree.paused = true
	var scene := tree.current_scene
	var player_node_for_lock := _find_player_node_under_scene(scene)
	var input_before: Variant = null
	if not skip_pause and player_node_for_lock != null and "enable_input_control" in player_node_for_lock:
		input_before = player_node_for_lock.get("enable_input_control")
		player_node_for_lock.set("enable_input_control", false)
	# 由于本函数无 await，保存写盘完成即立刻恢复 paused/input
	# 注意：任何早退都必须走到末尾恢复
	if not scene or scene.scene_file_path.is_empty():
		print("错误：没有有效的当前场景")
		if not skip_pause and input_before != null and player_node_for_lock != null and "enable_input_control" in player_node_for_lock:
			player_node_for_lock.set("enable_input_control", input_before)
		if not skip_pause:
			tree.paused = paused_before
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
	var player_camera_local := Vector2.ZERO
	var summon_unlocked := false
	
	var player_node := _find_player_node_under_scene(scene)
	if player_node:
		player_position = player_node.global_position
		if player_node.has_method("get_direction"):
			player_direction = player_node.get_direction()
		elif "direction" in player_node:
			player_direction = player_node.direction
		if player_node is Player:
			summon_unlocked = (player_node as Player).shangyang_summon_unlocked
		var cam := (player_node as Node).get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			player_camera_local = cam.position
	
	var player_inventory_dict := {}
	if player_node != null and (player_node as Node).has_node("PlayerInventory"):
		var inv := (player_node as Node).get_node("PlayerInventory")
		if inv.has_method("to_dict"):
			player_inventory_dict = inv.to_dict()

	var data := {
		"world_states": world_states,
		"character_registry": character_registry_data,
		"stats": player_stats.to_dict(),
		"mechanism_bus": MechanismLinkBus.export_state(),
		"bucket_states": _export_bucket_states(scene),
		"camera_cue_states": _export_camera_cue_states(scene),
		"player_inventory": player_inventory_dict,
		"scene": scene.scene_file_path,
		"player": {
			"direction": player_direction,
			"position": {
				"x": player_position.x,
				"y": player_position.y
			},
			"camera_local": {"x": player_camera_local.x, "y": player_camera_local.y},
			"shangyang_summon_unlocked": summon_unlocked
		}
	}
	
	var json := JSON.stringify(data)
	var path := _save_path_for_slot(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print("存档失败：无法创建文件")
		if input_before != null and player_node_for_lock != null and "enable_input_control" in player_node_for_lock:
			player_node_for_lock.set("enable_input_control", input_before)
		tree.paused = paused_before
		return
	
	file.store_string(json)
	file = null
	
	print("游戏已保存: ", scene_name, " slot=", slot)
	if not skip_pause and input_before != null and player_node_for_lock != null and "enable_input_control" in player_node_for_lock:
		player_node_for_lock.set("enable_input_control", input_before)
	if not skip_pause:
		tree.paused = paused_before


func _export_bucket_states(scene: Node) -> Dictionary:
	var out := {}
	if scene == null:
		return out
	for n in get_tree().get_nodes_in_group("save_bucket"):
		if n == null or not is_instance_valid(n):
			continue
		# 仅保存当前场景子树内的桶
		if scene != null and not scene.is_ancestor_of(n):
			continue
		if (n as Node).has_method("export_save_state"):
			out[String(scene.get_path_to(n as Node))] = (n as Node).call("export_save_state")
	return out


func _apply_bucket_states(scene: Node, states: Dictionary) -> void:
	if scene == null or states == null:
		return
	for key in states.keys():
		var p := NodePath(String(key))
		var node := scene.get_node_or_null(p)
		if node != null and (node as Node).has_method("apply_save_state"):
			(node as Node).call("apply_save_state", states[key])


func _export_camera_cue_states(scene: Node) -> Dictionary:
	var out := {}
	if scene == null:
		return out
	for n in get_tree().get_nodes_in_group("save_camera_cue"):
		if n == null or not is_instance_valid(n):
			continue
		if scene != null and not scene.is_ancestor_of(n):
			continue
		if (n as Node).has_method("export_save_state"):
			out[String(scene.get_path_to(n as Node))] = (n as Node).call("export_save_state")
	return out


func _apply_camera_cue_states(scene: Node, states: Dictionary) -> void:
	if scene == null or states == null:
		return
	for key in states.keys():
		var p := NodePath(String(key))
		var node := scene.get_node_or_null(p)
		if node != null and (node as Node).has_method("apply_save_state"):
			(node as Node).call("apply_save_state", states[key])

func load_game(reset_current_scene: bool = false, slot: String = SAVE_SLOT_SAVEPOINT) -> void:
	var path := _save_path_for_slot(slot)
	if not FileAccess.file_exists(path):
		print("存档文件不存在")
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
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

	# 记录机关状态：读档切场景时先清空总线，需在新场景加载后再恢复
	Engine.set_meta("__pending_mechanism_bus_state", data.get("mechanism_bus", {}))
	Engine.set_meta("__pending_bucket_states", data.get("bucket_states", {}))
	Engine.set_meta("__pending_camera_cue_states", data.get("camera_cue_states", {}))
	Engine.set_meta("__pending_player_inventory", data.get("player_inventory", {}))
	
	# 获取玩家位置和方向
	var player_data = data.get("player", {})
	var position_data = player_data.get("position", {"x": 0, "y": 0})
	var player_position = Vector2(position_data.get("x", 0), position_data.get("y", 0))
	var player_direction = player_data.get("direction", 1)
	var camera_local_data = player_data.get("camera_local", {"x": 0, "y": 0})
	var player_camera_local := Vector2(camera_local_data.get("x", 0), camera_local_data.get("y", 0))
	
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
	print("存档槽: ", slot)

	if reset_current_scene:
		# 读档已走 reload_scene_from_save（不保存当前场景状态）；
		# 这里不再手动销毁 current_scene，避免当前调用者随场景一起被释放导致 get_tree() 失效。
		pass
	
	var load_params := {
		"direction": player_direction,
		"position": player_position,
		"camera_local": player_camera_local,
		"shangyang_summon_unlocked": player_data.get("shangyang_summon_unlocked", false)
	}
	_world3_death_ui_opened = false
	await reload_scene_from_save(data.scene, load_params)


func reload_scene_from_save(path: String, params: Dictionary = {}) -> void:
	# 读档专用：不保存当前场景状态，直接按存档重建目标场景并恢复数据。
	MechanismLinkBus.clear_last_states()
	var tree := get_tree()
	if tree == null:
		push_error("读档失败：SceneTree 不可用")
		return
	await _shutdown_dialogic_for_navigation()
	tree.paused = true
	if color_rect != null:
		var fade_out := create_tween()
		fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade_out.tween_property(color_rect, "color:a", 1, 0.2)
		await fade_out.finished
	tree.change_scene_to_file(path)
	await _wait_for_scene_load(tree, 30)
	if tree.current_scene == null:
		push_error("读档失败：目标场景未加载")
		tree.paused = false
		return
	var new_name := tree.current_scene.scene_file_path.get_file().get_basename()
	# 先恢复机关总线状态，让门窗/开关在 _ready 的 deferred_sync_initial_from_bus 中无动画同步
	if Engine.has_meta("__pending_mechanism_bus_state"):
		var mb: Variant = Engine.get_meta("__pending_mechanism_bus_state")
		if mb is Dictionary:
			MechanismLinkBus.import_state(mb as Dictionary, false)
		Engine.remove_meta("__pending_mechanism_bus_state")
	# 先恢复桶状态（尽量在场景脚本 from_dict 之前）
	if Engine.has_meta("__pending_bucket_states"):
		var bs: Variant = Engine.get_meta("__pending_bucket_states")
		if bs is Dictionary:
			_apply_bucket_states(tree.current_scene, bs as Dictionary)
		Engine.remove_meta("__pending_bucket_states")
	# 恢复相机 cue（焦点区/拖拽区）的触发次数
	if Engine.has_meta("__pending_camera_cue_states"):
		var cs: Variant = Engine.get_meta("__pending_camera_cue_states")
		if cs is Dictionary:
			_apply_camera_cue_states(tree.current_scene, cs as Dictionary)
		Engine.remove_meta("__pending_camera_cue_states")
	# 恢复玩家背包
	if Engine.has_meta("__pending_player_inventory"):
		var pid: Variant = Engine.get_meta("__pending_player_inventory")
		if pid is Dictionary and not pid.is_empty():
			var pn := _find_player_node_under_scene(tree.current_scene)
			if pn != null and (pn as Node).has_node("PlayerInventory"):
				var inv := (pn as Node).get_node("PlayerInventory")
				if inv.has_method("from_dict"):
					inv.from_dict(pid as Dictionary)
		Engine.remove_meta("__pending_player_inventory")
	if new_name in world_states and tree.current_scene.has_method("from_dict"):
		tree.current_scene.from_dict(world_states[new_name])
		print("读档恢复场景状态: ", new_name)
	# 读档后再广播一次总线状态：确保门/窗/开关已连接信号后能同步（恢复期间不播动画）
	if MechanismLinkBus.has_method("rebroadcast_all_states"):
		await tree.process_frame
		MechanismLinkBus.rebroadcast_all_states()
	if params.has("position") and params.has("direction") and tree.current_scene.has_method("update_player"):
		tree.current_scene.update_player(params.position, params.direction)
	if params.has("camera_local"):
		var pn_cam := _find_player_node_under_scene(tree.current_scene)
		if pn_cam != null and (pn_cam as Node).has_method("apply_camera_local_position_from_save"):
			(pn_cam as Node).call("apply_camera_local_position_from_save", params["camera_local"])
	if params.has("shangyang_summon_unlocked"):
		var pn := _find_player_node_under_scene(tree.current_scene)
		if pn is Player:
			(pn as Player).shangyang_summon_unlocked = bool(params["shangyang_summon_unlocked"])
	tree.paused = false
	if color_rect != null:
		await tree.process_frame
		var fade_in := create_tween()
		fade_in.tween_property(color_rect, "color:a", 0, 0.2)

func _reset_session_for_new_run() -> void:
	world_states.clear()
	_rebind_player_stats_to_embedded()
	if player_stats != null and is_instance_valid(player_stats):
		player_stats.from_dict(default_player_stats)
	var registry = get_node_or_null(DIALOGIC_REGISTRY_PATH)
	if registry and registry.has_method("clear_all"):
		registry.clear_all()
	_world3_death_ui_opened = false


func new_game() -> void:
	# 新游戏：在进入关卡前清空会话状态（勿依赖 change_scene 的 params，避免与步骤 8 的 from_dict 顺序纠缠）
	_reset_session_for_new_run()
	change_scene("res://system/levels/world.tscn", {})


func return_to_title_screen() -> void:
	# 返回标题：会话重置与 new_game 一致，但进入主菜单而非关卡
	_reset_session_for_new_run()
	change_scene(TITLE_SCENE_PATH, {})

func _unhandled_input(event: InputEvent) -> void:
	# 场景内若实例化了 Game 节点，只允许 Autoload(/root/Game)处理全局存读档输入，避免重入读档卡住。
	if not _is_autoload_game():
		return
	var tree_h := get_tree()
	if _current_scene_is_title(tree_h):
		return
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()
		return
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			print("读取存档（SavePoint槽）")
			load_game(true, SAVE_SLOT_SAVEPOINT)


func _open_pause_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if _current_scene_is_title(tree):
		return
	# 检查 Dialogic 是否活跃（避免冲突）
	var dlg_autoload := DialogicUtil.autoload() if DialogicUtil else null
	if dlg_autoload and dlg_autoload.has_method("has_active_timeline") and dlg_autoload.has_active_timeline():
		return
	# 已有暂停菜单则不重复打开
	for child in tree.root.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("pause_menu.gd"):
			return
	tree.paused = true
	var menu_scene := load("res://system/ui/pause_menu.tscn")
	if menu_scene == null:
		tree.paused = false
		return
	var menu: Node = menu_scene.instantiate()
	if menu == null:
		tree.paused = false
		return
	tree.root.add_child(menu)


func _is_world3_boss_scene(scene: Node) -> bool:
	return scene != null and scene.scene_file_path == WORLD3_BOSS_SCENE_PATH


func _on_player_stats_changed() -> void:
	if player_stats == null or not is_instance_valid(player_stats):
		return
	if player_stats.health > 0:
		return
	var scene := get_tree().current_scene
	if not _is_world3_boss_scene(scene):
		return
	if _world3_death_ui_opened:
		return
	_world3_death_ui_opened = true
	_open_world3_death_retry_ui()


func _play_world3_death_fullscreen_flash() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 200
	flash_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 1)
	flash.modulate = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.offset_left = 0.0
	flash.offset_top = 0.0
	flash.offset_right = 0.0
	flash.offset_bottom = 0.0
	flash_layer.add_child(flash)
	tree.root.add_child(flash_layer)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(flash, "modulate:a", world3_death_flash_peak_alpha, world3_death_flash_fade_in)
	tw.tween_property(flash, "modulate:a", 0.0, world3_death_flash_fade_out)
	await tw.finished
	flash_layer.queue_free()


func _open_world3_death_retry_ui() -> void:
	if WORLD3_DEATH_UI_SCENE == null:
		_world3_death_ui_opened = false
		return
	var tree := get_tree()
	if tree == null:
		_world3_death_ui_opened = false
		return
	tree.paused = true
	await _play_world3_death_fullscreen_flash()
	var ui := WORLD3_DEATH_UI_SCENE.instantiate() as CanvasLayer
	if ui == null:
		tree.paused = false
		_world3_death_ui_opened = false
		return
	tree.root.add_child(ui)
	if ui.has_method("bind_game"):
		ui.call("bind_game", self)


func on_world3_death_choice_load_heart() -> void:
	if not has_save(SAVE_SLOT_HEART):
		print("心剑存档不存在，无法回到上一个心。")
		return
	get_tree().paused = false
	load_game(true, SAVE_SLOT_HEART)


func on_world3_death_choice_load_savepoint() -> void:
	if not has_save(SAVE_SLOT_SAVEPOINT):
		print("存档点存档不存在，无法读取。")
		return
	get_tree().paused = false
	load_game(true, SAVE_SLOT_SAVEPOINT)
