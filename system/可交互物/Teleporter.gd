class_name Teleporter

extends Interactable

@export_file("*.tscn") var path:String

func interact()->void:
	super()
	get_tree().change_scene_to_file(path)
	
