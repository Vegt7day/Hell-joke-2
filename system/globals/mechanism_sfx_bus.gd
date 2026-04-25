extends Node
## 机关音效总线（Autoload）。
## 统一播放机关触发音，并对同 key 请求做同帧去重 + 短冷却节流。

@export var default_bus: StringName = &"Master"
@export var default_volume_db: float = 0.0
@export var default_cooldown_ms: int = 100

var _player: AudioStreamPlayer
var _last_frame_by_key: Dictionary = {}
var _last_tick_ms_by_key: Dictionary = {}


func _ready() -> void:
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
