class_name 自动传送门

extends 接触触发

@export_file("*.tscn") var path:String

func interact()->void:
	super()
	get_tree().change_scene_to_file(path)
	
