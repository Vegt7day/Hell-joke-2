extends Node2D

@export var stats:Stats


@onready var health_bar: TextureProgressBar = $"status panel/HealthBar"

func _ready() -> void:
	stats.health_changed.connect(update_heath)

func update_heath() -> void :
	var percentage :=stats.health / float(stats.max_health)
	health_bar.value = percentage
	
