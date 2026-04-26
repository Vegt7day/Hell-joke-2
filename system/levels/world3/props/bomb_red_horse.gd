extends Area2D
## 红马炸弹：静止于生成点，爆炸动画窗内伤害（占位）。

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	add_to_group("boss_red_horse_bomb")
	call_deferred("_run_red_bomb_sequence")


func _run_red_bomb_sequence() -> void:
	if animation_player == null:
		queue_free()
		return
	await _play_optional(&"ready", 0.5)
	await _play_optional(&"boom", 0.5)
	queue_free()


func _play_optional(anim_name: StringName, fallback_seconds: float = 0.5) -> void:
	if animation_player == null or not animation_player.has_animation(anim_name):
		await get_tree().create_timer(fallback_seconds).timeout
		return
	animation_player.play(anim_name)
	var length := animation_player.get_animation(anim_name).length
	if length <= 0.0:
		length = fallback_seconds
	await get_tree().create_timer(length).timeout
