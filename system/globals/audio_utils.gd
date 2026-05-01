class_name AudioUtils
extends RefCounted


static func ensure_looping_bgm(host: Node, current_player: AudioStreamPlayer, stream: AudioStream, bus: StringName = &"BGM", player_name: StringName = &"LevelNormalBgm") -> AudioStreamPlayer:
	if current_player != null and is_instance_valid(current_player):
		return current_player
	if host == null or stream == null:
		return current_player
	var p := AudioStreamPlayer.new()
	p.name = String(player_name)
	p.bus = bus
	var copied_stream: AudioStream = stream.duplicate()
	if copied_stream is AudioStreamMP3:
		(copied_stream as AudioStreamMP3).loop = false
	elif copied_stream is AudioStreamOggVorbis:
		(copied_stream as AudioStreamOggVorbis).loop = false
	p.stream = copied_stream
	p.finished.connect(Callable(AudioUtils, "_replay_player").bind(p))
	host.add_child(p)
	p.play()
	return p


static func _replay_player(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.stream == null:
		return
	player.play()
