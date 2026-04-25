extends StaticBody2D

@export var bullet_trigger_enabled: bool = true
@export var damage_threshold: float = 1.0
@export var water_scene: PackedScene = preload("res://system/可交互物/水.tscn")
@export var spawn_offset: Vector2 = Vector2(32.0, -48.0)

@onready var animation_player: AnimationPlayer = $AnimationPlayer

enum BarrelState {
	WITH_WATER_IDLE,
	LOSING_WATER,
	ADDING_WATER,
}

var _state: BarrelState = BarrelState.WITH_WATER_IDLE
var _is_auto_cycle_running: bool = false
var _stop_after_current_cycle: bool = false


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	_enter_idle()


func take_damage(damage_amount: float, attacker = null) -> void:
	if not bullet_trigger_enabled:
		return
	if damage_amount < damage_threshold:
		return
	_on_hit()


func _on_hit() -> void:
	match _state:
		BarrelState.WITH_WATER_IDLE:
			_is_auto_cycle_running = true
			_stop_after_current_cycle = false
			_start_lose_water()
		BarrelState.ADDING_WATER:
			if _is_auto_cycle_running:
				_stop_after_current_cycle = true
		BarrelState.LOSING_WATER:
			if _is_auto_cycle_running:
				_stop_after_current_cycle = true


func _start_lose_water() -> void:
	_state = BarrelState.LOSING_WATER
	animation_player.play("lose_water", -1.0, 1.0, false)
	_spawn_water()


func _start_add_water() -> void:
	_state = BarrelState.ADDING_WATER
	animation_player.play("add_water", -1.0, 1.0, false)


func _enter_idle() -> void:
	_state = BarrelState.WITH_WATER_IDLE
	animation_player.play("with_water_idle")
	_is_auto_cycle_running = false
	_stop_after_current_cycle = false


func _on_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		&"lose_water":
			if _state == BarrelState.LOSING_WATER:
				_start_add_water()
		&"add_water":
			if _state == BarrelState.ADDING_WATER:
				if _is_auto_cycle_running and not _stop_after_current_cycle:
					_start_lose_water()
				else:
					_enter_idle()


func _spawn_water() -> void:
	if water_scene == null:
		push_warning("桶: water_scene 未配置，无法生成水")
		return
	var water := water_scene.instantiate()
	if water == null:
		return
	var p := _resolve_water_spawn_position()
	if water is Node2D:
		(water as Node2D).global_position = p
	if water.has_method("initialize_from_bucket"):
		water.call("initialize_from_bucket", p)
	get_tree().current_scene.add_child(water)


func _resolve_water_spawn_position() -> Vector2:
	var marker := get_node_or_null("WaterSpawnPoint") as Marker2D
	if marker != null:
		return marker.global_position
	return global_position + spawn_offset
