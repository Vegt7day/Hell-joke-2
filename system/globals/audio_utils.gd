class_name AudioUtils
extends RefCounted


static func ensure_looping_bgm(host: Node, current_player: AudioStreamPlayer, stream: AudioStream, bus: StringName = &"BGM", player_name: StringName = &"LevelNormalBgm") -> AudioStreamPlayer:
	if current_player != null and is_instance_valid(current_player):
		return current_player
	if host == null or stream == null:
		return current_player
	var p := AudioStreamPlayer.new()
	p.name = String(player_name)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
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


## 替换播放器上的循环音频（用于在不销毁节点的情况下切换曲目）；与 ensure_looping_bgm 使用相同的「播完再 play」循环策略。
static func assign_looping_stream_to_player(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	var conns := player.finished.get_connections()
	for i in range(conns.size() - 1, -1, -1):
		player.finished.disconnect(conns[i].callable)
	var copied_stream: AudioStream = stream.duplicate()
	if copied_stream is AudioStreamMP3:
		(copied_stream as AudioStreamMP3).loop = false
	elif copied_stream is AudioStreamOggVorbis:
		(copied_stream as AudioStreamOggVorbis).loop = false
	elif copied_stream is AudioStreamWAV:
		(copied_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	player.stream = copied_stream
	player.finished.connect(Callable(AudioUtils, "_replay_player").bind(player))


static func _replay_player(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.stream == null:
		return
	player.play()
