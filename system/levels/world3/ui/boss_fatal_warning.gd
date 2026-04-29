extends CanvasLayer
## Boss 致命攻击前全屏警告（占位：Label + AnimationPlayer；精灵层预留 AnimatedSprite2D）。

signal warning_finished

@onready var _anim: AnimationPlayer = $AnimationPlayer
const _FATAL_WARNING_DURATION := 5.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	if _anim:
		if not _anim.animation_finished.is_connected(_on_animation_finished):
			_anim.animation_finished.connect(_on_animation_finished)
		if _anim.has_animation(&"warning"):
			_anim.play(&"warning")
		else:
			await get_tree().create_timer(_FATAL_WARNING_DURATION).timeout
			_emit_done()
	else:
		await get_tree().create_timer(_FATAL_WARNING_DURATION).timeout
		_emit_done()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"warning":
		_emit_done()


func _emit_done() -> void:
	warning_finished.emit()
	queue_free()
