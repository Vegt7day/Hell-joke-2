extends Node
## 机关链接总线（Autoload）。开关作为发布者调用 [method publish_channel_state]，
## 机关作为订阅者连接 [signal channel_state_changed]。
## 策略：末次写入——同一 [param channel_id] 仅保留最后一次发布的开/关状态。

signal channel_state_changed(channel_id: StringName, is_open: bool)

var _last_is_open: Dictionary = {}
var is_restoring: bool = false


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


## 导出总线状态（用于存档）
func export_state() -> Dictionary:
	var out := {}
	for k in _last_is_open.keys():
		out[String(k)] = bool(_last_is_open[k])
	return out


## 导入总线状态（用于读档）
## 默认不广播信号：让机关在 _ready 的 deferred_sync_initial_from_bus 中无动画同步到正确状态。
func import_state(state: Dictionary, emit_signals: bool = false) -> void:
	_last_is_open.clear()
	if state == null:
		return
	for k in state.keys():
		_last_is_open[StringName(String(k))] = bool(state[k])
	if emit_signals:
		is_restoring = true
		for ch in _last_is_open.keys():
			channel_state_changed.emit(ch as StringName, bool(_last_is_open[ch]))
		is_restoring = false


func rebroadcast_all_states() -> void:
	is_restoring = true
	for ch in _last_is_open.keys():
		channel_state_changed.emit(ch as StringName, bool(_last_is_open[ch]))
	is_restoring = false
