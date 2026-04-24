class_name Stats
extends Node

signal health_changed
signal ink_changed

@export var max_health:int=3
@export var max_ink:float=100


@onready var health:int = max_health:
	set(v):
		v = clampi(v,0,max_health)
		if health == v:
			return
		health = v
		health_changed.emit()

@onready var ink:float = max_ink:
	set(v):
		v = clampf(v, 0.0, max_ink)
		if is_equal_approx(ink, v):
			return
		ink = v
		ink_changed.emit()


func to_dict()->Dictionary:
	return{
		max_health=max_health,
		health=health,
		max_ink=max_ink,
		ink=ink,
	}
	
func from_dict(dict:Dictionary)->void:
	max_health=dict.max_health
	health=dict.health
	max_ink=dict.max_ink
	ink=dict.get("ink", max_ink)
