extends Node
class_name World3RandomPieceBuilder

@export var random_pieces_start_path: NodePath = NodePath("../../Bosses/PropsSpawn/RandomPiecesStart")
@export var pieces_runtime_root_path: NodePath = NodePath("../../Bosses/PropsSpawn/RandomPiecesRuntime")
@export var piece_pool: Array[PackedScene] = []
@export var piece_count: int = 5
@export var allow_repeat_piece: bool = true
@export var use_fixed_seed: bool = false
@export var fixed_seed: int = 20260427
@export var heart_interactable_scene: PackedScene = preload("res://system/levels/world3/props/boss_damage_interactable.tscn")
@export var spawn_heart_enabled: bool = true
@export var spawn_heart_every_n: int = 2
@export var heart_spawn_start_index: int = 1
@export var heart_spawn_offset: Vector2 = Vector2.ZERO

var _planned_piece_scenes: Array[PackedScene] = []
var _planned_piece_positions: Array[Vector2] = []
var _active_piece_nodes: Dictionary = {} # index(int) -> Node2D
var _last_outer_index: int = -999999
var _last_inner_index: int = -999999
var _selected_pool_indices: Array[int] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _piece_runtime_state_cache: Dictionary = {} # index(int) -> Dictionary
var _current_generation_seed: int = 0

func _ready() -> void:
	var start_marker: Marker2D = get_node_or_null(random_pieces_start_path) as Marker2D
	var runtime_root: Node2D = get_node_or_null(pieces_runtime_root_path) as Node2D
	if start_marker == null:
		push_warning("[RandomPieceBuilder] 未找到 RandomPiecesStart，后续拼接无法对齐。")
	if runtime_root == null:
		push_warning("[RandomPieceBuilder] 未找到 RandomPiecesRuntime，后续运行时实例无挂载点。")
	if piece_pool.is_empty():
		push_warning("[RandomPieceBuilder] piece_pool 为空：请在 Inspector 配置 5 个小场景。")
	print("[RandomPieceBuilder] Step1 基础骨架已就绪。piece_count=%d allow_repeat=%s fixed_seed=%s" % [
		piece_count,
		str(allow_repeat_piece),
		str(use_fixed_seed),
	])
	if start_marker == null or runtime_root == null or piece_pool.is_empty():
		return
	_build_sequence_with_seed(start_marker, runtime_root)


func _build_sequence_with_seed(start_marker: Marker2D, runtime_root: Node2D) -> void:
	_clear_runtime_root(runtime_root)
	_planned_piece_scenes.clear()
	_planned_piece_positions.clear()
	_active_piece_nodes.clear()
	_selected_pool_indices.clear()
	_last_outer_index = -999999
	_last_inner_index = -999999
	_piece_runtime_state_cache.clear()
	var count: int = max(1, piece_count)
	if not allow_repeat_piece:
		count = min(count, piece_pool.size())
	if use_fixed_seed:
		_rng.seed = int(fixed_seed)
		_current_generation_seed = int(fixed_seed)
	else:
		_rng.randomize()
		_current_generation_seed = int(_rng.seed)
	_select_piece_indices(count)
	var next_anchor_world: Vector2 = start_marker.global_position
	for i in count:
		var pool_idx: int = int(_selected_pool_indices[i])
		var piece_scene: PackedScene = piece_pool[pool_idx]
		if piece_scene == null:
			push_warning("[RandomPieceBuilder] piece_pool[%d] 为空，跳过。" % pool_idx)
			continue
		var preview: Node2D = piece_scene.instantiate() as Node2D
		if preview == null:
			push_warning("[RandomPieceBuilder] piece_pool[%d] 不是 Node2D 根节点，跳过。" % pool_idx)
			continue
		runtime_root.add_child(preview)
		var start_m: Marker2D = preview.get_node_or_null("start") as Marker2D
		var over_m: Marker2D = preview.get_node_or_null("over") as Marker2D
		if start_m == null or over_m == null:
			push_warning("[RandomPieceBuilder] 模块 %s 缺少 start/over，已移除实例。" % [preview.name])
			preview.queue_free()
			continue
		var delta: Vector2 = next_anchor_world - start_m.global_position
		preview.global_position += delta
		_planned_piece_scenes.append(piece_scene)
		_planned_piece_positions.append(preview.global_position)
		next_anchor_world = over_m.global_position
		print("[RandomPieceBuilder] Step3 随机拼接 index=%d pool=%d piece=%s start=%s over=%s" % [
			i,
			pool_idx,
			preview.name,
			str(start_m.global_position),
			str(over_m.global_position),
		])
		preview.queue_free()
	# Step4: 初始仅加载起始邻域（0 与 1），避免一次性全生成占内存。
	ensure_neighbors_loaded(0)
	trim_to_neighbors(0)
	print("[RandomPieceBuilder] Step4 初始邻域加载完成：seed=%d 选中序列=%s 计划=%d 初始活跃=%d" % [
		_current_generation_seed,
		str(_selected_pool_indices),
		_planned_piece_scenes.size(),
		_active_piece_nodes.size(),
	])


func _select_piece_indices(count: int) -> void:
	if piece_pool.is_empty() or count <= 0:
		return
	if allow_repeat_piece:
		for _i in count:
			_selected_pool_indices.append(_rng.randi_range(0, piece_pool.size() - 1))
		return
	var candidates: Array[int] = []
	for i in piece_pool.size():
		candidates.append(i)
	for _j in count:
		if candidates.is_empty():
			break
		var pick_at := _rng.randi_range(0, candidates.size() - 1)
		_selected_pool_indices.append(candidates[pick_at])
		candidates.remove_at(pick_at)


func _build_fixed_sequence(start_marker: Marker2D, runtime_root: Node2D) -> void:
	# 兼容旧方法名：默认走新版随机+seed流程。
	_build_sequence_with_seed(start_marker, runtime_root)


func get_selected_pool_indices() -> Array[int]:
	return _selected_pool_indices.duplicate()


func get_generation_seed() -> int:
	return _current_generation_seed


func apply_generation_from_indices(indices: Array, seed_opt: int = 0) -> void:
	# 供后续存档恢复复用：直接指定模块序列重建（暂不自动调用）。
	var start_marker: Marker2D = get_node_or_null(random_pieces_start_path) as Marker2D
	var runtime_root: Node2D = get_node_or_null(pieces_runtime_root_path) as Node2D
	if start_marker == null or runtime_root == null:
		return
	_clear_runtime_root(runtime_root)
	_planned_piece_scenes.clear()
	_planned_piece_positions.clear()
	_active_piece_nodes.clear()
	_selected_pool_indices.clear()
	_piece_runtime_state_cache.clear()
	if seed_opt != 0:
		_rng.seed = seed_opt
		_current_generation_seed = seed_opt
	for x in indices:
		var idx := int(x)
		if idx >= 0 and idx < piece_pool.size():
			_selected_pool_indices.append(idx)
	var next_anchor_world: Vector2 = start_marker.global_position
	for k in _selected_pool_indices.size():
		var scn: PackedScene = piece_pool[_selected_pool_indices[k]]
		if scn == null:
			continue
		var preview: Node2D = scn.instantiate() as Node2D
		if preview == null:
			continue
		runtime_root.add_child(preview)
		var sm: Marker2D = preview.get_node_or_null("start") as Marker2D
		var om: Marker2D = preview.get_node_or_null("over") as Marker2D
		if sm == null or om == null:
			preview.queue_free()
			continue
		var delta: Vector2 = next_anchor_world - sm.global_position
		preview.global_position += delta
		_planned_piece_scenes.append(scn)
		_planned_piece_positions.append(preview.global_position)
		next_anchor_world = om.global_position
		preview.queue_free()
	ensure_neighbors_loaded(0)
	trim_to_neighbors(0)


func _clear_runtime_root(runtime_root: Node2D) -> void:
	for c in runtime_root.get_children():
		c.queue_free()


func _spawn_piece_if_needed(index: int, runtime_root: Node2D) -> void:
	if index < 0 or index >= _planned_piece_scenes.size():
		return
	if _active_piece_nodes.has(index):
		return
	var scn: PackedScene = _planned_piece_scenes[index]
	if scn == null:
		return
	var piece: Node2D = scn.instantiate() as Node2D
	if piece == null:
		return
	runtime_root.add_child(piece)
	piece.global_position = _planned_piece_positions[index]
	piece.set_meta("piece_index", index)
	_active_piece_nodes[index] = piece
	_apply_cached_piece_runtime_state_if_any(index, piece)
	_attach_heart_interactable_if_needed(index, piece)
	_bind_piece_streaming_areas(piece, index)


func _bind_piece_streaming_areas(piece: Node2D, index: int) -> void:
	var outer: Area2D = piece.get_node_or_null("OuterStreamingArea") as Area2D
	var inner: Area2D = piece.get_node_or_null("InnerStreamingArea") as Area2D
	if outer != null and not outer.body_entered.is_connected(_on_outer_streaming_body_entered):
		outer.body_entered.connect(_on_outer_streaming_body_entered.bind(index))
	if inner != null and not inner.body_entered.is_connected(_on_inner_streaming_body_entered):
		inner.body_entered.connect(_on_inner_streaming_body_entered.bind(index))


func _on_outer_streaming_body_entered(body: Node, index: int) -> void:
	if not (body is Node) or not (body as Node).is_in_group("player"):
		return
	if _last_outer_index == index:
		return
	_last_outer_index = index
	ensure_neighbors_loaded(index)


func _on_inner_streaming_body_entered(body: Node, index: int) -> void:
	if not (body is Node) or not (body as Node).is_in_group("player"):
		return
	if _last_inner_index == index:
		return
	_last_inner_index = index
	trim_to_neighbors(index)


func ensure_neighbors_loaded(center_index: int) -> void:
	var runtime_root: Node2D = get_node_or_null(pieces_runtime_root_path) as Node2D
	if runtime_root == null:
		return
	for idx in [center_index - 1, center_index, center_index + 1]:
		_spawn_piece_if_needed(idx, runtime_root)


func trim_to_neighbors(center_index: int) -> void:
	var keys := _active_piece_nodes.keys()
	for k in keys:
		var idx := int(k)
		if abs(idx - center_index) <= 1:
			continue
		var n := _active_piece_nodes[idx] as Node2D
		if n != null and is_instance_valid(n):
			_capture_piece_runtime_state(idx, n)
			n.queue_free()
		_active_piece_nodes.erase(idx)


func _capture_piece_runtime_state(index: int, piece: Node2D) -> void:
	var merged: Dictionary = {}
	if piece != null and piece.has_method("export_piece_runtime_state"):
		var st: Variant = piece.call("export_piece_runtime_state")
		if st is Dictionary:
			merged.merge(st as Dictionary, true)
	var heart := piece.get_node_or_null("HeartInteractable") as BossDamageInteractable
	if heart != null:
		merged["heart_interactable"] = heart.export_save_state()
	if not merged.is_empty():
		_piece_runtime_state_cache[index] = merged


func _apply_cached_piece_runtime_state_if_any(index: int, piece: Node2D) -> void:
	if not _piece_runtime_state_cache.has(index):
		return
	if piece != null and piece.has_method("apply_piece_runtime_state"):
		piece.call("apply_piece_runtime_state", _piece_runtime_state_cache[index])


func _should_spawn_heart_for_index(index: int) -> bool:
	if not spawn_heart_enabled:
		return false
	if spawn_heart_every_n <= 0:
		return false
	if index < heart_spawn_start_index:
		return false
	return ((index - heart_spawn_start_index) % spawn_heart_every_n) == 0


func _attach_heart_interactable_if_needed(index: int, piece: Node2D) -> void:
	if piece == null:
		return
	if not _should_spawn_heart_for_index(index):
		return
	if heart_interactable_scene == null:
		return
	if piece.get_node_or_null("HeartInteractable") != null:
		return
	var attack_m := piece.get_node_or_null("attack") as Marker2D
	if attack_m == null:
		return
	var heart: Node2D = heart_interactable_scene.instantiate() as Node2D
	if heart == null:
		return
	heart.name = "HeartInteractable"
	piece.add_child(heart)
	heart.global_position = attack_m.global_position + heart_spawn_offset
	if heart is BossDamageInteractable and _piece_runtime_state_cache.has(index):
		var saved: Dictionary = _piece_runtime_state_cache[index] as Dictionary
		var hst: Variant = saved.get("heart_interactable", {})
		if hst is Dictionary:
			(heart as BossDamageInteractable).apply_save_state(hst as Dictionary)


func export_builder_state() -> Dictionary:
	for k in _active_piece_nodes.keys():
		var idx := int(k)
		var node := _active_piece_nodes[idx] as Node2D
		if node != null and is_instance_valid(node):
			_capture_piece_runtime_state(idx, node)
	var cache_export: Dictionary = {}
	for k2 in _piece_runtime_state_cache.keys():
		cache_export[str(int(k2))] = _piece_runtime_state_cache[k2]
	return {
		"seed": int(_rng.seed),
		"selected_pool_indices": _selected_pool_indices.duplicate(),
		"piece_runtime_state_cache": cache_export,
	}


func apply_builder_state(state: Dictionary) -> void:
	var start_marker: Marker2D = get_node_or_null(random_pieces_start_path) as Marker2D
	var runtime_root: Node2D = get_node_or_null(pieces_runtime_root_path) as Node2D
	if start_marker == null or runtime_root == null:
		return
	_piece_runtime_state_cache.clear()
	var cache_raw: Variant = state.get("piece_runtime_state_cache", {})
	if cache_raw is Dictionary:
		for key in (cache_raw as Dictionary).keys():
			_piece_runtime_state_cache[int(str(key))] = (cache_raw as Dictionary)[key]
	var seq: Variant = state.get("selected_pool_indices", [])
	var seed_opt := int(state.get("seed", 0))
	if seq is Array:
		apply_generation_from_indices(seq as Array, seed_opt)
