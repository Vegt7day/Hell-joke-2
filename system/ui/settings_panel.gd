extends CanvasLayer

@onready var _body: Control = $Root/Center/SettingsBody


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 115
	if _body.has_signal(&"close_requested"):
		_body.close_requested.connect(_on_body_close_request)


func _on_body_close_request() -> void:
	if _body.is_in_group(&"settings_ui"):
		_body.remove_from_group(&"settings_ui")
	queue_free()
