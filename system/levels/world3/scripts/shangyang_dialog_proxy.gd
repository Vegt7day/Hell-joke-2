extends Node2D
## Boss 战专用：向 DialogicRegistry 提供稳定的「商鞅」锚点。
## 预警阶段可开启追踪，每帧对齐到召唤商鞅（或回退到场景内静态商鞅）；找不到则保持当前位置，对话仍在原位触发。

@export var fallback_shangyang_path: NodePath = NodePath("../../商鞅")

var _tracking: bool = false


func set_tracking(enabled: bool) -> void:
	_tracking = enabled
	if enabled:
		sync_now()


func sync_now() -> void:
	var t := _resolve_shangyang_visual()
	if t != null and is_instance_valid(t):
		global_position = t.global_position


func get_dialog_anchor() -> Node2D:
	var m := get_node_or_null("DialogMarker") as Node2D
	return m if m else self


func _process(_delta: float) -> void:
	if not _tracking:
		return
	sync_now()


func _resolve_shangyang_visual() -> Node2D:
	for n in get_tree().get_nodes_in_group("shangyang_player_summon"):
		if n is ShangYang and is_instance_valid(n):
			return n as Node2D
	if fallback_shangyang_path != NodePath():
		var f := get_node_or_null(fallback_shangyang_path) as Node2D
		if f != null and is_instance_valid(f):
			return f
	return null
