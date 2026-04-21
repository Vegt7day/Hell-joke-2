class_name Stats
extends Node

signal health_changed

@export var max_health:int=3
@export var max_energy:int=3


@onready var health:int = max_health:
	set(v):
		v = clampi(v,0,max_health)
		if health == v:
			return
		health = v
		health_changed.emit()


func to_dict()->Dictionary:
	return{
		max_health=max_health,
		health=health,
		max_energy=max_energy,
	}
	
func from_dict(dict:Dictionary)->void:
	max_health=dict.max_health
	health=dict.health
	max_energy=dict.max_energy
