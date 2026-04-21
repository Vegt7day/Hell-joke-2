extends Node2D

@export var stats:Stats

@onready var health_bar: TextureProgressBar = $外框/HealthBar

@onready var eased_health_bar: TextureProgressBar = $外框/HealthBar/EasedHealthBar
@onready var ink_bar: TextureProgressBar = $外框/InkBar


func _ready() -> void:
	if not stats:
		stats=Game.player_stats
	stats.health_changed.connect(update_heath)
	stats.ink_changed.connect(update_ink)
	update_ink()
	update_heath(true)
	
func update_heath(skip_anim:=false) -> void :
	var percentage :=stats.health / float(stats.max_health)
	health_bar.value = percentage
	
	if skip_anim :
		eased_health_bar.value = percentage
	else:
		create_tween().tween_property(eased_health_bar,"value",percentage,0.3)
	
func update_ink() -> void :
	var percentage :=stats.ink / float(stats.max_ink)
	ink_bar.value = percentage
	



	
