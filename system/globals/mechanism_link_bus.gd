extends Node
## 机关链接总线（Autoload）。开关作为发布者调用 [method publish_channel_state]，
## 机关作为订阅者连接 [signal channel_state_changed]。
## 策略：末次写入——同一 [param channel_id] 仅保留最后一次发布的开/关状态。

signal channel_state_changed(channel_id: StringName, is_open: bool)

var _last_is_open: Dictionary = {}


func publish_channel_state(channel_id: StringName, is_open: bool) -> void:
	if channel_id.is_empty():
		return
	_last_is_open[channel_id] = is_open
	channel_state_changed.emit(channel_id, is_open)


func has_published_state(channel_id: StringName) -> bool:
	return _last_is_open.has(channel_id)


func get_last_is_open(channel_id: StringName) -> bool:
	return bool(_last_is_open[channel_id])


func clear_last_states() -> void:
	_last_is_open.clear()
