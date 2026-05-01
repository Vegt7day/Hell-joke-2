class_name LevelMapScanner
extends RefCounted
## 扫描 TileMapLayer：地区（source 0）、墙（source 1）；多边形提示计入「地区」层。
## 地图逻辑格 = 2×2 瓦（共四瓦一格）；同一逻辑格内任一为墙则整格为墙，否则有地则为地。
## 收集机关：开关始终记录；洞未触发时并入「地」格；门/窗/桶；存档点、心与剑（BossDamageInteractable）。
## ctx[&"tile_size"]：单瓦像素尺寸；ctx[&"cell_size"]：逻辑格像素尺寸（≈ tile_size×2），供绘制与坐标量化。

const POLYGON_HINT_GROUP := &"abstract_map_polygon_hint"
const MAP_BLOCK_EDGE_TILES := 2
const MECHANISM_GRID_OFFSET := Vector2i(0, -1)
## 桶在地图上的逻辑格相对节点的偏移（右移 2 格、上移 1 格），叠加在 MECHANISM_GRID_OFFSET 之上
const BUCKET_GRID_OFFSET_EXTRA := Vector2i(2, -1)
## 心与剑：上移 1 逻辑格；存档点：下移 1 逻辑格（均叠加在 MECHANISM_GRID_OFFSET 之上）
const HEART_BLADE_GRID_OFFSET_EXTRA := Vector2i(0, -1)
const SAVE_POINT_GRID_OFFSET_EXTRA := Vector2i(0, 1)

## 与 resources 共用 TileSet：sources/0 = 地，sources/1 = 墙
const TILE_SOURCE_FLOOR := 0
const TILE_SOURCE_WALL := 1

static func scan_scene(scene_root: Node) -> Dictionary:
	var default_tile := Vector2(16, 16)
	var ctx := {
		&"tile_size": default_tile,
		&"cell_size": _map_cell_size_from_tile(default_tile),
		&"cells_floor": {},
		&"cells_wall": {},
		&"cells": {},
		&"tile_layers": 0,
		&"hints": 0,
		&"mechanisms": [],
	}
	if scene_root == null:
		return ctx
	_walk_collect_tiles(scene_root, ctx)
	var tree := scene_root.get_tree()
	if tree != null:
		for hint in tree.get_nodes_in_group(POLYGON_HINT_GROUP):
			if hint is AbstractMapPolygonHint:
				var poly := (hint as AbstractMapPolygonHint).get_world_polygon()
				if poly.size() >= 3:
					ctx[&"hints"] = int(ctx[&"hints"]) + 1
					var fl: Dictionary = ctx[&"cells_floor"]
					var wl: Dictionary = ctx[&"cells_wall"]
					_rasterize_polygon(poly, fl, wl, ctx[&"cell_size"])
	_rebuild_union_cells(ctx)
	_collect_mechanisms(scene_root, ctx)
	_rebuild_union_cells(ctx)
	return ctx


static func _rebuild_union_cells(ctx: Dictionary) -> void:
	var uni: Dictionary = {}
	var cf: Dictionary = ctx[&"cells_floor"]
	var cw: Dictionary = ctx[&"cells_wall"]
	for k in cf.keys():
		uni[k] = true
	for k in cw.keys():
		uni[k] = true
	ctx[&"cells"] = uni


static func _map_cell_size_from_tile(tile_cs: Vector2) -> Vector2:
	return Vector2(
		tile_cs.x * float(MAP_BLOCK_EDGE_TILES),
		tile_cs.y * float(MAP_BLOCK_EDGE_TILES),
	)


static func _walk_collect_tiles(n: Node, ctx: Dictionary) -> void:
	if n is TileMapLayer:
		_collect_layer_cells(n as TileMapLayer, ctx)
	for c in n.get_children():
		_walk_collect_tiles(c, ctx)


static func _collect_layer_cells(layer: TileMapLayer, ctx: Dictionary) -> void:
	var ts := layer.tile_set
	if ts == null:
		return
	var tile_cs := Vector2(ts.tile_size)
	if tile_cs.x <= 0.001 or tile_cs.y <= 0.001:
		return
	ctx[&"tile_layers"] = int(ctx[&"tile_layers"]) + 1
	if int(ctx[&"tile_layers"]) == 1:
		ctx[&"tile_size"] = tile_cs
		ctx[&"cell_size"] = _map_cell_size_from_tile(tile_cs)
	var map_cs: Vector2 = ctx[&"cell_size"]
	if map_cs.x <= 0.001:
		map_cs = _map_cell_size_from_tile(tile_cs)
		ctx[&"cell_size"] = map_cs
	var floor_cells: Dictionary = ctx[&"cells_floor"]
	var wall_cells: Dictionary = ctx[&"cells_wall"]
	var used := layer.get_used_rect()
	for y in range(used.position.y, used.position.y + used.size.y):
		for x in range(used.position.x, used.position.x + used.size.x):
			var c := Vector2i(x, y)
			if not _cell_is_used(layer, c):
				continue
			var sid := layer.get_cell_source_id(c)
			var glob := layer.to_global(layer.map_to_local(c))
			var g := _world_to_grid(glob, map_cs)
			if sid == TILE_SOURCE_FLOOR:
				if not wall_cells.has(g):
					floor_cells[g] = true
			elif sid == TILE_SOURCE_WALL:
				wall_cells[g] = true
				floor_cells.erase(g)
			else:
				# 其它图源当作障碍物显示
				wall_cells[g] = true
				floor_cells.erase(g)


static func _cell_is_used(layer: TileMapLayer, c: Vector2i) -> bool:
	return layer.get_cell_source_id(c) >= 0


static func _world_to_grid(global_pt: Vector2, cell_size: Vector2) -> Vector2i:
	return Vector2i(int(floor(global_pt.x / cell_size.x)), int(floor(global_pt.y / cell_size.y)))


static func _rasterize_polygon(
	poly_world: PackedVector2Array,
	floor_cells: Dictionary,
	wall_cells: Dictionary,
	cell_size: Vector2,
) -> void:
	if cell_size.x <= 0.001 or cell_size.y <= 0.001:
		return
	var b := Rect2(poly_world[0], Vector2.ZERO)
	for i in range(1, poly_world.size()):
		b = b.expand(poly_world[i])
	var min_gx := int(floor(b.position.x / cell_size.x))
	var max_gx := int(floor((b.position.x + b.size.x) / cell_size.x))
	var min_gy := int(floor(b.position.y / cell_size.y))
	var max_gy := int(floor((b.position.y + b.size.y) / cell_size.y))
	for gx in range(min_gx, max_gx + 1):
		for gy in range(min_gy, max_gy + 1):
			var center := Vector2((gx + 0.5) * cell_size.x, (gy + 0.5) * cell_size.y)
			if Geometry2D.is_point_in_polygon(center, poly_world):
				var gv := Vector2i(gx, gy)
				floor_cells[gv] = true
				wall_cells.erase(gv)


static func _collect_mechanisms(root: Node, ctx: Dictionary) -> void:
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var n: Node = queue.pop_front()
		for c in n.get_children():
			queue.append(c)
		_try_append_mechanism(n, ctx)


static func _try_append_mechanism(node: Node, ctx: Dictionary) -> void:
	if not (node is Node2D):
		return
	var scr: Variant = node.get_script()
	if scr == null:
		return
	var path := String(scr.resource_path).replace("\\", "/")
	var file := path.get_file()
	var cell_size: Vector2 = ctx[&"cell_size"]
	if cell_size.x <= 0.001:
		cell_size = Vector2(16, 16)
	var out: Array = ctx[&"mechanisms"]
	var kind := ""
	match file:
		"洞.gd":
			var trv: Variant = node.get(&"is_triggered")
			if trv == null or not bool(trv):
				var nh := node as Node2D
				var gh := _world_to_grid(nh.global_position, cell_size) + MECHANISM_GRID_OFFSET
				var fl: Dictionary = ctx[&"cells_floor"]
				var wl: Dictionary = ctx[&"cells_wall"]
				fl[gh] = true
				wl.erase(gh)
				return
			kind = "hole"
		"开关.gd":
			kind = "switch"
		"门.gd":
			kind = "door"
		"窗.gd":
			kind = "window"
		"桶.gd":
			kind = "bucket"
		"save_point_interactable.gd":
			kind = "save_point"
		"boss_damage_interactable.gd":
			kind = "heart_blade"
		_:
			return
	var n2 := node as Node2D
	var g := _world_to_grid(n2.global_position, cell_size) + MECHANISM_GRID_OFFSET
	match kind:
		"bucket":
			g += BUCKET_GRID_OFFSET_EXTRA
		"heart_blade":
			g += HEART_BLADE_GRID_OFFSET_EXTRA
		"save_point":
			g += SAVE_POINT_GRID_OFFSET_EXTRA
		_:
			pass
	var entry := {
		&"name": String(node.name),
		&"kind": kind,
		&"g": g,
	}
	if kind == "switch":
		entry[&"switch_on"] = bool(node.get(&"is_on"))
	elif kind == "save_point":
		entry[&"save_point_id"] = _save_point_id_from(node)
		entry[&"world_px"] = n2.global_position
	out.append(entry)


static func _save_point_id_from(node: Node) -> String:
	if node.has_method(&"get_save_point_id"):
		return str(node.call(&"get_save_point_id")).strip_edges()
	return String(node.name)


static func get_logic_cell_size_for_scene(scene_root: Node) -> Vector2:
	var fallback_tile := Vector2(16, 16)
	if scene_root == null:
		return _map_cell_size_from_tile(fallback_tile)
	var queue: Array[Node] = [scene_root]
	while not queue.is_empty():
		var n: Node = queue.pop_front()
		if n is TileMapLayer:
			var ts := (n as TileMapLayer).tile_set
			if ts != null:
				var t := Vector2(ts.tile_size)
				if t.x > 0.001 and t.y > 0.001:
					return _map_cell_size_from_tile(t)
		for c in n.get_children():
			queue.append(c)
	return _map_cell_size_from_tile(fallback_tile)


static func world_to_logic_grid(global_pt: Vector2, cell_size: Vector2) -> Vector2i:
	var cs := cell_size
	if cs.x <= 0.001:
		cs.x = 16.0
	if cs.y <= 0.001:
		cs.y = 16.0
	return Vector2i(int(floor(global_pt.x / cs.x)), int(floor(global_pt.y / cs.y)))
