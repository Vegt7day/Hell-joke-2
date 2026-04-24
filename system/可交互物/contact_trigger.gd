class_name ContactTrigger
extends Area2D

signal interacted

func _init() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact() -> void:
	print("[Interact] %s" % name)
	interacted.emit()


func _on_body_entered(player: Player) -> void:
	player.register_contact_trigger(self)


func _on_body_exited(player: Player) -> void:
	player.unregister_contact_trigger(self)
