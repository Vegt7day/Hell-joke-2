class_name AbstractMapPolygonHint
extends Node2D
## 放入关卡编辑器：本地 Polygon2D 顶点会被栅格化并并入抽象地图（组：abstract_map_polygon_hint）。


func _ready() -> void:
	add_to_group(&"abstract_map_polygon_hint")


func get_world_polygon() -> PackedVector2Array:
	var poly_node := get_node_or_null("Polygon2D") as Polygon2D
	if poly_node == null:
		return PackedVector2Array()
	var local_poly := poly_node.polygon
	var out := PackedVector2Array()
	out.resize(local_poly.size())
	for i in local_poly.size():
		out[i] = poly_node.to_global(local_poly[i])
	return out
