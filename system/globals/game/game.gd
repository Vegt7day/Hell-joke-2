extends Node

var world_states := {}

## 地图探索：场景文件 basename → { "gx_gy": true }（玩家经过的逻辑格，存档持久化）
var map_exploration: Dictionary = {}
## 已在存档点选择「存档」或「传送」并登记的存档点，键："scene_bn::save_point_id"（地图上「存」显示红色）
var save_points_known: Dictionary = {}
var observed_mechanisms: Dictionary = {}
var observed_boss_skills: Dictionary = {}
## 地图详图：相对足迹的轴对齐矩形（逻辑格）。左/右各 10，上 7（y 减小），下 3（y 增大）
const MAP_DETAIL_HALF_W := 10
const MAP_DETAIL_UP := 7
const MAP_DETAIL_DOWN := 3
## 地图灰块：相对足迹更大矩形。左/右各 20，上 14，下 6（仅外形无字）
const MAP_DIM_HALF_W := 20
const MAP_DIM_UP := 14
const MAP_DIM_DOWN := 6

@onready var color_rect: ColorRect = $ColorRect
@onready var player_stats: Stats = $PlayerStats
@onready var default_player_stats := player_stats.to_dict()
const SAVE_SLOT_SAVEPOINT := "savepoint"
const SAVE_SLOT_HEART := "heart"
## 暂停菜单 / 标题 / 存档点共用的三个手动槽位（同一套文件）
const SAVE_SLOT_MANUAL_1 := "manual_1"
const SAVE_SLOT_MANUAL_2 := "manual_2"
const SAVE_SLOT_MANUAL_3 := "manual_3"
const SAVE_PATH_SAVEPOINT := "user://data_savepoint.sav"
const SAVE_PATH_HEART := "user://data_heart.sav"
const SAVE_PATH_MANUAL_1 := "user://save_slot_1.sav"
const SAVE_PATH_MANUAL_2 := "user://save_slot_2.sav"
const SAVE_PATH_MANUAL_3 := "user://save_slot_3.sav"

enum SaveSlotsSheetMode {
	SAVE,
	LOAD,
}
const WORLD3_BOSS_SCENE_PATH := "res://system/levels/world3/world3_boss_arena.tscn"
const TITLE_SCENE_PATH := "res://system/scene/title_screen.tscn"
const SETTINGS_CFG_PATH := "user://settings.cfg"
const SETTINGS_UI_GROUP := &"settings_ui"
const SAVE_SLOTS_SHEET_GROUP := &"save_slots_sheet"
const AUDIO_VOL_MIN_DB := -80.0
const AUDIO_VOL_MAX_DB := 0.0
const WORLD3_DEATH_UI_SCENE := preload("res://system/ui/world3_death_retry_ui.tscn")
const _AUDIO_UTILS := preload("res://system/globals/audio_utils.gd")
const _STREAM_DEFAULT_BGM := preload("res://assets/资源总库/10_音频/场景背景音乐.mp3")
var _world3_death_ui_opened: bool = false
var _continuous_bgm_player: AudioStreamPlayer
var _continuous_bgm_player_b: AudioStreamPlayer
var _continuous_bgm_is_default_stream: bool = true
var _continuous_bgm_crossfade_active_is_a: bool = true
var _continuous_bgm_crossfade_tween: Tween
const _BOSS_BGM_SILENT_DB := -60.0
var _settings_window_width: int = 640
var _settings_window_height: int = 360

## World3 死亡：先全屏白闪再出死亡 UI（Tween 在暂停下仍推进）
@export var world3_death_flash_peak_alpha: float = 0.92
@export var world3_death_flash_fade_in: float = 0.07
@export var world3_death_flash_fade_out: float = 0.32

func _ready() -> void:
	color_rect.color.a = 0
	if player_stats != null and not player_stats.health_changed.is_connected(_on_player_stats_changed):
		player_stats.health_changed.connect(_on_player_stats_changed)
	print("游戏管理器初始化完成")
	call_deferred(&"apply_saved_settings")
	call_deferred(&"ensure_continuous_bgm_playing")


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


## 标题 / 关卡 / 切换场景共用同一 BGM 节点，避免切段；关卡脚本在进入时也调用以保持播放。
func ensure_continuous_bgm_playing() -> void:
	if not _is_autoload_game():
		return
	var tree := get_tree()
	var on_boss_arena := tree != null and tree.current_scene != null and tree.current_scene.scene_file_path == WORLD3_BOSS_SCENE_PATH
	if not on_boss_arena:
		_normalize_continuous_bgm_after_leaving_boss_arena()
	if _continuous_bgm_player == null or not is_instance_valid(_continuous_bgm_player):
		_continuous_bgm_player = _AUDIO_UTILS.ensure_looping_bgm(self, null, _STREAM_DEFAULT_BGM, &"BGM", &"ContinuousBgm")
	elif not _continuous_bgm_player.playing:
		_continuous_bgm_player.play()


func _normalize_continuous_bgm_after_leaving_boss_arena() -> void:
	boss_bgm_kill_crossfade_tween()
	if _continuous_bgm_player_b != null and is_instance_valid(_continuous_bgm_player_b):
		_continuous_bgm_player_b.stop()
	if _continuous_bgm_player != null and is_instance_valid(_continuous_bgm_player):
		_continuous_bgm_player.volume_db = 0.0
		if not _continuous_bgm_is_default_stream:
			_AUDIO_UTILS.assign_looping_stream_to_player(_continuous_bgm_player, _STREAM_DEFAULT_BGM)
			_continuous_bgm_is_default_stream = true
		if not _continuous_bgm_player.playing:
			_continuous_bgm_player.play()
	_continuous_bgm_crossfade_active_is_a = true


func _ensure_continuous_bgm_player_b() -> void:
	if _continuous_bgm_player_b != null and is_instance_valid(_continuous_bgm_player_b):
		return
	var p := AudioStreamPlayer.new()
	p.name = "ContinuousBgmB"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.bus = &"BGM"
	add_child(p)
	_continuous_bgm_player_b = p


func _continuous_bgm_active_player() -> AudioStreamPlayer:
	return _continuous_bgm_player if _continuous_bgm_crossfade_active_is_a else _continuous_bgm_player_b


func _continuous_bgm_incoming_player() -> AudioStreamPlayer:
	return _continuous_bgm_player_b if _continuous_bgm_crossfade_active_is_a else _continuous_bgm_player


func boss_bgm_kill_crossfade_tween() -> void:
	if _continuous_bgm_crossfade_tween != null and is_instance_valid(_continuous_bgm_crossfade_tween):
		_continuous_bgm_crossfade_tween.kill()
	_continuous_bgm_crossfade_tween = null


func boss_bgm_has_active_crossfade_tween() -> bool:
	return _continuous_bgm_crossfade_tween != null and is_instance_valid(_continuous_bgm_crossfade_tween)


func boss_bgm_active_output_is_audible(threshold_db: float = -54.0) -> bool:
	if _continuous_bgm_player == null:
		return false
	var p := _continuous_bgm_active_player()
	return p != null and is_instance_valid(p) and p.playing and p.volume_db > threshold_db


## Boss 场开局：使用 Autoload 上的 ContinuousBgm / ContinuousBgmB 做双轨交叉淡化（与关卡共用同一对节点）。
func boss_bgm_crossfade_start(initial_stream: AudioStream, volume_db: float) -> void:
	if not _is_autoload_game():
		return
	boss_bgm_kill_crossfade_tween()
	if _continuous_bgm_player == null or not is_instance_valid(_continuous_bgm_player):
		_continuous_bgm_player = _AUDIO_UTILS.ensure_looping_bgm(self, null, initial_stream, &"BGM", &"ContinuousBgm")
	else:
		_AUDIO_UTILS.assign_looping_stream_to_player(_continuous_bgm_player, initial_stream)
	_continuous_bgm_is_default_stream = false
	_continuous_bgm_player.volume_db = volume_db
	_continuous_bgm_player.play()
	_ensure_continuous_bgm_player_b()
	if _continuous_bgm_player_b != null:
		_continuous_bgm_player_b.stop()
		_continuous_bgm_player_b.volume_db = _BOSS_BGM_SILENT_DB
	_continuous_bgm_crossfade_active_is_a = true


func boss_bgm_crossfade_to(target_stream: AudioStream, duration_seconds: float, volume_db: float, fade_finished: Callable = Callable()) -> void:
	if not _is_autoload_game():
		return
	ensure_continuous_bgm_playing()
	_ensure_continuous_bgm_player_b()
	var outgoing := _continuous_bgm_active_player()
	var incoming := _continuous_bgm_incoming_player()
	if outgoing == null or incoming == null:
		return
	_AUDIO_UTILS.assign_looping_stream_to_player(incoming, target_stream)
	_continuous_bgm_is_default_stream = false
	incoming.volume_db = _BOSS_BGM_SILENT_DB
	if not incoming.playing:
		incoming.play(0.0)
	boss_bgm_kill_crossfade_tween()
	_continuous_bgm_crossfade_tween = create_tween()
	_continuous_bgm_crossfade_tween.set_parallel(true)
	_continuous_bgm_crossfade_tween.tween_property(outgoing, "volume_db", _BOSS_BGM_SILENT_DB, duration_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_continuous_bgm_crossfade_tween.tween_property(incoming, "volume_db", volume_db, duration_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var out_player := outgoing
	var set_active_is_a := not _continuous_bgm_crossfade_active_is_a
	var on_crossfade_done := func():
		if is_instance_valid(out_player):
			out_player.stop()
		_continuous_bgm_crossfade_active_is_a = set_active_is_a
		if fade_finished.is_valid():
			fade_finished.call()
	_continuous_bgm_crossfade_tween.finished.connect(on_crossfade_done, CONNECT_ONE_SHOT)


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
	ensure_continuous_bgm_playing()
	
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


func _resolve_player_inventory_dict(scene: Node) -> Dictionary:
	if scene == null:
		return {}
	var q: Array[Node] = [scene]
	while not q.is_empty():
		var n: Node = q.pop_front()
		if n is PlayerInventory:
			var inv := n as PlayerInventory
			if inv.has_method(&"to_dict"):
				return inv.to_dict()
		for ch in n.get_children():
			q.append(ch)
	return {}


func _save_path_for_slot(slot: String) -> String:
	match slot:
		SAVE_SLOT_HEART:
			return SAVE_PATH_HEART
		SAVE_SLOT_SAVEPOINT:
			return SAVE_PATH_SAVEPOINT
		SAVE_SLOT_MANUAL_1:
			return SAVE_PATH_MANUAL_1
		SAVE_SLOT_MANUAL_2:
			return SAVE_PATH_MANUAL_2
		SAVE_SLOT_MANUAL_3:
			return SAVE_PATH_MANUAL_3
		_:
			return SAVE_PATH_SAVEPOINT


func manual_save_slot_ids() -> PackedStringArray:
	return PackedStringArray([SAVE_SLOT_MANUAL_1, SAVE_SLOT_MANUAL_2, SAVE_SLOT_MANUAL_3])


func manual_save_slot_id(index_zero_based: int) -> String:
	var ids := manual_save_slot_ids()
	if index_zero_based < 0 or index_zero_based >= ids.size():
		return SAVE_SLOT_MANUAL_1
	return ids[index_zero_based]


## Unix 秒 → 本机 wall-clock（年月日时分）。引擎内部 dict-from-unix 按 UTC 拆分，此处用 OS 时区 bias（含夏令时偏移）对齐电脑时钟。
func format_unix_timestamp_local_wall_datetime(unix_ts: float) -> String:
	var ts := int(floor(unix_ts + 0.5))
	var tz := Time.get_time_zone_from_system()
	var bias_min := int(tz.get("bias", 0))
	var dt := Time.get_datetime_dict_from_unix_time(ts + bias_min * 60)
	return "%04d-%02d-%02d %02d:%02d" % [int(dt.year), int(dt.month), int(dt.day), int(dt.hour), int(dt.minute)]


## 读取手动槽存档摘要（供槽位选择 UI）；无文件或损坏返回 empty=true
func read_manual_save_slot_summary(slot_id: String) -> Dictionary:
	var path := _save_path_for_slot(slot_id)
	var empty_ret := {"empty": true}
	if not FileAccess.file_exists(path):
		return empty_ret
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return empty_ret
	var json_text := file.get_as_text()
	file = null
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not (parsed is Dictionary):
		return empty_ret
	var d: Dictionary = parsed as Dictionary
	var scene_path := str(d.get("scene", ""))
	var basename_fallback := scene_path.get_file().get_basename() if not scene_path.is_empty() else ""
	var map_label := basename_fallback
	var time_text := ""
	var saved_unix := -1.0
	var meta: Variant = d.get("save_meta", null)
	if meta is Dictionary:
		var m: Dictionary = meta as Dictionary
		var bn := str(m.get("scene_basename", "")).strip_edges()
		if not bn.is_empty():
			map_label = bn
		elif m.has("scene_path"):
			map_label = str(m.get("scene_path", "")).get_file().get_basename()
		if m.has("saved_at_unix"):
			saved_unix = float(m.get("saved_at_unix", -1.0))
	if map_label.is_empty():
		map_label = "未知地图"
	if saved_unix >= 0.0:
		time_text = format_unix_timestamp_local_wall_datetime(saved_unix)
	return {"empty": false, "map_label": map_label, "time_text": time_text, "saved_at_unix": saved_unix}


func has_any_manual_save() -> bool:
	for id in manual_save_slot_ids():
		if has_save(id):
			return true
	return false


## 用于死亡重试 / 快捷键：取三个手动槽中最近一次存档（优先 save_meta 时间，否则文件修改时间）
func find_latest_manual_save_slot_id() -> String:
	var best_id := ""
	var best_key := -1.0
	for id in manual_save_slot_ids():
		var summ := read_manual_save_slot_summary(id)
		if bool(summ.get("empty", true)):
			continue
		var u := float(summ.get("saved_at_unix", -1.0))
		var key := u
		if key < 0.0:
			var p := _save_path_for_slot(id)
			key = float(FileAccess.get_modified_time(p))
		if key > best_key:
			best_key = key
			best_id = id
	return best_id


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
	
	var player_inventory_dict := _resolve_player_inventory_dict(scene)

	var data := {
		"world_states": world_states,
		"map_exploration": map_exploration,
		"save_points_known": save_points_known,
		"character_registry": character_registry_data,
		"stats": player_stats.to_dict(),
		"mechanism_bus": MechanismLinkBus.export_state(),
		"bucket_states": _export_bucket_states(scene),
		"camera_cue_states": _export_camera_cue_states(scene),
		"observed_mechanisms": observed_mechanisms,
		"observed_boss_skills": observed_boss_skills,
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
		},
		"save_meta": {
			"scene_path": scene.scene_file_path,
			"scene_basename": scene_name,
			"saved_at_unix": Time.get_unix_time_from_system(),
		},
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

func load_game(reset_current_scene: bool = false, slot: String = SAVE_SLOT_SAVEPOINT) -> bool:
	var path := _save_path_for_slot(slot)
	if not FileAccess.file_exists(path):
		print("存档文件不存在")
		return false
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print("读取存档失败：无法打开文件")
		return false
	
	var json := file.get_as_text()
	var parse_result = JSON.parse_string(json)
	
	if not parse_result or not (parse_result is Dictionary):
		print("存档文件格式错误")
		return false
	
	var data := parse_result as Dictionary
	
	# 验证必要字段
	if not data.has("scene") or not data.has("player") or not data.has("stats"):
		print("存档文件缺少必要字段")
		return false
	
	# 恢复世界状态
	world_states = data.get("world_states", {})
	map_exploration = data.get("map_exploration", {})
	save_points_known = data.get("save_points_known", {})
	observed_mechanisms = data.get("observed_mechanisms", {})
	observed_boss_skills = data.get("observed_boss_skills", {})
	
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
	var tr := get_tree()
	return tr != null and tr.current_scene != null


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
	ensure_continuous_bgm_playing()
	if color_rect != null:
		await tree.process_frame
		var fade_in := create_tween()
		fade_in.tween_property(color_rect, "color:a", 0, 0.2)

func _reset_session_for_new_run() -> void:
	world_states.clear()
	map_exploration.clear()
	save_points_known.clear()
	observed_mechanisms.clear()
	observed_boss_skills.clear()
	_rebind_player_stats_to_embedded()
	if player_stats != null and is_instance_valid(player_stats):
		player_stats.from_dict(default_player_stats)
	var registry = get_node_or_null(DIALOGIC_REGISTRY_PATH)
	if registry and registry.has_method("clear_all"):
		registry.clear_all()
	_world3_death_ui_opened = false


func mark_mechanism_observed(path: String) -> void:
	observed_mechanisms[path] = true


func mark_boss_skill_observed(horse_id: int, skill_id: int) -> void:
	if not observed_boss_skills.has(horse_id):
		observed_boss_skills[horse_id] = []
	if skill_id not in observed_boss_skills[horse_id]:
		observed_boss_skills[horse_id].append(skill_id)


func new_game() -> void:
	# 新游戏：在进入关卡前清空会话状态（勿依赖 change_scene 的 params，避免与步骤 8 的 from_dict 顺序纠缠）
	_reset_session_for_new_run()
	change_scene("res://system/levels/world.tscn", {})


func return_to_title_screen() -> void:
	# 返回标题：会话重置与 new_game 一致，但进入主菜单而非关卡
	_reset_session_for_new_run()
	change_scene(TITLE_SCENE_PATH, {})


func inventory_ui_is_open() -> bool:
	var tree := get_tree()
	return tree != null and tree.get_first_node_in_group(&"inventory_ui") != null


func open_inventory_ui() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if _current_scene_is_title(tree):
		return
	var dlg_autoload := DialogicUtil.autoload() if DialogicUtil else null
	if dlg_autoload and dlg_autoload.has_method("has_active_timeline") and dlg_autoload.has_active_timeline():
		return
	if tree.get_first_node_in_group(&"save_point_choice_ui") != null:
		return
	if inventory_ui_is_open():
		return
	tree.paused = true
	var ps := load("res://system/ui/inventory/inventory_ui.tscn") as PackedScene
	if ps == null:
		tree.paused = false
		return
	var ui := ps.instantiate()
	if ui == null:
		tree.paused = false
		return
	tree.root.add_child(ui)
	CursorManager.set_cursor_type(CursorManager.CursorType.HUD)
	CursorManager.show_cursor()


func close_inventory_ui() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group(&"inventory_ui"):
		if is_instance_valid(n):
			n.queue_free()
	CursorManager.set_cursor_type(CursorManager.CursorType.ATTACK)


func abstract_map_ui_is_open() -> bool:
	var tree := get_tree()
	return tree != null and tree.get_first_node_in_group(&"abstract_map_ui") != null


func open_abstract_map_ui(for_teleport_pick: bool = false) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if _current_scene_is_title(tree):
		return
	var dlg_autoload := DialogicUtil.autoload() if DialogicUtil else null
	if dlg_autoload and dlg_autoload.has_method("has_active_timeline") and dlg_autoload.has_active_timeline():
		return
	if inventory_ui_is_open() or abstract_map_ui_is_open():
		return
	if tree.get_first_node_in_group(&"save_point_choice_ui") != null:
		return
	tree.paused = true
	var ps := load("res://system/ui/abstract_map/abstract_map_ui.tscn") as PackedScene
	if ps == null:
		tree.paused = false
		return
	var ui := ps.instantiate()
	if ui == null:
		tree.paused = false
		return
	ui.set_meta(&"abstract_map_teleport_pick", for_teleport_pick)
	tree.root.add_child(ui)
	CursorManager.set_cursor_type(CursorManager.CursorType.HUD)
	CursorManager.show_cursor()


func close_abstract_map_ui() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group(&"abstract_map_ui"):
		if is_instance_valid(n):
			n.queue_free()
	CursorManager.set_cursor_type(CursorManager.CursorType.ATTACK)


func settings_ui_is_open() -> bool:
	var tree := get_tree()
	return tree != null and tree.get_first_node_in_group(SETTINGS_UI_GROUP) != null


func get_audio_bus_slider_normalized(bus_name: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 1.0
	var db := AudioServer.get_bus_volume_db(idx)
	return clampf((db - AUDIO_VOL_MIN_DB) / (AUDIO_VOL_MAX_DB - AUDIO_VOL_MIN_DB), 0.0, 1.0)


func set_audio_bus_from_normalized(bus_name: StringName, t: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var db := lerpf(AUDIO_VOL_MIN_DB, AUDIO_VOL_MAX_DB, clampf(t, 0.0, 1.0))
	AudioServer.set_bus_volume_db(idx, db)


func _main_window_id() -> int:
	var vp := get_viewport()
	if vp == null:
		return 0
	return vp.get_window_id()


func display_is_fullscreen() -> bool:
	var win_id: int = _main_window_id()
	var m := DisplayServer.window_get_mode(win_id)
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func get_settings_window_width() -> int:
	return _settings_window_width


func get_settings_window_height() -> int:
	return _settings_window_height


func apply_display_settings(fullscreen: bool, window_w: int, window_h: int) -> void:
	_settings_window_width = clampi(window_w, 320, 7680)
	_settings_window_height = clampi(window_h, 240, 4320)
	var win_id: int = _main_window_id()
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, win_id)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, win_id)
		DisplayServer.window_set_size(Vector2i(_settings_window_width, _settings_window_height), win_id)
		var scr := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen(win_id))
		var sz := DisplayServer.window_get_size(win_id)
		var pos := Vector2i((scr.x - sz.x) / 2, (scr.y - sz.y) / 2)
		DisplayServer.window_set_position(pos, win_id)


func apply_saved_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_CFG_PATH) != OK:
		return
	for bus_key in [&"Master", &"BGM", &"SFX", &"UI"]:
		var k := String(bus_key).to_lower()
		if cf.has_section_key("audio", k):
			set_audio_bus_from_normalized(bus_key, float(cf.get_value("audio", k)))
	var fs := bool(cf.get_value("display", "fullscreen", false))
	_settings_window_width = int(cf.get_value("display", "window_width", 640))
	_settings_window_height = int(cf.get_value("display", "window_height", 360))
	apply_display_settings(fs, _settings_window_width, _settings_window_height)


func persist_settings_to_disk() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_CFG_PATH)
	for bus_key in [&"Master", &"BGM", &"SFX", &"UI"]:
		cf.set_value("audio", String(bus_key).to_lower(), get_audio_bus_slider_normalized(bus_key))
	cf.set_value("display", "fullscreen", display_is_fullscreen())
	cf.set_value("display", "window_width", _settings_window_width)
	cf.set_value("display", "window_height", _settings_window_height)
	cf.save(SETTINGS_CFG_PATH)


func open_settings_ui() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if not _current_scene_is_title(tree):
		return
	if settings_ui_is_open():
		return
	var dlg_autoload := DialogicUtil.autoload() if DialogicUtil else null
	if dlg_autoload and dlg_autoload.has_method("has_active_timeline") and dlg_autoload.has_active_timeline():
		return
	if tree.get_first_node_in_group(&"save_point_choice_ui") != null:
		return
	if inventory_ui_is_open() or abstract_map_ui_is_open():
		return
	var ps := load("res://system/ui/settings_panel.tscn") as PackedScene
	if ps == null:
		return
	var ui := ps.instantiate()
	if ui == null:
		return
	tree.root.add_child(ui)
	CursorManager.set_cursor_type(CursorManager.CursorType.HUD)
	CursorManager.show_cursor()


func save_slots_sheet_is_open() -> bool:
	var tree := get_tree()
	return tree != null and tree.get_first_node_in_group(SAVE_SLOTS_SHEET_GROUP) != null


func close_save_point_choice_ui() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var n := tree.get_first_node_in_group(&"save_point_choice_ui")
	if n != null and is_instance_valid(n):
		n.queue_free()
	CursorManager.set_cursor_type(CursorManager.CursorType.ATTACK)


## 存档点交互打开菜单时：先把当前场景快照写入 world_states，选槽写入文件时数据已就绪
func prepare_save_point_session(_save_point: SavePointInteractable) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var sc := tree.current_scene
	if sc.scene_file_path.is_empty():
		return
	var scene_name := sc.scene_file_path.get_file().get_basename()
	if sc.has_method(&"to_dict"):
		world_states[scene_name] = sc.to_dict()


## 槽位保存完成并已解除暂停后：后台播放存档点演出（不阻塞、不在此处改 paused）
func start_save_point_post_save_feedback(save_point: SavePointInteractable) -> void:
	if save_point == null or not is_instance_valid(save_point):
		return
	save_point.run_save_sequence_and_heal()


func open_save_slots_sheet(mode: SaveSlotsSheetMode, pause_menu: Node = null, save_point_after_save: SavePointInteractable = null) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if mode == SaveSlotsSheetMode.SAVE and _current_scene_is_title(tree):
		return
	if save_slots_sheet_is_open():
		return
	var dlg_autoload := DialogicUtil.autoload() if DialogicUtil else null
	if dlg_autoload and dlg_autoload.has_method("has_active_timeline") and dlg_autoload.has_active_timeline():
		return
	if save_point_after_save == null and tree.get_first_node_in_group(&"save_point_choice_ui") != null:
		return
	if inventory_ui_is_open() or abstract_map_ui_is_open():
		return
	if settings_ui_is_open():
		return
	var ps := load("res://system/ui/save_slots_sheet.tscn") as PackedScene
	if ps == null:
		return
	var sheet := ps.instantiate()
	if sheet == null:
		return
	if sheet.has_method(&"setup"):
		sheet.call(&"setup", mode, pause_menu, save_point_after_save)
	tree.root.add_child(sheet)
	CursorManager.set_cursor_type(CursorManager.CursorType.HUD)
	CursorManager.show_cursor()


func get_current_scene_basename() -> String:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	var p := tree.current_scene.scene_file_path
	if p.is_empty():
		return ""
	return p.get_file().get_basename()


func save_point_known_key(scene_bn: String, save_id: String) -> String:
	return "%s::%s" % [scene_bn, save_id]


func mark_save_point_known(scene_bn: String, save_id: String) -> void:
	if scene_bn.is_empty() or save_id.is_empty():
		return
	save_points_known[save_point_known_key(scene_bn, save_id)] = true


func is_save_point_known(scene_bn: String, save_id: String) -> bool:
	if scene_bn.is_empty() or save_id.is_empty():
		return false
	return bool(save_points_known.get(save_point_known_key(scene_bn, save_id), false))


func open_save_point_choice_ui(save_point: SavePointInteractable) -> void:
	var tree := get_tree()
	if tree == null or save_point == null:
		return
	if _current_scene_is_title(tree):
		return
	var dlg_autoload := DialogicUtil.autoload() if DialogicUtil else null
	if dlg_autoload and dlg_autoload.has_method("has_active_timeline") and dlg_autoload.has_active_timeline():
		return
	if inventory_ui_is_open() or abstract_map_ui_is_open():
		return
	if tree.get_first_node_in_group(&"save_point_choice_ui") != null:
		return
	tree.paused = true
	prepare_save_point_session(save_point)
	var ps := load("res://system/ui/save_point_panel.tscn") as PackedScene
	if ps == null:
		tree.paused = false
		return
	var ui := ps.instantiate()
	if ui == null:
		tree.paused = false
		return
	if ui.has_method(&"setup"):
		ui.call(&"setup", save_point)
	tree.root.add_child(ui)
	CursorManager.set_cursor_type(CursorManager.CursorType.HUD)
	CursorManager.show_cursor()


func teleport_player_to_world(global_pos: Vector2, direction: int = -999) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var sc := tree.current_scene
	if not sc.has_method(&"update_player"):
		return
	var dir := direction
	if dir == -999:
		dir = 1
		var pl := tree.get_first_node_in_group(&"player")
		if pl != null and "direction" in pl:
			dir = int(pl.direction)
	sc.call(&"update_player", global_pos, dir)


func register_map_exploration_at_world(world: Vector2) -> void:
	if not _is_autoload_game():
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	if _current_scene_is_title(tree):
		return
	var path_str := tree.current_scene.scene_file_path
	if path_str.is_empty():
		return
	var scene_bn := path_str.get_file().get_basename()
	var cs := LevelMapScanner.get_logic_cell_size_for_scene(tree.current_scene)
	var g := LevelMapScanner.world_to_logic_grid(world, cs)
	var k := "%d_%d" % [g.x, g.y]
	var sub: Variant = map_exploration.get(scene_bn, {})
	var subd: Dictionary = sub as Dictionary if sub is Dictionary else {}
	if bool(subd.get(k, false)):
		return
	subd[k] = true
	map_exploration[scene_bn] = subd


## 由已访问格扩展：详图为矩形并集；灰块为更大矩形并集减去详图（用于地图绘制）
func build_map_reveal_masks(scene_basename: String) -> Dictionary:
	var visited: Variant = map_exploration.get(scene_basename, {})
	if visited == null or not (visited is Dictionary):
		return {&"full": {}, &"dim": {}}
	var vd := visited as Dictionary
	var full: Dictionary = {}
	var dim: Dictionary = {}
	for vk in vd.keys():
		if not bool(vd[vk]):
			continue
		var parts := String(vk).split("_")
		if parts.size() != 2:
			continue
		var gx := int(parts[0])
		var gy := int(parts[1])
		for dx in range(-MAP_DIM_HALF_W, MAP_DIM_HALF_W + 1):
			for dy in range(-MAP_DIM_UP, MAP_DIM_DOWN + 1):
				var ck := "%d_%d" % [gx + dx, gy + dy]
				var in_detail := absi(dx) <= MAP_DETAIL_HALF_W and dy >= -MAP_DETAIL_UP and dy <= MAP_DETAIL_DOWN
				if in_detail:
					full[ck] = true
				else:
					dim[ck] = true
	for fk in full.keys():
		dim.erase(fk)
	return {&"full": full, &"dim": dim}


func _unhandled_input(event: InputEvent) -> void:
	# 场景内若实例化了 Game 节点，只允许 Autoload(/root/Game)处理全局存读档输入，避免重入读档卡住。
	if not _is_autoload_game():
		return
	var tree_h := get_tree()
	if settings_ui_is_open():
		return
	if save_slots_sheet_is_open():
		return
	if _current_scene_is_title(tree_h):
		return
	if tree_h.get_first_node_in_group(&"save_point_choice_ui") != null:
		return
	if event.is_action_pressed("ui_inventory"):
		if inventory_ui_is_open():
			close_inventory_ui()
		else:
			open_inventory_ui()
		get_viewport().set_input_as_handled()
		return
	if inventory_ui_is_open():
		return
	if event.is_action_pressed(&"ui_map"):
		if abstract_map_ui_is_open():
			close_abstract_map_ui()
		else:
			open_abstract_map_ui()
		get_viewport().set_input_as_handled()
		return
	if abstract_map_ui_is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		open_pause_menu()
		return
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			var pk := key_event.physical_keycode
			if pk >= KEY_1 and pk <= KEY_8:
				var digit := int(pk - KEY_1)
				var pl := tree_h.get_first_node_in_group(&"player")
				if pl != null:
					var inv := pl.get_node_or_null("PlayerInventory") as PlayerInventory
					if inv != null:
						inv.set_hotbar_selection(digit)
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_R:
				var latest := find_latest_manual_save_slot_id()
				if latest.is_empty():
					print("没有可读的手动存档槽")
				else:
					print("读取最近手动存档槽: ", latest)
					load_game(true, latest)


func open_pause_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if _current_scene_is_title(tree):
		return
	if settings_ui_is_open():
		return
	if save_slots_sheet_is_open():
		return
	# 检查 Dialogic 是否活跃（避免冲突）
	var dlg_autoload := DialogicUtil.autoload() if DialogicUtil else null
	if dlg_autoload and dlg_autoload.has_method("has_active_timeline") and dlg_autoload.has_active_timeline():
		return
	if tree.get_first_node_in_group(&"save_point_choice_ui") != null:
		return
	if inventory_ui_is_open() or abstract_map_ui_is_open():
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
	CursorManager.set_cursor_type(CursorManager.CursorType.HUD)
	CursorManager.show_cursor()


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
	var latest := find_latest_manual_save_slot_id()
	if latest.is_empty():
		print("没有可读的手动存档，无法从存档点回溯。")
		return
	get_tree().paused = false
	load_game(true, latest)
