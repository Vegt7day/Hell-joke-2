class_name Teleporter

extends Interactable
@export var entry_point:String

@export_file("*.tscn") var path:String

func interact()->void:
	super()
	Game.change_scene(path,entry_point)
