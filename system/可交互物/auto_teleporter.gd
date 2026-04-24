class_name AutoTeleporter
extends ContactTrigger

@export_file("*.tscn") var path: String
@export var entry_point: String


func interact() -> void:
	super()
	Game.change_scene(path, { "entry_point": entry_point })
