extends Interactable
class_name ShangYangStoryInteract


func set_interact_enabled(on: bool) -> void:
	monitoring = on
	monitorable = on


func interact() -> void:
	var sy := get_parent()
	if not sy is ShangYang:
		return
	if not (sy as ShangYang).can_use_story_interact():
		return
	super.interact()
	(sy as ShangYang).on_player_story_interact()
