extends Node
## 机关音效总线（Autoload）。
## 统一播放机关触发音，并对同 key 请求做同帧去重 + 短冷却节流。

@export var default_bus: StringName = &"SFX_Mechanism"
@export var default_volume_db: float = 0.0
@export var default_cooldown_ms: int = 100

var _player: AudioStreamPlayer
var _last_frame_by_key: Dictionary = {}
var _last_tick_ms_by_key: Dictionary = {}

const _REQUIRED_BUSES := [
	&"BGM",
	&"BGM_Boss",
	&"SFX",
	&"SFX_Player",
	&"SFX_Mechanism",
	&"SFX_Enemy",
	&"SFX_EnemyBullet",
	&"UI",
]
const _BUS_SEND := {
	&"BGM": &"Master",
	&"BGM_Boss": &"Master",
	&"SFX": &"Master",
	&"SFX_Player": &"SFX",
	&"SFX_Mechanism": &"SFX",
	&"SFX_Enemy": &"SFX",
	&"SFX_EnemyBullet": &"SFX",
	&"UI": &"Master",
}


func _ready() -> void:
	_ensure_bus_tree()
	_player = AudioStreamPlayer.new()
	_player.name = "MechanismSfxPlayer"
	_player.bus = StringName(default_bus)
	_player.volume_db = default_volume_db
	add_child(_player)


func request_once(event_key: StringName, stream: AudioStream, cooldown_ms: int = -1) -> void:
	if stream == null or event_key.is_empty():
		return
	var now_frame := Engine.get_physics_frames()
	var now_ms := Time.get_ticks_msec()
	var cd := cooldown_ms if cooldown_ms >= 0 else default_cooldown_ms
	if _last_frame_by_key.get(event_key, -1) == now_frame:
		return
	var last_ms := int(_last_tick_ms_by_key.get(event_key, -1))
	if last_ms >= 0 and (now_ms - last_ms) < cd:
		return
	_last_frame_by_key[event_key] = now_frame
	_last_tick_ms_by_key[event_key] = now_ms
	_play(stream)


func _play(stream: AudioStream) -> void:
	if _player == null:
		return
	_player.stream = stream
	_player.play()


func _ensure_bus_tree() -> void:
	for bus_name in _REQUIRED_BUSES:
		_ensure_bus(bus_name)
	for bus_name in _REQUIRED_BUSES:
		var idx := _find_bus_index(bus_name)
		if idx < 0:
			continue
		var send_to: StringName = _BUS_SEND.get(bus_name, &"Master")
		if send_to != &"Master" and _find_bus_index(send_to) < 0:
			_ensure_bus(send_to)
		AudioServer.set_bus_send(idx, String(send_to))


func _ensure_bus(bus_name: StringName) -> void:
	if _find_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus(AudioServer.get_bus_count())
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, String(bus_name))


func _find_bus_index(bus_name: StringName) -> int:
	for i in range(AudioServer.get_bus_count()):
		if StringName(AudioServer.get_bus_name(i)) == bus_name:
			return i
	return -1
