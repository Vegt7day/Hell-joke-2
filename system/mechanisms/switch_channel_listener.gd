extends Node
## 挂在门或其它机关下的子节点：订阅 [MechanismLinkBus]，仅响应与 [member channel_id] 一致的颜色通道。
## [member channel_id] 为空时，若父节点存在 [code]initial_color[/code] 字符串属性，则以其为通道 ID（与开关 [code]current_color[/code] 一致）。

@export var channel_id: StringName = StringName()

var _resolved_channel: StringName = StringName()


func _ready() -> void:
	_resolved_channel = _resolve_channel_id()
	if _resolved_channel.is_empty():
		push_warning("switch_channel_listener: 未配置 channel_id 且父节点无 initial_color，已禁用 (%s)" % get_path())
		return
	MechanismLinkBus.channel_state_changed.connect(_on_channel_state_changed)
	call_deferred("_deferred_sync_initial_from_bus")


func _exit_tree() -> void:
	if MechanismLinkBus.channel_state_changed.is_connected(_on_channel_state_changed):
		MechanismLinkBus.channel_state_changed.disconnect(_on_channel_state_changed)


func _resolve_channel_id() -> StringName:
	if not channel_id.is_empty():
		return channel_id
	var p := get_parent()
	if p != null and "initial_color" in p:
		return StringName(str(p.get("initial_color")))
	return StringName()


func _deferred_sync_initial_from_bus() -> void:
	if not is_inside_tree():
		return
	if not MechanismLinkBus.has_published_state(_resolved_channel):
		return
	_apply_to_parent(MechanismLinkBus.get_last_is_open(_resolved_channel), false)


func _on_channel_state_changed(ch: StringName, is_open: bool) -> void:
	if ch != _resolved_channel:
		return
	_apply_to_parent(is_open, true)


func _apply_to_parent(is_open: bool, play_anim: bool) -> void:
	var p := get_parent()
	if p == null:
		return
	if p.has_method("apply_switch_bus_state"):
		p.call("apply_switch_bus_state", is_open, play_anim)
