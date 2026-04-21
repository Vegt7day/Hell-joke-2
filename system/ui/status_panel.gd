extends Node2D

@export var stats:Stats

@onready var health_bar: TextureProgressBar = $外框/HealthBar

@onready var eased_health_bar: TextureProgressBar = $外框/HealthBar/EasedHealthBar

func _ready() -> void:
	if not stats:
		stats=Game.player_stats
	stats.health_changed.connect(update_heath)
	update_heath()

func update_heath() -> void :
	var percentage :=stats.health / float(stats.max_health)
	health_bar.value = percentage
	create_tween().tween_property(eased_health_bar,"value",percentage,0.3)
	
